// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

import 'assignment.dart';
import 'datadog_flags_config.dart';
import 'evaluation_context.dart';
import 'flags_configuration.dart';
import 'json_value.dart';
import 'sdk_metadata.dart';

class EvaluationAggregator {
  static const int defaultMaxBatchSize = 1000;
  static const Duration defaultUploadTimeout = Duration(seconds: 15);
  static const Duration defaultRetryDelay = Duration(milliseconds: 500);

  @visibleForTesting
  static int maxBatchSize = defaultMaxBatchSize;

  @visibleForTesting
  static Duration uploadTimeout = defaultUploadTimeout;

  @visibleForTesting
  static Duration retryDelay = defaultRetryDelay;

  final DatadogFlagsConfiguration configuration;
  final DatadogFlagsConfig datadogConfig;
  final http.Client httpClient;
  final Map<String, _AggregatedEvaluation> _aggregations = {};
  Future<bool>? _uploadInFlight;
  Future<void>? _shutdownInFlight;
  Timer? _periodicFlushTimer;
  bool _shutdownDrainActive = false;

  EvaluationAggregator({
    required this.configuration,
    required this.datadogConfig,
    required this.httpClient,
  }) {
    _periodicFlushTimer = Timer.periodic(
      configuration.evaluationFlushInterval,
      (_) => unawaited(flush()),
    );
  }

  void recordEvaluation({
    required String flagKey,
    required FlagAssignment? assignment,
    required FlagsEvaluationContext evaluationContext,
    required String? error,
  }) {
    final now = configuration.dateProvider().millisecondsSinceEpoch;
    final key = _aggregationKey(
      flagKey: flagKey,
      allocationKey: assignment?.allocationKey,
      variantKey: assignment?.variationKey,
      evaluationContext: evaluationContext,
      error: error,
    );
    final existing = _aggregations[key];
    if (existing != null) {
      existing.evaluationCount += 1;
      existing.lastEvaluation = now;
      return;
    }

    final runtimeDefaultUsed =
        assignment == null || assignment.reason == 'DEFAULT' || error != null;
    _aggregations[key] = _AggregatedEvaluation(
      aggregationKey: key,
      flagKey: flagKey,
      variantKey: assignment?.variationKey,
      allocationKey: assignment?.allocationKey,
      targetingKey: evaluationContext.targetingKey,
      error: error,
      attributes: evaluationContext.attributes,
      firstEvaluation: now,
      lastEvaluation: now,
      evaluationCount: 1,
      runtimeDefaultUsed: runtimeDefaultUsed,
    );

    if (_aggregations.length >= maxBatchSize) {
      unawaited(_flushPendingEvaluations(rescheduleOnFailure: true));
    }
  }

  Future<void> flush() {
    return _flushPendingEvaluations(rescheduleOnFailure: true);
  }

  Future<void> shutdown() {
    _periodicFlushTimer?.cancel();
    _periodicFlushTimer = null;

    final shutdownInFlight = _shutdownInFlight;
    if (shutdownInFlight != null) {
      return shutdownInFlight;
    }

    late final Future<void> shutdownOperation;
    shutdownOperation = _shutdownDrain().whenComplete(() {
      if (identical(_shutdownInFlight, shutdownOperation)) {
        _shutdownInFlight = null;
      }
    });
    _shutdownInFlight = shutdownOperation;
    return shutdownOperation;
  }

  Future<void> _shutdownDrain() async {
    _shutdownDrainActive = true;
    try {
      final activeUpload = _uploadInFlight;
      if (activeUpload != null) {
        await activeUpload;
      }

      await _uploadPendingEvaluations(rescheduleOnFailure: false);
    } finally {
      _shutdownDrainActive = false;
    }
  }

  Future<void> _flushPendingEvaluations({
    required bool rescheduleOnFailure,
  }) async {
    if (_uploadInFlight != null) {
      return;
    }

    await _uploadPendingEvaluations(rescheduleOnFailure: rescheduleOnFailure);
  }

  Future<bool> _uploadPendingEvaluations({
    required bool rescheduleOnFailure,
  }) {
    final activeUpload = _uploadInFlight;
    if (activeUpload != null) {
      return activeUpload;
    }

    if (_aggregations.isEmpty) {
      return Future.value(true);
    }

    late final Future<bool> uploadOperation;
    uploadOperation = _uploadLoop(
      rescheduleOnFailure: rescheduleOnFailure,
    ).whenComplete(() {
      if (identical(_uploadInFlight, uploadOperation)) {
        _uploadInFlight = null;
      }
    });
    _uploadInFlight = uploadOperation;
    return uploadOperation;
  }

  Future<bool> _uploadLoop({
    required bool rescheduleOnFailure,
  }) async {
    var succeeded = true;
    while (_aggregations.isNotEmpty) {
      final evaluations =
          List<_AggregatedEvaluation>.from(_aggregations.values);
      _aggregations.clear();

      succeeded = await _sendEvaluations(evaluations);
      if (succeeded) {
        continue;
      }

      _restore(evaluations);
      if (!rescheduleOnFailure || _shutdownDrainActive) {
        return false;
      }

      await Future<void>.delayed(retryDelay);
      if (_shutdownDrainActive) {
        return false;
      }
    }
    return succeeded;
  }

