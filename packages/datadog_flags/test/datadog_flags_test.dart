// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('enable creates the default shared client', () async {
    final requests = <http.Request>[];
    final datadogFlags = DatadogFlags();
    await datadogFlags.enable(
      configuration: DatadogFlagsConfiguration(
        datadogConfig: _datadogConfig(),
        httpClient: _clientWithResponse(requests, _assignmentsResponse()),
      ),
    );

    final shared = datadogFlags.sharedClient();

    expect(shared.name, DatadogFlags.defaultClientName);
    expect(datadogFlags.isEnabled, isTrue);
  });

  test('missing configuration creates a no-op client', () async {
    final datadogFlags = DatadogFlags();

    await datadogFlags.enable();
    final flags = datadogFlags.sharedClient();

    expect(datadogFlags.isEnabled, isFalse);
    final details = flags.getBooleanDetails(
      key: 'show-paywall',
      defaultValue: false,
    );
    expect(details.value, isFalse);
    expect(details.error, FlagEvaluationError.providerNotReady);
  });

  test('returns typed details and drops unknown variation types', () async {
    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      response: _assignmentsResponse(),
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );

    final booleanDetails = client.getBooleanDetails(
      key: 'show-paywall',
      defaultValue: false,
    );
    expect(booleanDetails.value, isTrue);

    final stringDetails = client.getStringDetails(
      key: 'theme',
      defaultValue: 'light',
    );
    expect(stringDetails.value, 'dark');

    final integerDetails = client.getIntegerDetails(
      key: 'max-items',
      defaultValue: 1,
    );
    expect(integerDetails.value, 3);

    final doubleDetails = client.getDoubleDetails(
      key: 'ratio',
      defaultValue: 1,
    );
    expect(doubleDetails.value, 0.5);

    final objectDetails = client.getObjectDetails(
      key: 'config',
      defaultValue: null,
    );
    expect(objectDetails.value, {
      'enabled': true,
      'labels': ['a', 'b'],
    });

    final missing = client.getStringDetails(
      key: 'bad',
      defaultValue: 'fallback',
    );
    expect(missing.value, 'fallback');
    expect(missing.error, FlagEvaluationError.flagNotFound);
  });

  test('reports provider readiness, not-found, and type mismatch details',
      () async {
    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      response: _assignmentsResponse(),
    );

    final notReady = client.getBooleanDetails(
      key: 'show-paywall',
      defaultValue: false,
    );
    expect(notReady.value, isFalse);
    expect(notReady.error, FlagEvaluationError.providerNotReady);

    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );

    final missing = client.getBooleanDetails(
      key: 'missing',
      defaultValue: false,
    );
    expect(missing.value, isFalse);
    expect(missing.error, FlagEvaluationError.flagNotFound);

    final mismatch = client.getIntegerDetails(
      key: 'show-paywall',
      defaultValue: 7,
    );
    expect(mismatch.value, 7);
    expect(mismatch.error, FlagEvaluationError.typeMismatch);
  });

  test('keeps the latest context when fetches resolve out of order', () async {
    final requests = <http.Request>[];
    final responseCompleters = <Completer<http.Response>>[];
    final client = await _createClient(
      requests: requests,
      httpClient: MockClient((request) {
        requests.add(request);
        final completer = Completer<http.Response>();
        responseCompleters.add(completer);
        return completer.future;
      }),
    );

    final first = client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-first'),
    );
    final second = client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-second'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(responseCompleters, hasLength(2));
    responseCompleters[1].complete(http.Response(
      jsonEncode(_assignmentsResponse(
        booleanVariationKey: 'second',
        booleanValue: false,
      )),
      200,
    ));
    await second;

    responseCompleters[0].complete(http.Response(
      jsonEncode(_assignmentsResponse(
        booleanVariationKey: 'first',
        booleanValue: true,
      )),
      200,
    ));
    await first;

    final details = client.getBooleanDetails(
      key: 'show-paywall',
      defaultValue: true,
    );
    expect(details.value, isFalse);
    expect(details.variant, 'second');
  });

  test('does not throw when context fetch fails', () async {
    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('not found', 404);
      }),
    );

    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );

    final details = client.getBooleanDetails(
      key: 'show-paywall',
      defaultValue: false,
    );
    expect(details.value, isFalse);
    expect(details.error, FlagEvaluationError.providerNotReady);
  });

  test('returns object defaults without validating their JSON shape', () async {
    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      response: _assignmentsResponse(),
    );

    final defaultValue = Object();
    final details = client.getObjectDetails(
      key: 'config',
      defaultValue: defaultValue,
    );

    expect(details.value, same(defaultValue));
    expect(details.error, FlagEvaluationError.providerNotReady);
  });

  test('shutdown clears the current assignment state', () async {
    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      response: _assignmentsResponse(),
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );

    expect(
      client.getBooleanDetails(key: 'show-paywall', defaultValue: false).value,
      isTrue,
    );

    await client.shutdown();

    final details = client.getBooleanDetails(
      key: 'show-paywall',
      defaultValue: false,
    );
    expect(details.value, isFalse);
    expect(details.error, FlagEvaluationError.providerNotReady);
  });
}

