// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flags/datadog_flags.dart';

import 'flags_request_counter.dart';
import 'forwarding_flags_counter.dart';

const _externalFlagsEndpoint = String.fromEnvironment('FLAGS_ENDPOINT');
const _externalExposureEndpoint = String.fromEnvironment(
  'FLAGS_EXPOSURE_ENDPOINT',
);
const _externalEvaluationEndpoint = String.fromEnvironment(
  'FLAGS_EVALUATION_ENDPOINT',
);
const _countRequests = bool.fromEnvironment(
  'FLAGS_COUNT_REQUESTS',
  defaultValue: true,
);
const _customClientToken = String.fromEnvironment('FLAGS_CUSTOM_CLIENT_TOKEN');
const _customEnv = String.fromEnvironment(
  'FLAGS_CUSTOM_ENV',
  defaultValue: 'prod',
);
const _customSite = String.fromEnvironment(
  'FLAGS_CUSTOM_SITE',
  defaultValue: 'us1',
);

class FlagsDemoRuntime {
  FlagsRequestCounter? _counter;
  final DatadogFlagsConfig? _baseDatadogConfig;
  final Uri? _customFlagsEndpoint;
  final Uri? _customExposureEndpoint;
  final Uri? _customEvaluationEndpoint;
  final String? applicationId;
  final String configuredEnv;
  final String obfuscatedClientToken;

  FlagsDemoRuntime._({
    required FlagsRequestCounter? counter,
    required DatadogFlagsConfig? datadogConfig,
    required Uri? customFlagsEndpoint,
    required Uri? customExposureEndpoint,
    required Uri? customEvaluationEndpoint,
    required this.applicationId,
    required this.configuredEnv,
    required this.obfuscatedClientToken,
  })  : _counter = counter,
        _baseDatadogConfig = datadogConfig,
        _customFlagsEndpoint = customFlagsEndpoint,
        _customExposureEndpoint = customExposureEndpoint,
        _customEvaluationEndpoint = customEvaluationEndpoint;

  FlagsRequestCounter? get counter => _counter;

  bool get hasCustomProvider => _customClientToken.isNotEmpty;

  DatadogFlagsConfiguration get configuration => _configurationFor(
        datadogConfig: _baseDatadogConfig,
        customFlagsEndpoint: _customFlagsEndpoint,
        customExposureEndpoint: _customExposureEndpoint,
        customEvaluationEndpoint: _customEvaluationEndpoint,
      );

  Future<void> stop() async {
    await DatadogFlags.instance.disable();
    await _counter?.stop();
  }

  Future<FlagsDemoProviderDiagnostics> enableProvider(
    FlagsDemoProviderMode mode,
  ) async {
    final previousCounter = _counter;
    _counter = _createCounter();
    final provider = providerConfiguration(mode);
    final stopwatch = Stopwatch()..start();
    try {
      await DatadogFlags.instance.enable(configuration: provider.configuration);
      stopwatch.stop();
      await previousCounter?.stop();
      return FlagsDemoProviderDiagnostics(
        configuredEnv: provider.configuredEnv,
        obfuscatedClientToken: provider.obfuscatedClientToken,
        providerInitializationDuration: stopwatch.elapsed,
      );
    } catch (_) {
      stopwatch.stop();
      await _counter?.stop();
      _counter = previousCounter;
      rethrow;
    }
  }

  FlagsDemoProviderConfiguration providerConfiguration(
    FlagsDemoProviderMode mode,
  ) {
    return switch (mode) {
      FlagsDemoProviderMode.ffeDogfooding => FlagsDemoProviderConfiguration(
          configuration: configuration,
          configuredEnv: configuredEnv,
          obfuscatedClientToken: obfuscatedClientToken,
        ),
      FlagsDemoProviderMode.custom => _customProviderConfiguration(),
    };
  }

  FlagsDemoProviderConfiguration _customProviderConfiguration() {
    final datadogConfig = _datadogConfig(
      clientToken: _customClientToken,
      env: _customEnv,
      siteName: _customSite,
      applicationId: applicationId,
    );
    if (datadogConfig == null) {
      return providerConfiguration(FlagsDemoProviderMode.ffeDogfooding);
    }

    return FlagsDemoProviderConfiguration(
      configuration: _configurationFor(datadogConfig: datadogConfig),
      configuredEnv: datadogConfig.env,
      obfuscatedClientToken: _obfuscateToken(datadogConfig.clientToken),
    );
  }

