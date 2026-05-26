package com.gamerrec.recording

import android.app.Service
import android.content.Intent
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Binder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import io.flutter.plugin.common.EventChannel
import com.gamerrec.notification.RecordingNotificationManager

class RecordingService : Service() {

    companion object {
        private const val TAG = "RecordingService"
        const val EXTRA_RESULT_CODE   = "resultCode"
        const val EXTRA_RESULT_DATA   = "resultData"
        const val EXTRA_WIDTH         = "width"
        const val EXTRA_HEIGHT        = "height"
        const val EXTRA_FRAME_RATE    = "frameRate"
        const val EXTRA_BITRATE_BPS   = "bitrateBps"
        const val EXTRA_AUDIO_MODE    = "audioMode"
        const val EXTRA_SHAKE_TO_STOP = "shakeToStop"
        const val EXTRA_FLOATING_OVERLAY = "floatingOverlay"
        const val EXTRA_DND_MODE      = "dndMode"
        const val EXTRA_VIDEO_ENCODER = "videoEncoder"
        const val EXTRA_ORIENTATION_MODE = "orientationMode"
    }

    inner class RecordingBinder : Binder() {
        fun getService(): RecordingService = this@RecordingService
    }

    private val binder = RecordingBinder()
    private var mediaProjection: MediaProjection? = null
    private var projectionCallback: MediaProjection.Callback? = null
    private var recordingEngine: RecordingEngine? = null
    private var notifManager: RecordingNotificationManager? = null
    private var overlayManager: FloatingOverlayManager? = null
    private var eventSink: EventChannel.EventSink? = null

    // Buffer events that arrive before the sink is connected
    private val pendingEvents = mutableListOf<Map<String, Any?>>()

    private val handler = Handler(Looper.getMainLooper())
    private var startTimeMs = 0L
    private var pausedDurationMs = 0L
    private var pauseStartMs = 0L
    private var isPaused = false

    private var sensorManager: android.hardware.SensorManager? = null
    private var accelerometer: android.hardware.Sensor? = null
    private var shakeListener: android.hardware.SensorEventListener? = null
    private var shakeToStopEnabled = false

    private var windowManager: android.view.WindowManager? = null
    private var floatingView: android.view.View? = null
    
    private var originalInterruptionFilter = android.app.NotificationManager.INTERRUPTION_FILTER_UNKNOWN
    private var dndModeEnabled = false

    override fun onCreate() {
        super.onCreate()
        notifManager = RecordingNotificationManager(this)
        notifManager?.createChannel()
        sensorManager = getSystemService(android.content.Context.SENSOR_SERVICE) as android.hardware.SensorManager
        accelerometer = sensorManager?.getDefaultSensor(android.hardware.Sensor.TYPE_ACCELEROMETER)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent ?: return START_NOT_STICKY

        when (intent.getStringExtra("notification_action")) {
            "STOP"   -> { stopRecording(); return START_NOT_STICKY }
            "PAUSE"  -> { pauseRecording(); return START_NOT_STICKY }
            "RESUME" -> { resumeRecording(); return START_NOT_STICKY }
        }

        val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, -1)
        @Suppress("DEPRECATION")
        val resultData: Intent? = intent.getParcelableExtra(EXTRA_RESULT_DATA)

        if (resultData == null) {
            Log.e(TAG, "No MediaProjection result data")
            stopSelf()
            return START_NOT_STICKY
        }

        val width      = intent.getIntExtra(EXTRA_WIDTH, 1920)
        val height     = intent.getIntExtra(EXTRA_HEIGHT, 1080)
        val frameRate  = intent.getIntExtra(EXTRA_FRAME_RATE, 30)
        val bitrateBps = intent.getIntExtra(EXTRA_BITRATE_BPS, 8_000_000) // 8 Mbps safe default
        val audioMode  = intent.getIntExtra(EXTRA_AUDIO_MODE, 3)
        val shakeToStop = intent.getBooleanExtra(EXTRA_SHAKE_TO_STOP, false)
        val floatingOverlay = intent.getBooleanExtra(EXTRA_FLOATING_OVERLAY, false)
        val dndMode = intent.getBooleanExtra(EXTRA_DND_MODE, false)
        val videoEncoder = intent.getIntExtra(EXTRA_VIDEO_ENCODER, 1)
        val orientationMode = intent.getIntExtra(EXTRA_ORIENTATION_MODE, 0)
        shakeToStopEnabled = shakeToStop
        dndModeEnabled = dndMode

