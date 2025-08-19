/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.resource

import android.graphics.Bitmap
import android.os.Build
import com.datadog.android.api.InternalLogger
import com.datadoghq.flutter.sessionreplay.models.ResourceEvent
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.security.MessageDigest
import java.security.NoSuchAlgorithmException

/**
 * ResourceProcessor is responsible for processing resources and pairing Flutter's
 * resource keys with their corresponding resource IDs (which are MD5 hashes of the
 * contents of the resource).
 *
 * This uses synchronous, on-demand resource processing. When the processor requests
 * the ID of a resource, it will compress the resource bytes, generate the MD5 hash, then
 * write the resource to ResourcesFeature, which will upload the resources asynchronously.
 */
internal class ResourceResolver(
    val internalLogger: InternalLogger,
    val resourceWriter: ResourcesWriter,
) {
    class ResourceEntry(
        // The resource ID from Flutter
        val resourceKey: Int,
        // The width of the resource
        val width: Int,
        // The height of the resource
        val height: Int,
        // The resource Id which is the MD5 hash of the actual resource
        var resourceId: String? = null,
        // The actual byte array of the resource, which is valid only until
        // the resource's hash is generated, at which point it is set to null
        var resourceBytes: ByteArray?
    ) {

    }

    private val resourceKeyMap: MutableMap<Int, ResourceEntry> = mutableMapOf()
    private val knownResources: MutableSet<String> = mutableSetOf()

    /**
     * Adds a resource to with the given Flutter Key to be resolved later.
     */
    internal fun addResource(
        resourceKey: Int,
        width: Int,
        height: Int,
        resourceBytes: ByteArray
    ): ResourceEntry {
        val entry = ResourceEntry(resourceKey, width, height, resourceBytes = resourceBytes)
        resourceKeyMap[resourceKey] = entry
        return entry
    }

    fun resolveResource(resourceKey: Int): String? {
        // TODO: Telemetry, unknown resource key
        val resourceEntry = resourceKeyMap[resourceKey] ?: return null

        if (resourceEntry.resourceId != null) {
            return resourceEntry.resourceId
        }

        val resourceId = resourceEntry.resourceBytes?.let {
            val bitmap = createBitmap(it, resourceEntry.width, resourceEntry.height)
            // Discard the original bytes as fast as possible as they are no longer needed
            resourceEntry.resourceBytes = null

            return compressBitmap(bitmap)?.let { compressedData ->
                // Generate the resource ID (MD5 hash) from the bytes
                val resourceId = generateResourceId(compressedData)
                resourceEntry.resourceId = resourceId

                if (resourceId != null && !knownResources.contains(resourceEntry.resourceId)) {
                    knownResources.add(resourceId)
                    resourceWriter.write(identifier = resourceId, resourceData = compressedData)
                }

                return resourceId
            }
        }

        return resourceId
    }

    private fun getImageCompressionFormat(): Bitmap.CompressFormat =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Bitmap.CompressFormat.WEBP_LOSSY
        } else {
            @Suppress("DEPRECATION")
            Bitmap.CompressFormat.WEBP
        }

    fun createBitmap(bytes: ByteArray, width: Int, height: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val buffer = ByteBuffer.wrap(bytes)

        // Despite what the above `Bitmap.Config` says, the actual pixel format is RGBA_8888
        // with premultiplied alpha, which is the exact format that Flutter uses.
        bitmap.copyPixelsFromBuffer(buffer)
        return bitmap
    }

    fun compressBitmap(bitmap: Bitmap): ByteArray? {
        val byteOutputStream = ByteArrayOutputStream(bitmap.allocationByteCount)
        val imageFormat = getImageCompressionFormat()

        @Suppress("SwallowedException")
        try {
            // stream is not null and image quality is between 0 and 100
            @Suppress("UnsafeThirdPartyFunctionCall")
            bitmap.compress(imageFormat, IMAGE_QUALITY, byteOutputStream)
        } catch (e: IllegalStateException) {
            // probably if the bitmap was recycled while we were working on it
            internalLogger.log(
                InternalLogger.Level.ERROR,
                listOf(InternalLogger.Target.MAINTAINER, InternalLogger.Target.TELEMETRY),
                { IMAGE_COMPRESSION_ERROR },
                e
            )

            return null
        }

        return byteOutputStream.toByteArray()
    }

    fun generateResourceId(input: ByteArray): String? {
        return try {
            val messageDigest = MessageDigest.getInstance("MD5")
            messageDigest.update(input)

            val hashBytes = messageDigest.digest()

            hashBytes.toHexString()
        } catch (e: NoSuchAlgorithmException) {
            internalLogger.log(
                InternalLogger.Level.ERROR,
                listOf(InternalLogger.Target.MAINTAINER, InternalLogger.Target.TELEMETRY),
                { MD5_HASH_GENERATION_ERROR },
                e
            )
            null
        }
    }

    companion object {
        private val EMPTY_BYTEARRAY = ByteArray(0)

        // This is the default compression for webp when writing to the output stream -
        // a lower quality leads to a lower filesize and worse fidelity image
        private const val IMAGE_QUALITY = 75

        private const val IMAGE_COMPRESSION_ERROR = "Error while compressing the image."
        private const val MD5_HASH_GENERATION_ERROR = "Cannot generate MD5 hash."
    }
}

private const val BYTE_MASK = 0xff
private const val HEX_SHIFT = 4
private const val LOWER_NIBBLE_MASK = 0x0f
private const val HEX_CHARS = "0123456789abcdef"

/**
 * Converts a ByteArray to its corresponding hexadecimal String representation.
 *
 * Each byte in the array is converted into two hexadecimal characters.
 * For example, the byte array `[0xA, 0x1F]` will be converted to the string `"0a1f"`.
 *
 * This method avoids performance overhead by using bitwise operations and
 * minimizing object allocations compared to alternatives like `joinToString`.
 *
 * @receiver ByteArray The byte array to be converted.
 * @return A hexadecimal [String] representation of the byte array.
 *
 */
// TODO: See if we can grab this from the Android SDK directly instead of copying it here.
fun ByteArray.toHexString(): String {
    @Suppress("UnsafeThirdPartyFunctionCall") // byte array size is always positive.
    val result = StringBuilder(size * 2)
    for (byte in this) {
        val intVal = byte.toInt() and BYTE_MASK
        result.append(HEX_CHARS[intVal ushr HEX_SHIFT]) // Append first half of byte
        result.append(HEX_CHARS[intVal and LOWER_NIBBLE_MASK]) // Append second half of byte
    }
    return result.toString()
}