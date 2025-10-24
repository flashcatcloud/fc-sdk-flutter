// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

// ignore_for_file: invalid_use_of_internal_member

import 'dart:io';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// A set of callbacks that allow you to provide attributes that should be
/// attached to a Datadog RUM resource created from a [DatadogDioInterceptor]. This
/// callback is called as part of the [Interceptor.onResponse] and [Interceptor.onError]
/// callbacks..
///
/// If any of these functions throw, it will prevent proper tracking of this resource.
abstract interface class DatadogDioAttributeProvider {
  Map<String, Object?>? onResponse(Response<dynamic> response);
  Map<String, Object?>? onError(DioException err);
}

class DatadogDioInterceptor extends Interceptor {
  static const String datadogRumExtraKey = '__datadog_rum_key';

  final DatadogSdk datadogSdk;
  final List<RegExp> ignoreUrlPatterns;
  final DatadogDioAttributeProvider? attributesProvider;

  final Uuid _uuid = const Uuid();

  DatadogDioInterceptor({
    required this.datadogSdk,
    this.ignoreUrlPatterns = const [],
    this.attributesProvider,
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final rum = DatadogSdk.instance.rum;
    if (!kIsWeb && rum != null) {
      _trackRequest(options, rum);
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) {
    final rum = datadogSdk.rum;
    final rumKey = response.requestOptions.extra[datadogRumExtraKey];
    if (!kIsWeb && rum != null && rumKey is String) {
      try {
        final contentTypeHeader =
            response.headers[Headers.contentTypeHeader]?.firstOrNull;
        final contentType = contentTypeHeader != null
            ? ContentType.parse(contentTypeHeader)
            : ContentType.text;
        final resourceType = resourceTypeFromContentType(contentType);
        int? contentLength;
        final contentLengthHeader =
            response.headers[Headers.contentLengthHeader]?.firstOrNull;
        if (contentLengthHeader != null) {
          contentLength = int.tryParse(contentLengthHeader);
        }
        final attributes = attributesProvider?.onResponse(response) ?? {};
        rum.stopResource(
          rumKey,
          response.statusCode,
          resourceType,
          contentLength,
          attributes,
        );
      } catch (e, st) {
        datadogSdk.internalLogger.sendToDatadog(
          '$DatadogDioInterceptor encountered an error while attempting '
          ' to track a request: $e',
          st,
          e.runtimeType.toString(),
        );
      }
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final rum = datadogSdk.rum;
    final rumKey = err.requestOptions.extra[datadogRumExtraKey];
    if (!kIsWeb && rum != null && rumKey is String) {
      try {
        final attributes = attributesProvider?.onError(err) ?? {};
        rum.stopResourceWithErrorInfo(
            rumKey, err.toString(), err.type.toString(), attributes);
      } catch (e, st) {
        datadogSdk.internalLogger.sendToDatadog(
          '$DatadogDioInterceptor encountered an error while attempting '
          ' to track a request: $e',
          st,
          e.runtimeType.toString(),
        );
      }
    }
    super.onError(err, handler);
  }

  void _trackRequest(RequestOptions options, DatadogRum rum) {
    String? rumKey;
    if (_shouldTrackRequest(options)) {
      try {
        final tracingHeaders = datadogSdk.headerTypesForHost(options.uri);
        final rumHttpMethod = rumMethodFromMethodString(options.method);
        var attributes = <String, Object?>{};
        // Is first party?
        if (tracingHeaders.isNotEmpty) {
          var shouldSample = rum.shouldSampleTrace();
          var context = generateTracingContext(shouldSample);

          attributes = _appendRequestHeaders(
            options,
            context,
            tracingHeaders,
            rum.contextInjectionSetting,
          );
        }

        rumKey = _uuid.v1();
        options.extra[datadogRumExtraKey] = rumKey;
        rum.startResource(
            rumKey, rumHttpMethod, options.uri.toString(), attributes);
      } catch (e, st) {
        datadogSdk.internalLogger.sendToDatadog(
          '$DatadogDioInterceptor encountered an error while attempting'
          ' to track a request: $e',
          st,
          e.runtimeType.toString(),
        );
        // Since there was an error, don't attempt any more tracking
        rumKey = null;
      }
    }
  }

  bool _shouldTrackRequest(RequestOptions options) {
    final url = options.uri.toString();
    for (final pattern in ignoreUrlPatterns) {
      if (pattern.hasMatch(url)) {
        return false;
      }
    }
    return true;
  }

  Map<String, Object?> _appendRequestHeaders(
    RequestOptions requestOptions,
    TracingContext context,
    Set<TracingHeaderType> tracingHeaderTypes,
    TraceContextInjection contextInjection,
  ) {
    var attributes = <String, Object?>{};

    if (tracingHeaderTypes.isNotEmpty) {
      attributes = generateDatadogAttributes(
          context, datadogSdk.rum?.traceSampleRate ?? 0);

      for (final headerType in tracingHeaderTypes) {
        requestOptions.headers.addAll(getTracingHeaders(
          context,
          headerType,
          contextInjection: contextInjection,
        ));
      }
    }

    return attributes;
  }
}
