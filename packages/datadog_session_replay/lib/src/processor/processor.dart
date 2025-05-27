// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import '../capture/recorder.dart';
import 'processor_worker.dart';

/// Spawns a background isolate to process session replay snapshots before
/// sending them to the native platform for serialization and distribution to
/// intake
class SessionReplayProcessor {
  final ReceivePort _mainReceivePort = ReceivePort('sr-replay-port');
  SendPort? _mainSendPort;

  Future<void> start() async {
    await Isolate.spawn(
      _captureProcessor,
      _ProcessorArgs(RootIsolateToken.instance!, _mainReceivePort.sendPort),
    );

    _mainSendPort = await _mainReceivePort.first;
  }

  void process(CaptureResult captureResult) {
    _mainSendPort?.send(captureResult);
  }

  static Future<void> _captureProcessor(_ProcessorArgs args) async {
    BackgroundIsolateBinaryMessenger.ensureInitialized(args.rootIsolateToken);
    final ReceivePort commandPort = ReceivePort();
    final responsePort = args.sendPort;
    responsePort.send(commandPort.sendPort);

    final internalProcessor = ProcessorWorker();

    await for (final message in commandPort) {
      if (message is CaptureResult) {
        await internalProcessor.processSnapshot(message);
      } else if (message == null) {
        break;
      }
    }

    Isolate.exit();
  }
}

@immutable
class _ProcessorArgs {
  final RootIsolateToken rootIsolateToken;
  final SendPort sendPort;

  const _ProcessorArgs(this.rootIsolateToken, this.sendPort);
}
