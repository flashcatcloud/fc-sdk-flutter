// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:convert';

import 'package:jni/jni.dart';

import '../../datadog_flutter_plugin.dart';
import '../internal_logger.dart';
import '../rum/rum_mapper_proxy.dart';
import 'datadog_android_bridge.dart';

typedef _MapperFunction = Map<String, dynamic>? Function(Map<String, dynamic>);

class AndroidRumEventMapper extends RumMapperProxy {
  final InternalLogger _internalLogger;

  AndroidRumEventMapper(DatadogRumConfiguration config, InternalLogger logger)
    : _internalLogger = logger,
      super(
        viewEventMapper: config.viewEventMapper,
        actionEventMapper: config.actionEventMapper,
        resourceEventMapper: config.resourceEventMapper,
        errorEventMapper: config.errorEventMapper,
        longTaskEventMapper: config.longTaskEventMapper,
      ) {
    final listener = DatadogRumEventMapper$EventMapper.implement(
      $DatadogRumEventMapper$EventMapper(
        mapViewEvent: (encoded) {
          // Map View Event is weird because it's the only one that doesn't allow returning null, so it has special handling
          final decoded = _safeDecodeJavaJson(encoded);
          if (decoded == null) return encoded;

          final mapped = mapViewEvent(decoded);
          return _safeEncodeJavaJson(mapped, fallback: encoded) ?? encoded;
        },
        mapActionEvent: (encoded) => _callMapper(encoded, mapActionEvent),
        mapResourceEvent: (encoded) => _callMapper(encoded, mapResourceEvent),
        mapErrorEvent: (encoded) => _callMapper(encoded, mapErrorEvent),
        mapLongTaskEvent: (encoded) => _callMapper(encoded, mapLongTaskEvent),
      ),
    );

    DatadogRumPlugin.Companion.setRumEventMapper(listener);
  }

  Map<String, dynamic>? _safeDecodeJavaJson(JString json) {
    try {
      final jsonString = json.toDartString();
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e, st) {
      _internalLogger.error('Error performing mapping deserialization: $e');
      _internalLogger.sendToDatadog(e.toString(), st, e.runtimeType.toString());
    }
    return null;
  }

  JString? _safeEncodeJavaJson(
    Map<String, dynamic>? encoded, {
    required JString? fallback,
  }) {
    if (encoded == null) return null;

    try {
      String json = jsonEncode(encoded);
      return JString.fromString(json);
    } catch (e, st) {
      _internalLogger.error('Error performing mapping deserialization: $e');
      _internalLogger.sendToDatadog(e.toString(), st, e.runtimeType.toString());
    }
    return null;
  }

  JString? _callMapper(JString encoded, _MapperFunction mapper) {
    final decoded = _safeDecodeJavaJson(encoded);
    if (decoded == null) return encoded;

    final mapped = mapper(decoded);
    return _safeEncodeJavaJson(mapped, fallback: encoded);
  }
}
