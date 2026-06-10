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

  test(
    'reports provider readiness, not-found, and type mismatch details',
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
    },
  );

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
    responseCompleters[1].complete(
      http.Response(
        jsonEncode(
          _assignmentsResponse(
            booleanVariationKey: 'second',
            booleanValue: false,
          ),
        ),
        200,
      ),
    );
    await second;

    responseCompleters[0].complete(
      http.Response(
        jsonEncode(
          _assignmentsResponse(
            booleanVariationKey: 'first',
            booleanValue: true,
          ),
        ),
        200,
      ),
    );
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

  test(
    'emits exposure events for successful details at the HTTP boundary',
    () async {
      final requests = <http.Request>[];
      final now = DateTime.fromMillisecondsSinceEpoch(1234567890000);
      final client = await _createClient(
        requests: requests,
        response: _assignmentsResponse(),
        trackExposures: true,
        dateProvider: () => now,
      );

      client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
      await Future<void>.delayed(Duration.zero);
      expect(_exposureRequests(requests), isEmpty);

      await client.initialize(
        const FlagsEvaluationContext(
          targetingKey: 'user-123',
          attributes: {'plan': 'pro'},
        ),
      );

      client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
      client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
      client.getIntegerDetails(key: 'show-paywall', defaultValue: 0);
      client.getBooleanDetails(key: 'missing', defaultValue: false);
      await client.shutdown();

      expect(_exposureRequests(requests), hasLength(1));
      final request = _exposureRequests(requests).single;
      expect(
        request.url.toString(),
        'https://browser-intake-datadoghq.com/api/v2/exposures?ddsource=flutter',
      );
      expect(request.headers['Content-Type'], 'text/plain;charset=UTF-8');
      expect(request.headers['DD-API-KEY'], 'client-token');
      expect(request.headers['DD-EVP-ORIGIN'], 'flutter');
      expect(request.headers['DD-EVP-ORIGIN-VERSION'], '9.8.7');
      expect(request.headers['DD-REQUEST-ID'], isNotEmpty);

      final exposure = _exposureEvents(request).single;
      expect(exposure, {
        'timestamp': 1234567890000,
        'allocation': {'key': 'allocation-a'},
        'flag': {'key': 'show-paywall'},
        'variant': {'key': 'enabled'},
        'subject': {
          'id': 'user-123',
          'attributes': {'plan': 'pro'},
        },
      });
    },
  );

  test('does not emit exposures when tracking is disabled', () async {
    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      response: _assignmentsResponse(),
      trackExposures: false,
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );

    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await Future<void>.delayed(Duration.zero);

    expect(_exposureRequests(requests), isEmpty);
  });

  test('does not emit exposures when doLog is false', () async {
    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      response: _assignmentsResponse(doLog: false),
      trackExposures: true,
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );

    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await client.shutdown();

    expect(_exposureRequests(requests), isEmpty);
  });

  test('retries exposure emission after a failed send', () async {
    final requests = <http.Request>[];
    var exposureAttempt = 0;
    final client = await _createClient(
      requests: requests,
      trackExposures: true,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/precompute-assignments') {
          return http.Response(jsonEncode(_assignmentsResponse()), 200);
        }
        if (request.url.path == '/api/v2/exposures') {
          exposureAttempt += 1;
          return http.Response('{"ok":true}', exposureAttempt == 1 ? 500 : 200);
        }
        return http.Response('{"error":"unexpected"}', 404);
      }),
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );

    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await client.shutdown();
    await client.shutdown();

    expect(exposureAttempt, 2);
  });

  test('batches unique exposure events in one request body', () async {
    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      response: _assignmentsResponse(),
      trackExposures: true,
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );

    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    client.getStringDetails(key: 'theme', defaultValue: 'light');
    await client.shutdown();

    final request = _exposureRequests(requests).single;
    final events = _exposureEvents(request);
    expect(events, hasLength(2));
    expect(
      events.map((event) => (event['flag'] as Map<String, Object?>)['key']),
      ['show-paywall', 'theme'],
    );
    expect(request.body.split('\n'), hasLength(2));
  });

  test('deduplicates exposures by the mobile assignment tuple', () async {
    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      response: _assignmentsResponse(),
      trackExposures: true,
    );
    await client.initialize(
      const FlagsEvaluationContext(
        targetingKey: 'user-123',
        attributes: {'plan': 'pro'},
      ),
    );

    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await client.initialize(
      const FlagsEvaluationContext(
        targetingKey: 'user-123',
        attributes: {'plan': 'enterprise'},
      ),
    );
    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await client.shutdown();

    final event = _exposureEvents(_exposureRequests(requests).single).single;
    expect(event['subject'], {
      'id': 'user-123',
      'attributes': {'plan': 'pro'},
    });
  });

  test('does not collapse distinct exposure tuples with separators', () async {
    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      response: _assignmentsResponse(
        additionalFlags: {
          'c': _assignment(
            allocationKey: 'd',
            variationKey: 'e',
            variationType: 'boolean',
            variationValue: true,
          ),
          'b|c': _assignment(
            allocationKey: 'd',
            variationKey: 'e',
            variationType: 'boolean',
            variationValue: true,
          ),
        },
      ),
      trackExposures: true,
    );

    await client.initialize(const FlagsEvaluationContext(targetingKey: 'a|b'));
    client.getBooleanDetails(key: 'c', defaultValue: false);
    await client.initialize(const FlagsEvaluationContext(targetingKey: 'a'));
    client.getBooleanDetails(key: 'b|c', defaultValue: false);
    await client.shutdown();

    final events = _exposureEvents(_exposureRequests(requests).single);
    expect(events, hasLength(2));
    expect(
      events.map(
        (event) => [
          ((event['subject'] as Map<String, Object?>)['id']),
          ((event['flag'] as Map<String, Object?>)['key']),
        ],
      ),
      [
        ['a|b', 'c'],
        ['a', 'b|c'],
      ],
    );
  });

  test('logs another exposure when the assignment changes', () async {
    final requests = <http.Request>[];
    var precomputeRequestCount = 0;
    final client = await _createClient(
      requests: requests,
      trackExposures: true,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/precompute-assignments') {
          precomputeRequestCount += 1;
          return http.Response(
            jsonEncode(
              _assignmentsResponse(
                booleanVariationKey:
                    precomputeRequestCount == 1 ? 'enabled' : 'disabled',
                booleanValue: precomputeRequestCount == 1,
              ),
            ),
            200,
          );
        }
        return http.Response('{"ok":true}', 200);
      }),
    );

    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );
    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );
    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await client.shutdown();

    final events = _exposureEvents(_exposureRequests(requests).single);
    expect(
      events.map((event) => (event['variant'] as Map<String, Object?>)['key']),
      ['enabled', 'disabled'],
    );
  });
}

