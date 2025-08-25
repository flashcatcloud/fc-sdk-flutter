/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.resource

import android.graphics.Bitmap
import assertk.assertThat
import assertk.assertions.isEqualTo
import assertk.assertions.isNotEqualTo
import assertk.assertions.isNull
import com.datadog.android.api.InternalLogger
import fr.xgouchet.elmyr.annotation.IntForgery
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import java.nio.ByteBuffer
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith

@ExtendWith(ForgeExtension::class)
internal class ResourceResolverTest {
    val mockInternalLogger = mockk<InternalLogger>()
    val mockResourcesWriter = mockk<ResourceWriter>()
    val mockBitmapHandler = mockk<BitmapHandler>()

    fun createFakeImage(width: Int = 25, height: Int = 25, filledWith: Byte = 0): ByteBuffer {
        val byteArray = ByteArray(width * height) { filledWith }
        return ByteBuffer.wrap(byteArray)
    }

    @Test
    fun `M return null W resolveResource {unknown key}`(
        @IntForgery key: Int
    ) {
        // Given
        val resolver = DefaultResourceResolver(
            mockInternalLogger,
            mockResourcesWriter,
            mockBitmapHandler
        )

        // When
        val result = resolver.resolveResource(key)

        // Then
        assertThat(result).isNull()
    }

    @Test
    fun `M return hash W resolveResource {known key}`(
        @IntForgery key: Int,
        @StringForgery hash: String
    ) {
        // Given
        val resolver = DefaultResourceResolver(
            mockInternalLogger,
            mockResourcesWriter,
            mockBitmapHandler
        )
        val fakeCompressedImage = ByteArray(25) { 0 }
        val mockBitmap = mockk<Bitmap>()
        every { mockBitmapHandler.createBitmap(any(), any(), any()) } returns mockBitmap
        every { mockBitmapHandler.compressBitmap(mockBitmap, any()) } returns fakeCompressedImage
        every { mockResourcesWriter.write(any(), any()) } answers {}

        // When
        val fakeImage = createFakeImage()
        resolver.addResource(key, 25, 25, fakeImage)
        val result = resolver.resolveResource(key)

        // Then - this is the MD5 hash of an array of 25 zero bytes
        assertThat(result).isEqualTo("d28c293e10139d5d8f6e4592aeaffc1b")
    }

    @Test
    fun `M return same hash W resolveResource {same image}`(
        @IntForgery keyA: Int,
        @IntForgery keyB: Int
    ) {
        // Given
        val resolver = DefaultResourceResolver(
            mockInternalLogger,
            mockResourcesWriter,
            mockBitmapHandler
        )
        val fakeCompressedImage = ByteArray(25) { 0 }
        val mockBitmap = mockk<Bitmap>()
        every { mockBitmapHandler.createBitmap(any(), any(), any()) } returns mockBitmap
        every { mockBitmapHandler.compressBitmap(mockBitmap, any()) } returns fakeCompressedImage
        every { mockResourcesWriter.write(any(), any()) } answers {}

        // When
        val fakeImage = createFakeImage()
        resolver.addResource(keyA, 25, 25, fakeImage)
        resolver.addResource(keyB, 25, 25, fakeImage)
        val resultA = resolver.resolveResource(keyA)
        val resultB = resolver.resolveResource(keyB)

        // Then
        assertThat(resultA).isEqualTo(resultB)
    }

    @Test
    fun `M return different hash W resolveResource {different image}`(
        @IntForgery key: Int
    ) {
        // Given
        val resolver = DefaultResourceResolver(
            mockInternalLogger,
            mockResourcesWriter,
            mockBitmapHandler
        )
        val fakeImageA = createFakeImage()
        val fakeImageB = createFakeImage()
        val mockBitmapA = mockk<Bitmap>()
        val mockBitmapB = mockk<Bitmap>()
        val fakeCompressedImageA = ByteArray(25) { 0 }
        val fakeCompressedImageB = ByteArray(25) { 124 }
        every {
            mockBitmapHandler.createBitmap(any(), any(), refEq(fakeImageA))
        } returns mockBitmapA
        every {
            mockBitmapHandler.createBitmap(any(), any(), refEq(fakeImageB))
        } returns mockBitmapB
        every { mockBitmapHandler.compressBitmap(mockBitmapA, any()) } returns fakeCompressedImageA
        every { mockBitmapHandler.compressBitmap(mockBitmapB, any()) } returns fakeCompressedImageB
        every { mockResourcesWriter.write(any(), any()) } answers {}

        // When
        resolver.addResource(key, 25, 25, fakeImageA)
        resolver.addResource(key + 1, 25, 25, fakeImageB)
        val resultA = resolver.resolveResource(key)
        val resultB = resolver.resolveResource(key + 1)

        // Then
        assertThat(resultA).isNotEqualTo(resultB)
    }

