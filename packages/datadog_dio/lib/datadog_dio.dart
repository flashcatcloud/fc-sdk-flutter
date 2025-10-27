// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_dio/src/datadog_dio_interceptor.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:dio/dio.dart';

/// A set of callbacks that allow you to provide attributes that should be
/// attached to a Datadog RUM resource created from a [DatadogDioInterceptor]. This
/// callback is called as part of the [Interceptor.onResponse] and [Interceptor.onError]
/// callbacks..
///
/// If any of these functions throw, it will prevent proper tracking of this resource.
abstract interface class DatadogDioAttributeProvider {
  Map<String, Object?>? onRequest(RequestOptions request);
  Map<String, Object?>? onResponse(Response<dynamic> response);
  Map<String, Object?>? onError(DioException err);
}

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
