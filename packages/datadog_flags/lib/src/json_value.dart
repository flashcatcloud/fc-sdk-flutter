// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

/// Recursively validates values that will be JSON encoded.
///
/// This keeps targeting attributes and object flag values from carrying Dart
/// objects that `jsonEncode` cannot represent.
Object? sanitizeJsonValue(Object? value) {
  if (value == null ||
      value is String ||
      value is bool ||
      value is int ||
      value is double) {
    return value;
  }
  if (value is Map<Object?, Object?>) {
    return value.map((key, value) {
      if (key is! String) {
        throw ArgumentError.value(
          key,
          'key',
          'JSON object keys must be String',
        );
      }
      return MapEntry(key, sanitizeJsonValue(value));
    });
  }
  if (value is Iterable<Object?>) {
    return value.map(sanitizeJsonValue).toList();
  }
  throw ArgumentError.value(value, 'value', 'Unsupported JSON value');
}
