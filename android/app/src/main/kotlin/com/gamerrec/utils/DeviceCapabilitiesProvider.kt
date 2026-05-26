// android/app/src/main/kotlin/com/gamerrec/utils/DeviceCapabilitiesProvider.kt

package com.gamerrec.utils

import android.content.Context
import android.media.MediaCodecList
import android.media.MediaFormat
import android.os.Build
import android.util.Log
import android.view.WindowManager

/**
 * Queries the device's hardware encoder capabilities and returns a Map
 * that is sent to Flutter via the capabilities MethodChannel.
 * See doc §5.2 and §3.4.
 */
class DeviceCapabilitiesProvider(private val context: Context) {

    companion object {
        private const val TAG = "DeviceCapabilities"
    }

    fun getCapabilitiesMap(): Map<String, Any?> {
        return mapOf(
            "resolutions"                  to getSupportedResolutions(),
            "hevcHardwareAccelerated"      to isCodecHardwareAccelerated("video/hevc", 1920, 1080),
            "vp9HardwareAccelerated"       to isCodecHardwareAccelerated("video/x-vnd.on2.vp9", 1920, 1080),
            "av1HardwareAccelerated"        to isCodecHardwareAccelerated("video/av01", 1920, 1080),
            "systemAudioCaptureAvailable"  to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
        )
    }

    private fun getSupportedResolutions(): List<Map<String, Any>> {
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val maxW: Int
        val maxH: Int

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = wm.currentWindowMetrics.bounds
            maxW = bounds.width()
            maxH = bounds.height()
        } else {
            @Suppress("DEPRECATION")
            val dm = android.util.DisplayMetrics()
            @Suppress("DEPRECATION")
            wm.defaultDisplay.getRealMetrics(dm)
            maxW = dm.widthPixels
            maxH = dm.heightPixels
        }

        val candidates = listOf(
            Pair(1280, 720),
            Pair(1920, 1080),
            Pair(2560, 1440),
            Pair(maxW, maxH)
        )

        val screenLong = maxOf(maxW, maxH)
        val screenShort = minOf(maxW, maxH)

        return candidates
            .filter { (w, h) -> maxOf(w, h) <= screenLong && minOf(w, h) <= screenShort }
            .distinctBy { it }
            .map { (w, h) ->
                mapOf(
                    "width"  to w,
                    "height" to h,
                    "maxFps" to getMaxFpsForResolution(w, h)
                )
            }
    }

    private fun getMaxFpsForResolution(width: Int, height: Int): Int {
        return try {
            val codecList = MediaCodecList(MediaCodecList.REGULAR_CODECS)
            val format = MediaFormat.createVideoFormat("video/avc", width, height)
            val encoderName = codecList.findEncoderForFormat(format) ?: return 30

            val codec = android.media.MediaCodec.createByCodecName(encoderName)
            val caps = codec.codecInfo
                .getCapabilitiesForType("video/avc")
                .videoCapabilities
            codec.release()

            val supportedRates = caps?.getSupportedFrameRatesFor(width, height)
            if (supportedRates != null) {
                minOf(supportedRates.upper.toInt(), 60)
            } else {
                30
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not query FPS caps for ${width}x${height}: ${e.message}")
            30
        }
    }

    /**
     * Checks if a specific codec is hardware accelerated for the given resolution.
     */
    private fun isCodecHardwareAccelerated(mime: String, width: Int, height: Int): Boolean {
        return try {
            val codecList = MediaCodecList(MediaCodecList.REGULAR_CODECS)
            val format = MediaFormat.createVideoFormat(mime, width, height)
            val encoderName = codecList.findEncoderForFormat(format) ?: return false

            // Check if encoder exists but is software-only (will be slow)
            val isSoftwareOnly = encoderName.startsWith("OMX.google")

            // For modern Android, check hardware acceleration flag
            val isHw = if (Build.VERSION.SDK_INT >= 29) {
                val codec = android.media.MediaCodec.createByCodecName(encoderName)
                val result = codec.codecInfo.isHardwareAccelerated
                codec.release()
                result
            } else {
                !isSoftwareOnly
            }

            Log.d(TAG, "$mime hardware accelerated: $isHw (encoder: $encoderName)")
            isHw
        } catch (e: Exception) {
            Log.w(TAG, "$mime check failed: ${e.message}")
            false
        }
    }
}
