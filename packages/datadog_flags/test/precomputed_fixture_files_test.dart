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
  for (final fixtureFileName in _fixtureFileNames) {
    test(
      'mirrored canonical precompute fixture $fixtureFileName parses',
      () async {
        final fixture = _fixtureCase(fixtureFileName);
        final assignments = await _fetchAssignments(fixture);
        final flags = _flagsFrom(fixture);

        for (final entry in flags.entries) {
          final rawAssignment = entry.value as Map<String, Object?>;
          final FlagVariationType expectedType;
          try {
            expectedType = FlagVariationType.fromWireName(
              rawAssignment['variationType'] as String?,
            );
          } catch (_) {
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
      },
    );
  }
}

const _fixtureFileNames = [
  'all-types-success.json',
  'defaults-and-emission-gates.json',
];

Map<String, Object?> _fixtureCase(String fileName) {
  final file = File.fromUri(
    _packageRoot().uri.resolve('test/fixtures/precomputed/cases/$fileName'),
  );
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}

Directory _packageRoot() {
  if (Platform.script.scheme == 'file') {
    final scriptRoot = _findPackageRoot(File.fromUri(Platform.script).parent);
    if (scriptRoot != null) {
      return scriptRoot;
    }
  }

  final currentRoot = _findPackageRoot(Directory.current);
  if (currentRoot != null) {
    return currentRoot;
  }

  throw StateError('Could not find datadog_flags package root.');
}

Directory? _findPackageRoot(Directory start) {
  var directory = start.absolute;
  while (true) {
    if (_isDatadogFlagsPackage(directory)) {
      return directory;
    }

    final nested = Directory.fromUri(
      directory.uri.resolve('packages/datadog_flags/'),
    );
    if (_isDatadogFlagsPackage(nested)) {
      return nested;
    }

    final parent = directory.parent;
    if (parent.path == directory.path) {
      return null;
    }
    directory = parent;
  }
}

bool _isDatadogFlagsPackage(Directory directory) {
  return File.fromUri(directory.uri.resolve('pubspec.yaml')).existsSync() &&
      File.fromUri(directory.uri.resolve('lib/datadog_flags.dart'))
          .existsSync();
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

  return (await fetcher.fetch(
    FlagsEvaluationContext.fromJson(
      fixture['context'] as Map<String, Object?>,
    ),
  ))
      .flags;
}

Map<String, Object?> _flagsFrom(Map<String, Object?> fixture) {
  final response = fixture['response'] as Map<String, Object?>;
  final data = response['data'] as Map<String, Object?>;
  final attributes = data['attributes'] as Map<String, Object?>;
  return attributes['flags'] as Map<String, Object?>;
}
