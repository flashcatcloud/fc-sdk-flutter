/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay

import com.datadog.android.Datadog
import com.datadog.android.api.feature.FeatureSdkCore
import com.datadoghq.flutter.sessionreplay.feature.FlutterSessionReplayFeature

class FlutterSessionReplayBridge {
    data class RumContext(
        val applicationId: String?,
        val sessionId: String?,
        val viewId: String?,
        val viewServerTimeOffset: Long?
    ) {
        constructor(context: FlutterSessionReplayFeature.RumContext) : this(
            applicationId = context.applicationId,
            sessionId = context.sessionId,
            viewId = context.viewId,
            viewServerTimeOffset = context.viewServerTimeOffset
        )
    }

    interface ContextListener {
        fun onContextChanged(context: RumContext)
    }

    data class Configuration(
        val customEndpointUrl: String? = null,
        val onContextChanged: ContextListener
    )

    private var feature: FlutterSessionReplayFeature? = null

    fun enable(configuration: Configuration): FlutterSessionReplayFeature {
        val featureSdkCore = Datadog.getInstance() as FeatureSdkCore
        feature = FlutterSessionReplayFeature(
            featureSdkCore,
            { context -> configuration.onContextChanged.onContextChanged(RumContext(context)) },
            configuration.customEndpointUrl
        )
        feature?.let {
            featureSdkCore.registerFeature(it)
        }

        return feature ?: throw IllegalStateException("Feature should not be null after enabling")
    }

    fun setHasReplay(viewId: String, hasReplay: Boolean) {
        feature?.setHasReplay(viewId, hasReplay)
    }

    fun setRecordCount(viewId: String, recordCount: Int) {
        feature?.setRecordCount(viewId, recordCount)
    }

    fun writeSegment(segment: String) {
        feature?.writeSegment(segment)
    }

    fun telemetryDebug(message: String) {
        Datadog._internalProxy()._telemetry.debug(message)
    }

    fun telemetryError(message: String, stack: String, kind: String) {
        Datadog._internalProxy()._telemetry.error(message, stack, kind)
    }
}