// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';

enum DatadogFlagsSite {
  us1,
  us3,
  us5,
  eu1,
  ap1,
  ap2,
  us1Fed,
}

class DatadogFlagsContext {
  final String clientToken;
  final String env;
  final DatadogFlagsSite site;
  final String? applicationId;

  const DatadogFlagsContext({
    required this.clientToken,
    required this.env,
    required this.site,
    this.applicationId,
  });

  factory DatadogFlagsContext.fromSdk(DatadogSdk sdk) {
    final configuration = sdk.configuration;
    if (configuration == null) {
      throw StateError(
        'DatadogSdk must be initialized before enabling DatadogFlags.',
      );
    }

    return DatadogFlagsContext(
      clientToken: configuration.clientToken,
      env: configuration.env,
      site: _siteFromSdk(configuration.site),
      applicationId: configuration.rumConfiguration?.applicationId,
    );
  }

  Uri flagsEndpoint() {
    return switch (site) {
      DatadogFlagsSite.us1 => Uri.parse('https://preview.ff-cdn.datadoghq.com'),
      DatadogFlagsSite.us3 =>
        Uri.parse('https://preview.ff-cdn.us3.datadoghq.com'),
      DatadogFlagsSite.us5 =>
        Uri.parse('https://preview.ff-cdn.us5.datadoghq.com'),
      DatadogFlagsSite.eu1 => Uri.parse('https://preview.ff-cdn.datadoghq.eu'),
      DatadogFlagsSite.ap1 =>
        Uri.parse('https://preview.ff-cdn.ap1.datadoghq.com'),
      DatadogFlagsSite.ap2 =>
        Uri.parse('https://preview.ff-cdn.ap2.datadoghq.com'),
      DatadogFlagsSite.us1Fed =>
        Uri.parse('https://preview.ff-cdn.datadoghq.com'),
    };
  }
}

DatadogFlagsSite _siteFromSdk(DatadogSite site) {
  return switch (site) {
    DatadogSite.us1 => DatadogFlagsSite.us1,
    DatadogSite.us3 => DatadogFlagsSite.us3,
    DatadogSite.us5 => DatadogFlagsSite.us5,
    DatadogSite.eu1 => DatadogFlagsSite.eu1,
    DatadogSite.ap1 => DatadogFlagsSite.ap1,
    DatadogSite.ap2 => DatadogFlagsSite.ap2,
    DatadogSite.us1Fed => DatadogFlagsSite.us1Fed,
  };
}
