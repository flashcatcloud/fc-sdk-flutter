// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'assignment.dart';
import 'evaluation_context.dart';
import 'flags_runtime.dart';
import 'json_value.dart';

class EvaluationAggregator {
  final FlagsRuntime runtime;
  final Map<String, _AggregatedEvaluation> _aggregations = {};
  Timer? _flushTimer;

  EvaluationAggregator(this.runtime) {
    if (runtime.configuration.trackEvaluations) {
      _flushTimer = Timer.periodic(
        runtime.configuration.evaluationFlushInterval,
        (_) => unawaited(flush()),
      );
    }
  }

  void recordEvaluation({
    required String flagKey,
    required FlagAssignment? assignment,
    required FlagsEvaluationContext evaluationContext,
    required String? error,
  }) {
    final configuration = runtime.configuration;
    if (!configuration.trackEvaluations) {
      return;
    }

    final now = configuration.dateProvider().millisecondsSinceEpoch;
    final ddContext = _datadogContext();
    final key = _aggregationKey(
      flagKey: flagKey,
      allocationKey: assignment?.allocationKey,
      variantKey: assignment?.variationKey,
      evaluationContext: evaluationContext,
      ddContext: ddContext,
      error: error,
    );
    final existing = _aggregations[key];
    if (existing != null) {
      existing.evaluationCount += 1;
      existing.lastEvaluation = now;
      return;
    }

    final runtimeDefaultUsed = assignment == null || error != null;
    _aggregations[key] = _AggregatedEvaluation(
      aggregationKey: key,
      flagKey: flagKey,
      variantKey: assignment?.variationKey,
      allocationKey: assignment?.allocationKey,
      targetingKey: evaluationContext.targetingKey,
      error: error,
      attributes: evaluationContext.attributes,
      ddContext: ddContext,
      firstEvaluation: now,
      lastEvaluation: now,
      evaluationCount: 1,
      runtimeDefaultUsed: runtimeDefaultUsed,
    );

    if (_aggregations.length >= configuration.evaluationMaxBatchSize) {
      unawaited(flush());
    }
  }

  Future<void> flush() async {
    final configuration = runtime.configuration;
    if (!configuration.trackEvaluations || _aggregations.isEmpty) {
      return;
    }

    final evaluations = List<_AggregatedEvaluation>.from(_aggregations.values);
    _aggregations.clear();

    final endpoint = _evaluationEndpoint();
    final body = jsonEncode({
      'context': _datadogContext(),
      'flagEvaluations': evaluations.map((e) => e.toJson()).toList(),
    });

    try {
      final response = await runtime.httpClient.post(
        endpoint,
        headers: {
          'Content-Type': 'application/json',
          'DD-API-KEY': runtime.datadogConfig.clientToken,
          'DD-EVP-ORIGIN': runtime.datadogConfig.source,
          'DD-EVP-ORIGIN-VERSION': runtime.datadogConfig.sdkVersion,
          'DD-REQUEST-ID': const Uuid().v4(),
        },
        body: body,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _restore(evaluations);
      }
    } catch (_) {
      _restore(evaluations);
    }
  }

  void dispose() {
    _flushTimer?.cancel();
    _flushTimer = null;
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
    final datadogConfig = runtime.datadogConfig;
    final endpoint = runtime.configuration.customEvaluationEndpoint ??
        datadogConfig.intakeEndpoint().replace(path: '/api/v2/flagevaluation');
    return endpoint.replace(
      queryParameters: {
        ...endpoint.queryParameters,
        'ddsource': datadogConfig.source,
      },
    );
  }

  Map<String, Object?> _datadogContext() {
    final applicationId = runtime.datadogConfig.applicationId;
    return _removeNullValues({
      'env': runtime.datadogConfig.env,
      'rum': applicationId == null
          ? null
          : {
              'application': {'id': applicationId},
              'view': null,
            },
    });
  }
}

String _aggregationKey({
  required String flagKey,
  required String? allocationKey,
  required String? variantKey,
  required FlagsEvaluationContext evaluationContext,
  required Map<String, Object?>? ddContext,
  required String? error,
}) {
  return jsonEncode({
    'flagKey': flagKey,
    'variantKey': variantKey,
    'allocationKey': allocationKey,
    'targetingKey': evaluationContext.targetingKey,
    'error': error,
    'context': _sortedJson(evaluationContext.attributes),
    'dd': _sortedJson(ddContext),
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
  final Map<String, Object?>? ddContext;
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
    required this.ddContext,
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
      'dd': ddContext,
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
  return Map.fromEntries(input.entries.where((entry) => entry.value != null));
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
