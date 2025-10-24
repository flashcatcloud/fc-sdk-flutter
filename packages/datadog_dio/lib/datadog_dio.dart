// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_dio/src/datadog_dio_interceptor.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:dio/dio.dart';

extension DatadogDio on Dio {
  void addDatadogInterceptor(
    DatadogSdk sdk, {
    List<RegExp> ignoreUrlPatterns = const [],
    DatadogDioAttributeProvider? attributesProvider,
  }) {
    // Add the interceptor as the first interceptor to ensure
    // other interceptors can't skip it.
    interceptors.insert(
        0,
        DatadogDioInterceptor(
          datadogSdk: sdk,
          ignoreUrlPatterns: ignoreUrlPatterns,
          attributesProvider: attributesProvider,
        ));
  }
}
