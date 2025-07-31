// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:js_interop';

import 'package:web/web.dart';

import 'raw_events.dart';

@JSExport()
class RumWebPlugin {
  final String name = 'DatadogFlutterWeb';

  JSFunction? _addEvent;
  int? _navigationStart;

  void onRumStart(OnRumStartOptions options) {
    _addEvent = options.addEvent;
  }

  void addEvent(
      JSNumber time, RumWebRawEvent event, RumWebEventDomainContext context) {
    _addEvent?.callAsFunction(null, time, event, context, null);
  }

  JSNumber getEventRelativeTime(DateTime time) {
    _navigationStart ??= window.performance.timing.navigationStart;
    if (_navigationStart == null) {
      return time.millisecondsSinceEpoch.toJS;
    }

    return (time.millisecondsSinceEpoch - _navigationStart!).toJS;
  }
}

@anonymous
extension type OnRumStartOptions._(JSObject _) implements JSObject {
  external JSFunction addEvent;
}
