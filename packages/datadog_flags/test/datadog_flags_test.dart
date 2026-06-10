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
        trackEvaluations: false,
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
      await _waitUntil(() => _exposureRequests(requests).length == 1);
      client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
      client.getIntegerDetails(key: 'show-paywall', defaultValue: 0);
      client.getBooleanDetails(key: 'missing', defaultValue: false);
      await Future<void>.delayed(Duration.zero);

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

      final exposure = jsonDecode(request.body) as Map<String, Object?>;
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
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );

    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await Future<void>.delayed(Duration.zero);

    expect(_exposureRequests(requests), isEmpty);
  });

  test('retries exposure emission after a failed send', () async {
    final requests = <http.Request>[];
    var exposureAttempt = 0;
    final client = await _createClient(
      requests: requests,
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
    await _waitUntil(() => _exposureRequests(requests).length == 1);
    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await _waitUntil(() => _exposureRequests(requests).length == 2);

    expect(exposureAttempt, 2);
  });

  test(
    'emits flag evaluation batches for typed details at the HTTP boundary',
    () async {
      final requests = <http.Request>[];
      final now = DateTime.fromMillisecondsSinceEpoch(1234567890000);
      final client = await _createClient(
        requests: requests,
        response: _assignmentsResponse(),
        trackExposures: false,
        trackEvaluations: true,
        dateProvider: () => now,
      );
      await client.initialize(
        const FlagsEvaluationContext(
          targetingKey: 'user-123',
          attributes: {'plan': 'pro'},
        ),
      );

      client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
      client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
      client.getIntegerDetails(key: 'show-paywall', defaultValue: 7);
      client.getBooleanDetails(key: 'missing', defaultValue: false);
      await client.shutdown();

      final request = _evaluationRequests(requests).single;
      expect(
        request.url.toString(),
        'https://browser-intake-datadoghq.com/api/v2/flagevaluation?ddsource=flutter',
      );
      expect(request.headers['Content-Type'], 'application/json');
      expect(request.headers['DD-API-KEY'], 'client-token');
      expect(request.headers['DD-EVP-ORIGIN'], 'flutter');
      expect(request.headers['DD-EVP-ORIGIN-VERSION'], '9.8.7');
      expect(request.headers['DD-REQUEST-ID'], isNotEmpty);

      final body = jsonDecode(request.body) as Map<String, Object?>;
      expect(body['context'], _datadogEventContext());

      final evaluations = (body['flagEvaluations'] as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(evaluations, hasLength(3));

      final success = _evaluation(
        evaluations,
        flagKey: 'show-paywall',
        error: null,
      );
      expect(success['timestamp'], 1234567890000);
      expect(success['first_evaluation'], 1234567890000);
      expect(success['last_evaluation'], 1234567890000);
      expect(success['evaluation_count'], 2);
      expect(success['variant'], {'key': 'enabled'});
      expect(success['allocation'], {'key': 'allocation-a'});
      expect(success['targeting_key'], 'user-123');
      expect(success['context'], {
        'evaluation': {'plan': 'pro'},
        'dd': _datadogEventContext(),
      });
      expect(success.containsKey('runtime_default_used'), isFalse);

      final mismatch = _evaluation(
        evaluations,
        flagKey: 'show-paywall',
        error: FlagEvaluationError.typeMismatch.name,
      );
      expect(mismatch['runtime_default_used'], isTrue);
      expect(mismatch['error'], {
        'message': FlagEvaluationError.typeMismatch.name,
      });
      expect(mismatch.containsKey('variant'), isFalse);
      expect(mismatch.containsKey('allocation'), isFalse);

      final missing = _evaluation(
        evaluations,
        flagKey: 'missing',
        error: FlagEvaluationError.flagNotFound.name,
      );
      expect(missing['runtime_default_used'], isTrue);
      expect(missing['error'], {
        'message': FlagEvaluationError.flagNotFound.name,
      });
      expect(missing['targeting_key'], 'user-123');
    },
  );

  test('emits provider-not-ready flag evaluation defaults', () async {
    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      response: _assignmentsResponse(),
      trackExposures: false,
      trackEvaluations: true,
    );

    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await client.shutdown();

    final request = _evaluationRequests(requests).single;
    final body = jsonDecode(request.body) as Map<String, Object?>;
    final evaluations =
        (body['flagEvaluations'] as List<Object?>).cast<Map<String, Object?>>();

    final evaluation = evaluations.single;
    expect(evaluation['flag'], {'key': 'show-paywall'});
    expect(evaluation['runtime_default_used'], isTrue);
    expect(evaluation['error'], {
      'message': FlagEvaluationError.providerNotReady.name,
    });
    expect(evaluation.containsKey('targeting_key'), isFalse);
  });

  test('does not emit flag evaluations when tracking is disabled', () async {
    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      response: _assignmentsResponse(),
      trackExposures: false,
      trackEvaluations: false,
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );

    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await client.shutdown();

    expect(_evaluationRequests(requests), isEmpty);
  });

  test('sends flag evaluations when max batch size is reached', () async {
    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      response: _assignmentsResponse(),
      trackExposures: false,
      trackEvaluations: true,
      evaluationMaxBatchSize: 1,
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );

    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await _waitUntil(() => _evaluationRequests(requests).length == 1);
    await client.shutdown();

    expect(_evaluationRequests(requests), hasLength(1));
  });

  test('retries flag evaluation emission after a failed send', () async {
    final requests = <http.Request>[];
    var evaluationAttempt = 0;
    final client = await _createClient(
      requests: requests,
      trackExposures: false,
      trackEvaluations: true,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/precompute-assignments') {
          return http.Response(jsonEncode(_assignmentsResponse()), 200);
        }
        if (request.url.path == '/api/v2/flagevaluation') {
          evaluationAttempt += 1;
          return http.Response(
            '{"ok":true}',
            evaluationAttempt == 1 ? 500 : 200,
          );
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

    expect(evaluationAttempt, 2);
    expect(_evaluationRequests(requests), hasLength(2));
  });
}

Future<DatadogFlagsClient> _createClient({
  required List<http.Request> requests,
  Object? response,
  http.Client? httpClient,
  bool trackExposures = true,
  bool trackEvaluations = false,
  int evaluationMaxBatchSize = 1000,
  DateTime Function()? dateProvider,
}) async {
  final datadogFlags = DatadogFlags();
  await datadogFlags.enable(
    configuration: DatadogFlagsConfiguration(
      datadogConfig: _datadogConfig(),
      trackExposures: trackExposures,
      trackEvaluations: trackEvaluations,
      evaluationFlushInterval: const Duration(hours: 1),
      evaluationMaxBatchSize: evaluationMaxBatchSize,
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

List<http.Request> _exposureRequests(List<http.Request> requests) {
  return requests
      .where((request) => request.url.path == '/api/v2/exposures')
      .toList();
}

List<http.Request> _evaluationRequests(List<http.Request> requests) {
  return requests
      .where((request) => request.url.path == '/api/v2/flagevaluation')
      .toList();
}

Map<String, Object?> _datadogEventContext() {
  return {
    'env': 'staging',
    'rum': {
      'application': {'id': 'application-id'},
      'view': null,
    },
  };
}

Map<String, Object?> _evaluation(
  List<Map<String, Object?>> evaluations, {
  required String flagKey,
  required String? error,
}) {
  return evaluations.singleWhere((evaluation) {
    final flag = evaluation['flag'] as Map<String, Object?>;
    final errorBody = evaluation['error'] as Map<String, Object?>?;
    return flag['key'] == flagKey && errorBody?['message'] == error;
  });
}

Future<void> _waitUntil(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}
