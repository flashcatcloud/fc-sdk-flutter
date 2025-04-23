// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
// ignore: avoid_web_libraries_in_flutter

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'datadog_session_replay_platform_interface.dart';

/// A web implementation of the DatadogSessionReplayPlatform of the DatadogSessionReplay plugin.
class DatadogSessionReplayWeb extends DatadogSessionReplayPlatform {
  /// Constructs a DatadogSessionReplayWeb
  DatadogSessionReplayWeb();

  static void registerWith(Registrar registrar) {
    DatadogSessionReplayPlatform.instance = DatadogSessionReplayWeb();
  }
}
