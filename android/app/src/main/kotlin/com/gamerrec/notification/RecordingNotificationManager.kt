// android/app/src/main/kotlin/com/gamerrec/notification/RecordingNotificationManager.kt

package com.gamerrec.notification

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import com.gamerrec.MainActivity
import com.gamerrec.R

class RecordingNotificationManager(private val context: Context) {

    companion object {
        const val CHANNEL_ID       = "gamer_rec_recording"
        const val NOTIFICATION_ID  = 1001

        const val ACTION_STOP      = "com.gamerrec.action.STOP"
        const val ACTION_PAUSE     = "com.gamerrec.action.PAUSE"
        const val ACTION_RESUME    = "com.gamerrec.action.RESUME"
    }

    fun createChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Recording Status",
            NotificationManager.IMPORTANCE_LOW   // no sound, no heads-up (doc §6.2)
        ).apply {
            description = "Shows while screen recording is active"
            setShowBadge(false)
        }
        context.getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    fun buildNotification(elapsed: String, isPaused: Boolean): Notification {
        val stopPi = PendingIntent.getBroadcast(
            context, 0,
            Intent(ACTION_STOP).setPackage(context.packageName),
            PendingIntent.FLAG_IMMUTABLE
        )
        val pauseResumePi = PendingIntent.getBroadcast(
            context, 1,
            Intent(if (isPaused) ACTION_RESUME else ACTION_PAUSE)
                .setPackage(context.packageName),
            PendingIntent.FLAG_IMMUTABLE
        )
        val launchPi = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE
        )

        val title = if (isPaused) "Recording Paused" else "Recording — $elapsed"

        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_recording_dot)
            .setContentTitle(title)
            .setContentText("Tap to open Gamer Rec")
            .setOngoing(true)           // cannot be dismissed while service runs
            .setShowWhen(false)
            .setContentIntent(launchPi)
            .addAction(R.drawable.ic_stop, "Stop", stopPi)
            .addAction(
                if (isPaused) R.drawable.ic_resume else R.drawable.ic_pause,
                if (isPaused) "Resume" else "Pause",
                pauseResumePi
            )
            .build()
    }
}
