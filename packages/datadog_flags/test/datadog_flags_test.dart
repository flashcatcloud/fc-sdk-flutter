// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags/src/default_flags_client.dart';
import 'package:datadog_flags/src/evaluation_aggregator.dart';
import 'package:datadog_flags/src/exposure_logger.dart';
import 'package:datadog_flags/src/flags_repository.dart';
import 'package:datadog_flags/src/rum_flag_evaluation_reporter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;
  late DateTime now;

  setUp(() async {
    requests = [];
    now = DateTime.fromMillisecondsSinceEpoch(1234567890000);
    await DatadogFlags.disable();
  });

  tearDown(() async {
    await DatadogFlags.disable();
  });

  test('enable creates the default shared client', () async {
    await DatadogFlags.enable(
      configuration: DatadogFlagsConfiguration(
        datadogContext: datadogContext(),
        httpClient: clientWithResponse(requests, assignmentsResponse()),
        store: InMemoryDatadogFlagsStore(),
      ),
    );

    final shared = DatadogFlags.sharedClient();

    expect(shared.name, DatadogFlagsClient.defaultName);
    expect(DatadogFlags.isEnabled, isTrue);
  });

  test('returns typed values and drops unknown variation types', () async {
    final client = await createClient(
      requests: requests,
      response: assignmentsResponse(),
    );
    await client.setEvaluationContext(
      const DatadogFlagsEvaluationContext(targetingKey: 'user-123'),
    );

    expect(
      client.getBooleanValue(key: 'show-paywall', defaultValue: false),
      isTrue,
    );
    expect(client.getStringValue(key: 'theme', defaultValue: 'light'), 'dark');
    expect(client.getIntegerValue(key: 'max-items', defaultValue: 1), 3);
    expect(client.getDoubleValue(key: 'ratio', defaultValue: 1), 0.5);
    expect(client.getObjectValue(key: 'config', defaultValue: null), {
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
    final client = await createClient(
      requests: requests,
      response: assignmentsResponse(),
    );

    final notReady = client.getBooleanDetails(
      key: 'show-paywall',
      defaultValue: false,
    );
    expect(notReady.value, isFalse);
    expect(notReady.error, FlagEvaluationError.providerNotReady);

    await client.setEvaluationContext(
      const DatadogFlagsEvaluationContext(targetingKey: 'user-123'),
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
    final responseCompleters = <Completer<http.Response>>[];
    final client = await createClient(
      requests: requests,
      httpClient: MockClient((request) {
        requests.add(request);
        final completer = Completer<http.Response>();
        responseCompleters.add(completer);
        return completer.future;
      }),
    );

    final first = client.setEvaluationContext(
      const DatadogFlagsEvaluationContext(targetingKey: 'user-first'),
    );
    await waitUntil(() => responseCompleters.length == 1);
    final second = client.setEvaluationContext(
      const DatadogFlagsEvaluationContext(targetingKey: 'user-second'),
    );
    await waitUntil(() => responseCompleters.length == 2);

    expect(responseCompleters, hasLength(2));
    responseCompleters[1].complete(http.Response(
      jsonEncode(assignmentsResponse(
        booleanVariationKey: 'second',
        booleanValue: false,
      )),
      200,
    ));
    await second;

    responseCompleters[0].complete(http.Response(
      jsonEncode(assignmentsResponse(
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

  test('reports only successful typed evaluations to RUM', () async {
    final context = datadogContext();
    final httpClient = clientWithResponse(requests, assignmentsResponse());
    final config = DatadogFlagsConfiguration(
      datadogContext: context,
      httpClient: httpClient,
      trackExposures: false,
      trackEvaluations: false,
    );
    final repository = FlagsRepository(
      clientName: 'rum-test',
      fetcher: FlagAssignmentsFetcher(
        datadogContext: context,
        configuration: config,
        httpClient: httpClient,
      ),
      store: InMemoryDatadogFlagsStore(),
      dateProvider: () => now,
    );
    final fakeRum = FakeRumFlagEvaluationReporter();
    final client = DefaultDatadogFlagsClient(
      name: 'rum-test',
      repository: repository,
      exposureLogger: ExposureLogger(
        datadogContext: context,
        configuration: config,
        httpClient: httpClient,
      ),
      evaluationAggregator: EvaluationAggregator(
        datadogContext: context,
        configuration: config,
        httpClient: httpClient,
      ),
      rumFlagEvaluationReporter: fakeRum,
    );

    client.getBooleanValue(key: 'show-paywall', defaultValue: false);
    await client.setEvaluationContext(
      const DatadogFlagsEvaluationContext(targetingKey: 'user-123'),
    );
    client.getBooleanValue(key: 'show-paywall', defaultValue: false);
    client.getIntegerValue(key: 'show-paywall', defaultValue: 0);
    client.getBooleanValue(key: 'missing', defaultValue: false);

    expect(fakeRum.calls, [
      const RumCall('show-paywall', true),
    ]);
  });

  test('reset clears the current assignment state', () async {
    final store = InMemoryDatadogFlagsStore();
    final client = await createClient(
      requests: requests,
      response: assignmentsResponse(),
      store: store,
    );
    await client.setEvaluationContext(
      const DatadogFlagsEvaluationContext(targetingKey: 'user-123'),
    );

    expect(client.getBooleanValue(key: 'show-paywall', defaultValue: false),
        isTrue);

    await client.reset();

    final details = client.getBooleanDetails(
      key: 'show-paywall',
      defaultValue: false,
    );
    expect(details.value, isFalse);
    expect(details.error, FlagEvaluationError.providerNotReady);
    expect(store.values, isEmpty);
  });

  test('counts exposure emissions at the HTTP boundary', () async {
    final client = await createClient(
      requests: requests,
      response: assignmentsResponse(),
      dateProvider: () => now,
    );

    client.getBooleanValue(key: 'show-paywall', defaultValue: false);
    await Future<void>.delayed(Duration.zero);
    expect(exposureRequests(requests), isEmpty);

    await client.setEvaluationContext(
      const DatadogFlagsEvaluationContext(
        targetingKey: 'user-123',
        attributes: {'plan': 'pro'},
      ),
    );

    client.getBooleanValue(key: 'show-paywall', defaultValue: false);
    await waitUntil(() => exposureRequests(requests).length == 1);
    client.getBooleanValue(key: 'show-paywall', defaultValue: false);
    client.getIntegerValue(key: 'show-paywall', defaultValue: 0);
    client.getBooleanValue(key: 'missing', defaultValue: false);
    await Future<void>.delayed(Duration.zero);

    expect(exposureRequests(requests), hasLength(1));
    final request = exposureRequests(requests).single;
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
    expect(exposure['timestamp'], 1234567890000);
    expect(exposure['service'], 'flutter-example');
    expect(exposure['rum'], {
      'application': {'id': 'rum-app-id'},
      'view': null,
    });
    expect(exposure['flag'], {'key': 'show-paywall'});
    expect(exposure['allocation'], {'key': 'allocation-a'});
    expect(exposure['variant'], {'key': 'enabled'});
    expect(exposure['subject'], {
      'id': 'user-123',
      'attributes': {'plan': 'pro'},
    });
  });

  test('does not emit exposures when doLog is false', () async {
    final client = await createClient(
      requests: requests,
      response: assignmentsResponse(doLog: false),
    );
    await client.setEvaluationContext(
      const DatadogFlagsEvaluationContext(targetingKey: 'user-123'),
    );

    client.getBooleanValue(key: 'show-paywall', defaultValue: false);
    await Future<void>.delayed(Duration.zero);

    expect(exposureRequests(requests), isEmpty);
  });

  test('retries exposure emission after a failed send', () async {
    var exposureAttempt = 0;
    final client = await createClient(
      requests: requests,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/precompute-assignments') {
          return http.Response(jsonEncode(assignmentsResponse()), 200);
        }
        if (request.url.path == '/api/v2/exposures') {
          exposureAttempt += 1;
          return http.Response(
            '{"ok":true}',
            exposureAttempt == 1 ? 500 : 200,
          );
        }
        return http.Response('{"error":"unexpected"}', 404);
      }),
    );
    await client.setEvaluationContext(
      const DatadogFlagsEvaluationContext(targetingKey: 'user-123'),
    );

    client.getBooleanValue(key: 'show-paywall', defaultValue: false);
    await waitUntil(() => exposureRequests(requests).length == 1);
    client.getBooleanValue(key: 'show-paywall', defaultValue: false);
    await waitUntil(() => exposureRequests(requests).length == 2);

    expect(exposureAttempt, 2);
  });

  test('flushes aggregated evaluation metrics with success and error payloads',
      () async {
    final client = await createClient(
      requests: requests,
      response: assignmentsResponse(),
      dateProvider: () => now,
      trackExposures: false,
    );

    client.getBooleanValue(key: 'show-paywall', defaultValue: false);
    await client.setEvaluationContext(
      const DatadogFlagsEvaluationContext(
        targetingKey: 'user-123',
        attributes: {'plan': 'pro'},
      ),
    );
    client.getBooleanValue(key: 'show-paywall', defaultValue: false);
    client.getBooleanValue(key: 'show-paywall', defaultValue: false);
    client.getIntegerValue(key: 'show-paywall', defaultValue: 0);
    client.getBooleanValue(key: 'missing', defaultValue: false);

    await client.flush();

    expect(evaluationRequests(requests), hasLength(1));
    final request = evaluationRequests(requests).single;
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
    expect(body['context'], {
      'service': 'flutter-example',
      'version': '1.2.3',
      'env': 'staging',
      'rum': {
        'application': {'id': 'rum-app-id'},
        'view': null,
      },
    });

    final evaluations =
        (body['flagEvaluations'] as List<Object?>).cast<Map<String, Object?>>();
    final success = evaluations.singleWhere((evaluation) {
      return (evaluation['flag'] as Map<String, Object?>)['key'] ==
              'show-paywall' &&
          evaluation['error'] == null;
    });
    expect(success['evaluation_count'], 2);
    expect(success['variant'], {'key': 'enabled'});
    expect(success['allocation'], {'key': 'allocation-a'});
    expect(success['runtime_default_used'], isNull);
    expect(success['context'], {
      'evaluation': {'plan': 'pro'},
      'dd': {
        'service': 'flutter-example',
        'version': '1.2.3',
        'env': 'staging',
        'rum': {
          'application': {'id': 'rum-app-id'},
          'view': null,
        },
      },
    });

    final providerNotReady = evaluations.singleWhere((evaluation) {
      return ((evaluation['error'] as Map<String, Object?>?)?['message']) ==
          'PROVIDER_NOT_READY';
    });
    expect(providerNotReady['runtime_default_used'], isTrue);
    expect(providerNotReady['variant'], isNull);
    expect(providerNotReady['allocation'], isNull);

    final typeMismatch = evaluations.singleWhere((evaluation) {
      return ((evaluation['error'] as Map<String, Object?>?)?['message']) ==
          'TYPE_MISMATCH';
    });
    expect(typeMismatch['runtime_default_used'], isTrue);

    final flagNotFound = evaluations.singleWhere((evaluation) {
      return ((evaluation['error'] as Map<String, Object?>?)?['message']) ==
          'FLAG_NOT_FOUND';
    });
    expect(flagNotFound['runtime_default_used'], isTrue);
  });

  test('restores aggregated evaluation metrics after a failed flush', () async {
    var evaluationAttempt = 0;
    final client = await createClient(
      requests: requests,
      trackExposures: false,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/precompute-assignments') {
          return http.Response(jsonEncode(assignmentsResponse()), 200);
        }
        if (request.url.path == '/api/v2/flagevaluation') {
          evaluationAttempt += 1;
          return http.Response(
            '{"ok":true}',
            evaluationAttempt == 1 ? 500 : 200,
          );
        }
        return http.Response('{"ok":true}', 200);
      }),
    );
    await client.setEvaluationContext(
      const DatadogFlagsEvaluationContext(targetingKey: 'user-123'),
    );
    client.getBooleanValue(key: 'show-paywall', defaultValue: false);

    await client.flush();
    await client.flush();

    expect(evaluationRequests(requests), hasLength(2));
    final retryBody = jsonDecode(evaluationRequests(requests).last.body)
        as Map<String, Object?>;
    final retryEvaluations = retryBody['flagEvaluations'] as List<Object?>;
    expect(retryEvaluations, hasLength(1));
  });

  test('flushes aggregated evaluation metrics at the configured batch size',
      () async {
    final client = await createClient(
      requests: requests,
      response: assignmentsResponse(),
      trackExposures: false,
      evaluationMaxBatchSize: 1,
    );
    await client.setEvaluationContext(
      const DatadogFlagsEvaluationContext(targetingKey: 'user-123'),
    );

    client.getBooleanValue(key: 'show-paywall', defaultValue: false);
    await waitUntil(() => evaluationRequests(requests).length == 1);

    expect(evaluationRequests(requests), hasLength(1));
  });

  test('persists assignments and restores only for the matching context',
      () async {
    final store = InMemoryDatadogFlagsStore();
    final client = await createClient(
      requests: requests,
      response: assignmentsResponse(),
      store: store,
      trackExposures: false,
      trackEvaluations: false,
    );
    const context = DatadogFlagsEvaluationContext(
      targetingKey: 'user-123',
      attributes: {'plan': 'pro'},
    );
    await client.setEvaluationContext(context);

    expect(store.values, contains(DatadogFlagsClient.defaultName));
    await DatadogFlags.disable();

    final responseCompleter = Completer<http.Response>();
    final restored = await createClient(
      requests: requests,
      store: store,
      trackExposures: false,
      trackEvaluations: false,
      httpClient: MockClient((request) {
        requests.add(request);
        return responseCompleter.future;
      }),
    );

    final refresh = restored.setEvaluationContext(context);
    await Future<void>.delayed(Duration.zero);
    expect(
      restored.getBooleanValue(key: 'show-paywall', defaultValue: false),
      isTrue,
    );

    responseCompleter.complete(http.Response(
      jsonEncode(assignmentsResponse(booleanValue: false)),
      200,
    ));
    await refresh;
    expect(
      restored.getBooleanValue(key: 'show-paywall', defaultValue: true),
      isFalse,
    );
  });

  test('ignores cached assignments for a different context', () async {
    final store = InMemoryDatadogFlagsStore();
    final client = await createClient(
      requests: requests,
      response: assignmentsResponse(),
      store: store,
      trackExposures: false,
      trackEvaluations: false,
    );
    await client.setEvaluationContext(
      const DatadogFlagsEvaluationContext(targetingKey: 'user-123'),
    );
    await DatadogFlags.disable();

    final responseCompleter = Completer<http.Response>();
    final restored = await createClient(
      requests: requests,
      store: store,
      trackExposures: false,
      trackEvaluations: false,
      httpClient: MockClient((request) {
        requests.add(request);
        return responseCompleter.future;
      }),
    );

    final refresh = restored.setEvaluationContext(
      const DatadogFlagsEvaluationContext(targetingKey: 'user-456'),
    );
    await Future<void>.delayed(Duration.zero);
    final notReady = restored.getBooleanDetails(
      key: 'show-paywall',
      defaultValue: false,
    );
    expect(notReady.error, FlagEvaluationError.providerNotReady);

    responseCompleter.complete(http.Response(
      jsonEncode(assignmentsResponse(booleanValue: false)),
      200,
    ));
    await refresh;
    expect(
      restored.getBooleanValue(key: 'show-paywall', defaultValue: true),
      isFalse,
    );
  });

  test('overlapping context fetches persist only the latest context', () async {
    final store = InMemoryDatadogFlagsStore();
    final responseCompleters = <Completer<http.Response>>[];
    final client = await createClient(
      requests: requests,
      store: store,
      trackExposures: false,
      trackEvaluations: false,
      httpClient: MockClient((request) {
        requests.add(request);
        final completer = Completer<http.Response>();
        responseCompleters.add(completer);
        return completer.future;
      }),
    );

    final first = client.setEvaluationContext(
      const DatadogFlagsEvaluationContext(targetingKey: 'user-first'),
    );
    await waitUntil(() => responseCompleters.length == 1);
    final second = client.setEvaluationContext(
      const DatadogFlagsEvaluationContext(targetingKey: 'user-second'),
    );
    await waitUntil(() => responseCompleters.length == 2);

    responseCompleters[1].complete(http.Response(
      jsonEncode(assignmentsResponse(
        booleanVariationKey: 'second',
        booleanValue: false,
      )),
      200,
    ));
    await second;

    responseCompleters[0].complete(http.Response(
      jsonEncode(assignmentsResponse(
        booleanVariationKey: 'first',
        booleanValue: true,
      )),
      200,
    ));
    await first;

    final persisted = store.values[DatadogFlagsClient.defaultName]!;
    expect(persisted.context.targetingKey, 'user-second');
    expect(persisted.flags['show-paywall']!.variationKey, 'second');
  });

  test('shared preferences store round-trips persisted assignments', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesDatadogFlagsStore(
      sharedPreferences: preferences,
      namespace: 'test_flags',
    );
    final data = FlagsData(
      flags: {
        'show-paywall': const FlagAssignment(
          allocationKey: 'allocation-a',
          variationKey: 'enabled',
          variationType: FlagVariationType.boolean,
          variationValue: true,
          reason: 'TARGETING_MATCH',
          doLog: true,
        ),
      },
      context: const DatadogFlagsEvaluationContext(targetingKey: 'user-123'),
      date: now,
    );

    await store.write('client', data);
    final restored = await store.read('client');

    expect(restored!.context.targetingKey, 'user-123');
    expect(restored.flags['show-paywall']!.variationValue, isTrue);

    await store.delete('client');
    expect(await store.read('client'), isNull);
  });
}

Future<DatadogFlagsClient> createClient({
  required List<http.Request> requests,
  Object? response,
  http.Client? httpClient,
  DateTime Function()? dateProvider,
  bool trackExposures = true,
  bool trackEvaluations = true,
  int evaluationMaxBatchSize = 1000,
  DatadogFlagsStore? store,
}) async {
  await DatadogFlags.enable(
    configuration: DatadogFlagsConfiguration(
      datadogContext: datadogContext(),
      httpClient: httpClient ?? clientWithResponse(requests, response!),
      rumIntegrationEnabled: false,
      dateProvider: dateProvider ?? DateTime.now,
      trackExposures: trackExposures,
      trackEvaluations: trackEvaluations,
      evaluationMaxBatchSize: evaluationMaxBatchSize,
      store: store ?? InMemoryDatadogFlagsStore(),
    ),
  );
  return DatadogFlagsClient.create();
}

DatadogFlagsContext datadogContext() {
  return const DatadogFlagsContext(
    clientToken: 'client-token',
    env: 'staging',
    site: DatadogFlagsSite.us1,
    service: 'flutter-example',
    version: '1.2.3',
    applicationId: 'rum-app-id',
    sdkVersion: '9.8.7',
  );
}

http.Client clientWithResponse(
  List<http.Request> requests,
  Object body, {
  int statusCode = 200,
}) {
  return MockClient((request) async {
    requests.add(request);
    return http.Response(jsonEncode(body), statusCode);
  });
}

Map<String, Object?> assignmentsResponse({
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

List<http.Request> exposureRequests(List<http.Request> requests) {
  return requests
      .where((request) => request.url.path == '/api/v2/exposures')
      .toList();
}

List<http.Request> evaluationRequests(List<http.Request> requests) {
  return requests
      .where((request) => request.url.path == '/api/v2/flagevaluation')
      .toList();
}

Future<void> waitUntil(
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

class FakeRumFlagEvaluationReporter implements RumFlagEvaluationReporter {
  final List<RumCall> calls = [];

  @override
  void report(String flagKey, Object value) {
    calls.add(RumCall(flagKey, value));
  }
}

class RumCall {
  final String key;
  final Object value;

  const RumCall(this.key, this.value);

  @override
  bool operator ==(Object other) {
    return other is RumCall && other.key == key && other.value == value;
  }

  @override
  int get hashCode => Object.hash(key, value);

  @override
  String toString() => 'RumCall($key, $value)';
}
