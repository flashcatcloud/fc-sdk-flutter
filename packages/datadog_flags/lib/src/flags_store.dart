// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:meta/meta.dart';

import 'assignment.dart';
import 'evaluation_context.dart';

abstract class DatadogFlagsStore {
  Future<FlagsData?> read(String clientName);
  Future<void> write(String clientName, FlagsData data);
  Future<void> delete(String clientName);
}

@immutable
class FlagsData {
  final Map<String, FlagAssignment> flags;
  final FlagsEvaluationContext context;
  final DateTime date;

  const FlagsData({
    required this.flags,
    required this.context,
    required this.date,
  });

  factory FlagsData.fromJson(Map<String, Object?> json) {
    final flags = json['flags'] as Map<String, Object?>? ?? const {};
    return FlagsData(
      flags: flags.map((key, value) {
        return MapEntry(
          key,
          FlagAssignment.fromJson(Map<String, Object?>.from(value as Map)),
        );
      }),
      context: FlagsEvaluationContext.fromJson(
        Map<String, Object?>.from(json['context'] as Map),
      ),
      date: DateTime.parse(json['date'] as String),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'flags': flags.map((key, value) => MapEntry(key, value.toJson())),
      'context': context.toJson(),
      'date': date.toIso8601String(),
    };
  }
}

class InMemoryDatadogFlagsStore implements DatadogFlagsStore {
  final Map<String, FlagsData> _values = {};

  @override
  Future<FlagsData?> read(String clientName) async {
    final value = _values[clientName];
    return value == null ? null : _cloneFlagsData(value);
  }

  @override
  Future<void> write(String clientName, FlagsData data) async {
    _values[clientName] = _cloneFlagsData(data);
  }

  @override
  Future<void> delete(String clientName) async {
    _values.remove(clientName);
  }
}

FlagsData _cloneFlagsData(FlagsData value) {
  return FlagsData.fromJson(value.toJson());
}
