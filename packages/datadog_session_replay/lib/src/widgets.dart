// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'capture/pointer_capture.dart';
import 'datadog_session_replay.dart';
import 'sr_data_models.dart';

class SessionReplayCapture extends StatefulWidget {
  final DatadogRum rum;
  final DatadogSessionReplay sessionReplay;
  final Widget child;

  SessionReplayCapture({
    super.key,
    required this.child,
    required this.rum,
    required this.sessionReplay,
  }) {
    if (key == null) {
      sessionReplay.internalLogger.log(
        CoreLoggerLevel.warn,
        'SessionReplayCapture has a null Key value. A Key is required for Session Replay to work.',
      );
    }
  }

  @override
  StatefulElement createElement() {
    final e = super.createElement();
    if (key != null) {
      sessionReplay.addElement(key!, e);
    }

    return e;
  }

  @override
  State<SessionReplayCapture> createState() => _SessionReplayCaptureState();
}

class _SessionReplayCaptureState extends State<SessionReplayCapture> {
  @override
  Widget build(BuildContext context) {
    return PointerRecorder(
      // ignore: invalid_use_of_internal_member
      snapshotRecorder: PointerSnapshotRecorder(widget.rum.timeProvider),
      child: RumUserActionDetector(rum: widget.rum, child: widget.child),
    );
  }
}

@immutable
class PointerRecorder extends StatelessWidget {
  final PointerSnapshotRecorder snapshotRecorder;
  final Widget child;

  const PointerRecorder({
    super.key,
    required this.snapshotRecorder,
    required this.child,
  });

  void _onPointerDown(PointerDownEvent event) =>
      _capturePointerEvent(SRPointerEventType.down, event);

  void _onPointerMove(PointerMoveEvent event) =>
      _capturePointerEvent(SRPointerEventType.move, event);

  void _onPointerCancel(PointerCancelEvent event) =>
      _capturePointerEvent(SRPointerEventType.up, event);

  void _onPointerHover(PointerHoverEvent event) =>
      _capturePointerEvent(SRPointerEventType.move, event);

  void _onPointerUp(PointerUpEvent event) =>
      _capturePointerEvent(SRPointerEventType.up, event);

  void _capturePointerEvent(SRPointerEventType type, PointerEvent event) {
    snapshotRecorder.capturePointer(
      event.pointer,
      type,
      event.position.dx,
      event.position.dy,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerCancel: _onPointerCancel,
      onPointerHover: _onPointerHover,
      onPointerUp: _onPointerUp,
      child: child,
    );
  }
}
