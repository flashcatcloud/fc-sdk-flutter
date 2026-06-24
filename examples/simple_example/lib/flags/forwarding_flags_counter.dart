// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'flags_request_counter.dart';

class ForwardingFlagsCounter implements FlagsRequestCounter {
  final CountingFlagsHttpClient httpClient;

  ForwardingFlagsCounter._(this.httpClient);

  factory ForwardingFlagsCounter.create() {
    return ForwardingFlagsCounter._(CountingFlagsHttpClient(http.Client()));
  }

  @override
  int get precomputeRequestCount => httpClient.precomputeRequestCount;

  @override
  int get exposureCount => httpClient.exposureCount;

  @override
  int get evaluationRequestCount => httpClient.evaluationRequestCount;

  @override
  int get evaluationEventCount => httpClient.evaluationEventCount;

  @override
  int? get lastPrecomputeFlagCount => httpClient.lastPrecomputeFlagCount;

  @override
  int? get lastPrecomputePayloadBytes => httpClient.lastPrecomputePayloadBytes;

  @override
  int? get lastPrecomputeStatusCode => httpClient.lastPrecomputeStatusCode;

  @override
  Duration? get lastPrecomputeHttpDuration =>
      httpClient.lastPrecomputeHttpDuration;

  @override
  Duration? get lastPrecomputePayloadParseDuration =>
      httpClient.lastPrecomputePayloadParseDuration;

  @override
  Future<void> stop() async {
    httpClient.close();
  }
}

class CountingFlagsHttpClient extends http.BaseClient {
  final http.Client _inner;

  int precomputeRequestCount = 0;
  int exposureCount = 0;
  int evaluationRequestCount = 0;
  int evaluationEventCount = 0;
  int? lastPrecomputeFlagCount;
  int? lastPrecomputePayloadBytes;
  int? lastPrecomputeStatusCode;
  Duration? lastPrecomputeHttpDuration;
  Duration? lastPrecomputePayloadParseDuration;

  CountingFlagsHttpClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = request is http.Request ? request.body : '';
    final path = request.url.path;
    if (path == '/precompute-assignments') {
      precomputeRequestCount += 1;
      final stopwatch = Stopwatch()..start();
      final response = await _inner.send(request);
      final bodyBytes = await response.stream.toBytes();
      stopwatch.stop();
      lastPrecomputeHttpDuration = stopwatch.elapsed;
      lastPrecomputePayloadBytes = bodyBytes.length;
      lastPrecomputeStatusCode = response.statusCode;

      final parseStopwatch = Stopwatch()..start();
      lastPrecomputeFlagCount = _tryCountPrecomputeFlags(bodyBytes);
      parseStopwatch.stop();
      lastPrecomputePayloadParseDuration = parseStopwatch.elapsed;

      return _copyResponseWithBytes(response, bodyBytes);
    } else if (path == '/api/v2/exposures') {
      exposureCount += _countExposureBody(body);
    } else if (path == '/api/v2/flagevaluation') {
      evaluationRequestCount += 1;
      evaluationEventCount += _tryCountEvaluationEvents(body);
    }
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

int _countExposureBody(String body) {
  return body.split('\n').where((line) => line.trim().isNotEmpty).length;
}

int? _tryCountPrecomputeFlags(List<int> bodyBytes) {
  try {
    final decoded = jsonDecode(utf8.decode(bodyBytes)) as Map<String, Object?>;
    final data = decoded['data'] as Map<String, Object?>;
    final attributes = data['attributes'] as Map<String, Object?>;
    final flags = attributes['flags'] as Map<String, Object?>;
    return flags.length;
  } catch (_) {
    return null;
  }
}

int _tryCountEvaluationEvents(String body) {
  try {
    final decoded = jsonDecode(body) as Map<String, Object?>;
    final evaluations = decoded['flagEvaluations'] as List<Object?>;
    return evaluations.length;
  } catch (_) {
    return 0;
  }
}

http.StreamedResponse _copyResponseWithBytes(
  http.StreamedResponse response,
  List<int> bodyBytes,
) {
  return http.StreamedResponse(
    Stream.value(bodyBytes),
    response.statusCode,
    contentLength: response.contentLength,
    request: response.request,
    headers: response.headers,
    isRedirect: response.isRedirect,
    persistentConnection: response.persistentConnection,
    reasonPhrase: response.reasonPhrase,
  );
}
