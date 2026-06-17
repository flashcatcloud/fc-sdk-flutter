// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:http/http.dart' as http;

import 'default_flags_client.dart';
import 'evaluation_aggregator.dart';
import 'exposure_logger.dart';
import 'flag_assignments_fetcher.dart';
import 'flags_client.dart';
import 'flags_configuration.dart';
import 'flags_repository.dart';
import 'no_op_flags_client.dart';

/// Entry point for configuring and creating Datadog feature flag clients.
///
/// `DatadogFlags` state is local to the current Dart isolate. Background
/// isolates must use their own [DatadogFlags] instance, create any clients they
/// need, and initialize each client before evaluating flags.
class DatadogFlags {
  static const defaultClientName = 'default';

  static DatadogFlags? _singleton;

  static DatadogFlags get instance {
    _singleton ??= DatadogFlags();
    return _singleton!;
  }

  http.Client? _httpClient;
  DatadogFlagsConfiguration? _configuration;
  final Map<String, DatadogFlagsClient> _clients = {};

  DatadogFlags();

  bool get isEnabled => _configuration != null;

  Future<void> enable({
    DatadogFlagsConfiguration configuration = const DatadogFlagsConfiguration(),
  }) async {
    await disable();

    final datadogConfig = configuration.datadogConfig;
    if (datadogConfig == null) {
      return;
    }

    _httpClient = configuration.httpClient ?? http.Client();
    _configuration = configuration;
    sharedClient();
  }

  DatadogFlagsClient sharedClient({String name = defaultClientName}) {
    return _client(name);
  }

  Future<void> reset() async {
    await Future.wait(
      _clients.values.map((client) async {
        if (client is DefaultDatadogFlagsClient) {
          await client.reset();
        } else {
          await client.shutdown();
        }
      }),
    );
  }

  Future<void> disable() async {
    await Future.wait(_clients.values.map((client) => client.shutdown()));
    _clients.clear();
    _httpClient?.close();
    _httpClient = null;
    _configuration = null;
  }

  DatadogFlagsClient _client(String name) {
    final existing = _clients[name];
    if (existing != null) {
      return existing;
    }

    final configuration = _configuration;
    final datadogConfig = configuration?.datadogConfig;
    final httpClient = _httpClient;
    if (configuration == null || datadogConfig == null || httpClient == null) {
      final client = NoOpDatadogFlagsClient(name: name);
      _clients[name] = client;
      return client;
    }

    final fetcher = FlagAssignmentsFetcher(
      datadogConfig: datadogConfig,
      configuration: configuration,
      httpClient: httpClient,
    );

    final repository = FlagsRepository(
      clientName: name,
      fetcher: fetcher,
      store: configuration.store,
      dateProvider: configuration.dateProvider,
    );

    final client = DefaultDatadogFlagsClient(
      name: name,
      repository: repository,
      exposureLogger: ExposureLogger(
        configuration: configuration,
        datadogConfig: datadogConfig,
        httpClient: httpClient,
      ),
      evaluationAggregator: configuration.trackEvaluations
          ? EvaluationAggregator(
              configuration: configuration,
              datadogConfig: datadogConfig,
              httpClient: httpClient,
            )
          : null,
    );
    _clients[name] = client;
    return client;
  }
}
