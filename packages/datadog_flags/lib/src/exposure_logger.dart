// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'assignment.dart';
import 'evaluation_context.dart';
import 'flags_runtime.dart';
import 'json_value.dart';

class ExposureLogger {
  final FlagsRuntime runtime;
  final Set<String> _loggedExposures = {};

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

    final exposureKey = [
      evaluationContext.targetingKey,
      flagKey,
      assignment.allocationKey,
      assignment.variationKey,
    ].join('|');
    if (!_loggedExposures.add(exposureKey)) {
      return;
    }

    try {
      final endpoint = _exposureEndpoint();
      final subject = _removeNullValues({
        'id': evaluationContext.targetingKey,
        'attributes': sanitizeJsonValue(evaluationContext.attributes),
      });
      final event = {
        'timestamp': configuration.dateProvider().millisecondsSinceEpoch,
        'allocation': {'key': assignment.allocationKey},
        'flag': {'key': flagKey},
        'variant': {'key': assignment.variationKey},
        'subject': subject,
      };
      final response = await runtime.httpClient.post(
        endpoint,
        headers: {
          'Content-Type': 'text/plain;charset=UTF-8',
          'DD-API-KEY': runtime.datadogConfig.clientToken,
          'DD-EVP-ORIGIN': runtime.datadogConfig.source,
          'DD-EVP-ORIGIN-VERSION': runtime.datadogConfig.sdkVersion,
          'DD-REQUEST-ID': const Uuid().v4(),
        },
        body: jsonEncode(event),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _loggedExposures.remove(exposureKey);
      }
    } catch (_) {
      _loggedExposures.remove(exposureKey);
    }
  }

  Uri _exposureEndpoint() {
    final datadogConfig = runtime.datadogConfig;
    final endpoint = runtime.configuration.customExposureEndpoint ??
        datadogConfig.intakeEndpoint().replace(path: '/api/v2/exposures');
    return endpoint.replace(
      queryParameters: {
        ...endpoint.queryParameters,
        'ddsource': datadogConfig.source,
      },
    );
  }
}

Map<String, Object?> _removeNullValues(Map<String, Object?> input) {
  return Map.fromEntries(input.entries.where((entry) => entry.value != null));
}
