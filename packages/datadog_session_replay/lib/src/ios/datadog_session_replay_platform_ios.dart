// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:async';
import 'dart:ffi' as ffi;

import 'package:flutter/foundation.dart';
import 'package:objective_c/objective_c.dart';

import '../../datadog_session_replay.dart';
import '../datadog_session_replay_platform_interface.dart';
import '../rum_context.dart';
import 'datadog_session_replay_bridge_ios.dart';

class DatadogSessionReplayPlatformIos extends DatadogSessionReplayPlatform {
  late FlutterSessionReplay _iosBridge;

  // Create the
  DatadogSessionReplayPlatformIos() {
    _iosBridge = FlutterSessionReplay();
  }

  DatadogSessionReplayPlatformIos.fromBridgePtr(ffi.Pointer<ObjCObject> ptr)
    : _iosBridge = FlutterSessionReplay.castFromPointer(ptr);

  @override
  Object? get isolateToken => _iosBridge.ref.pointer;

  @override
  FutureOr<bool> enable(
    DatadogSessionReplayConfiguration configuration,
    void Function(RUMContext p1) onContextChanged,
  ) {
    NSURL? url;
    if (configuration.customEndpoint case final customEndpoint?) {
      url = NSURL().initWithString(NSString(customEndpoint));
      if (url == null) {
        final message =
            'Failed to parse custom endpoint $customEndpoint. Session replay was not initialized.';
        if (kDebugMode) {
          print('Datadog SR] ERROR: $message');
        }
        _iosBridge.postTelemetryDebugWithId(
          NSString('bad_custom_url'),
          message: NSString(message),
        );
      }
    }

    final contextChangedListener =
        ObjCBlock_ffiVoid_FlutterRUMCoreContext.listener((context) {
          RUMContext? dartContext;
          if (context != null) {
            dartContext = RUMContext(
              applicationId: context.applicationID.toDartString(),
              sessionId: context.sessionID.toDartString(),
              viewId: context.viewID?.toDartString(),
            );
            onContextChanged(dartContext);
          }
        });

    final iOsConfiguration =
        FlutterSessionReplayConfiguration.alloc()..initWithCustomEndpoint(
          url,
          onContextChanged: contextChangedListener,
        );
    _iosBridge.enableWith(iOsConfiguration);

    return true;
  }

  @override
  FutureOr<void> setHasReplay(bool hasReplay) {
    _iosBridge.setHasReplayWithHasReplay(hasReplay);
  }

  @override
  FutureOr<void> setRecordCount(String viewId, int count) {
    _iosBridge.setRecordCountFor(NSString(viewId), count: count);
  }

  @override
  FutureOr<void> writeSegment(String record, String viewId) {
    _iosBridge.writeSegmentWithSegment(NSString(record));
  }

  @override
  FutureOr<void> telemetryDebug(String id, String message) {
    _iosBridge.postTelemetryDebugWithId(
      NSString(id),
      message: NSString(message),
    );
  }

  @override
  FutureOr<void> telemetryError(String message, String kind, String stack) {
    _iosBridge.postTelemetryErrorWithMessage(
      NSString(message),
      kind: NSString(kind),
      stackTrace: NSString(stack),
    );
  }
}
