/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay

import com.datadog.android.Datadog
import com.datadoghq.flutter.missingParameter
import com.datadoghq.flutter.sessionreplay.feature.FlutterSessionReplayFeature
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class DatadogSessionReplayPlugin : FlutterPlugin, MethodCallHandler {
    // Internal only for unit testing purposes
    internal lateinit var channel: MethodChannel

    private var feature: FlutterSessionReplayFeature? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "datadog_sdk_flutter.session_replay"
        )
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "enable" -> {
                enable(call, result)
            }
            "setHasReplay" -> {
                setHasReplay(call, result)
            }
            "setRecordCount" -> {
                setRecordCount(call, result)
            }
            "writeSegment" -> {
                writeSegment(call, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun enable(call: MethodCall, result: Result) {
        val options = call.argument<Map<String, Any?>>("configuration")
        if (options == null) {
            result.missingParameter(call.method)
            return
        }
        val configuration = FlutterSessionReplay.fromFlutter(options)
        enable(configuration)
        result.success(true)
    }

    internal fun enable(configuration: FlutterSessionReplay.Configuration) {
        feature = FlutterSessionReplay.enable(
            configuration = configuration,
            onContextChanged = { context ->
                onContextChanged(context)
            },
            sdkCore = Datadog.getInstance()
        )
    }

    internal fun onContextChanged(context: Map<String, Any?>) {
        channel.invokeMethod(
            "onContextChanged",
            context
        )
    }

    private fun setHasReplay(call: MethodCall, result: Result) {
        val viewId = call.argument<String>("viewId")
        val hasReplay = call.argument<Boolean>("hasReplay")
        if (hasReplay == null || viewId == null) {
            result.missingParameter(call.method)
            return
        }
        feature?.setHasReplay(viewId, hasReplay)
        result.success(null)
    }

    private fun setRecordCount(call: MethodCall, result: Result) {
        val viewId = call.argument<String>("viewId")
        val recordCount = call.argument<Int>("count")
        if (recordCount == null || viewId == null) {
            result.missingParameter(call.method)
            return
        }
        feature?.setRecordCount(viewId, recordCount)
        result.success(null)
    }

    private fun writeSegment(call: MethodCall, result: MethodChannel.Result) {
        val segment = call.argument<String>("segment")
        if (segment == null) {
            result.missingParameter(call.method)
            return
        }
        feature?.writeSegment(segment)
        result.success(null)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
