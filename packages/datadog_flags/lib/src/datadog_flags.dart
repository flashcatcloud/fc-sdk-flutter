// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:http/http.dart' as http;

import 'datadog_context.dart';
import 'default_flags_client.dart';
import 'flag_assignments_fetcher.dart';
import 'flags_client.dart';
import 'flags_configuration.dart';
import 'flags_repository.dart';
import 'no_op_flags_client.dart';

/// Entry point for configuring and creating Datadog feature flag clients.
///
/// `DatadogFlags` state is local to the current Dart isolate. Background
/// isolates must use their own [DatadogFlags] instance, create any clients they
/// need, and set their own evaluation contexts before evaluating flags.
class DatadogFlags {
  static const defaultClientName = 'default';

  static DatadogFlags? _singleton;

  static DatadogFlags get instance {
    _singleton ??= DatadogFlags();
    return _singleton!;
  }

  http.Client? _httpClient;
  _FlagsRuntime? _runtime;
  final Map<String, DatadogFlagsClient> _clients = {};

  DatadogFlags();

  bool get isEnabled => _runtime != null;

  Future<void> enable({
    DatadogFlagsConfiguration configuration = const DatadogFlagsConfiguration(),
  }) async {
    await disable();

    final datadogContext = configuration.datadogContext;
    if (datadogContext == null) {
      return;
    }

    _httpClient = configuration.httpClient ?? http.Client();
    _runtime = _FlagsRuntime(
      configuration: configuration,
      datadogContext: datadogContext,
      httpClient: _httpClient!,
    );
    sharedClient();
  }

  DatadogFlagsClient sharedClient({
    String name = defaultClientName,
  }) {
    return _client(name);
  }

  Future<void> reset() async {
    await Future.wait(_clients.values.map((client) => client.reset()));
  }

  Future<void> disable() async {
    _clients.clear();
    _httpClient?.close();
    _httpClient = null;
    _runtime = null;
  }

  DatadogFlagsClient _client(String name) {
    final existing = _clients[name];
    if (existing != null) {
      return existing;
    }

    final runtime = _runtime;
    if (runtime == null) {
      final client = NoOpDatadogFlagsClient(name: name);
      _clients[name] = client;
      return client;
    }

    final repository = FlagsRepository(
      fetcher: FlagAssignmentsFetcher(
        datadogContext: runtime.datadogContext,
        configuration: runtime.configuration,
        httpClient: runtime.httpClient,
      ),
    );

    final client = DefaultDatadogFlagsClient(
      name: name,
      repository: repository,
    );
    _clients[name] = client;
    return client;
  }
}

class _FlagsRuntime {
  final DatadogFlagsConfiguration configuration;
  final DatadogFlagsContext datadogContext;
  final http.Client httpClient;

  const _FlagsRuntime({
    required this.configuration,
    required this.datadogContext,
    required this.httpClient,
  });
}
