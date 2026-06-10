// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:meta/meta.dart';

enum DatadogFlagsSite {
  us1('https://preview.ff-cdn.datadoghq.com'),
  us1Staging('https://preview.ff-cdn.datad0g.com'),
  us3('https://preview.ff-cdn.us3.datadoghq.com'),
  us5('https://preview.ff-cdn.us5.datadoghq.com'),
  eu1('https://preview.ff-cdn.datadoghq.eu'),
  ap1('https://preview.ff-cdn.ap1.datadoghq.com'),
  ap2('https://preview.ff-cdn.ap2.datadoghq.com');

  final String flagsEndpointUrl;

  const DatadogFlagsSite(this.flagsEndpointUrl);

  Uri get flagsEndpoint => Uri.parse(flagsEndpointUrl);
}

@immutable
final class DatadogFlagsConfig {
  static const defaultSdkName = 'dd-sdk-flutter';
  static const defaultSdkVersion = '0.0.1';

  final String clientToken;
  final String env;
  final DatadogFlagsSite site;
  final String? applicationId;
  final String sdkVersion;

  const DatadogFlagsConfig({
    required this.clientToken,
    required this.env,
    required this.site,
    this.applicationId,
    this.sdkVersion = DatadogFlagsConfig.defaultSdkVersion,
  });

  Uri flagsEndpoint() => site.flagsEndpoint;
}
