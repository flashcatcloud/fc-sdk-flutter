// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:datadog_flags/datadog_flags.dart';

Future<void> main() async {
  final clientToken = _requiredEnvironment('DD_CLIENT_TOKEN');
  final flagKey = Platform.environment['DD_FLAG_KEY'] ?? 'checkout.enabled';
  final flagType = Platform.environment['DD_FLAG_TYPE'] ?? 'boolean';
  final targetingKey = Platform.environment['DD_TARGETING_KEY'];
  final attributes = _targetingAttributes();

  await DatadogFlags.enable(
    configuration: DatadogFlagsConfiguration(
      datadogContext: DatadogFlagsContext(
        clientToken: clientToken,
        env: Platform.environment['DD_ENV'] ?? 'staging',
        site: _siteFromEnvironment(),
        applicationId: Platform.environment['DD_APPLICATION_ID'],
      ),
    ),
  );

  final flags = DatadogFlags.sharedClient();
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

  await DatadogFlags.disable();
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
    _ => throw ArgumentError.value(
        flagType,
        'DD_FLAG_TYPE',
        'Expected boolean, string, integer, double, float, object, or json.',
      ),
  };
}

DatadogFlagsSite _siteFromEnvironment() {
  final site = Platform.environment['DD_SITE'] ?? 'us1';
  return switch (site.toLowerCase().replaceAll('-', '_')) {
    'us1' => DatadogFlagsSite.us1,
    'us1_staging' => DatadogFlagsSite.us1Staging,
    'us3' => DatadogFlagsSite.us3,
    'us5' => DatadogFlagsSite.us5,
    'eu1' => DatadogFlagsSite.eu1,
    'ap1' => DatadogFlagsSite.ap1,
    'ap2' => DatadogFlagsSite.ap2,
    _ => throw ArgumentError.value(site, 'DD_SITE', 'Unsupported site.'),
  };
}

Map<String, Object?> _targetingAttributes() {
  final json = Platform.environment['DD_TARGETING_ATTRIBUTES'];
  if (json == null || json.isEmpty) {
    return const {};
  }

  final decoded = jsonDecode(json);
  if (decoded is Map) {
    return Map<String, Object?>.from(decoded);
  }

  throw const FormatException('DD_TARGETING_ATTRIBUTES must be a JSON object.');
}

String _requiredEnvironment(String name) {
  final value = Platform.environment[name];
  if (value == null || value.isEmpty) {
    stderr.writeln('Missing required environment variable: $name');
    exitCode = 64;
    exit(exitCode);
  }
  return value;
}
