// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'flags_store.dart';

class FileDatadogFlagsStore implements DatadogFlagsStore {
  static const defaultDirectoryName = 'datadog_flags';

  final Directory directory;

  FileDatadogFlagsStore({Directory? directory})
      : directory = directory ??
            Directory('${Directory.systemTemp.path}/$defaultDirectoryName');

  @override
  Future<Map<String, Object?>?> read(String clientName) async {
    try {
      final file = _file(clientName);
      if (!await file.exists()) {
        return null;
      }

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        return null;
      }
      return Map<String, Object?>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String clientName, Map<String, Object?> data) async {
    try {
      await directory.create(recursive: true);
      final file = _file(clientName);
      final temporaryFile = File('${file.path}.tmp');

      await temporaryFile.writeAsString(jsonEncode(data), flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await temporaryFile.rename(file.path);
    } catch (_) {
      await _deleteTemporaryFile(clientName);
    }
  }

  @override
  Future<void> delete(String clientName) async {
    try {
      final file = _file(clientName);
      if (await file.exists()) {
        await file.delete();
      }
      await _deleteTemporaryFile(clientName);
    } catch (_) {
      return;
    }
  }

  File _file(String clientName) {
    final encoded = base64Url.encode(utf8.encode(clientName)).replaceAll(
          '=',
          '',
        );
    return File('${directory.path}/flags-$encoded.json');
  }

  Future<void> _deleteTemporaryFile(String clientName) async {
    try {
      final temporaryFile = File('${_file(clientName).path}.tmp');
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
    } catch (_) {
      return;
    }
  }
}
