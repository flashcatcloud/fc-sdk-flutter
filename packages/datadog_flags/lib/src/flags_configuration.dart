// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:http/http.dart' as http;

import 'datadog_context.dart';

class DatadogFlagsConfiguration {
  final Uri? customFlagsEndpoint;
  final Map<String, String>? customFlagsHeaders;
  final Uri? customExposureEndpoint;
  final bool trackExposures;
  final http.Client? httpClient;
  final DatadogFlagsContext? datadogContext;
  final bool rumIntegrationEnabled;
  final DateTime Function() dateProvider;

  const DatadogFlagsConfiguration({
    this.customFlagsEndpoint,
    this.customFlagsHeaders,
    this.customExposureEndpoint,
    this.trackExposures = true,
    this.httpClient,
    this.datadogContext,
    this.rumIntegrationEnabled = true,
    this.dateProvider = DateTime.now,
  });
}
