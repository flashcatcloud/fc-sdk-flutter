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
import 'json_value.dart';

class FlagAssignmentsFetcher {
  final DatadogFlagsContext datadogContext;
  final DatadogFlagsConfiguration configuration;
  final http.Client httpClient;

  FlagAssignmentsFetcher({
    required this.datadogContext,
    required this.configuration,
    required this.httpClient,
  });

  Future<Map<String, FlagAssignment>> fetch(
    DatadogFlagsEvaluationContext evaluationContext,
  ) async {
    final endpoint = configuration.customFlagsEndpoint ??
        datadogContext.flagsEndpoint().replace(
              path: '/precompute-assignments',
            );
    final http.Response response;
    try {
      response = await httpClient.post(
        endpoint,
        headers: _headers(),
        body: jsonEncode(_requestBody(evaluationContext)),
      );
    } catch (error) {
      throw FlagsException.networkError(
        'Failed to fetch flag assignments.',
        error,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FlagsException.networkError(
        'Unexpected flag assignments response status ${response.statusCode}.',
      );
    }

    try {
      final decoded = _asObject(jsonDecode(response.body), 'response');
      final data = _asObject(decoded['data'], 'data');
      final attributes = _asObject(data['attributes'], 'attributes');
      final flags = _asObject(attributes['flags'], 'flags');
      final assignments = <String, FlagAssignment>{};
      for (final entry in flags.entries) {
        final assignment = _parseAssignment(entry.value);
        if (assignment == null ||
            assignment.variationType == FlagVariationType.unknown) {
          continue;
        }
        assignments[entry.key] = assignment;
      }
      return assignments;
    } catch (error) {
      throw FlagsException.invalidResponse(
        'Failed to decode flag assignments response: $error',
      );
    }
  }

  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/vnd.api+json',
      'dd-client-token': datadogContext.clientToken,
      if (datadogContext.applicationId != null)
        'dd-application-id': datadogContext.applicationId!,
      ...?configuration.customFlagsHeaders,
    };
  }

  Map<String, Object?> _requestBody(
    DatadogFlagsEvaluationContext evaluationContext,
  ) {
    return {
      'data': {
        'type': 'precompute-assignments-request',
        'attributes': {
          'env': {
            'dd_env': datadogContext.env,
          },
          'subject': {
            'targeting_key': evaluationContext.targetingKey,
            'targeting_attributes': sanitizeJsonValue(
              evaluationContext.attributes,
            ),
          },
        },
      },
    };
  }
}

Map<String, Object?> _asObject(Object? value, String name) {
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  throw FormatException('$name must be a JSON object');
}

FlagAssignment? _parseAssignment(Object? value) {
  try {
    return FlagAssignment.fromJson(_asObject(value, 'flag assignment'));
  } catch (_) {
    return null;
  }
}
