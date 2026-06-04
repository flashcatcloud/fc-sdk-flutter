// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'json_value.dart';

class DatadogFlagsEvaluationContext {
  static const empty = DatadogFlagsEvaluationContext();

  final String? targetingKey;
  final Map<String, Object?> attributes;

  const DatadogFlagsEvaluationContext({
    this.targetingKey,
    this.attributes = const {},
  });

  factory DatadogFlagsEvaluationContext.fromJson(Map<String, Object?> json) {
    final targetingKey = json['targetingKey'];
    return DatadogFlagsEvaluationContext(
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
