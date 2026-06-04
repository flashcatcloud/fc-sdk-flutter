// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags/src/assignment.dart';
import 'package:datadog_flags/src/flag_assignments_fetcher.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('mirrored canonical precompute fixture files load as JSON', () {
    final casesDirectory = [
      Directory('test/fixtures/precomputed/cases'),
      Directory('packages/datadog_flags/test/fixtures/precomputed/cases'),
    ].firstWhere((directory) => directory.existsSync());
    final files = casesDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList()
      ..sort((left, right) => left.path.compareTo(right.path));

    expect(files.map((file) => file.uri.pathSegments.last), [
      'all-types-success.json',
      'defaults-and-emission-gates.json',
    ]);

    for (final file in files) {
      final decoded = jsonDecode(file.readAsStringSync());
      expect(decoded, isA<Map<String, Object?>>());
    }
  });

  test('mirrored canonical precompute fixtures parse as assignments', () async {
    for (final fixture in _fixtureCases()) {
      final assignments = await _fetchAssignments(fixture);
      final flags = _flagsFrom(fixture);

      for (final entry in flags.entries) {
        final rawAssignment = entry.value as Map<String, Object?>;
        final expectedType = normalizeVariationType(
          rawAssignment['variationType'] as String?,
          rawAssignment['variationValue'],
        );
        if (expectedType == FlagVariationType.unknown) {
          expect(assignments.containsKey(entry.key), isFalse);
          continue;
        }

        final assignment = assignments[entry.key];
        expect(assignment, isNotNull);
        expect(assignment!.allocationKey, rawAssignment['allocationKey']);
        expect(assignment.variationKey, rawAssignment['variationKey']);
        expect(assignment.variationType, expectedType);
        expect(assignment.variationValue, rawAssignment['variationValue']);
        expect(assignment.reason, rawAssignment['reason']);
        expect(assignment.doLog, rawAssignment['doLog']);
      }
    }
  });
}

List<Map<String, Object?>> _fixtureCases() {
  final casesDirectory = [
    Directory('test/fixtures/precomputed/cases'),
    Directory('packages/datadog_flags/test/fixtures/precomputed/cases'),
  ].firstWhere((directory) => directory.existsSync());

  final files = casesDirectory
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.json'))
      .toList()
    ..sort((left, right) => left.path.compareTo(right.path));

  return [
    for (final file in files)
      jsonDecode(file.readAsStringSync()) as Map<String, Object?>,
  ];
}

Future<Map<String, FlagAssignment>> _fetchAssignments(
  Map<String, Object?> fixture,
) async {
  final fetcher = FlagAssignmentsFetcher(
    datadogContext: const DatadogFlagsContext(
      clientToken: 'client-token',
      env: 'staging',
      site: DatadogFlagsSite.us1,
    ),
    configuration: const DatadogFlagsConfiguration(),
    httpClient: MockClient((_) async {
      return http.Response(jsonEncode(fixture['response']), 200);
    }),
  );

  return fetcher.fetch(
    DatadogFlagsEvaluationContext.fromJson(
      fixture['context'] as Map<String, Object?>,
    ),
  );
}

Map<String, Object?> _flagsFrom(Map<String, Object?> fixture) {
  final response = fixture['response'] as Map<String, Object?>;
  final data = response['data'] as Map<String, Object?>;
  final attributes = data['attributes'] as Map<String, Object?>;
  return attributes['flags'] as Map<String, Object?>;
}
