/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay

import android.os.Looper
import assertk.assertThat
import assertk.assertions.isNull

import com.datadog.android.api.feature.FeatureSdkCore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import kotlin.test.AfterTest
import kotlin.test.Test
import org.junit.jupiter.api.AfterAll
import org.junit.jupiter.api.BeforeAll
import org.junit.jupiter.api.TestInstance

@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class DatadogSessionReplayPluginTest {
    @BeforeAll
    fun beforeAll() {
        val mockLooper = mockk<Looper>()
        mockkStatic(Looper::class)
        every { Looper.getMainLooper() }.returns(mockLooper)
    }

    @AfterAll
    fun afterAll() {
        unmockkStatic(Looper::class)
    }

    @AfterTest
    fun afterEach() {
        FlutterSessionReplayBridge.shutdown()
    }

    @Test
    fun `M null contextListener W onDetachedFromEngine`() {
        // Given
        val mockCore: FeatureSdkCore = mockk(relaxed = true)
        val configuration = FlutterSessionReplayBridge.Configuration(
            customEndpointUrl = null,
            onContextChanged = mockk(relaxed = true)
        )
        FlutterSessionReplayBridge.enable(configuration, core = mockCore)

        val plugin = DatadogSessionReplayPlugin()
        val mockBinding = mockk<FlutterPlugin.FlutterPluginBinding>(relaxed = true)

        // When
        plugin.onDetachedFromEngine(mockBinding)

        // Then
        assertThat(FlutterSessionReplayBridge.contextListener).isNull()
    }
}
