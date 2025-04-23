// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'datadog_session_replay_platform_interface.dart';

/// An implementation of [DatadogSessionReplayPlatform] that uses method channels.
class MethodChannelDatadogSessionReplay extends DatadogSessionReplayPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel(
    'datadog_sdk_flutter.session_replay',
  );
}
