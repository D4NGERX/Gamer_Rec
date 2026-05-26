// android/app/src/main/kotlin/com/gamerrec/notification/RecordingActionReceiver.kt

package com.gamerrec.notification

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.gamerrec.recording.RecordingService

/**
 * Handles Stop / Pause / Resume taps from the persistent notification
 * even when the Flutter UI is not in the foreground (doc §6.1).
 */
class RecordingActionReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "RecordingActionReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Action received: ${intent.action}")

        // We communicate with the already-running RecordingService
        // via a local broadcast that the service listens for.
        val serviceIntent = Intent(context, RecordingService::class.java).apply {
            action = intent.action
        }

        when (intent.action) {
            RecordingNotificationManager.ACTION_STOP   -> {
                // Sending the action as intent extra; RecordingService checks it
                serviceIntent.putExtra("notification_action", "STOP")
                context.startService(serviceIntent)
            }
            RecordingNotificationManager.ACTION_PAUSE  -> {
                serviceIntent.putExtra("notification_action", "PAUSE")
                context.startService(serviceIntent)
            }
            RecordingNotificationManager.ACTION_RESUME -> {
                serviceIntent.putExtra("notification_action", "RESUME")
                context.startService(serviceIntent)
            }
        }
    }
}
