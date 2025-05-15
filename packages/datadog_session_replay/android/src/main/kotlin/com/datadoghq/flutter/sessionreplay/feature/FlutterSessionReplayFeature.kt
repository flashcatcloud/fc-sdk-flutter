/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.feature

import android.content.Context
import com.datadog.android.api.feature.Feature
import com.datadog.android.api.feature.FeatureContextUpdateReceiver
import com.datadog.android.api.feature.FeatureEventReceiver
import com.datadog.android.api.feature.FeatureSdkCore
import com.datadog.android.api.feature.StorageBackedFeature
import com.datadog.android.api.net.RequestFactory
import com.datadog.android.api.storage.EventType
import com.datadog.android.api.storage.FeatureStorageConfiguration
import com.datadog.android.api.storage.RawBatchEvent

class FlutterSessionReplayFeature(
    private val sdkCore: FeatureSdkCore,
    private val onContextChanged: (Map<String, Any?>) -> Unit,
    private val customEndpointUrl: String?
) : StorageBackedFeature, FeatureEventReceiver, FeatureContextUpdateReceiver {

    override val name = Feature.SESSION_REPLAY_FEATURE_NAME
    override val storageConfiguration = STORAGE_CONFIGURATION

    override val requestFactory: RequestFactory by lazy {
        SegmentRequestFactory(
            customEndpointUrl,
            BatchesToSegmentsMapper(sdkCore.internalLogger)
        )
    }

    override fun onInitialize(appContext: Context) {
        sdkCore.setContextUpdateReceiver(
            SESSION_REPLAY_FEATURE_NAME,
            this
        )
    }

    override fun onStop() {
    }

    override fun onReceive(event: Any) {
    }

    override fun onContextUpdate(featureName: String, event: Map<String, Any?>) {
        if (featureName == Feature.RUM_FEATURE_NAME) {
            val applicationId = event[APPLICATION_ID_KEY] as? String
            val sessionId = event[SESSION_ID_KEY] as? String
            val viewId = event[VIEW_ID_KEY] as? String
            val serverTimeOffset = event[VIEW_SERVER_TIME_OFFSET_KEY] as? Long

            val flutterEncodedContext = mapOf<String, Any?>(
                "applicationId" to applicationId,
                "sessionId" to sessionId,
                "viewId" to viewId,
                "viewServerTimeOffset" to serverTimeOffset
            )
            onContextChanged(flutterEncodedContext)
        }
    }

    fun setHasReplay(viewId: String, hasReplay: Boolean) {
        sdkCore.updateFeatureContext(SESSION_REPLAY_FEATURE_NAME) {
            @Suppress("UNCHECKED_CAST")
            val viewMetadata: MutableMap<String, Any?> =
                (it[viewId] as? MutableMap<String, Any?>) ?: mutableMapOf()
            viewMetadata[HAS_REPLAY_KEY] = hasReplay
            it[viewId] = viewMetadata
        }
    }

    fun setRecordCount(viewId: String, recordCount: Int) {
        sdkCore.updateFeatureContext(SESSION_REPLAY_FEATURE_NAME) {
            @Suppress("UNCHECKED_CAST")
            val viewMetadata: MutableMap<String, Any?> =
                (it[viewId] as? MutableMap<String, Any?>) ?: mutableMapOf()
            viewMetadata[HAS_REPLAY_KEY] = true
            viewMetadata[VIEW_RECORDS_COUNT_KEY] = recordCount
            it[viewId] = viewMetadata
        }
    }

    fun writeSegment(segment: String) {
        sdkCore.getFeature(SESSION_REPLAY_FEATURE_NAME)?.withWriteContext { _, eventBatchWriter ->
            synchronized(this) {
                val serializedSegment = segment.toByteArray(Charsets.UTF_8)
                val rawBatchEvent = RawBatchEvent(data = serializedSegment)
                eventBatchWriter.write(
                    event = rawBatchEvent,
                    batchMetadata = null,
                    eventType = EventType.DEFAULT
                )
            }
        }
    }

    companion object {
        /**
         * Session Replay storage configuration with the following parameters:
         * max item size = 10 MB,
         * max items per batch = 500,
         * max batch size = 10 MB, SR intake batch limit is 10MB
         * old batch threshold = 18 hours.
         */
        internal val STORAGE_CONFIGURATION: FeatureStorageConfiguration =
            FeatureStorageConfiguration.DEFAULT.copy(
                maxItemSize = 10 * 1024 * 1024,
                maxBatchSize = 10 * 1024 * 1024
            )

        const val SESSION_REPLAY_FEATURE_NAME = "session_replay"
        const val HAS_REPLAY_KEY = "has_replay"
        const val VIEW_RECORDS_COUNT_KEY = "records_count"

        const val APPLICATION_ID_KEY = "application_id"
        const val SESSION_ID_KEY = "session_id"
        const val VIEW_ID_KEY = "view_id"
        const val VIEW_SERVER_TIME_OFFSET_KEY = "view_timestamp_offset"
    }
}