        if (dndModeEnabled) {
            enableDndMode()
        }

        if (floatingOverlay) {
            showFloatingOverlay()
        }

        if (shakeToStopEnabled && accelerometer != null) {
            shakeListener = object : android.hardware.SensorEventListener {
                private var lastUpdate: Long = 0
                private var lastX: Float = 0f
                private var lastY: Float = 0f
                private var lastZ: Float = 0f
                private val SHAKE_THRESHOLD = 800

                override fun onSensorChanged(event: android.hardware.SensorEvent) {
                    val curTime = SystemClock.elapsedRealtime()
                    if ((curTime - lastUpdate) > 100) {
                        val diffTime = curTime - lastUpdate
                        lastUpdate = curTime
                        val x = event.values[0]
                        val y = event.values[1]
                        val z = event.values[2]
                        val speed = Math.abs(x + y + z - lastX - lastY - lastZ) / diffTime * 10000
                        if (speed > SHAKE_THRESHOLD) {
                            Log.d(TAG, "Shake detected, stopping recording")
                            handler.post { stopRecording() }
                        }
                        lastX = x
                        lastY = y
                        lastZ = z
                    }
                }
                override fun onAccuracyChanged(sensor: android.hardware.Sensor?, accuracy: Int) {}
            }
            sensorManager?.registerListener(shakeListener, accelerometer, android.hardware.SensorManager.SENSOR_DELAY_NORMAL)
        }

        val notification = notifManager!!.buildNotification("00:00", false)
        startForeground(RecordingNotificationManager.NOTIFICATION_ID, notification)

        val projManager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        mediaProjection = projManager.getMediaProjection(resultCode, resultData)

