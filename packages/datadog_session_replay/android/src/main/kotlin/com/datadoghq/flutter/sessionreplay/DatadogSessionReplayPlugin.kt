/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay

import io.flutter.embedding.engine.plugins.FlutterPlugin

class DatadogSessionReplayPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // No-op: the context listener is set up when Dart calls enable() on the new engine.
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Null out the context listener so context updates don't attempt to invoke a
        // callback into the now-destroyed Dart isolate, which would cause a SIGABRT.
        // The listener will be restored when the new engine calls enable().
        FlutterSessionReplayBridge.detachFromEngine()
    }
}