Future<DatadogFlagsClient> _createClient({
  required List<http.Request> requests,
  Object? response,
  http.Client? httpClient,
}) async {
  final datadogFlags = DatadogFlags();
  await datadogFlags.enable(
    configuration: DatadogFlagsConfiguration(
      datadogConfig: _datadogConfig(),
      httpClient: httpClient ?? _clientWithResponse(requests, response!),
    ),
  );
  return datadogFlags.sharedClient();
}

DatadogFlagsConfig _datadogConfig() {
  return const DatadogFlagsConfig(
    clientToken: 'client-token',
    env: 'staging',
    site: DatadogFlagsSite.us1,
    applicationId: 'application-id',
  );
}

http.Client _clientWithResponse(
  List<http.Request> requests,
  Object body, {
  int statusCode = 200,
}) {
  return MockClient((request) async {
    requests.add(request);
    return http.Response(jsonEncode(body), statusCode);
  });
}

Map<String, Object?> _assignmentsResponse({
  bool doLog = true,
  String booleanVariationKey = 'enabled',
  bool booleanValue = true,
}) {
  return {
    'data': {
      'attributes': {
        'flags': {
          'show-paywall': {
            'allocationKey': 'allocation-a',
            'variationKey': booleanVariationKey,
            'variationType': 'boolean',
            'variationValue': booleanValue,
            'reason': 'TARGETING_MATCH',
            'doLog': doLog,
          },
          'theme': {
            'allocationKey': 'allocation-b',
            'variationKey': 'dark',
            'variationType': 'string',
            'variationValue': 'dark',
            'reason': 'TARGETING_MATCH',
            'doLog': true,
          },
          'max-items': {
            'allocationKey': 'allocation-c',
            'variationKey': 'three',
            'variationType': 'integer',
            'variationValue': 3,
            'reason': 'TARGETING_MATCH',
            'doLog': true,
          },
          'ratio': {
            'allocationKey': 'allocation-d',
            'variationKey': 'half',
            'variationType': 'float',
            'variationValue': 0.5,
            'reason': 'TARGETING_MATCH',
            'doLog': true,
          },
          'config': {
            'allocationKey': 'allocation-e',
            'variationKey': 'object',
            'variationType': 'object',
            'variationValue': {
              'enabled': true,
              'labels': ['a', 'b'],
            },
            'reason': 'TARGETING_MATCH',
            'doLog': true,
          },
          'bad': {
            'allocationKey': 'allocation-f',
            'variationKey': 'bad',
            'variationType': 'unsupported',
            'variationValue': 'bad',
            'reason': 'TARGETING_MATCH',
            'doLog': true,
          },
        },
      },
    },
  };
}
