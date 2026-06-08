// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'assignment.dart';
import 'flags_client.dart';
import 'flags_context.dart';
import 'flags_error.dart';
import 'flags_repository.dart';

class DefaultDatadogFlagsClient implements DatadogFlagsClient {
  static final Object _typeMismatch = Object();

  @override
  final String name;
  final FlagsRepository _repository;

  DefaultDatadogFlagsClient({
    required this.name,
    required FlagsRepository repository,
  }) : _repository = repository;

  @override
  Future<void> setEvaluationContext(
    FlagsEvaluationContext context,
  ) async {
    await _repository.setEvaluationContext(context);
  }

  @override
  FlagDetails<bool> getBooleanDetails({
    required String key,
    required bool defaultValue,
  }) {
    return getDetails(
      key: key,
      defaultValue: defaultValue,
      requestedType: FlagVariationType.boolean,
    );
  }

  @override
  bool getBooleanValue({
    required String key,
    required bool defaultValue,
  }) {
    return getBooleanDetails(key: key, defaultValue: defaultValue).value;
  }

  @override
  FlagDetails<String> getStringDetails({
    required String key,
    required String defaultValue,
  }) {
    return getDetails(
      key: key,
      defaultValue: defaultValue,
      requestedType: FlagVariationType.string,
    );
  }

  @override
  String getStringValue({
    required String key,
    required String defaultValue,
  }) {
    return getStringDetails(key: key, defaultValue: defaultValue).value;
  }

  @override
  FlagDetails<int> getIntegerDetails({
    required String key,
    required int defaultValue,
  }) {
    return getDetails(
      key: key,
      defaultValue: defaultValue,
      requestedType: FlagVariationType.integer,
    );
  }

  @override
  int getIntegerValue({
    required String key,
    required int defaultValue,
  }) {
    return getIntegerDetails(key: key, defaultValue: defaultValue).value;
  }

  @override
  FlagDetails<double> getDoubleDetails({
    required String key,
    required double defaultValue,
  }) {
    return getDetails(
      key: key,
      defaultValue: defaultValue,
      requestedType: FlagVariationType.float,
    );
  }

  @override
  double getDoubleValue({
    required String key,
    required double defaultValue,
  }) {
    return getDoubleDetails(key: key, defaultValue: defaultValue).value;
  }

  @override
  FlagDetails<Object?> getObjectDetails({
    required String key,
    required Object? defaultValue,
  }) {
    return getDetails(
      key: key,
      defaultValue: defaultValue,
      requestedType: FlagVariationType.object,
    );
  }

  @override
  Object? getObjectValue({
    required String key,
    required Object? defaultValue,
  }) {
    return getObjectDetails(key: key, defaultValue: defaultValue).value;
  }

  @override
  Future<void> reset() {
    return _repository.reset();
  }

  FlagDetails<T> getDetails<T>({
    required String key,
    required T defaultValue,
    required FlagVariationType requestedType,
  }) {
    final context = _repository.context;
    if (context == null) {
      return FlagDetails(
        key: key,
        value: defaultValue,
        error: FlagEvaluationError.providerNotReady,
      );
    }

    final assignment = _repository.flagAssignment(key);
    if (assignment == null) {
      return FlagDetails(
        key: key,
        value: defaultValue,
        error: FlagEvaluationError.flagNotFound,
      );
    }

    final variationValue = assignment.variationValue;
    final assignmentType = assignment.variationType;
    final resolvedValue = switch (requestedType) {
      FlagVariationType.boolean
          when assignmentType == FlagVariationType.boolean =>
        variationValue,
      FlagVariationType.string
          when assignmentType == FlagVariationType.string =>
        variationValue,
      FlagVariationType.integer
          when (assignmentType == FlagVariationType.integer ||
                  assignmentType == FlagVariationType.number) &&
              variationValue is int =>
        variationValue,
      FlagVariationType.float
          when (assignmentType == FlagVariationType.float ||
                  assignmentType == FlagVariationType.number) &&
              variationValue is num =>
        variationValue.toDouble(),
      FlagVariationType.object
          when assignmentType == FlagVariationType.object =>
        variationValue,
      _ => _typeMismatch,
    };

    if (identical(resolvedValue, _typeMismatch)) {
      return FlagDetails(
        key: key,
        value: defaultValue,
        error: FlagEvaluationError.typeMismatch,
      );
    }

    return FlagDetails(
      key: key,
      value: resolvedValue as T,
      variant: assignment.variationKey,
      reason: assignment.reason,
    );
  }
}
