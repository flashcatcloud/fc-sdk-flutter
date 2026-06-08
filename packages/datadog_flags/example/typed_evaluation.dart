// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:datadog_flags/datadog_flags.dart';

Future<void> main() async {
  final clientToken = Platform.environment['DD_CLIENT_TOKEN'] ?? '';
  final flagKey = Platform.environment['DD_FLAG_KEY'] ?? 'checkout.enabled';
  final flagType = Platform.environment['DD_FLAG_TYPE'] ?? 'boolean';
  final targetingKey = Platform.environment['DD_TARGETING_KEY'];
  final attributes = _targetingAttributes();

  final datadogFlags = DatadogFlags.instance;
  await datadogFlags.enable(
    configuration: DatadogFlagsConfiguration(
      datadogContext: DatadogFlagsContext(
        clientToken: clientToken,
        env: Platform.environment['DD_ENV'] ?? 'staging',
        site: DatadogFlagsSite.us1,
        applicationId: Platform.environment['DD_APPLICATION_ID'],
      ),
    ),
  );

  final flags = datadogFlags.sharedClient();
  await flags.setEvaluationContext(
    FlagsEvaluationContext(
      targetingKey: targetingKey,
      attributes: attributes,
    ),
  );

  final details = _evaluate(flags, flagKey, flagType);
  stdout.writeln('key: ${details.key}');
  stdout.writeln('value: ${jsonEncode(details.value)}');
  stdout.writeln('variant: ${details.variant ?? '(none)'}');
  stdout.writeln('reason: ${details.reason ?? '(none)'}');
  stdout.writeln('error: ${details.error?.name ?? '(none)'}');

  await datadogFlags.disable();
}

FlagDetails<Object?> _evaluate(
  DatadogFlagsClient flags,
  String flagKey,
  String flagType,
) {
  return switch (flagType) {
    'boolean' => flags.getBooleanDetails(
        key: flagKey,
        defaultValue: false,
      ),
    'string' => flags.getStringDetails(
        key: flagKey,
        defaultValue: '',
      ),
    'integer' => flags.getIntegerDetails(
        key: flagKey,
        defaultValue: 0,
      ),
    'double' || 'float' => flags.getDoubleDetails(
        key: flagKey,
        defaultValue: 0,
      ),
    'object' || 'json' => flags.getObjectDetails(
        key: flagKey,
        defaultValue: null,
      ),
    _ => flags.getBooleanDetails(
        key: flagKey,
        defaultValue: false,
      ),
  };
}

Map<String, Object?> _targetingAttributes() {
  final json = Platform.environment['DD_TARGETING_ATTRIBUTES'];
  if (json == null || json.isEmpty) {
    return const {};
  }

  try {
    final decoded = jsonDecode(json);
    if (decoded is Map) {
      return Map<String, Object?>.from(decoded);
    }
  } catch (_) {
    return const {};
  }

  return const {};
}
