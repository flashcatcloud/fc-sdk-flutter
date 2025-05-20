/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */
package com.datadoghq.flutter.sessionreplay

import com.datadog.android.api.SdkCore
import com.datadog.android.api.feature.FeatureSdkCore
import com.datadoghq.flutter.sessionreplay.feature.FlutterSessionReplayFeature

object FlutterSessionReplay {
    data class Configuration(
        val customEndpointUrl: String? = null
    )

    fun enable(
        configuration: Configuration,
        onContextChanged: (Map<String, Any?>) -> Unit,
        sdkCore: SdkCore
    ): FlutterSessionReplayFeature {
        val featureSdkCore = sdkCore as FeatureSdkCore
        val sessionReplayFeature = FlutterSessionReplayFeature(
            featureSdkCore,
            onContextChanged,
            configuration.customEndpointUrl
        )
        featureSdkCore.registerFeature(sessionReplayFeature)

        return sessionReplayFeature
    }

    fun fromFlutter(configuration: Map<String, Any?>): Configuration {
        val customEndpointUrl = configuration["customEndpointUrl"] as? String
        return Configuration(customEndpointUrl)
    }
}