  Future<bool> _sendEvaluations(
    List<_AggregatedEvaluation> evaluations,
  ) async {
    final endpoint = _evaluationEndpoint();
    final body = jsonEncode({
      'context': _datadogContext(),
      'flagEvaluations': evaluations.map((e) => e.toJson()).toList(),
    });

    try {
      final response = await httpClient
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'DD-API-KEY': datadogConfig.clientToken,
              'DD-EVP-ORIGIN': datadogFlagsSource,
              'DD-EVP-ORIGIN-VERSION': datadogFlagsSdkVersion,
              'DD-REQUEST-ID': const Uuid().v4(),
            },
            body: body,
          )
          .timeout(uploadTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    unawaited(shutdown());
  }

  void _restore(List<_AggregatedEvaluation> evaluations) {
    for (final evaluation in evaluations) {
      final existing = _aggregations[evaluation.aggregationKey];
      if (existing == null) {
        _aggregations[evaluation.aggregationKey] = evaluation;
        continue;
      }

      existing.firstEvaluation =
          existing.firstEvaluation < evaluation.firstEvaluation
              ? existing.firstEvaluation
              : evaluation.firstEvaluation;
      existing.lastEvaluation =
          existing.lastEvaluation > evaluation.lastEvaluation
              ? existing.lastEvaluation
              : evaluation.lastEvaluation;
      existing.evaluationCount += evaluation.evaluationCount;
    }
  }

  Uri _evaluationEndpoint() {
    final endpoint = configuration.customEvaluationEndpoint ??
        datadogConfig.intakeEndpoint().replace(path: '/api/v2/flagevaluation');
    return endpoint.replace(
      queryParameters: {
        ...endpoint.queryParameters,
        'ddsource': datadogFlagsSource,
      },
    );
  }

  Map<String, Object?> _datadogContext() {
    final applicationId = datadogConfig.applicationId;
    return _removeNullValues({
      'env': datadogConfig.env,
      'service': datadogConfig.service,
      'version': datadogConfig.version,
      'rum': applicationId == null
          ? null
          : {
              'application': {'id': applicationId},
            },
    });
  }
}

String _aggregationKey({
  required String flagKey,
  required String? allocationKey,
  required String? variantKey,
  required FlagsEvaluationContext evaluationContext,
  required String? error,
}) {
  return jsonEncode({
    'flagKey': flagKey,
    'variantKey': variantKey,
    'allocationKey': allocationKey,
    'targetingKey': evaluationContext.targetingKey,
    'error': error,
    'context': _sortedJson(evaluationContext.attributes),
  });
}

class _AggregatedEvaluation {
  final String aggregationKey;
  final String flagKey;
  final String? variantKey;
  final String? allocationKey;
  final String? targetingKey;
  final String? error;
  final Map<String, Object?> attributes;
  int firstEvaluation;
  int lastEvaluation;
  int evaluationCount;
  final bool runtimeDefaultUsed;

  _AggregatedEvaluation({
    required this.aggregationKey,
    required this.flagKey,
    required this.variantKey,
    required this.allocationKey,
    required this.targetingKey,
    required this.error,
    required this.attributes,
    required this.firstEvaluation,
    required this.lastEvaluation,
    required this.evaluationCount,
    required this.runtimeDefaultUsed,
  });

  Map<String, Object?> toJson() {
    final includeAssignment =
        !runtimeDefaultUsed && variantKey != null && allocationKey != null;
    final eventContext = _removeNullValues({
      'evaluation': attributes.isEmpty ? null : sanitizeJsonValue(attributes),
    });

    return _removeNullValues({
      'timestamp': firstEvaluation,
      'flag': {'key': flagKey},
      'first_evaluation': firstEvaluation,
      'last_evaluation': lastEvaluation,
      'evaluation_count': evaluationCount,
      'variant': includeAssignment ? {'key': variantKey} : null,
      'allocation': includeAssignment ? {'key': allocationKey} : null,
      'targeting_rule': null,
      'targeting_key': targetingKey,
      'runtime_default_used': runtimeDefaultUsed ? true : null,
      'error': error == null ? null : {'message': error},
      'context': eventContext.isEmpty ? null : eventContext,
    });
  }
}

Map<String, Object?> _removeNullValues(Map<String, Object?> input) {
  return Map.fromEntries(
    input.entries.where((entry) => entry.value != null).map(
        (entry) => MapEntry(entry.key, _removeNestedNullValues(entry.value))),
  );
}

Object? _removeNestedNullValues(Object? value) {
  if (value is Map<Object?, Object?>) {
    return Map.fromEntries(
      value.entries.where((entry) => entry.value != null).map((entry) {
        return MapEntry(
          entry.key.toString(),
          _removeNestedNullValues(entry.value),
        );
      }),
    );
  }
  if (value is Iterable<Object?>) {
    return value.map(_removeNestedNullValues).toList();
  }
  return value;
}

Object? _sortedJson(Object? value) {
  if (value is Map<Object?, Object?>) {
    final entries = value.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    return {
      for (final entry in entries)
        entry.key.toString(): _sortedJson(entry.value),
    };
  }
  if (value is Iterable<Object?>) {
    return value.map(_sortedJson).toList();
  }
  return value;
}
