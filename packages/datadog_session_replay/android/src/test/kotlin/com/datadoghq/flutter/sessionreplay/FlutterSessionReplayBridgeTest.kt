/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay

import assertk.assertThat
import assertk.assertions.isEqualTo
import assertk.assertions.isNotNull
import com.datadog.android.Datadog
import com.datadog.android.api.feature.FeatureSdkCore
import com.datadoghq.flutter.sessionreplay.feature.FlutterSessionReplayFeature
import com.datadoghq.flutter.sessionreplay.resource.ResourceResolver
import fr.xgouchet.elmyr.annotation.BoolForgery
import fr.xgouchet.elmyr.annotation.IntForgery
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import java.nio.ByteBuffer
import kotlin.test.Test
import org.junit.jupiter.api.extension.ExtendWith

internal fun FlutterSessionReplayBridge.enableWithMock(
    mockFeature: FlutterSessionReplayFeature
) {
    this.feature = mockFeature
}

@ExtendWith(ForgeExtension::class)
class FlutterSessionReplayBridgeTest {
    var mockCore: FeatureSdkCore = mockk(relaxed = true)

    @Test
    fun `M register the feature W enable`() {
        // Given
        Datadog.getInstance()
        val bridge = FlutterSessionReplayBridge()
        val configuration = FlutterSessionReplayBridge.Configuration(
            customEndpointUrl = null,
            onContextChanged = mockk(relaxed = true)
        )

        // When
        bridge.enable(configuration, core = mockCore)

        // Then
        assertThat(bridge.feature).isNotNull()
        verify { mockCore.registerFeature(bridge.feature!!) }
    }

    @Test
    fun `M call setHasReplay on the feature W setHasReplay`(
        @StringForgery viewId: String,
        @BoolForgery hasReplay: Boolean
    ) {
        // Given
        val mockFeature = mockk<FlutterSessionReplayFeature>(relaxed = true)
        val bridge = FlutterSessionReplayBridge()
        bridge.enableWithMock(mockFeature)

        // When
        bridge.setHasReplay(viewId, hasReplay)

        // Then
        verify { mockFeature.setHasReplay(viewId, hasReplay) }
    }

    @Test
    fun `M call setRecordCount on the feature W setRecordCount`(
        @StringForgery viewId: String,
        @IntForgery recordCount: Int
    ) {
        // Given
        val mockFeature = mockk<FlutterSessionReplayFeature>(relaxed = true)
        val bridge = FlutterSessionReplayBridge()
        bridge.enableWithMock(mockFeature)

        // When
        bridge.setRecordCount(viewId, recordCount)

        // Then
        verify { mockFeature.setRecordCount(viewId, recordCount) }
    }

    @Test
    fun `M call writeSegment on the feature W writeSegment`(
        @StringForgery segment: String
    ) {
        // Given
        val mockFeature = mockk<FlutterSessionReplayFeature>(relaxed = true)
        val bridge = FlutterSessionReplayBridge()
        bridge.enableWithMock(mockFeature)

        // When
        bridge.writeSegment(segment)

        // Then
        verify { mockFeature.writeSegment(segment) }
    }

    @Test
    fun `M addResource W saveImageForProcessing`(
        @IntForgery key: Int,
        @IntForgery width: Int,
        @IntForgery height: Int
    ) {
        // Given
        val mockFeature = mockk<FlutterSessionReplayFeature>(relaxed = true)
        val mockResourceResolver = mockk<ResourceResolver>(relaxed = true)
        every { mockFeature.resourceResolver } returns mockResourceResolver

        val bridge = FlutterSessionReplayBridge()
        bridge.enableWithMock(mockFeature)

        // When
        val data = ByteBuffer.allocate(10)
        bridge.saveImageForProcessing(key, data, width, height)

        // Then
        verify { mockResourceResolver.addResource(key, width, height, data) }
    }

    @Test
    fun `M resolveResource W resourceIdForKey`(
        @IntForgery key: Int,
        @StringForgery resolvedKey: String
    ) {
        // Given
        val mockFeature = mockk<FlutterSessionReplayFeature>(relaxed = true)
        val mockResourceResolver = mockk<ResourceResolver>(relaxed = true)
        every { mockFeature.resourceResolver } returns mockResourceResolver
        every { mockResourceResolver.resolveResource(key) } returns resolvedKey

        val bridge = FlutterSessionReplayBridge()
        bridge.enableWithMock(mockFeature)

        // When
        val result = bridge.resourceIdForKey(key)

        // Then
        verify { mockResourceResolver.resolveResource(key) }
        assertThat(result).isEqualTo(resolvedKey)
    }
}
