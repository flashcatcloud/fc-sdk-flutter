// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:async';

import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '../datadog_session_replay.dart';
import 'capture/recorder.dart';
import 'datadog_session_replay_platform_interface.dart';
import 'processor/processor.dart';
import 'rum_context.dart';

class DatadogSessionReplay {
  static DatadogSessionReplay? _instance;
  static DatadogSessionReplay? get instance => _instance;

  final DatadogSessionReplayConfiguration _configuration;
  @internal
  final InternalLogger internalLogger;

  final SessionReplayProcessor _processor = SessionReplayProcessor();
  final SessionReplayRecorder _recorder = SessionReplayRecorder();

  @internal
  static Future<DatadogSessionReplay> init(
    DatadogSessionReplayConfiguration configuration,
    InternalLogger logger,
  ) async {
    _instance = DatadogSessionReplay._(configuration, logger);
    await _instance!._start();
    return _instance!;
  }

  DatadogSessionReplay._(this._configuration, this.internalLogger);

  void addElement(Key key, Element e) {
    _recorder.addElement(key, e);
  }

  void removeElement(Key key) {
    _recorder.removeElement(key);
  }

  void _onContextChanged(RUMContext context) {
    _recorder.onContextChanged(context);
  }

  Future<void> _start() async {
    final platform = DatadogSessionReplayPlatform.instance;
    bool success = false;
    await wrapAsync('enable', internalLogger, {}, () async {
      success = await platform.enable(_configuration, _onContextChanged);
    });

    if (success) {
      await _processor.start();

      const timerDuration = Duration(milliseconds: 100);
      // TODO(RUM-10155): See if we can be smarter about how often we perform tree captures
      final replayTimer = Timer.periodic(timerDuration, (timer) {
        final captureResult = _recorder.performCapture();
        if (captureResult != null) {
          _processor.process(captureResult);
        }
      });
    }
  }
}
