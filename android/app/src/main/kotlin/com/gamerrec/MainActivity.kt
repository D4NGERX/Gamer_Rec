// android/app/src/main/kotlin/com/gamerrec/MainActivity.kt

package com.gamerrec

import android.app.Activity
import android.content.Intent
import android.media.projection.MediaProjectionManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.gamerrec.channels.RecordingChannelHandler
import com.gamerrec.channels.FileChannelHandler
import com.gamerrec.utils.DeviceCapabilitiesProvider

class MainActivity : FlutterActivity() {

    companion object {
        private const val RECORDING_CHANNEL    = "com.gamerrec/recording"
        private const val EVENT_CHANNEL        = "com.gamerrec/recording_events"
        private const val FILE_CHANNEL         = "com.gamerrec/files"
        private const val CAPABILITIES_CHANNEL = "com.gamerrec/capabilities"

        const val REQUEST_MEDIA_PROJECTION = 1001
    }

    private lateinit var recordingHandler: RecordingChannelHandler
    private lateinit var fileHandler: FileChannelHandler

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // Recording controls channel
        recordingHandler = RecordingChannelHandler(this)
        MethodChannel(messenger, RECORDING_CHANNEL)
            .setMethodCallHandler(recordingHandler)

        // Status event stream
        EventChannel(messenger, EVENT_CHANNEL)
            .setStreamHandler(recordingHandler.eventStreamHandler)

        // File operations channel
        fileHandler = FileChannelHandler(this)
        MethodChannel(messenger, FILE_CHANNEL)
            .setMethodCallHandler(fileHandler)

        // Device capabilities channel
        val capsProvider = DeviceCapabilitiesProvider(this)
        MethodChannel(messenger, CAPABILITIES_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDeviceCapabilities" ->
                        result.success(capsProvider.getCapabilitiesMap())
                    else -> result.notImplemented()
                }
            }
    }

    // MediaProjection consent dialog result
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_MEDIA_PROJECTION) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                recordingHandler.onMediaProjectionGranted(resultCode, data)
            } else {
                recordingHandler.onMediaProjectionDenied()
            }
        }
    }

    override fun onDestroy() {
        recordingHandler.release()
        super.onDestroy()
    }
}
