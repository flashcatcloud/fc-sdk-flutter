/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay

import android.icu.text.ListFormatter.Width
import com.datadog.android.Datadog
import com.datadog.android.api.feature.FeatureSdkCore
import com.datadoghq.flutter.sessionreplay.feature.FlutterSessionReplayFeature
import java.nio.ByteBuffer

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

    private var resourceIdMap: MutableMap<Int, String> = mutableMapOf()

    fun enable(configuration: Configuration): FlutterSessionReplayFeature {
        val featureSdkCore = Datadog.getInstance() as FeatureSdkCore
        val feature = FlutterSessionReplayFeature(
            featureSdkCore,
            { context -> configuration.onContextChanged.onContextChanged(RumContext(context)) },
            configuration.customEndpointUrl
        )
        featureSdkCore.registerFeature(feature)
        this.feature = feature
        return feature
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

    fun saveImageForProcessing(
        resourceId: Int,
        imageData: ByteBuffer,
        width: Int,
        height: Int
    ) {
        feature?.resourceResolver?.addResource(
            resourceKey = resourceId,
            width = width,
            height = height,
            resourceBytes = imageData
        )
    }

    fun resourceIdForKey(resourceId: Int): String? {
        return feature?.resourceResolver?.resolveResource(resourceId)
    }
}
