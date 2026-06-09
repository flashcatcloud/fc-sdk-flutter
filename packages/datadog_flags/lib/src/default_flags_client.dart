// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';

import 'assignment.dart';
import 'evaluation_context.dart';
import 'exposure_logger.dart';
import 'flag_assignments_fetcher.dart';
import 'flags_client.dart';
import 'flags_error.dart';

class DefaultDatadogFlagsClient implements DatadogFlagsClient {
  static final Object _typeMismatch = Object();

  @override
  final String name;
  final FlagAssignmentsFetcher _fetcher;
  final ExposureLogger _exposureLogger;

  FlagsEvaluationContext? _context;
  Map<String, FlagAssignment> _flags = const {};
  int _contextRequestId = 0;

  DefaultDatadogFlagsClient({
    required this.name,
    required FlagAssignmentsFetcher fetcher,
    required ExposureLogger exposureLogger,
  })  : _fetcher = fetcher,
        _exposureLogger = exposureLogger;

  @override
  Future<void> initialize(FlagsEvaluationContext context) async {
    // Multiple initialize calls can be in flight at once. Only the latest
    // request is allowed to publish assignments back into this client.
    final requestId = ++_contextRequestId;
    final PrecomputedAssignments assignments;
    try {
      assignments = await _fetcher.fetch(context);
    } catch (_) {
      if (requestId == _contextRequestId) {
        _context = null;
        _flags = const {};
      }
      return;
    }

    if (requestId != _contextRequestId) {
      return;
    }

    _context = context;
    _flags = assignments.flags;
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
  Future<void> shutdown() async {
    _contextRequestId++;
    _context = null;
    _flags = const {};
  }

  FlagDetails<T> getDetails<T>({
    required String key,
    required T defaultValue,
    required FlagVariationType requestedType,
  }) {
    final context = _context;
    if (context == null) {
      return FlagDetails(
        key: key,
        value: defaultValue,
        error: FlagEvaluationError.providerNotReady,
      );
    }

    final assignment = _flags[key];
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

    unawaited(
      _exposureLogger.logExposure(
        flagKey: key,
        assignment: assignment,
        evaluationContext: context,
      ),
    );

    return FlagDetails(
      key: key,
      value: resolvedValue as T,
      variant: assignment.variationKey,
      reason: assignment.reason,
    );
  }
}
