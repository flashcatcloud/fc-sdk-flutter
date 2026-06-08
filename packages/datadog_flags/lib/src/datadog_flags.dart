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
import 'flags_error.dart';
import 'flags_repository.dart';

/// Entry point for configuring and creating Datadog feature flag clients.
///
/// `DatadogFlags` state is local to the current Dart isolate. Background
/// isolates must call [enable], create any clients they need, and set their own
/// evaluation contexts before evaluating flags.
class DatadogFlags {
  static DatadogFlagsConfiguration _configuration =
      const DatadogFlagsConfiguration();
  static DatadogFlagsContext? _datadogContext;
  static http.Client? _httpClient;
  static final Map<String, DatadogFlagsClient> _clients = {};
  static bool _enabled = false;

  DatadogFlags._();

  static bool get isEnabled => _enabled;

  static Future<void> enable({
    DatadogFlagsConfiguration configuration = const DatadogFlagsConfiguration(),
  }) async {
    await _disposeClients();
    _httpClient?.close();
    _httpClient = null;
    _datadogContext = null;
    _enabled = false;

    final datadogContext = configuration.datadogContext;
    if (datadogContext == null) {
      throw FlagsException.invalidConfiguration(
        'DatadogFlagsConfiguration.datadogContext is required.',
      );
    }

    _configuration = configuration;
    _datadogContext = datadogContext;
    _httpClient = configuration.httpClient ?? http.Client();
    _enabled = true;
    await createClient();
  }

  static Future<DatadogFlagsClient> createClient({
    String name = DatadogFlagsClient.defaultName,
  }) async {
    final existing = _clients[name];
    if (existing != null) {
      return existing;
    }

    final runtime = _runtimeOrThrow();
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

  static DatadogFlagsClient sharedClient({
    String name = DatadogFlagsClient.defaultName,
  }) {
    final client = _clients[name];
    if (client == null) {
      throw FlagsException.clientNotInitialized(
        'DatadogFlagsClient named "$name" has not been created.',
      );
    }
    return client;
  }

  static Future<void> reset() async {
    await Future.wait(_clients.values.map((client) => client.reset()));
  }

  static Future<void> disable() async {
    await _disposeClients();
    _httpClient?.close();
    _httpClient = null;
    _datadogContext = null;
    _enabled = false;
  }

  static Future<void> _disposeClients() async {
    await Future.wait(_clients.values.map((client) => client.dispose()));
    _clients.clear();
  }

  static _FlagsRuntime _runtimeOrThrow() {
    final datadogContext = _datadogContext;
    final httpClient = _httpClient;
    if (!_enabled || datadogContext == null || httpClient == null) {
      throw FlagsException.clientNotInitialized(
        'Call DatadogFlags.enable() before creating a flags client.',
      );
    }

    return _FlagsRuntime(
      configuration: _configuration,
      datadogContext: datadogContext,
      httpClient: httpClient,
    );
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
