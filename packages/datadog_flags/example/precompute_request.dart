// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final clientToken = Platform.environment['DD_CLIENT_TOKEN'];
  if (clientToken == null || clientToken.isEmpty) {
    stderr.writeln('Set DD_CLIENT_TOKEN before running this example.');
    exitCode = 64;
    return;
  }

  final customEndpoint = Platform.environment['DD_FLAGS_ENDPOINT'];
  final client = http.Client();
  try {
    final fetcher = FlagAssignmentsFetcher(
      datadogContext: DatadogFlagsContext(
        clientToken: clientToken,
        env: Platform.environment['DD_ENV'] ?? 'staging',
        site: _siteFromEnvironment(Platform.environment['DD_SITE']),
        applicationId: Platform.environment['DD_APPLICATION_ID'],
      ),
      configuration: DatadogFlagsConfiguration(
        customFlagsEndpoint:
            customEndpoint == null ? null : Uri.parse(customEndpoint),
      ),
      httpClient: client,
    );

    final assignments = await fetcher.fetch(
      DatadogFlagsEvaluationContext(
        targetingKey:
            Platform.environment['DD_TARGETING_KEY'] ?? 'test_subject4',
        attributes: const {
          'attr1': 'value1',
          'companyId': '1',
        },
      ),
    );

    stdout.writeln('Fetched ${assignments.length} assignment(s).');
    for (final entry in assignments.entries) {
      stdout.writeln(
        '${entry.key}: ${entry.value.variationValue} '
        '(${entry.value.variationKey})',
      );
    }
  } on FlagsException catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    client.close();
  }
}

DatadogFlagsSite _siteFromEnvironment(String? value) {
  return switch (value) {
    'us3' || 'datadoghq.com/us3' => DatadogFlagsSite.us3,
    'us5' || 'datadoghq.com/us5' => DatadogFlagsSite.us5,
    'eu1' || 'datadoghq.eu' => DatadogFlagsSite.eu1,
    'ap1' || 'ap1.datadoghq.com' => DatadogFlagsSite.ap1,
    'ap2' || 'ap2.datadoghq.com' => DatadogFlagsSite.ap2,
    'us1Fed' || 'ddog-gov.com' => DatadogFlagsSite.us1Fed,
    _ => DatadogFlagsSite.us1,
  };
}
