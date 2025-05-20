/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay

import assertk.assertThat
import assertk.assertions.isEqualTo
import assertk.assertions.isInstanceOf
import assertk.assertions.isNotNull
import com.datadog.android.Datadog
import com.datadog.android.api.context.DatadogContext
import com.datadog.android.api.feature.FeatureScope
import com.datadog.android.api.feature.FeatureSdkCore
import com.datadog.android.api.storage.EventBatchWriter
import com.datadog.android.api.storage.EventType
import com.datadoghq.flutter.DatadogSdkPlugin
import com.datadoghq.flutter.sessionreplay.feature.FlutterSessionReplayFeature
import fr.xgouchet.elmyr.annotation.BoolForgery
import fr.xgouchet.elmyr.annotation.IntForgery
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.Called
import io.mockk.every
import io.mockk.invoke
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.verify
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith

@ExtendWith(ForgeExtension::class)
internal class DatadogSessionReplayPluginTest {
    lateinit var mockCore: FeatureSdkCore
    lateinit var mockMethodChannel: MethodChannel

    @BeforeEach
    fun beforeEach() {
        mockCore = mockk(relaxed = true)
        mockkStatic(Datadog::class)
        every { Datadog.getInstance() } returns mockCore

        mockMethodChannel = mockk(relaxed = true)
    }

    @Test
    fun `M return NotImplemented W onMethodCall { unknown }`() {
        // Given
        val plugin = DatadogSessionReplayPlugin()
        val result = mockk<MethodChannel.Result>(relaxed = true)
        val call = MethodCall("unknown", mapOf<String, Any?>())

        // When
        plugin.onMethodCall(call, result)

        // Then
        verify { result.notImplemented() }
    }

    @Test
    fun `M enable feature W enable onMethodCall`() {
        // Given
        val plugin = DatadogSessionReplayPlugin()
        val result = mockk<MethodChannel.Result>(relaxed = true)
        val call = MethodCall(
            "enable",
            mapOf<String, Any?>(
                "configuration" to mapOf<String, Any?>()
            )
        )

        // When
        plugin.onMethodCall(call, result)

        // Then
        verify { result.success(null) }
        verify {
            mockCore.registerFeature(
                withArg {
                    assertThat(it).isInstanceOf(FlutterSessionReplayFeature::class)
                }
            )
        }
    }

    @Test
    fun `M return error W enable onMethodCall { missing configuration }`() {
        // Given
        val plugin = DatadogSessionReplayPlugin()
        val result = mockk<MethodChannel.Result>(relaxed = true)
        val call = MethodCall("enable", mapOf<String, Any?>())

        // When
        plugin.onMethodCall(call, result)

        // Then
        verify {
            result.error(
                DatadogSdkPlugin.CONTRACT_VIOLATION,
                "Missing required parameter in call to enable",
                null
            )
        }
        verify { mockCore wasNot Called }
    }

    @Test
    fun `M set context W setHasReplay onMethodCall`(
        @StringForgery viewId: String,
        @BoolForgery hasReplay: Boolean
    ) {
        // Given
        val plugin = DatadogSessionReplayPlugin()
        val result = mockk<MethodChannel.Result>(relaxed = true)
        val call = MethodCall(
            "setHasReplay",
            mapOf<String, Any?>(
                "viewId" to viewId,
                "hasReplay" to hasReplay
            )
        )
        var context = mutableMapOf<String, Any?>()
        every { mockCore.updateFeatureContext(any(), captureLambda()) } answers {
            lambda<(MutableMap<String, Any?>) -> Unit>().invoke(context)
        }

        // When
        plugin.enable(FlutterSessionReplay.Configuration())
        plugin.onMethodCall(call, result)

        // Then
        verify { result.success(null) }
        verify {
            mockCore.updateFeatureContext(
                FlutterSessionReplayFeature.SESSION_REPLAY_FEATURE_NAME,
                any()
            )
        }
        val viewMap = context[viewId] as? MutableMap<String, Any?>
        assertThat(viewMap).isNotNull()
        assertThat(viewMap?.get("has_replay")).isEqualTo(hasReplay)
    }

    @Test
    fun `M return error W setHasReplay onMethodCall { missing parameters }`() {
        // Given
        val plugin = DatadogSessionReplayPlugin()
        val result = mockk<MethodChannel.Result>(relaxed = true)
        val call = MethodCall("setHasReplay", mapOf<String, Any?>())

        // When
        plugin.enable(FlutterSessionReplay.Configuration())
        plugin.onMethodCall(call, result)

        // Then
        verify {
            result.error(
                DatadogSdkPlugin.CONTRACT_VIOLATION,
                "Missing required parameter in call to setHasReplay",
                null
            )
        }
    }