    @Test
    fun `M call compression only once W resolveResource {same key}`(
        @IntForgery key: Int
    ) {
        // Given
        val resolver = DefaultResourceResolver(
            mockInternalLogger,
            mockResourcesWriter,
            mockBitmapHandler
        )
        val fakeImage = createFakeImage()
        val mockBitmap = mockk<Bitmap>()
        val fakeCompressedImage = ByteArray(25) { 124 }
        every { mockBitmapHandler.createBitmap(any(), any(), refEq(fakeImage)) } returns mockBitmap
        every { mockBitmapHandler.compressBitmap(mockBitmap, any()) } returns fakeCompressedImage
        every { mockResourcesWriter.write(any(), any()) } answers {}

        // When
        resolver.addResource(key, 25, 25, fakeImage)
        val resultA = resolver.resolveResource(key)
        val resultB = resolver.resolveResource(key)

        // Then
        assertThat(resultA).isEqualTo(resultB)
        verify(exactly = 1) { mockBitmapHandler.createBitmap(any(), any(), any()) }
        verify(exactly = 1) { mockBitmapHandler.compressBitmap(any(), any()) }
        verify(exactly = 1) { mockResourcesWriter.write(any(), any()) }
    }

    @Test
    fun `M write resource to writer W resolveResource`(
        @IntForgery key: Int
    ) {
        // Given
        val resolver = DefaultResourceResolver(
            mockInternalLogger,
            mockResourcesWriter,
            mockBitmapHandler
        )
        val fakeImage = createFakeImage()
        val mockBitmap = mockk<Bitmap>()
        val fakeCompressedImage = ByteArray(25) { 124 }
        every { mockBitmapHandler.createBitmap(any(), any(), refEq(fakeImage)) } returns mockBitmap
        every { mockBitmapHandler.compressBitmap(mockBitmap, any()) } returns fakeCompressedImage
        every { mockResourcesWriter.write(any(), any()) } answers {}

        // When
        resolver.addResource(key, 25, 25, fakeImage)
        val resultA = resolver.resolveResource(key)

        // Then
        verify { mockResourcesWriter.write(resultA!!, refEq(fakeCompressedImage)) }
    }

    @Test
    fun `M write different resources to writer W resolveResource {different image}`(
        @IntForgery key: Int
    ) {
        // Given
        val resolver = DefaultResourceResolver(
            mockInternalLogger,
            mockResourcesWriter,
            mockBitmapHandler
        )
        val fakeImageA = createFakeImage()
        val fakeImageB = createFakeImage()
        val mockBitmapA = mockk<Bitmap>()
        val mockBitmapB = mockk<Bitmap>()
        val fakeCompressedImageA = ByteArray(25) { 0 }
        val fakeCompressedImageB = ByteArray(25) { 124 }
        every {
            mockBitmapHandler.createBitmap(any(), any(), refEq(fakeImageA))
        } returns mockBitmapA
        every {
            mockBitmapHandler.createBitmap(any(), any(), refEq(fakeImageB))
        } returns mockBitmapB
        every { mockBitmapHandler.compressBitmap(mockBitmapA, any()) } returns fakeCompressedImageA
        every { mockBitmapHandler.compressBitmap(mockBitmapB, any()) } returns fakeCompressedImageB
        every { mockResourcesWriter.write(any(), any()) } answers {}

        // When
        resolver.addResource(key, 25, 25, fakeImageA)
        resolver.addResource(key + 1, 25, 25, fakeImageB)
        val resultA = resolver.resolveResource(key)
        val resultB = resolver.resolveResource(key + 1)

        // Then
        assertThat(resultA).isNotEqualTo(resultB)
        verify { mockResourcesWriter.write(resultA!!, refEq(fakeCompressedImageA)) }
        verify { mockResourcesWriter.write(resultB!!, refEq(fakeCompressedImageB)) }
    }

    @Test
    fun `M not write resource to writer W resolveResource {known id}`(
        @IntForgery key: Int
    ) {
        // Given
        val resolver = DefaultResourceResolver(
            mockInternalLogger,
            mockResourcesWriter,
            mockBitmapHandler
        )
        val fakeImage = createFakeImage()
        val mockBitmap = mockk<Bitmap>()
        val fakeCompressedImage = ByteArray(25) { 124 }
        every { mockBitmapHandler.createBitmap(any(), any(), refEq(fakeImage)) } returns mockBitmap
        every { mockBitmapHandler.compressBitmap(mockBitmap, any()) } returns fakeCompressedImage
        every { mockResourcesWriter.write(any(), any()) } answers {}

        // When
        resolver.addResource(key, 25, 25, fakeImage)
        resolver.addResource(key + 1, 25, 25, fakeImage)
        val resultA = resolver.resolveResource(key)
        val resultB = resolver.resolveResource(key)

        // Then
        assertThat(resultA).isEqualTo(resultB)
        verify(exactly = 1) { mockResourcesWriter.write(resultA!!, refEq(fakeCompressedImage)) }
    }
}
