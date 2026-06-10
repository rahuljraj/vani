package com.vani.vani

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import androidx.core.app.ServiceCompat
import kotlin.math.abs

/**
 * Floating launcher bubble (Labs feature, default OFF).
 *
 * A draggable always-on-top button that opens VANI in auto-listen mode —
 * the same EXTRA_AUTO_LISTEN one-shot the Quick Settings tile uses, so the
 * shipped instant-listen path is reused, not modified. The QS tile remains
 * the default launcher; this is additive and opt-in.
 *
 * Requires SYSTEM_ALERT_WINDOW (user grants in settings) and runs as a
 * special-use foreground service. Both need Play declarations — see
 * docs/play-bubble-permissions.md. Survival under OxygenOS battery
 * management is ⏳ UNVERIFIED (docs/future-device-checklist.md).
 */
class VaniBubbleService : Service() {

    companion object {
        @Volatile
        var isRunning = false
            private set

        private const val NOTIF_ID = 1101
        private const val CHANNEL_ID = "vani_bubble"
        private const val PREFS = "vani_bubble"

        // Finger movement below this (in px) counts as a tap, not a drag.
        private const val CLICK_SLOP_PX = 14f
    }

    private var windowManager: WindowManager? = null
    private var bubbleView: ImageView? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startAsForeground()
        if (!Settings.canDrawOverlays(this)) {
            // Permission revoked after the toggle was flipped → bail out
            // gracefully; Dart sees isRunning=false and resets the flag.
            stopSelf()
            return
        }
        addBubble()
        isRunning = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onDestroy() {
        removeBubble()
        isRunning = false
        super.onDestroy()
    }

    private fun startAsForeground() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID, "VANI bubble", NotificationManager.IMPORTANCE_MIN
            ).apply { description = "Floating bubble status" }
        )

        val tapIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE
        )

        val notification = Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_vani_tile)
            .setContentTitle("VANI bubble on hai")
            .setContentText("Band karne ke liye VANI → Labs → toggle off.")
            .setContentIntent(tapIntent)
            .setOngoing(true)
            .build()

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE else 0
        ServiceCompat.startForeground(this, NOTIF_ID, notification, type)
    }

    private fun addBubble() {
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val density = resources.displayMetrics.density

        val view = ImageView(this).apply {
            setImageResource(R.drawable.ic_vani_tile)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(0xE61A1A1A.toInt())          // dark surface
                setStroke((2 * density).toInt(), 0xFF6C63FF.toInt()) // accent ring
            }
            val pad = (12 * density).toInt()
            setPadding(pad, pad, pad, pad)
            contentDescription = "VANI"
        }

        val size = (56 * density).toInt()
        val params = WindowManager.LayoutParams(
            size, size,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = prefs.getInt("x", 0)
            y = prefs.getInt("y", (200 * density).toInt())
        }

        view.setOnTouchListener(DragTapListener(prefs, params, view))
        windowManager?.addView(view, params)
        bubbleView = view
    }

    private fun removeBubble() {
        bubbleView?.let { view ->
            try {
                windowManager?.removeView(view)
            } catch (_: Exception) {
                // View already gone (e.g. permission revoked) — nothing to do.
            }
        }
        bubbleView = null
    }

    /** Drag to move (position persisted); a near-stationary touch is a tap. */
    private inner class DragTapListener(
        private val prefs: SharedPreferences,
        private val params: WindowManager.LayoutParams,
        private val view: ImageView,
    ) : View.OnTouchListener {
        private var startX = 0
        private var startY = 0
        private var touchX = 0f
        private var touchY = 0f

        override fun onTouch(v: View, event: MotionEvent): Boolean {
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    startX = params.x
                    startY = params.y
                    touchX = event.rawX
                    touchY = event.rawY
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    params.x = startX + (event.rawX - touchX).toInt()
                    params.y = startY + (event.rawY - touchY).toInt()
                    windowManager?.updateViewLayout(view, params)
                    return true
                }
                MotionEvent.ACTION_UP -> {
                    val moved = abs(event.rawX - touchX) > CLICK_SLOP_PX ||
                                abs(event.rawY - touchY) > CLICK_SLOP_PX
                    if (moved) {
                        prefs.edit().putInt("x", params.x).putInt("y", params.y).apply()
                    } else {
                        v.performClick()
                        launchVani()
                    }
                    return true
                }
            }
            return false
        }
    }

    private fun launchVani() {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(MainActivity.EXTRA_AUTO_LISTEN, true)
        }
        // Overlay-permission holders are exempt from Android 10+ background
        // activity-start restrictions, so this works from the service.
        startActivity(intent)
    }
}
