// android/app/src/main/kotlin/com/gamerrec/recording/AudioCaptureManager.kt

package com.gamerrec.recording

import android.Manifest
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.MediaCodec
import android.media.MediaFormat
import android.media.projection.MediaProjection
import android.os.Build
import android.os.Process
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Captures audio from system playback and/or microphone, mixes PCM if needed,
 * and feeds encoded AAC into the MediaMuxer.
 *
 * audioMode: 1 = system only, 2 = mic only, 3 = system + mic mixed
 */
class AudioCaptureManager(
    private val context: android.content.Context,
    private val mediaProjection: MediaProjection?,  // null when mic-only
    private val captureMic: Boolean,
    private val muxer: MediaMuxerWrapper,
    private val audioMode: Int = 3  // 0=none, 1=system, 2=mic, 3=both
) {
    companion object {
        private const val TAG = "AudioCaptureManager"
        private const val AUDIO_MIME    = "audio/mp4a-latm"
        private const val SAMPLE_RATE   = 48000  // Use 48kHz - more compatible
        private const val CHANNEL_COUNT = 2
        private const val BIT_RATE      = 128_000  // 128kbps AAC-LC
    }

    private val isRunning = AtomicBoolean(false)
    private val isPaused  = AtomicBoolean(false)

    private var systemRecord: AudioRecord? = null
    private var micRecord: AudioRecord?    = null
    private var audioEncoder: MediaCodec? = null
    private var captureThread: Thread?    = null

    // PTS correction (same pattern as VideoEncoder, doc §6.3)
    private var pauseStartUs = 0L
    private var totalPausedUs = 0L
    private var presentationUs = 0L  // running PTS counter

    fun start() {
        Log.d(TAG, "AudioCaptureManager.start() called with audioMode: ${
            when (audioMode) {
                0 -> "none"
                1 -> "systemOnly"
                2 -> "micOnly"
                3 -> "systemAndMic"
                else -> "unknown"
            }
        }")

        setupEncoder()

        val minBufSize = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_STEREO,
            AudioFormat.ENCODING_PCM_16BIT
        )

        if (minBufSize == AudioRecord.ERROR || minBufSize == AudioRecord.ERROR_BAD_VALUE) {
            Log.e(TAG, "Invalid min buffer size ($minBufSize), skipping audio capture")
            return
        }

        val bufSize = minBufSize * 2  // doc §3.6: at least 2× min to prevent dropouts

        // System audio (API 29+)
        if (mediaProjection != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                Log.d(TAG, "Initializing system audio capture...")
                val playbackConfig = AudioPlaybackCaptureConfiguration.Builder(mediaProjection)
                    .addMatchingUsage(android.media.AudioAttributes.USAGE_GAME)
                    .addMatchingUsage(android.media.AudioAttributes.USAGE_MEDIA)
                    .addMatchingUsage(android.media.AudioAttributes.USAGE_UNKNOWN)
                    .build()

                systemRecord = AudioRecord.Builder()
                    .setAudioPlaybackCaptureConfig(playbackConfig)
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setSampleRate(SAMPLE_RATE)
                            .setChannelMask(AudioFormat.CHANNEL_IN_STEREO)
                            .build()
                    )
                    .setBufferSizeInBytes(bufSize)
                    .build()

                val systemState = systemRecord?.state
                Log.d(TAG, "System AudioRecord state: $systemState (2 = INITIALIZED)")
                if (systemState != AudioRecord.STATE_INITIALIZED) {
                    Log.w(TAG, "System AudioRecord failed to initialize (state=$systemState), disabling system audio")
                    systemRecord?.release()
                    systemRecord = null
                } else {
                    Log.d(TAG, "System AudioRecord initialized successfully")
                }
            } catch (e: Exception) {
                Log.e(TAG, "System audio capture exception: ${e.message}", e)
                systemRecord = null
            }
        } else {
            Log.d(TAG, "System audio skipped: mediaProjection=$mediaProjection, SDK=${Build.VERSION.SDK_INT}")
        }

        // Microphone
        if (captureMic) {
            try {
                Log.d(TAG, "Initializing microphone capture...")
                micRecord = AudioRecord(
                    android.media.MediaRecorder.AudioSource.MIC,
                    SAMPLE_RATE,
                    AudioFormat.CHANNEL_IN_STEREO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    bufSize
                )

                val micState = micRecord?.state
                Log.d(TAG, "Mic AudioRecord state: $micState (2 = INITIALIZED)")
                if (micState != AudioRecord.STATE_INITIALIZED) {
                    Log.w(TAG, "Mic AudioRecord failed to initialize (state=$micState), disabling mic")
                    micRecord?.release()
                    micRecord = null
                } else {
                    Log.d(TAG, "Mic AudioRecord initialized successfully")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Mic capture exception: ${e.message}", e)
                micRecord = null
            }
        }

        // If neither audio source initialized, skip audio entirely
        if (systemRecord == null && micRecord == null) {
            Log.w(TAG, "No audio source available, audio capture will be skipped")
            audioEncoder?.release()
            audioEncoder = null
            return
        }

        isRunning.set(true)

        if (systemRecord != null) systemRecord!!.startRecording()
        if (micRecord != null)    micRecord!!.startRecording()

        audioEncoder?.start()

        captureThread = Thread({
            try {
                Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)  // doc §8.3
                captureLoop(bufSize)
            } catch (e: Exception) {
                Log.e(TAG, "Audio capture loop exception: ${e.message}")
            }
        }, "AudioCapture").apply {
            start()
        }
    }

    private fun captureLoop(bufSize: Int) {
        // Use a fixed chunk size for consistent encoder feeding.
        // 1024 stereo frames = ~21ms at 48kHz — a good balance.
        val chunkFrames = 1024
        val sysBuffer = if (systemRecord != null) ShortArray(chunkFrames * CHANNEL_COUNT) else null
        val micBuffer = if (micRecord != null)    ShortArray(chunkFrames * CHANNEL_COUNT) else null
        val mixBuffer = ShortArray(chunkFrames * CHANNEL_COUNT)

        var trackIndex = -1
        val bufferInfo = MediaCodec.BufferInfo()
        val encoder = audioEncoder ?: return

        Log.d(TAG, "captureLoop started — sys=${systemRecord != null}, mic=${micRecord != null}")

        while (isRunning.get()) {
            if (isPaused.get()) {
                Thread.sleep(10)
                continue
            }

            // Use BLOCKING reads so we always get real data (or silence-filled buffers).
            // This guarantees the encoder gets fed and produces INFO_OUTPUT_FORMAT_CHANGED.
            val sysRead = sysBuffer?.let { buf ->
                val read = systemRecord?.read(buf, 0, buf.size) ?: 0
                if (read < 0) { Log.w(TAG, "System read error: $read"); 0 } else read
            } ?: 0

            val micRead = micBuffer?.let { buf ->
                val read = micRecord?.read(buf, 0, buf.size) ?: 0
                if (read < 0) { Log.w(TAG, "Mic read error: $read"); 0 } else read
            } ?: 0

            // Even if both return 0, feed silence — this ensures the encoder initializes
            val sampleCount = maxOf(sysRead, micRead, chunkFrames * CHANNEL_COUNT)

            // Mix PCM (add samples with clamping)
            for (i in 0 until sampleCount) {
                val s = if (sysBuffer != null && i < sysRead) sysBuffer[i].toInt() else 0
                val m = if (micBuffer != null && i < micRead) micBuffer[i].toInt() else 0
                mixBuffer[i] = (s + m).coerceIn(Short.MIN_VALUE.toInt(),
                    Short.MAX_VALUE.toInt()).toShort()
            }

            // Feed into encoder
            val inputIdx = encoder.dequeueInputBuffer(10_000)
            if (inputIdx >= 0) {
                val buf = encoder.getInputBuffer(inputIdx) ?: continue
                buf.clear()
                // Only write as many bytes as the buffer can hold
                val maxSamples = minOf(sampleCount, buf.remaining() / 2)
                for (i in 0 until maxSamples) {
                    val s = mixBuffer[i]
                    buf.put((s.toInt() and 0xFF).toByte())
                    buf.put((s.toInt() shr 8).toByte())
                }
                val byteCount = maxSamples * 2

                // Use System.nanoTime() for PTS to sync with VideoEncoder
                val currentPtsUs = (System.nanoTime() / 1000) - totalPausedUs

                encoder.queueInputBuffer(inputIdx, 0, byteCount, currentPtsUs, 0)
            }

            // Drain encoder output
            drainEncoder(encoder, bufferInfo, trackIndex) { newTrackIndex ->
                trackIndex = newTrackIndex
            }
        }

        Log.d(TAG, "captureLoop exited")
    }

    /**
     * Drain all available encoded output buffers.
     * When INFO_OUTPUT_FORMAT_CHANGED arrives, register the audio track with the muxer.
     */
    private fun drainEncoder(
        encoder: MediaCodec,
        bufferInfo: MediaCodec.BufferInfo,
        currentTrackIndex: Int,
        onTrackRegistered: (Int) -> Unit
    ) {
        var trackIndex = currentTrackIndex
        while (true) {
            val outIdx = encoder.dequeueOutputBuffer(bufferInfo, 0)
            when {
                outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    trackIndex = muxer.addAudioTrack(encoder.outputFormat)
                    Log.d(TAG, "Audio track registered with muxer, index=$trackIndex")
                    onTrackRegistered(trackIndex)
                }
                outIdx >= 0 -> {
                    if (trackIndex >= 0 &&
                        bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0
                    ) {
                        val encodedData = encoder.getOutputBuffer(outIdx)
                        if (encodedData != null) {
                            encodedData.position(bufferInfo.offset)
                            encodedData.limit(bufferInfo.offset + bufferInfo.size)
                            muxer.writeAudioSample(encodedData, bufferInfo, trackIndex)
                        }
                    }
                    encoder.releaseOutputBuffer(outIdx, false)
                }
                else -> break // INFO_TRY_AGAIN_LATER or other — no more output available
            }
        }
    }

    private fun setupEncoder() {
        val format = MediaFormat.createAudioFormat(AUDIO_MIME, SAMPLE_RATE, CHANNEL_COUNT).apply {
            setInteger(MediaFormat.KEY_BIT_RATE, BIT_RATE)
            setInteger(MediaFormat.KEY_AAC_PROFILE,
                android.media.MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            // Removed KEY_MAX_INPUT_SIZE to allow dynamic buffer sizing
        }
        audioEncoder = MediaCodec.createEncoderByType(AUDIO_MIME).apply {
            configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        }
    }

    fun pause() {
        pauseStartUs = System.nanoTime() / 1000
        isPaused.set(true)
    }

    fun resume() {
        if (isPaused.get()) {
            totalPausedUs += (System.nanoTime() / 1000) - pauseStartUs
            // Advance presentationUs to avoid gap
            presentationUs += totalPausedUs
            isPaused.set(false)
        }
    }

    fun stop() {
        isRunning.set(false)
        captureThread?.join(3000)

        try {
            systemRecord?.stop()
        } catch (e: Exception) {
            Log.w(TAG, "System AudioRecord stop error: ${e.message}")
        }
        systemRecord?.release()
        systemRecord = null

        try {
            micRecord?.stop()
        } catch (e: Exception) {
            Log.w(TAG, "Mic AudioRecord stop error: ${e.message}")
        }
        micRecord?.release()
        micRecord = null

        try {
            audioEncoder?.stop()
            audioEncoder?.release()
        } catch (e: Exception) {
            Log.w(TAG, "Audio encoder release error: ${e.message}")
        }
        audioEncoder = null
    }
}
