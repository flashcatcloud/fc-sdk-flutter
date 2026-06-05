// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'json_value.dart';

part 'flags_context.g.dart';

@immutable
@JsonSerializable()
final class FlagsEvaluationContext {
  static const empty = FlagsEvaluationContext();

  @JsonKey(includeIfNull: false)
  final String? targetingKey;
  @JsonKey(fromJson: _attributesFromJson, toJson: sanitizeJsonValue)
  final Map<String, Object?> attributes;

  const FlagsEvaluationContext({
    this.targetingKey,
    this.attributes = const {},
  });

  factory FlagsEvaluationContext.fromJson(Map<String, Object?> json) =>
      _$FlagsEvaluationContextFromJson(json);

  Map<String, Object?> toJson() => _$FlagsEvaluationContextToJson(this);
}

Map<String, Object?> _attributesFromJson(Object? value) {
  if (value == null) {
    return const {};
  }
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  throw FormatException('attributes must be a JSON object');
}
