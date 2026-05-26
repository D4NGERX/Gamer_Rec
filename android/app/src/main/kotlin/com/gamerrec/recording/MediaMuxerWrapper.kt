// android/app/src/main/kotlin/com/gamerrec/recording/MediaMuxerWrapper.kt

package com.gamerrec.recording

import android.media.MediaCodec
import android.media.MediaFormat
import android.media.MediaMuxer
import android.util.Log
import java.nio.ByteBuffer
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

/**
 * Thread-safe wrapper around MediaMuxer.
 *
 * KEY RULE: MediaMuxer.start() MUST be called only after ALL tracks are added.
 * Calling addTrack() after start() throws IllegalStateException.
 *
 * Fix: pass [expectedTrackCount] so this wrapper knows when to auto-start.
 *  - video-only recording  → expectedTrackCount = 1
 *  - video + audio         → expectedTrackCount = 2
 *
 * Both VideoEncoder and AudioCaptureManager call addVideoTrack / addAudioTrack;
 * [maybeStart] fires onMuxerReady() the moment the last expected track registers.
 */
class MediaMuxerWrapper(
    private val outputPath: String,
    private val expectedTrackCount: Int,          // 1 = video only, 2 = video+audio
    private val onMuxerReady: () -> Unit,
    private val onError: (String) -> Unit
) {
    companion object {
        private const val TAG = "MediaMuxerWrapper"
    }

    private val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    private val lock = ReentrantLock()

    private var videoTrackIndex = -1
    private var audioTrackIndex = -1
    private var videoFormatAdded = false
    private var audioFormatAdded = false
    private val started = AtomicBoolean(false)
    private val stopped = AtomicBoolean(false)

    // Write queue for the MuxerThread
    private data class MuxSample(
        val trackIndex: Int,
        val data: ByteBuffer,
        val info: MediaCodec.BufferInfo
    )

    private val writeQueue = LinkedBlockingQueue<MuxSample>(512)
    private val muxRunning = AtomicBoolean(true)
    private val muxerThread = Thread({ muxerLoop() }, "MuxerThread").apply { start() }

    // ── Track registration ────────────────────────────────────────────────────

    fun addVideoTrack(format: MediaFormat): Int {
        return lock.withLock {
            if (videoFormatAdded) return@withLock videoTrackIndex
            videoTrackIndex = muxer.addTrack(format)
            videoFormatAdded = true
            Log.d(TAG, "Video track added: index=$videoTrackIndex")
            maybeStart()
            videoTrackIndex
        }
    }

    fun addAudioTrack(format: MediaFormat): Int {
        return lock.withLock {
            if (audioFormatAdded) return@withLock audioTrackIndex
            audioTrackIndex = muxer.addTrack(format)
            audioFormatAdded = true
            Log.d(TAG, "Audio track added: index=$audioTrackIndex")
            maybeStart()
            audioTrackIndex
        }
    }

    /**
     * Called inside [lock] after every track registration.
     * Starts the underlying MediaMuxer the moment all expected tracks are present.
     */
    private fun maybeStart() {
        val registered = (if (videoFormatAdded) 1 else 0) + (if (audioFormatAdded) 1 else 0)
        Log.d(TAG, "maybeStart: registered=$registered / expected=$expectedTrackCount, started=${started.get()}")
        if (registered >= expectedTrackCount && !started.get()) {
            try {
                muxer.start()
                started.set(true)
                Log.d(TAG, "Muxer started successfully with $registered track(s)")
                onMuxerReady()
            } catch (e: Exception) {
                Log.e(TAG, "Muxer.start() failed: ${e.message}", e)
                onError("Muxer start failed: ${e.message}")
            }
        }
    }

    // ── Write helpers ─────────────────────────────────────────────────────────

    fun writeVideoSample(data: ByteBuffer, info: MediaCodec.BufferInfo, trackIndex: Int) {
        enqueueSample(trackIndex, data, info)
    }

    fun writeAudioSample(data: ByteBuffer, info: MediaCodec.BufferInfo, trackIndex: Int) {
        enqueueSample(trackIndex, data, info)
    }

    private fun enqueueSample(trackIndex: Int, data: ByteBuffer, info: MediaCodec.BufferInfo) {
        if (!started.get() || stopped.get() || trackIndex < 0) return
        // Copy buffer so the encoder can immediately reuse its memory
        val copy = ByteBuffer.allocate(info.size)
        copy.put(data)
        copy.flip()
        val infoCopy = MediaCodec.BufferInfo().apply {
            set(0, info.size, info.presentationTimeUs, info.flags)
        }
        if (!writeQueue.offer(MuxSample(trackIndex, copy, infoCopy), 100, TimeUnit.MILLISECONDS)) {
            Log.w(TAG, "Write queue full, dropping sample for track $trackIndex")
        }
    }

    // ── Muxer thread ──────────────────────────────────────────────────────────

    private fun muxerLoop() {
        while (muxRunning.get() || writeQueue.isNotEmpty()) {
            val sample = writeQueue.poll(10, TimeUnit.MILLISECONDS) ?: continue
            try {
                if (started.get() && !stopped.get()) {
                    muxer.writeSampleData(sample.trackIndex, sample.data, sample.info)
                }
            } catch (e: Exception) {
                Log.e(TAG, "writeSampleData error: ${e.message}")
            }
        }
    }

    // ── Stop ──────────────────────────────────────────────────────────────────

    fun stop() {
        if (stopped.getAndSet(true)) return
        muxRunning.set(false)
        muxerThread.join(3000)
        try {
            if (started.get()) {
                muxer.stop()
                muxer.release()
                Log.d(TAG, "Muxer stopped and released → $outputPath")
            } else {
                muxer.release()
                Log.w(TAG, "Muxer released without starting (no output written)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Muxer stop error: ${e.message}")
        }
    }
}
