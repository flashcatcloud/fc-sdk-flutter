// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'assignment.dart';
import 'datadog_context.dart';
import 'flags_configuration.dart';
import 'flags_context.dart';
import 'flags_error.dart';
import 'precompute_request.dart';
import 'precompute_response.dart';

class FlagAssignmentsFetcher {
  final DatadogFlagsContext datadogContext;
  final DatadogFlagsConfiguration configuration;
  final http.Client httpClient;

  FlagAssignmentsFetcher({
    required this.datadogContext,
    required this.configuration,
    required this.httpClient,
  });

  Future<PrecomputedAssignments> fetch(
    FlagsEvaluationContext evaluationContext,
  ) async {
    final endpoint = configuration.customFlagsEndpoint ??
        datadogContext.flagsEndpoint().replace(path: '/precompute-assignments');
    final http.Response response;
    try {
      response = await httpClient.post(
        endpoint,
        headers: _headers(),
        body: jsonEncode(
          PrecomputeRequest.fromContext(
            datadogContext: datadogContext,
            evaluationContext: evaluationContext,
          ).toJson(),
        ),
      );
    } catch (error) {
      throw FlagsException.networkError(
        'Failed to fetch flag assignments.',
        cause: error,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FlagsException.networkError(
        'Unexpected flag assignments response status ${response.statusCode}.',
      );
    }

    try {
      final decoded = PrecomputeResponse.fromJson(
        _asObject(jsonDecode(response.body), 'response'),
      );
      final attributes = decoded.data.attributes;
      return PrecomputedAssignments(
        flags: attributes.flags,
        createdAt: attributes.createdAt,
        environment: attributes.environment,
      );
    } catch (error) {
      throw FlagsException.invalidResponse(
        'Failed to decode flag assignments response: $error',
        cause: error,
      );
    }
  }

  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/vnd.api+json',
      'dd-client-token': datadogContext.clientToken,
      if (datadogContext.applicationId case final applicationId?)
        'dd-application-id': applicationId,
      ...?configuration.customFlagsHeaders,
    };
  }
}

Map<String, Object?> _asObject(Object? value, String name) {
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  throw FormatException('$name must be a JSON object');
}