Future<DatadogFlagsClient> _createClient({
  required List<http.Request> requests,
  Object? response,
  http.Client? httpClient,
  bool trackExposures = false,
  DateTime Function()? dateProvider,
}) async {
  final datadogFlags = DatadogFlags();
  await datadogFlags.enable(
    configuration: DatadogFlagsConfiguration(
      datadogConfig: _datadogConfig(),
      trackExposures: trackExposures,
      httpClient: httpClient ?? _clientWithResponse(requests, response!),
      dateProvider: dateProvider ?? DateTime.now,
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
    sdkVersion: '9.8.7',
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
  String booleanAllocationKey = 'allocation-a',
  String booleanVariationKey = 'enabled',
  bool booleanValue = true,
  Map<String, Object?> additionalFlags = const {},
}) {
  return {
    'data': {
      'attributes': {
        'flags': {
          'show-paywall': {
            'allocationKey': booleanAllocationKey,
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
          ...additionalFlags,
        },
      },
    },
  };
}

Map<String, Object?> _assignment({
  required String allocationKey,
  required String variationKey,
  required String variationType,
  required Object variationValue,
  bool doLog = true,
}) {
  return {
    'allocationKey': allocationKey,
    'variationKey': variationKey,
    'variationType': variationType,
    'variationValue': variationValue,
    'reason': 'TARGETING_MATCH',
    'doLog': doLog,
  };
}

List<http.Request> _exposureRequests(List<http.Request> requests) {
  return requests
      .where((request) => request.url.path == '/api/v2/exposures')
      .toList();
}

List<Map<String, Object?>> _exposureEvents(http.Request request) {
  return request.body
      .split('\n')
      .where((line) => line.isNotEmpty)
      .map((line) => jsonDecode(line) as Map<String, Object?>)
      .toList();
}
