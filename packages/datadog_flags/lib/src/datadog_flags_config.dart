// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:meta/meta.dart';

enum DatadogFlagsSite {
  us1(
    'https://preview.ff-cdn.datadoghq.com',
    'https://browser-intake-datadoghq.com',
  ),
  us1Staging(
    'https://preview.ff-cdn.datad0g.com',
    'https://browser-intake-datad0g.com',
  ),
  us3(
    'https://preview.ff-cdn.us3.datadoghq.com',
    'https://browser-intake-us3-datadoghq.com',
  ),
  us5(
    'https://preview.ff-cdn.us5.datadoghq.com',
    'https://browser-intake-us5-datadoghq.com',
  ),
  eu1(
    'https://preview.ff-cdn.datadoghq.eu',
    'https://browser-intake-datadoghq.eu',
  ),
  ap1(
    'https://preview.ff-cdn.ap1.datadoghq.com',
    'https://browser-intake-ap1-datadoghq.com',
  ),
  ap2(
    'https://preview.ff-cdn.ap2.datadoghq.com',
    'https://browser-intake-ap2-datadoghq.com',
  );

  final String flagsEndpointUrl;
  final String intakeEndpointUrl;

  const DatadogFlagsSite(this.flagsEndpointUrl, this.intakeEndpointUrl);

  Uri get flagsEndpoint => Uri.parse(flagsEndpointUrl);
  Uri get intakeEndpoint => Uri.parse(intakeEndpointUrl);
}

@immutable
final class DatadogFlagsConfig {
  final String clientToken;
  final String env;
  final DatadogFlagsSite site;
  final String? applicationId;

  const DatadogFlagsConfig({
    required this.clientToken,
    required this.env,
    required this.site,
    this.applicationId,
  });

  Uri flagsEndpoint() => site.flagsEndpoint;
  Uri intakeEndpoint() => site.intakeEndpoint;
}
