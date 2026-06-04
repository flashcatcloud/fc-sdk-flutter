// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:meta/meta.dart';

import 'json_value.dart';

@immutable
final class FlagsEvaluationContext {
  static const empty = FlagsEvaluationContext();

  final String? targetingKey;
  final Map<String, Object?> attributes;

  const FlagsEvaluationContext({
    this.targetingKey,
    this.attributes = const {},
  });

  factory FlagsEvaluationContext.fromJson(Map<String, Object?> json) {
    final targetingKey = json['targetingKey'];
    return FlagsEvaluationContext(
      targetingKey: targetingKey is String ? targetingKey : null,
      attributes: Map<String, Object?>.from(
        json['attributes'] as Map<String, Object?>? ?? const {},
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      if (targetingKey != null) 'targetingKey': targetingKey,
      'attributes': sanitizeJsonValue(attributes),
    };
  }
}
