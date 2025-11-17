// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import '../../datadog_internal.dart';
import 'datadog_android_bridge.dart' as bridge;

class AndroidDatadogFlutterPlugin {
  static DatadogContext? getContext() {
    final javaContext = bridge.DatadogSdkPlugin.Companion.getCoreContext();
    if (javaContext == null) return null;

    return DatadogContext(
      accountId: javaContext.getAccountInfo()?.getId().toDartString(),
      userId: javaContext.getUserInfo().getId()?.toDartString(),
    );
  }
}
