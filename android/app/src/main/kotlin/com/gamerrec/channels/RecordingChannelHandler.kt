// android/app/src/main/kotlin/com/gamerrec/channels/RecordingChannelHandler.kt

package com.gamerrec.channels

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.media.projection.MediaProjectionManager
import android.os.IBinder
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.gamerrec.MainActivity
import com.gamerrec.recording.RecordingService

/**
 * Handles Flutter ↔ Native method calls for recording control.
 * Owns the EventChannel sink that pushes status updates back to Flutter.
 */
class RecordingChannelHandler(private val activity: Activity) :
    MethodChannel.MethodCallHandler {

    // ── Event channel sink ──────────────────────────────────────────────────
    val eventStreamHandler = object : EventChannel.StreamHandler {
        override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
            eventSink = sink
        }
        override fun onCancel(args: Any?) {
            eventSink = null
        }
    }
    var eventSink: EventChannel.EventSink? = null

    // ── Pending Flutter result (waiting for MediaProjection dialog) ─────────
    private var pendingResult: MethodChannel.Result? = null
    private var pendingConfig: Map<String, Any?>? = null

    // ── Service binding ─────────────────────────────────────────────────────
    private var recordingService: RecordingService? = null
    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            val b = binder as? RecordingService.RecordingBinder ?: return
            recordingService = b.getService()
            recordingService?.setEventSink(eventSink)
        }
        override fun onServiceDisconnected(name: ComponentName?) {
            recordingService = null
        }
    }

    // ── MethodCallHandler ───────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startRecording" -> handleStart(call, result)
            "stopRecording"  -> handleStop(result)
            "pauseRecording" -> handlePause(result)
            "resumeRecording" -> handleResume(result)
            else -> result.notImplemented()
        }
    }

    private fun handleStart(call: MethodCall, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST")
        val config = call.arguments as? Map<String, Any?> ?: run {
            result.error("INVALID_ARGS", "Missing recording config", null)
            return
        }

        pendingResult = result
        pendingConfig = config

        // Request MediaProjection consent
        val projectionManager =
            activity.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        @Suppress("DEPRECATION")
        activity.startActivityForResult(
            projectionManager.createScreenCaptureIntent(),
            MainActivity.REQUEST_MEDIA_PROJECTION
        )
    }

    private fun handleStop(result: MethodChannel.Result) {
        val service = recordingService
        if (service == null) {
            result.error("NOT_RECORDING", "No active recording", null)
            return
        }
        service.stopRecording()
        activity.unbindService(serviceConnection)
        recordingService = null
        result.success(null)
    }

    private fun handlePause(result: MethodChannel.Result) {
        recordingService?.pauseRecording()
        result.success(null)
    }

    private fun handleResume(result: MethodChannel.Result) {
        recordingService?.resumeRecording()
        result.success(null)
    }

    // ── MediaProjection callbacks ───────────────────────────────────────────

    fun onMediaProjectionGranted(resultCode: Int, data: Intent) {
        val config = pendingConfig ?: run {
            pendingResult?.error("NO_CONFIG", "Missing config", null)
            return
        }
        val result = pendingResult
        pendingResult = null
        pendingConfig = null

        // Start the foreground service with the projection token
        val serviceIntent = Intent(activity, RecordingService::class.java).apply {
            putExtra(RecordingService.EXTRA_RESULT_CODE, resultCode)
            putExtra(RecordingService.EXTRA_RESULT_DATA, data)
            putExtra(RecordingService.EXTRA_WIDTH,     config["width"] as? Int ?: 1920)
            putExtra(RecordingService.EXTRA_HEIGHT,    config["height"] as? Int ?: 1080)
            putExtra(RecordingService.EXTRA_FRAME_RATE, config["frameRate"] as? Int ?: 30)
            putExtra(RecordingService.EXTRA_BITRATE_BPS,
                (config["bitrateBps"] as? Int) ?: 40_000_000)
            putExtra(RecordingService.EXTRA_AUDIO_MODE, config["audioMode"] as? Int ?: 3)
            putExtra(RecordingService.EXTRA_SHAKE_TO_STOP, config["shakeToStop"] as? Boolean ?: false)
            putExtra(RecordingService.EXTRA_FLOATING_OVERLAY, config["floatingOverlay"] as? Boolean ?: false)
            putExtra(RecordingService.EXTRA_DND_MODE, config["dndMode"] as? Boolean ?: false)
            putExtra(RecordingService.EXTRA_VIDEO_ENCODER, config["videoEncoder"] as? Int ?: 1)
            putExtra(RecordingService.EXTRA_ORIENTATION_MODE, config["orientationMode"] as? Int ?: 0)
        }

        activity.startForegroundService(serviceIntent)
        activity.bindService(serviceIntent, serviceConnection, Context.BIND_AUTO_CREATE)

        result?.success(null)
    }

    fun onMediaProjectionDenied() {
        pendingResult?.error("PROJECTION_CANCELLED",
            "User cancelled screen capture permission", null)
        pendingResult = null
        pendingConfig = null
    }

    fun release() {
        try { activity.unbindService(serviceConnection) } catch (_: Exception) {}
    }
}
