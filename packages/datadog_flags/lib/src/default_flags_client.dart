// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'assignment.dart';
import 'flags_client.dart';
import 'flags_context.dart';
import 'flags_details.dart';
import 'flags_error.dart';
import 'flags_repository.dart';

class DefaultDatadogFlagsClient implements DatadogFlagsClient {
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
    return _getDetails(
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
    return _getDetails(
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
    return _getDetails(
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
    return _getDetails(
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
    return _getDetails(
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
  Future<void> flush() async {}

  @override
  Future<void> reset() {
    return _repository.reset();
  }

  @override
  Future<void> dispose() async {}

  FlagDetails<T> _getDetails<T>({
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

    if (requestedType == FlagVariationType.object &&
        assignment.variationType != FlagVariationType.object) {
      return FlagDetails(
        key: key,
        value: defaultValue,
        error: FlagEvaluationError.typeMismatch,
      );
    }

    final typedValue = _typedValue<T>(assignment, requestedType);
    if (!typedValue.matched) {
      return FlagDetails(
        key: key,
        value: defaultValue,
        error: FlagEvaluationError.typeMismatch,
      );
    }

    return FlagDetails(
      key: key,
      value: typedValue.value as T,
      variant: assignment.variationKey,
      reason: assignment.reason,
    );
  }

  ({bool matched, T? value}) _typedValue<T>(
    FlagAssignment assignment,
    FlagVariationType requestedType,
  ) {
    final variationValue = assignment.variationValue;
    final assignmentType = assignment.variationType;
    final Object? value = switch (requestedType) {
      FlagVariationType.boolean
          when assignmentType == FlagVariationType.boolean &&
              variationValue is bool =>
        variationValue,
      FlagVariationType.string
          when assignmentType == FlagVariationType.string &&
              variationValue is String =>
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
      _ => null,
    };

    if (value == null && requestedType != FlagVariationType.object) {
      return (matched: false, value: null);
    }

    if (value is! T && !(requestedType == FlagVariationType.object)) {
      return (matched: false, value: null);
    }

    return (matched: true, value: value as T?);
  }
}
