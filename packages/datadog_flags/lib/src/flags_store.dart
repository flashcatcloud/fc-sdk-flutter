// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:meta/meta.dart';

import 'assignment.dart';
import 'evaluation_context.dart';

abstract class DatadogFlagsStore {
  Future<Map<String, Object?>?> read(String clientName);
  Future<void> write(String clientName, Map<String, Object?> data);
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
  final Map<String, Map<String, Object?>> _values = {};

  @override
  Future<Map<String, Object?>?> read(String clientName) async {
    final value = _values[clientName];
    return value == null ? null : _cloneJsonObject(value);
  }

  @override
  Future<void> write(String clientName, Map<String, Object?> data) async {
    _values[clientName] = _cloneJsonObject(data);
  }

  @override
  Future<void> delete(String clientName) async {
    _values.remove(clientName);
  }
}

Map<String, Object?> _cloneJsonObject(Map<String, Object?> value) {
  return Map<String, Object?>.from(jsonDecode(jsonEncode(value)) as Map);
}
