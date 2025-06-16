// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';

import 'src/datadog_session_replay_plugin.dart';

export 'src/datadog_session_replay.dart' show DatadogSessionReplay;
export 'src/widgets.dart' show SessionReplayCapture;

/// Privacy levels for text and input masking in Session Replay
enum TextAndInputPrivacyLevel {
  /// Show all text except sensitive inputs (those with obscureText set)
  maskSensitiveInputs,

  /// Mask all input fields, such as TextField, Checkbox, Switch, etc.
  maskAllInputs,

  /// Mask all text and inputs, including all Text widgets.
  maskAll,
}

class DatadogSessionReplayConfiguration {
  double replaySampleRate;
  TextAndInputPrivacyLevel textAndInputPrivacyLevel;
  String? customEndpoint;

  DatadogSessionReplayConfiguration({
    required this.replaySampleRate,
    this.textAndInputPrivacyLevel = TextAndInputPrivacyLevel.maskAll,
    this.customEndpoint,
  });
}

extension SessionReplayExtension on DatadogConfiguration {
  void enableSessionReplay(DatadogSessionReplayConfiguration config) {
    addPlugin(DatadogSessionReplayPluginConfiguration(configuration: config));
  }
}
