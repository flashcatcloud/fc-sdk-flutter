// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'evaluation_context.dart';
import 'flags_error.dart';

/// Evaluates feature flags for one current evaluation context.
///
/// Create separate clients for separate mobile subjects, such as logged-out and
/// logged-in users. Clients are local to the Dart isolate where they are
/// created and must be recreated in background isolates.
abstract interface class DatadogFlagsClient {
  String get name;

  Future<void> initialize(
    FlagsEvaluationContext context,
  );

  FlagDetails<bool> getBooleanDetails({
    required String key,
    required bool defaultValue,
  });

  FlagDetails<String> getStringDetails({
    required String key,
    required String defaultValue,
  });

  FlagDetails<int> getIntegerDetails({
    required String key,
    required int defaultValue,
  });

  FlagDetails<double> getDoubleDetails({
    required String key,
    required double defaultValue,
  });

  FlagDetails<Object?> getObjectDetails({
    required String key,
    required Object? defaultValue,
  });

  Future<void> shutdown();
}

class FlagDetails<T> {
  final String key;
  final T value;
  final String? variant;
  final String? reason;
  final FlagEvaluationError? error;

  const FlagDetails({
    required this.key,
    required this.value,
    this.variant,
    this.reason,
    this.error,
  });
}
