// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 'datadog_flags_config.dart';
import 'flags_store.dart';

@immutable
final class DatadogFlagsConfiguration {
  static const defaultEvaluationFlushInterval = Duration(seconds: 10);
  static const minEvaluationFlushInterval = Duration(seconds: 1);
  static const maxEvaluationFlushInterval = Duration(seconds: 60);

  final Uri? customFlagsEndpoint;
  final Map<String, String>? customFlagsHeaders;
  final Uri? customExposureEndpoint;
  final bool trackExposures;
  final Uri? customEvaluationEndpoint;
  final bool trackEvaluations;
  final Duration _evaluationFlushInterval;
  final http.Client? httpClient;
  final DatadogFlagsConfig? datadogConfig;
  final DatadogFlagsStore? store;
  final DateTime Function() dateProvider;

  const DatadogFlagsConfiguration({
    this.customFlagsEndpoint,
    this.customFlagsHeaders,
    this.customExposureEndpoint,
    this.trackExposures = true,
    this.customEvaluationEndpoint,
    this.trackEvaluations = true,
    Duration evaluationFlushInterval = defaultEvaluationFlushInterval,
    this.httpClient,
    this.datadogConfig,
    this.store,
    this.dateProvider = DateTime.now,
  }) : _evaluationFlushInterval = evaluationFlushInterval;

  /// Flush interval coerced to the same 1s-60s bounds used by the iOS and
  /// Android Flags SDKs.
  Duration get evaluationFlushInterval {
    if (_evaluationFlushInterval < minEvaluationFlushInterval) {
      return minEvaluationFlushInterval;
    }
    if (_evaluationFlushInterval > maxEvaluationFlushInterval) {
      return maxEvaluationFlushInterval;
    }
    return _evaluationFlushInterval;
  }
}
