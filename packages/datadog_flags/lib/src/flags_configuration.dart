// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:http/http.dart' as http;

import 'datadog_context.dart';

class DatadogFlagsConfiguration {
  final Uri? customFlagsEndpoint;
  final Map<String, String>? customFlagsHeaders;
  final http.Client? httpClient;
  final DatadogFlagsContext? datadogContext;

  const DatadogFlagsConfiguration({
    this.customFlagsEndpoint,
    this.customFlagsHeaders,
    this.httpClient,
    this.datadogContext,
  });
}