        // Android 14+ requires registering a callback before createVirtualDisplay()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            projectionCallback = object : MediaProjection.Callback() {
                override fun onStop() {
                    Log.d(TAG, "MediaProjection stopped by system")
                    handler.post { stopRecording() }
                }
            }
            mediaProjection!!.registerCallback(projectionCallback!!, handler)
        }

        val config = RecordingConfig(
            width      = width,
            height     = height,
            frameRate  = frameRate,
            bitrateBps = bitrateBps,
            audioMode  = audioMode,
            dndMode    = dndMode,
            videoEncoder = videoEncoder,
            orientationMode = orientationMode
        )

        // Delay engine start slightly so the service binding has time to complete
        // and the event sink gets connected before any events fire
        
        if (floatingOverlay) {
            overlayManager = FloatingOverlayManager(
                context = this,
                onPauseResume = {
                    if (isPaused) resumeRecording() else pauseRecording()
                },
                onStop = {
                    stopRecording()
                }
            )
        }

        handler.postDelayed({ startEngine(config) }, 300)

        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onDestroy() {
        disableDndMode()
        removeFloatingOverlay()
        stopTimerLoop()
        recordingEngine?.stop()
        if (shakeListener != null) {
            sensorManager?.unregisterListener(shakeListener)
            shakeListener = null
        }
        // Unregister the callback before stopping the projection
        if (projectionCallback != null) {
            mediaProjection?.unregisterCallback(projectionCallback!!)
            projectionCallback = null
        }
        mediaProjection?.stop()
        mediaProjection = null
        super.onDestroy()
    }

    private fun startEngine(config: RecordingConfig) {
        try {
            val engine = RecordingEngine(
                context         = this,
                mediaProjection = mediaProjection!!,
                config          = config,
                onStarted       = { path ->
                    startTimeMs = SystemClock.elapsedRealtime()
                    startTimerLoop()
                    sendEvent(mapOf("type" to "recording_started", "outputPath" to path))
                    handler.post { overlayManager?.show() }
                },
                onStopped       = { path ->
                    stopTimerLoop()
                    handler.post { overlayManager?.remove() }
                    exportToGallery(path)
                    sendEvent(mapOf("type" to "recording_stopped", "outputPath" to path))
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf()
                },
                onError         = { msg ->
                    Log.e(TAG, "Engine error: $msg")
                    sendEvent(mapOf("type" to "recording_error", "error" to msg))
                    handler.post { overlayManager?.remove() }
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf()
                }
            )
            recordingEngine = engine
            engine.start()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start engine", e)
            sendEvent(mapOf("type" to "recording_error", "error" to (e.message ?: "Start failed")))
            stopSelf()
        }
    }

    private fun exportToGallery(filePath: String) {
        val file = java.io.File(filePath)
        if (!file.exists()) return

        Thread {
            try {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                    val values = android.content.ContentValues().apply {
                        put(android.provider.MediaStore.Video.Media.DISPLAY_NAME, file.name)
                        put(android.provider.MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                        put(android.provider.MediaStore.Video.Media.RELATIVE_PATH, "Movies/GamerRec")
                        put(android.provider.MediaStore.Video.Media.IS_PENDING, 1)
                    }
                    val resolver = contentResolver
                    val uri = resolver.insert(android.provider.MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)
                    if (uri != null) {
                        resolver.openOutputStream(uri)?.use { outStream ->
                            file.inputStream().use { inStream ->
                                inStream.copyTo(outStream)
                            }
                        }
                        values.clear()
                        values.put(android.provider.MediaStore.Video.Media.IS_PENDING, 0)
                        resolver.update(uri, values, null, null)
                    }
                } else {
                    android.media.MediaScannerConnection.scanFile(
                        this, arrayOf(file.absolutePath), arrayOf("video/mp4"), null
                    )
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to export to gallery: ${e.message}")
            }
        }.start()
    }

    fun stopRecording() { recordingEngine?.stop() }

    fun pauseRecording() {
        if (!isPaused) {
            isPaused = true
            pauseStartMs = SystemClock.elapsedRealtime()
            recordingEngine?.pause()
            sendEvent(mapOf("type" to "recording_paused"))
            refreshNotification()
            overlayManager?.updatePausedState(true)
        }
    }

    fun resumeRecording() {
        if (isPaused) {
            pausedDurationMs += SystemClock.elapsedRealtime() - pauseStartMs
            isPaused = false
            recordingEngine?.resume()
            sendEvent(mapOf("type" to "recording_resumed"))
            refreshNotification()
            overlayManager?.updatePausedState(false)
        }
    }

    private val timerRunnable = object : Runnable {
        override fun run() {
            if (!isPaused) {
                val elapsedMs = SystemClock.elapsedRealtime() - startTimeMs - pausedDurationMs
                val sec = elapsedMs / 1000
                val mm  = (sec / 60).toString().padStart(2, '0')
                val ss  = (sec % 60).toString().padStart(2, '0')
                sendEvent(mapOf(
                    "type"          to "recording_progress",
                    "elapsedMs"     to elapsedMs,
                    "fileSizeBytes" to (recordingEngine?.currentFileSizeBytes ?: 0L)
                ))
                updateNotificationTime("$mm:$ss")
            }
            handler.postDelayed(this, 1000)
        }
    }

    private fun startTimerLoop() = handler.postDelayed(timerRunnable, 1000)
    private fun stopTimerLoop()  = handler.removeCallbacks(timerRunnable)

    private fun refreshNotification() {
        val elapsedMs = SystemClock.elapsedRealtime() - startTimeMs - pausedDurationMs
        val mm = (elapsedMs / 60000).toString().padStart(2, '0')
        val ss = ((elapsedMs / 1000) % 60).toString().padStart(2, '0')
        updateNotificationTime("$mm:$ss")
    }

    private fun updateNotificationTime(timeStr: String) {
        val notif = notifManager?.buildNotification(timeStr, isPaused) ?: return
        (getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager)
            .notify(RecordingNotificationManager.NOTIFICATION_ID, notif)
    }

    // Deliver pending events immediately when sink connects
    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
        if (sink != null && pendingEvents.isNotEmpty()) {
            val toDeliver = pendingEvents.toList()
            pendingEvents.clear()
            toDeliver.forEach { event ->
                handler.post { sink.success(event) }
            }
        }
    }

    private fun sendEvent(map: Map<String, Any?>) {
        handler.post {
            val sink = eventSink
            if (sink != null) {
                sink.success(map)
            } else {
                // Buffer until sink connects
                pendingEvents.add(map)
            }
        }
    }

    private fun enableDndMode() {
        val nm = getSystemService(android.app.NotificationManager::class.java)
        if (nm.isNotificationPolicyAccessGranted) {
            originalInterruptionFilter = nm.currentInterruptionFilter
            nm.setInterruptionFilter(android.app.NotificationManager.INTERRUPTION_FILTER_PRIORITY)
        } else {
            Log.w(TAG, "DND Mode enabled but notification policy access not granted")
        }
    }

    private fun disableDndMode() {
        if (dndModeEnabled) {
            val nm = getSystemService(android.app.NotificationManager::class.java)
            if (nm.isNotificationPolicyAccessGranted && originalInterruptionFilter != android.app.NotificationManager.INTERRUPTION_FILTER_UNKNOWN) {
                nm.setInterruptionFilter(originalInterruptionFilter)
            }
        }
    }

    @android.annotation.SuppressLint("ClickableViewAccessibility")
    private fun showFloatingOverlay() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M && android.provider.Settings.canDrawOverlays(this)) {
            windowManager = getSystemService(WINDOW_SERVICE) as android.view.WindowManager
            
            val imageView = android.widget.ImageView(this).apply {
                setImageResource(com.gamerrec.R.drawable.ic_recording_dot)
                setBackgroundColor(android.graphics.Color.argb(180, 0, 0, 0))
                setPadding(40, 40, 40, 40)
            }
            floatingView = imageView

            val params = android.view.WindowManager.LayoutParams(
                android.view.WindowManager.LayoutParams.WRAP_CONTENT,
                android.view.WindowManager.LayoutParams.WRAP_CONTENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    android.view.WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                else
                    @Suppress("DEPRECATION") android.view.WindowManager.LayoutParams.TYPE_PHONE,
                android.view.WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                android.graphics.PixelFormat.TRANSLUCENT
            )
            params.gravity = android.view.Gravity.TOP or android.view.Gravity.START
            params.x = 0
            params.y = 200

            var initialX = 0
            var initialY = 0
            var initialTouchX = 0f
            var initialTouchY = 0f
            var isMoved = false

            floatingView?.setOnTouchListener { view, event ->
                when (event.action) {
                    android.view.MotionEvent.ACTION_DOWN -> {
                        initialX = params.x
                        initialY = params.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        isMoved = false
                        true
                    }
                    android.view.MotionEvent.ACTION_MOVE -> {
                        val dx = (event.rawX - initialTouchX).toInt()
                        val dy = (event.rawY - initialTouchY).toInt()
                        if (Math.abs(dx) > 10 || Math.abs(dy) > 10) isMoved = true
                        params.x = initialX + dx
                        params.y = initialY + dy
                        windowManager?.updateViewLayout(floatingView, params)
                        true
                    }
                    android.view.MotionEvent.ACTION_UP -> {
                        if (!isMoved) {
                            view.performClick()
                        }
                        true
                    }
                    else -> false
                }
            }

            floatingView?.setOnClickListener {
                stopRecording()
            }

            windowManager?.addView(floatingView, params)
        } else {
            Log.w(TAG, "Floating overlay enabled but SYSTEM_ALERT_WINDOW not granted")
        }
    }

    private fun removeFloatingOverlay() {
        if (floatingView != null) {
            windowManager?.removeView(floatingView)
            floatingView = null
        }
    }
}