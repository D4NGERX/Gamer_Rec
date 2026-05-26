package com.gamerrec.recording

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.provider.Settings

class FloatingOverlayManager(
    private val context: Context,
    private val onPauseResume: () -> Unit,
    private val onStop: () -> Unit
) {
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var isPaused = false

    fun show() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(context)) {
            return
        }

        windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val container = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            setBackgroundColor(Color.parseColor("#80000000")) // Semi-transparent black
            setPadding(16, 16, 16, 16)
            elevation = 10f
        }

        // Pause/Resume Button
        val pauseBtn = ImageView(context).apply {
            setImageResource(android.R.drawable.ic_media_pause)
            setColorFilter(Color.WHITE)
            setPadding(8, 8, 8, 8)
            setOnClickListener {
                onPauseResume()
            }
        }

        // Stop Button
        val stopBtn = ImageView(context).apply {
            setImageResource(android.R.drawable.ic_media_play) // Actually stop icon is not always there, use ic_menu_close_clear_cancel
            setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
            setColorFilter(Color.RED)
            setPadding(8, 8, 8, 8)
            setOnClickListener {
                onStop()
            }
        }

        container.addView(pauseBtn)
        container.addView(stopBtn)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP or Gravity.START
        params.x = 0
        params.y = 200

        // Make it draggable
        container.setOnTouchListener(object : View.OnTouchListener {
            private var initialX = 0
            private var initialY = 0
            private var initialTouchX = 0f
            private var initialTouchY = 0f

            override fun onTouch(v: View, event: MotionEvent): Boolean {
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = params.x
                        initialY = params.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        params.x = initialX + (event.rawX - initialTouchX).toInt()
                        params.y = initialY + (event.rawY - initialTouchY).toInt()
                        windowManager?.updateViewLayout(overlayView, params)
                        return true
                    }
                }
                return false
            }
        })

        overlayView = container
        windowManager?.addView(overlayView, params)
    }

    fun updatePausedState(paused: Boolean) {
        isPaused = paused
        // Find the pause button and update its icon
        val container = overlayView as? LinearLayout ?: return
        if (container.childCount > 0) {
            val pauseBtn = container.getChildAt(0) as? ImageView
            if (paused) {
                pauseBtn?.setImageResource(android.R.drawable.ic_media_play)
            } else {
                pauseBtn?.setImageResource(android.R.drawable.ic_media_pause)
            }
        }
    }

    fun remove() {
        if (overlayView != null) {
            windowManager?.removeView(overlayView)
            overlayView = null
        }
    }
}
