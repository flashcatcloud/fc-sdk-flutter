// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:meta/meta.dart';

import 'json_value.dart';

enum FlagVariationType {
  boolean('boolean'),
  string('string'),
  integer('integer'),
  float('float'),
  number('number'),
  object('object');

  final String wireName;

  const FlagVariationType(this.wireName);

  factory FlagVariationType.fromWireName(String? value) {
    return switch (value) {
      'boolean' => FlagVariationType.boolean,
      'string' => FlagVariationType.string,
      'integer' => FlagVariationType.integer,
      'float' => FlagVariationType.float,
      'number' => FlagVariationType.number,
      'object' => FlagVariationType.object,
      _ => throw FormatException('Unsupported flag variation type: $value'),
    };
  }

  Object? decodeVariationValue(Object? value) {
    return switch (this) {
      FlagVariationType.boolean when value is bool => value,
      FlagVariationType.string when value is String => value,
      FlagVariationType.integer when value is int => value,
      FlagVariationType.float when value is num => value.toDouble(),
      FlagVariationType.number when value is num => value,
      FlagVariationType.object => sanitizeJsonValue(value),
      _ => throw FormatException('Invalid variation value for $wireName'),
    };
  }
}

@immutable
final class PrecomputedAssignments {
  final Map<String, FlagAssignment> flags;
  final DateTime? createdAt;
  final String? environment;

  const PrecomputedAssignments({
    required this.flags,
    this.createdAt,
    this.environment,
  });
}

@immutable
final class FlagAssignment {
  final String allocationKey;
  final String variationKey;
  final FlagVariationType variationType;
  final Object? variationValue;
  final String reason;
  final bool doLog;

  const FlagAssignment({
    required this.allocationKey,
    required this.variationKey,
    required this.variationType,
    required this.variationValue,
    required this.reason,
    required this.doLog,
  });

  factory FlagAssignment.fromJson(Map<String, Object?> json) {
    final typeName = json['variationType'] as String?;
    final value = json['variationValue'];
    final variationType = FlagVariationType.fromWireName(typeName);
    final variationValue = variationType.decodeVariationValue(value);

    return FlagAssignment(
      allocationKey: json['allocationKey'] as String,
      variationKey: json['variationKey'] as String,
      variationType: variationType,
      variationValue: variationValue,
      reason: json['reason'] as String,
      doLog: json['doLog'] as bool,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'allocationKey': allocationKey,
      'variationKey': variationKey,
      'variationType': variationType.wireName,
      'variationValue': sanitizeJsonValue(variationValue),
      'reason': reason,
      'doLog': doLog,
    };
  }

  Object? typedValue(FlagVariationType requestedType) {
    if (variationType == FlagVariationType.number) {
      return switch (requestedType) {
        FlagVariationType.integer when variationValue is int => variationValue,
        FlagVariationType.float when variationValue is num =>
          (variationValue as num).toDouble(),
        FlagVariationType.number when variationValue is num => variationValue,
        _ => null,
      };
    }

    if (variationType != requestedType) {
      return null;
    }

    return switch (requestedType) {
      FlagVariationType.boolean when variationValue is bool => variationValue,
      FlagVariationType.string when variationValue is String => variationValue,
      FlagVariationType.integer when variationValue is int => variationValue,
      FlagVariationType.float when variationValue is double => variationValue,
      FlagVariationType.number when variationValue is num => variationValue,
      FlagVariationType.object => variationValue,
      _ => null,
    };
  }
}
