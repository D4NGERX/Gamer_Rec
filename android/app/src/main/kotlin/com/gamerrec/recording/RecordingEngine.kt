package com.gamerrec.recording

import android.content.Context
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import android.media.projection.MediaProjection
import android.os.Environment
import android.util.DisplayMetrics
import android.util.Log
import android.view.WindowManager
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class RecordingEngine(
    private val context: Context,
    private val mediaProjection: MediaProjection,
    private val config: RecordingConfig,
    private val onStarted: (String) -> Unit,
    private val onStopped: (String) -> Unit,
    private val onError: (String) -> Unit
) {
    companion object {
        private const val TAG = "RecordingEngine"
    }

    private var videoEncoder: VideoEncoder? = null
    private var audioCapture: AudioCaptureManager? = null
    private var muxerWrapper: MediaMuxerWrapper? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var outputFile: File? = null

    val currentFileSizeBytes: Long get() = outputFile?.length() ?: 0L

    fun start() {
        try {
            // Step 1: Validate and clamp config against device capabilities
            var safeConfig = clampConfig(config)
            
            // Adjust orientation
            val metrics = context.resources.displayMetrics
            val isPhysicalLandscape = metrics.widthPixels > metrics.heightPixels
            val maxDim = maxOf(safeConfig.width, safeConfig.height)
            val minDim = minOf(safeConfig.width, safeConfig.height)
            
            val (finalWidth, finalHeight) = when (safeConfig.orientationMode) {
                1 -> Pair(minDim, maxDim) // Portrait
                2 -> Pair(maxDim, minDim) // Landscape
                else -> { // Auto
                    if (isPhysicalLandscape) Pair(maxDim, minDim) else Pair(minDim, maxDim)
                }
            }
            safeConfig = safeConfig.copy(width = finalWidth, height = finalHeight)

            Log.d(TAG, "Starting with config: ${safeConfig.width}x${safeConfig.height} " +
                    "@${safeConfig.frameRate}fps bitrate=${safeConfig.bitrateBps}")

            // Step 2: Create output file
            outputFile = createOutputFile(safeConfig)
            val filePath = outputFile!!.absolutePath
            Log.d(TAG, "Output file: $filePath")

            // Step 3: Create muxer — tell it how many tracks to expect before starting
            // MediaMuxer MUST have all tracks added before start() is called.
            // expectedTrackCount=2 (video+audio) when audio is enabled, 1 for video-only.
            val expectedTrackCount = if (safeConfig.audioMode != 0) 2 else 1
            muxerWrapper = MediaMuxerWrapper(
                outputPath         = filePath,
                expectedTrackCount = expectedTrackCount,
                onMuxerReady       = { onStarted(filePath) },
                onError            = { msg -> onError(msg) }
            )

            // Step 4: Create and start video encoder
            videoEncoder = VideoEncoder(config = safeConfig, muxer = muxerWrapper!!)
            val inputSurface = videoEncoder!!.prepare()

            // Step 5: Create virtual display
            virtualDisplay = mediaProjection.createVirtualDisplay(
                "GamerRecCapture",
                safeConfig.width,
                safeConfig.height,
                getDisplayDpi(),
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                inputSurface,
                null,
                null
            )

            videoEncoder!!.start()

            // Step 6: Start audio if needed
            if (safeConfig.audioMode != 0) {
                Log.d(TAG, "Starting audio capture with mode: ${safeConfig.audioMode}")
                audioCapture = AudioCaptureManager(
                    context        = context,
                    mediaProjection = if (safeConfig.audioMode != 2) mediaProjection else null,
                    captureMic     = safeConfig.audioMode == 2 || safeConfig.audioMode == 3,
                    muxer          = muxerWrapper!!,
                    audioMode      = safeConfig.audioMode
                )
                audioCapture?.start()
            } else {
                Log.d(TAG, "Audio recording disabled (audioMode=0)")
            }

        } catch (e: Exception) {
            Log.e(TAG, "Failed to start recording engine", e)
            onError(e.message ?: "Engine start failed")
            cleanup()
        }
    }

    fun stop() {
        try {
            audioCapture?.stop()
            videoEncoder?.stop()
            virtualDisplay?.release()
            muxerWrapper?.stop()
            mediaProjection.stop()
            val path = outputFile?.absolutePath ?: ""
            onStopped(path)
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping engine", e)
            onError(e.message ?: "Stop failed")
        } finally {
            cleanup()
        }
    }

    fun pause() {
        audioCapture?.pause()
        videoEncoder?.pause()
    }

    fun resume() {
        audioCapture?.resume()
        videoEncoder?.resume()
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /**
     * Clamps the requested config to what the device encoder actually supports.
     * This prevents MediaCodec from throwing during configure().
     *
     * IMPORTANT: H.264 (AVC) is the fallback codec - if HEVC/VP9/AV1 isn't supported,
     * we fall back to H.264 at NATIVE resolution, NOT to a lower resolution.
     */
    private fun clampConfig(requested: RecordingConfig): RecordingConfig {
        // If user already selected H.264, just validate and clamp FPS/bitrate
        if (requested.videoEncoder == 0) {
            return clampAvcConfig(requested)
        }

        // For HEVC/VP9/AV1, try the requested codec first
        val mime = when (requested.videoEncoder) {
            1 -> "video/hevc"
            2 -> "video/x-vnd.on2.vp9"
            3 -> "video/av01"
            else -> "video/avc"
        }

        val codecList = MediaCodecList(MediaCodecList.REGULAR_CODECS)
        val format = MediaFormat.createVideoFormat(mime,
            requested.width, requested.height)
        val encoderName = try {
            codecList.findEncoderForFormat(format)
        } catch (e: Exception) { null }

        if (encoderName == null) {
            Log.w(TAG, "No $mime encoder for ${requested.width}x${requested.height}, " +
                    "falling back to H.264 at native resolution")
            // Fall back to H.264 at NATIVE resolution, not 1280x720
            return clampAvcConfig(requested.copy(videoEncoder = 0))
        }

        val codec = try {
            android.media.MediaCodec.createByCodecName(encoderName)
        } catch (e: Exception) {
            return requested.copy(bitrateBps = minOf(requested.bitrateBps, 8_000_000))
        }

        val videoCaps = try {
            codec.codecInfo
                .getCapabilitiesForType(mime)
                .videoCapabilities
        } catch (e: Exception) {
            codec.release()
            return requested
        }

        val maxFps = try {
            videoCaps.getSupportedFrameRatesFor(requested.width, requested.height)
                .upper.toInt().coerceAtMost(60)
        } catch (e: Exception) { 30 }

        val safeFps = minOf(requested.frameRate, maxFps)

        val maxBitrate = try {
            videoCaps.bitrateRange.upper
        } catch (e: Exception) { 20_000_000 }

        val safeBitrate = minOf(requested.bitrateBps, maxBitrate)

        codec.release()

        return requested.copy(frameRate = safeFps, bitrateBps = safeBitrate)
    }

    /**
     * Validates H.264 config - H.264 is universally supported so we keep native resolution.
     * Only clamp FPS and bitrate to device capabilities.
     */
    private fun clampAvcConfig(requested: RecordingConfig): RecordingConfig {
        val codecList = MediaCodecList(MediaCodecList.REGULAR_CODECS)
        val format = MediaFormat.createVideoFormat("video/avc",
            requested.width, requested.height)
        val encoderName = try {
            codecList.findEncoderForFormat(format)
        } catch (e: Exception) { null }

        if (encoderName == null) {
            // H.264 should always work, but if it doesn't, try 1920x1080 as last resort
            Log.w(TAG, "H.264 not available, trying 1920x1080")
            return requested.copy(width = 1920, height = 1080,
                frameRate = minOf(requested.frameRate, 30),
                bitrateBps = minOf(requested.bitrateBps, 40_000_000))
        }

        val codec = try {
            android.media.MediaCodec.createByCodecName(encoderName)
        } catch (e: Exception) {
            return requested.copy(bitrateBps = minOf(requested.bitrateBps, 40_000_000))
        }

        val videoCaps = try {
            codec.codecInfo
                .getCapabilitiesForType("video/avc")
                .videoCapabilities
        } catch (e: Exception) {
            codec.release()
            return requested
        }

        val maxFps = try {
            videoCaps.getSupportedFrameRatesFor(requested.width, requested.height)
                .upper.toInt().coerceAtMost(60)
        } catch (e: Exception) { 60 }

        val safeFps = minOf(requested.frameRate, maxFps)

        val maxBitrate = try {
            videoCaps.bitrateRange.upper.toInt()
        } catch (e: Exception) { 100_000_000 }

        val safeBitrate = minOf(requested.bitrateBps, maxBitrate)

        codec.release()

        Log.d(TAG, "H.264 validated: ${requested.width}x${requested.height} @ ${safeFps}fps, bitrate=${safeBitrate}")
        return requested.copy(frameRate = safeFps, bitrateBps = safeBitrate)
    }

    private fun getDisplayDpi(): Int {
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            context.resources.displayMetrics.densityDpi
        } else {
            @Suppress("DEPRECATION")
            val dm = DisplayMetrics()
            @Suppress("DEPRECATION")
            wm.defaultDisplay.getMetrics(dm)
            dm.densityDpi
        }
    }

    private fun createOutputFile(cfg: RecordingConfig): File {
        val dir = File(
            context.getExternalFilesDir(Environment.DIRECTORY_MOVIES),
            "GamerRec"
        ).also { it.mkdirs() }

        val ts  = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val res = "${cfg.width}x${cfg.height}"
        val fps = cfg.frameRate
        return File(dir, "GamerRec_${ts}_${res}_${fps}fps.mp4")
    }

    private fun cleanup() {
        virtualDisplay?.release()
        virtualDisplay = null
        videoEncoder   = null
        audioCapture   = null
        muxerWrapper   = null
    }
}