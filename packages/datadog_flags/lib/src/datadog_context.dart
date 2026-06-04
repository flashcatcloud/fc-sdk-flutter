// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'flags_site.dart';

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

  Uri flagsEndpoint() {
    return switch (site) {
      DatadogFlagsSite.us1 => Uri.parse('https://preview.ff-cdn.datadoghq.com'),
      DatadogFlagsSite.us1Staging => Uri.parse(
          'https://preview.ff-cdn.datad0g.com',
        ),
      DatadogFlagsSite.us3 => Uri.parse(
          'https://preview.ff-cdn.us3.datadoghq.com',
        ),
      DatadogFlagsSite.us5 => Uri.parse(
          'https://preview.ff-cdn.us5.datadoghq.com',
        ),
      DatadogFlagsSite.eu1 => Uri.parse('https://preview.ff-cdn.datadoghq.eu'),
      DatadogFlagsSite.ap1 => Uri.parse(
          'https://preview.ff-cdn.ap1.datadoghq.com',
        ),
      DatadogFlagsSite.ap2 => Uri.parse(
          'https://preview.ff-cdn.ap2.datadoghq.com',
        ),
    };
  }
}
