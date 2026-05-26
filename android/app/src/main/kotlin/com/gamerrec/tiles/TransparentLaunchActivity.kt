package com.gamerrec.tiles

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Bundle
import android.util.Log
import com.gamerrec.recording.RecordingService
import android.content.SharedPreferences

class TransparentLaunchActivity : Activity() {
    private val REQUEST_PROJECTION = 1002

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            startActivityForResult(projectionManager.createScreenCaptureIntent(), REQUEST_PROJECTION)
        } catch (e: Exception) {
            finish()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_PROJECTION && resultCode == RESULT_OK && data != null) {
            startRecordingService(resultCode, data)
        }
        finish()
    }

    private fun startRecordingService(resultCode: Int, data: Intent) {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val width = prefs.getLong("flutter.rec_width", 1920L).toInt()
        val height = prefs.getLong("flutter.rec_height", 1080L).toInt()
        val fps = prefs.getLong("flutter.rec_fps", 1L).toInt() 
        val bitrate = prefs.getLong("flutter.rec_bitrate_mbps", 40L).toInt() * 1_000_000
        val audioMode = prefs.getLong("flutter.rec_audio_mode", 3L).toInt()
        val shakeToStop = prefs.getBoolean("flutter.rec_shake_to_stop", false)
        val floatingOverlay = prefs.getBoolean("flutter.rec_floating_overlay", false)
        val dndMode = prefs.getBoolean("flutter.rec_dnd_mode", false)
        val videoEncoder = prefs.getLong("flutter.rec_video_encoder", 1L).toInt()
        val orientationMode = prefs.getLong("flutter.rec_orientation_mode", 0L).toInt()

        val frameRateVal = when(fps) { 0 -> 15; 1 -> 30; 2 -> 45; 3 -> 60; else -> 30 }

        val serviceIntent = Intent(this, RecordingService::class.java).apply {
            putExtra(RecordingService.EXTRA_RESULT_CODE, resultCode)
            putExtra(RecordingService.EXTRA_RESULT_DATA, data)
            putExtra(RecordingService.EXTRA_WIDTH, width)
            putExtra(RecordingService.EXTRA_HEIGHT, height)
            putExtra(RecordingService.EXTRA_FRAME_RATE, frameRateVal)
            putExtra(RecordingService.EXTRA_BITRATE_BPS, bitrate)
            putExtra(RecordingService.EXTRA_AUDIO_MODE, audioMode)
            putExtra(RecordingService.EXTRA_SHAKE_TO_STOP, shakeToStop)
            putExtra(RecordingService.EXTRA_FLOATING_OVERLAY, floatingOverlay)
            putExtra(RecordingService.EXTRA_DND_MODE, dndMode)
            putExtra(RecordingService.EXTRA_VIDEO_ENCODER, videoEncoder)
            putExtra(RecordingService.EXTRA_ORIENTATION_MODE, orientationMode)
        }
        
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }
}
