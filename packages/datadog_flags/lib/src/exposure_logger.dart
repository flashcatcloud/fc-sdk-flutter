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
import 'sdk_metadata.dart';

class ExposureLogger {
  final FlagsRuntime runtime;
  final Map<_ExposureCacheKey, _ExposureCacheValue> _loggedAssignments = {};
  final List<Map<String, Object?>> _pendingExposures = [];
  Timer? _flushTimer;

  ExposureLogger(this.runtime);

  Future<void> logExposure({
    required String flagKey,
    required FlagAssignment assignment,
    required FlagsEvaluationContext evaluationContext,
  }) async {
    final configuration = runtime.configuration;
    if (!configuration.trackExposures || !assignment.doLog) {
      return;
    }

    final cacheKey = _ExposureCacheKey(
      targetingKey: evaluationContext.targetingKey,
      flagKey: flagKey,
    );
    final cacheValue = _ExposureCacheValue(
      allocationKey: assignment.allocationKey,
      variationKey: assignment.variationKey,
    );
    if (_loggedAssignments[cacheKey] == cacheValue) {
      return;
    }
    _loggedAssignments[cacheKey] = cacheValue;

    _pendingExposures.add(
      _buildExposureEvent(
        flagKey: flagKey,
        assignment: assignment,
        evaluationContext: evaluationContext,
      ),
    );
    _scheduleFlush();
  }

  Future<void> flush({bool rescheduleOnFailure = false}) async {
    _flushTimer?.cancel();
    _flushTimer = null;

    if (_pendingExposures.isEmpty) {
      return;
    }

    final exposures = List<Map<String, Object?>>.from(_pendingExposures);
    _pendingExposures.clear();

    try {
      final response = await runtime.httpClient.post(
        _exposureEndpoint(),
        headers: {
          'Content-Type': 'text/plain;charset=UTF-8',
          'DD-API-KEY': runtime.datadogConfig.clientToken,
          'DD-EVP-ORIGIN': datadogFlagsSource,
          'DD-EVP-ORIGIN-VERSION': datadogFlagsSdkVersion,
          'DD-REQUEST-ID': const Uuid().v4(),
        },
        body: exposures.map(jsonEncode).join('\n'),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _restore(exposures, reschedule: rescheduleOnFailure);
      }
    } catch (_) {
      _restore(exposures, reschedule: rescheduleOnFailure);
    }
  }

  Map<String, Object?> _buildExposureEvent({
    required String flagKey,
    required FlagAssignment assignment,
    required FlagsEvaluationContext evaluationContext,
  }) {
    final subject = _removeNullValues({
      'id': evaluationContext.targetingKey,
      'attributes': sanitizeJsonValue(evaluationContext.attributes),
    });
    return {
      'timestamp': runtime.configuration.dateProvider().millisecondsSinceEpoch,
      'allocation': {'key': assignment.allocationKey},
      'flag': {'key': flagKey},
      'variant': {'key': assignment.variationKey},
      'subject': subject,
    };
  }

  void _restore(
    List<Map<String, Object?>> exposures, {
    required bool reschedule,
  }) {
    _pendingExposures.insertAll(0, exposures);
    if (reschedule) {
      _scheduleFlush();
    }
  }

  void _scheduleFlush() {
    _flushTimer ??= Timer(_exposureFlushDelay, () {
      _flushTimer = null;
      unawaited(flush(rescheduleOnFailure: true));
    });
  }

  Uri _exposureEndpoint() {
    final datadogConfig = runtime.datadogConfig;
    final endpoint = runtime.configuration.customExposureEndpoint ??
        datadogConfig.intakeEndpoint().replace(path: '/api/v2/exposures');
    return endpoint.replace(
      queryParameters: {
        ...endpoint.queryParameters,
        'ddsource': datadogFlagsSource,
      },
    );
  }
}

final class _ExposureCacheKey {
  final String? targetingKey;
  final String flagKey;

  const _ExposureCacheKey({
    required this.targetingKey,
    required this.flagKey,
  });

  @override
  bool operator ==(Object other) {
    return other is _ExposureCacheKey &&
        other.targetingKey == targetingKey &&
        other.flagKey == flagKey;
  }

  @override
  int get hashCode {
    return Object.hash(targetingKey, flagKey);
  }
}

final class _ExposureCacheValue {
  final String allocationKey;
  final String variationKey;

  const _ExposureCacheValue({
    required this.allocationKey,
    required this.variationKey,
  });

  @override
  bool operator ==(Object other) {
    return other is _ExposureCacheValue &&
        other.allocationKey == allocationKey &&
        other.variationKey == variationKey;
  }

  @override
  int get hashCode {
    return Object.hash(allocationKey, variationKey);
  }
}

const _exposureFlushDelay = Duration(seconds: 10);

Map<String, Object?> _removeNullValues(Map<String, Object?> input) {
  return Map.fromEntries(input.entries.where((entry) => entry.value != null));
}
