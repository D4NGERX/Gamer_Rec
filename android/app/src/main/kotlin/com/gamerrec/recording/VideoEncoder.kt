package com.gamerrec.recording

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.os.Bundle
import android.util.Log
import android.view.Surface
import java.util.concurrent.atomic.AtomicBoolean

class VideoEncoder(
    private val config: RecordingConfig,
    private val muxer: MediaMuxerWrapper
) {
    companion object {
        private const val TAG = "VideoEncoder"
        private const val VIDEO_MIME      = "video/avc"
        private const val I_FRAME_INTERVAL = 2
    }

    private var codec: MediaCodec? = null
    private var inputSurface: Surface? = null
    private val isRunning = AtomicBoolean(false)
    private val isPaused  = AtomicBoolean(false)

    private var pauseStartUs  = 0L
    private var totalPausedUs = 0L

    private var drainThread: Thread? = null

    fun prepare(): Surface {
        val mime = when (config.videoEncoder) {
            0 -> "video/avc"
            1 -> "video/hevc"
            2 -> "video/x-vnd.on2.vp9"
            3 -> "video/av01"
            else -> "video/avc"
        }

        val format = MediaFormat.createVideoFormat(mime, config.width, config.height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, config.bitrateBps)
            setInteger(MediaFormat.KEY_FRAME_RATE, config.frameRate)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1) // 1 second I-frame interval for better seeking and quality
            setInteger(MediaFormat.KEY_BITRATE_MODE, MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_VBR)

            if (mime == "video/avc") {
                // High Profile for AVC
                setInteger(MediaFormat.KEY_PROFILE, MediaCodecInfo.CodecProfileLevel.AVCProfileHigh)
                setInteger(MediaFormat.KEY_LEVEL, MediaCodecInfo.CodecProfileLevel.AVCLevel41)
            }
        }

        val encoder = MediaCodec.createEncoderByType(mime)
        try {
            encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        } catch (e: Exception) {
            Log.w(TAG, "High profile / VBR failed (${e.message}), retrying with fallback")
            encoder.reset()
            val fallbackFormat = MediaFormat.createVideoFormat(mime, config.width, config.height).apply {
                setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
                setInteger(MediaFormat.KEY_BIT_RATE, config.bitrateBps)
                setInteger(MediaFormat.KEY_FRAME_RATE, config.frameRate)
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 2)
            }
            encoder.configure(fallbackFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        }

        inputSurface = encoder.createInputSurface()
        codec = encoder
        return inputSurface!!
    }

    fun start() {
        val encoder = codec ?: run { Log.e(TAG, "Encoder not prepared"); return }
        encoder.start()
        isRunning.set(true)
        drainThread = Thread({
            try {
                drainLoop()
            } catch (e: Exception) {
                Log.e(TAG, "Video drain loop exception: ${e.message}")
            }
        }, "VideoEncoderDrain").apply {
            priority = Thread.MAX_PRIORITY
            start()
        }
    }

    private fun drainLoop() {
        val encoder    = codec ?: return
        val bufferInfo = MediaCodec.BufferInfo()
        var trackIndex = -1

        while (isRunning.get()) {
            if (isPaused.get()) {
                Thread.sleep(10)
                continue
            }

            val outIndex = encoder.dequeueOutputBuffer(bufferInfo, 10_000L)

            if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                trackIndex = muxer.addVideoTrack(encoder.outputFormat)
                // NOTE: do NOT call muxer.start() here.
                // MediaMuxerWrapper.maybeStart() handles it automatically once
                // all expected tracks (video + audio) have been registered.
                Log.d("VideoEncoder", "Video format registered, track=$trackIndex")
            } else if (outIndex >= 0) {
                if (trackIndex < 0) {
                    encoder.releaseOutputBuffer(outIndex, false)
                } else if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                    encoder.releaseOutputBuffer(outIndex, false)
                } else {
                    val encodedData = encoder.getOutputBuffer(outIndex)
                    if (encodedData == null) {
                        encoder.releaseOutputBuffer(outIndex, false)
                    } else {
                        encodedData.position(bufferInfo.offset)
                        encodedData.limit(bufferInfo.offset + bufferInfo.size)
                        bufferInfo.presentationTimeUs = adjustedPts(bufferInfo.presentationTimeUs)
                        muxer.writeVideoSample(encodedData, bufferInfo, trackIndex)
                        encoder.releaseOutputBuffer(outIndex, false)
                        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            break
                        }
                    }
                }
            }
        }
    }

    fun pause() {
        pauseStartUs = System.nanoTime() / 1000
        isPaused.set(true)
    }

    fun resume() {
        if (isPaused.get()) {
            totalPausedUs += (System.nanoTime() / 1000) - pauseStartUs
            isPaused.set(false)
        }
    }

    fun stop() {
        isRunning.set(false)
        try { codec?.signalEndOfInputStream() } catch (e: Exception) {
            Log.w(TAG, "signalEndOfInputStream: ${e.message}")
        }
        drainThread?.join(2000)
        try {
            codec?.stop()
            codec?.release()
        } catch (e: Exception) {
            Log.w(TAG, "Codec release: ${e.message}")
        }
        codec = null
        inputSurface?.release()
        inputSurface = null
    }

    private fun adjustedPts(rawPts: Long): Long = rawPts - totalPausedUs

    fun updateBitrate(newBitrateBps: Int) {
        val params = Bundle().apply {
            putInt(MediaCodec.PARAMETER_KEY_VIDEO_BITRATE, newBitrateBps)
        }
        try { codec?.setParameters(params) } catch (_: Exception) {}
    }
}