    @Test
    fun `M set context W setRecordCountMethodCall`(
        @StringForgery viewId: String,
        @IntForgery recordCount: Int
    ) {
        // Given
        val plugin = DatadogSessionReplayPlugin()
        val result = mockk<MethodChannel.Result>(relaxed = true)
        val call = MethodCall(
            "setRecordCount",
            mapOf<String, Any?>(
                "viewId" to viewId,
                "count" to recordCount
            )
        )
        var context = mutableMapOf<String, Any?>()
        every { mockCore.updateFeatureContext(any(), captureLambda()) } answers {
            lambda<(MutableMap<String, Any?>) -> Unit>().invoke(context)
        }

        // When
        plugin.enable(FlutterSessionReplay.Configuration())
        plugin.onMethodCall(call, result)

        // Then
        verify { result.success(null) }
        verify {
            mockCore.updateFeatureContext(
                FlutterSessionReplayFeature.SESSION_REPLAY_FEATURE_NAME,
                any()
            )
        }
        val viewMap = context[viewId] as? MutableMap<String, Any?>
        assertThat(viewMap).isNotNull()
        assertThat(viewMap?.get("has_replay")).isEqualTo(true)
        assertThat(viewMap?.get("records_count")).isEqualTo(recordCount)
    }

    @Test
    fun `M return error W setRecordCount onMethodCall { missing parameters }`() {
        // Given
        val plugin = DatadogSessionReplayPlugin()
        val result = mockk<MethodChannel.Result>(relaxed = true)
        val call = MethodCall("setRecordCount", mapOf<String, Any?>())

        // When
        plugin.enable(FlutterSessionReplay.Configuration())
        plugin.onMethodCall(call, result)

        // Then
        verify {
            result.error(
                DatadogSdkPlugin.CONTRACT_VIOLATION,
                "Missing required parameter in call to setRecordCount",
                null
            )
        }
    }

    @Test
    fun `M broadcastRumContext W onReceive`(
        @StringForgery applicationId: String,
        @StringForgery sessionId: String,
        @StringForgery viewId: String
    ) {
        // Given
        val plugin = DatadogSessionReplayPlugin()
        plugin.enable(FlutterSessionReplay.Configuration())

        // When
        plugin.channel = mockMethodChannel
        plugin.onContextChanged(
            mapOf(
                "applicationId" to applicationId,
                "sessionId" to sessionId,
                "viewId" to viewId,
                "viewServerTimeOffset" to 0L
            )
        )

        // Then
        verify {
            mockMethodChannel.invokeMethod(
                "onContextChanged",
                mapOf(
                    "applicationId" to applicationId,
                    "sessionId" to sessionId,
                    "viewId" to viewId,
                    "viewServerTimeOffset" to 0L
                )
            )
        }
    }

    @Test
    fun `M writeSegment W writeSegment`(
        @StringForgery segment: String
    ) {
        // Given
        val mockEventBatchWriter = mockk<EventBatchWriter>(relaxed = true)
        val mockFeatureScope = mockk<FeatureScope>(relaxed = true)
        val fakeDatadogContext = mockk<DatadogContext>()
        val plugin = DatadogSessionReplayPlugin()
        val result = mockk<MethodChannel.Result>(relaxed = true)
        val call = MethodCall(
            "writeSegment",
            mapOf<String, Any?>(
                "segment" to segment
            )
        )
        every {
            mockCore.getFeature(FlutterSessionReplayFeature.SESSION_REPLAY_FEATURE_NAME)
        } answers { mockFeatureScope }
        every {
            mockFeatureScope.withWriteContext(any(), captureLambda())
        } answers {
            lambda<(DatadogContext, EventBatchWriter) -> Unit>().invoke(
                fakeDatadogContext,
                mockEventBatchWriter
            )
        }

        // When
        plugin.enable(FlutterSessionReplay.Configuration())
        plugin.onMethodCall(call, result)

        // Then
        verify { result.success(null) }
        verify {
            mockEventBatchWriter.write(
                withArg {
                    assertThat(it.data).isEqualTo(segment.toByteArray(Charsets.UTF_8))
                },
                null,
                EventType.DEFAULT
            )
        }
    }
}