  static Future<FlagsDemoRuntime> create({
    String? clientToken,
    String? env,
    String? siteName,
    String? applicationId,
  }) async {
    final externalFlagsEndpoint = _uriFromEnvironment(_externalFlagsEndpoint);
    final externalExposureEndpoint = _uriFromEnvironment(
      _externalExposureEndpoint,
    );
    final externalEvaluationEndpoint = _uriFromEnvironment(
      _externalEvaluationEndpoint,
    );

    final counter = _createCounter();
    final datadogConfig = _datadogConfig(
      clientToken: clientToken,
      env: env,
      siteName: siteName,
      applicationId: applicationId,
    );

    return FlagsDemoRuntime._(
      counter: counter,
      datadogConfig: datadogConfig,
      customFlagsEndpoint: externalFlagsEndpoint ??
          (siteName == 'datad0g.com'
              ? Uri.https(
                  'preview.ff-cdn.datad0g.com',
                  '/precompute-assignments',
                )
              : null),
      customExposureEndpoint: externalExposureEndpoint ??
          (siteName == 'datad0g.com'
              ? Uri.parse(
                  'https://browser-intake-datad0g.com/api/v2/exposures',
                )
              : null),
      customEvaluationEndpoint: externalEvaluationEndpoint ??
          (siteName == 'datad0g.com'
              ? Uri.parse(
                  'https://browser-intake-datad0g.com/api/v2/flagevaluation',
                )
              : null),
      applicationId: applicationId,
      configuredEnv: _configuredEnv(datadogConfig, env),
      obfuscatedClientToken: _obfuscateToken(
        datadogConfig?.clientToken ?? clientToken,
      ),
    );
  }

  DatadogFlagsConfiguration _configurationFor({
    required DatadogFlagsConfig? datadogConfig,
    Uri? customFlagsEndpoint,
    Uri? customExposureEndpoint,
    Uri? customEvaluationEndpoint,
  }) {
    final requestCounter = _counter;
    return DatadogFlagsConfiguration(
      customFlagsEndpoint: customFlagsEndpoint,
      customExposureEndpoint: customExposureEndpoint,
      customEvaluationEndpoint: customEvaluationEndpoint,
      httpClient: requestCounter is ForwardingFlagsCounter
          ? requestCounter.httpClient
          : null,
      datadogConfig: datadogConfig,
      evaluationFlushInterval: const Duration(seconds: 1),
    );
  }
}

enum FlagsDemoProviderMode { ffeDogfooding, custom }

class FlagsDemoProviderConfiguration {
  final DatadogFlagsConfiguration configuration;
  final String configuredEnv;
  final String obfuscatedClientToken;

  const FlagsDemoProviderConfiguration({
    required this.configuration,
    required this.configuredEnv,
    required this.obfuscatedClientToken,
  });
}

class FlagsDemoProviderDiagnostics {
  final String configuredEnv;
  final String obfuscatedClientToken;
  final Duration providerInitializationDuration;

  const FlagsDemoProviderDiagnostics({
    required this.configuredEnv,
    required this.obfuscatedClientToken,
    required this.providerInitializationDuration,
  });
}

DatadogFlagsConfig? _datadogConfig({
  required String? clientToken,
  required String? env,
  required String? siteName,
  required String? applicationId,
}) {
  if (clientToken == null || clientToken.isEmpty) {
    return null;
  }

  return DatadogFlagsConfig(
    clientToken: clientToken,
    env: env ?? 'dev',
    site: _flagsSiteForName(siteName),
    service: 'simple-example',
    version: '1.0.0',
    applicationId: _emptyToNull(applicationId),
  );
}

DatadogFlagsSite _flagsSiteForName(String? siteName) {
  return switch (siteName) {
    'datad0g.com' => DatadogFlagsSite.us1Staging,
    'us3' || 'us3.datadoghq.com' => DatadogFlagsSite.us3,
    'us5' || 'us5.datadoghq.com' => DatadogFlagsSite.us5,
    'eu1' || 'datadoghq.eu' => DatadogFlagsSite.eu1,
    'ap1' || 'ap1.datadoghq.com' => DatadogFlagsSite.ap1,
    'ap2' || 'ap2.datadoghq.com' => DatadogFlagsSite.ap2,
    _ => DatadogFlagsSite.us1,
  };
}

Uri? _uriFromEnvironment(String value) {
  if (value.isEmpty) {
    return null;
  }
  return Uri.parse(value);
}

String? _emptyToNull(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

String _configuredEnv(DatadogFlagsConfig? config, String? fallback) {
  if (config != null) {
    return config.env;
  }
  if (fallback != null && fallback.isNotEmpty) {
    return fallback;
  }
  return '-';
}

String _obfuscateToken(String? token) {
  if (token == null || token.isEmpty) {
    return '-';
  }
  if (token.length <= 10) {
    return '${token.substring(0, 1)}...${token.substring(token.length - 1)}';
  }
  return '${token.substring(0, 6)}...${token.substring(token.length - 4)}';
}

FlagsRequestCounter? _createCounter() {
  return _countRequests ? ForwardingFlagsCounter.create() : null;
}
