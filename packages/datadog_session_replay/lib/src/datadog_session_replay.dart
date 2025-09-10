// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:async';
import 'dart:math';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '../datadog_session_replay.dart';
import 'capture/recorder.dart';
import 'datadog_session_replay_platform_interface.dart';
import 'processor/processor.dart';
import 'rum_context.dart';

class DatadogSessionReplay {
  // The minimum amount of time that needs to pass before we perform another
  // tree capture.
  static const minCaptureTiming = Duration(milliseconds: 100);
  // The number of times in quick succession thar SR capture can throw before
  // we shut it down completely.
  static const errorTollerance = 10;

  static DatadogSessionReplay? _instance;
  static DatadogSessionReplay? get instance => _instance;

  final DatadogSessionReplayConfiguration _configuration;
  @internal
  final InternalLogger internalLogger;

  final SessionReplayProcessor _processor = SessionReplayProcessor();
  final SessionReplayRecorder _recorder;

  int _errorCounter = 0;
  bool _needCapture = true;

  @internal
  static Future<DatadogSessionReplay> init(
    DatadogSessionReplayConfiguration configuration,
    InternalLogger logger, {
    DatadogTimeProvider timeProvider = const DefaultTimeProvider(),
  }) async {
    _instance = DatadogSessionReplay._(configuration, logger);
    await _instance!._start();
    return _instance!;
  }

  DatadogSessionReplay._(this._configuration, this.internalLogger)
    : _recorder = SessionReplayRecorder(
        defaultCapturePrivacy: TreeCapturePrivacy(
          textAndInputPrivacyLevel: _configuration.textAndInputPrivacyLevel,
          imagePrivacyLevel: _configuration.imagePrivacyLevel,
        ),
        touchPrivacyLevel: _configuration.touchPrivacyLevel,
      );

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

      _startPeriodicCapture();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _needCapture = true;
      });
    }
  }

  void _startPeriodicCapture() async {
    Timer.periodic(minCaptureTiming, (timer) async {
      bool shouldScheduleNextCapture = true;
      if (_needCapture) {
        try {
          final captureResult = await _recorder.performCapture();
          if (captureResult != null) {
            _processor.process(captureResult);
          }
          _errorCounter = max(0, _errorCounter - 1);
        } catch (e, st) {
          internalLogger.sendToDatadog(
            'Exception during session replay capture: $e',
            st,
            e.runtimeType.toString(),
          );
          internalLogger.log(
            CoreLoggerLevel.warn,
            'Exception during session replay capture: $e',
          );
          _errorCounter += 1;
          if (_errorCounter > errorTollerance) {
            internalLogger.sendToDatadog(
              'Flutter SR has exceeded its error tollerance of $errorTollerance. Shutting down.',
              null,
              null,
            );
            timer.cancel();
            shouldScheduleNextCapture = false;
          }
        }
        _needCapture = false;
      }

      if (shouldScheduleNextCapture) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _needCapture = true;
        });
      }
    });
  }
}
