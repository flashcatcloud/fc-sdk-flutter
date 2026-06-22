// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

@TestOn('vm')
library;

import 'dart:io';

import 'package:datadog_flags/datadog_flags_io.dart';
import 'package:test/test.dart';

void main() {
  group('FileDatadogFlagsStore', () {
    test('defaults to a temp directory', () {
      final store = FileDatadogFlagsStore();

      expect(store.directory.path, contains(Directory.systemTemp.path));
      expect(
        store.directory.path,
        contains(FileDatadogFlagsStore.defaultDirectoryName),
      );
    });

    test('writes and reads JSON data from disk', () async {
      final directory = await _createTestDirectory();
      final store = FileDatadogFlagsStore(directory: directory);
      final data = {
        'context': {
          'targetingKey': 'user-123',
          'attributes': {'plan': 'pro'},
        },
        'flags': {
          'show-paywall': {'variationValue': true},
        },
      };

      await store.write('default', data);

      final files = await directory.list().toList();
      expect(files, hasLength(1));
      expect(await store.read('default'), data);
    });

    test('overwrites existing JSON data', () async {
      final directory = await _createTestDirectory();
      final store = FileDatadogFlagsStore(directory: directory);

      await store.write('default', {'value': 'old'});
      await store.write('default', {'value': 'new'});

      final files = await directory.list().toList();
      expect(files, hasLength(1));
      expect(await store.read('default'), {'value': 'new'});
    });

    test('keeps client names inside the store directory', () async {
      final directory = await _createTestDirectory();
      final store = FileDatadogFlagsStore(directory: directory);

      await store.write('../default', {'value': true});

      final files = await directory.list().toList();
      expect(files, hasLength(1));
      expect(files.single.path, startsWith(directory.path));
      expect(files.single.path, isNot(contains('..')));
    });

    test('deletes stored data', () async {
      final directory = await _createTestDirectory();
      final store = FileDatadogFlagsStore(directory: directory);

      await store.write('default', {'value': true});
      await store.delete('default');

      expect(await store.read('default'), isNull);
      expect(await directory.list().toList(), isEmpty);
    });

    test('returns null for invalid stored JSON', () async {
      final directory = await _createTestDirectory();
      final store = FileDatadogFlagsStore(directory: directory);

      await directory.create(recursive: true);
      await File('${directory.path}/flags-ZGVmYXVsdA.json').writeAsString('[]');

      expect(await store.read('default'), isNull);
    });
  });
}

Future<Directory> _createTestDirectory() async {
  final directory = await Directory.systemTemp.createTemp(
    'datadog-flags-store-test-',
  );
  addTearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });
  return directory;
}
