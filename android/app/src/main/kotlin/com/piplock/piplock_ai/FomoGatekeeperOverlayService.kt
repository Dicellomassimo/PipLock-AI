package com.piplock.piplock_ai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

/**
 * FomoGatekeeperOverlayService
 *
 * Shows a dismissible semi-transparent overlay on top of MT5/cTrader when a
 * behavioural warning pattern is detected (FOMO, revenge trading, overleveraging,
 * overtrading). Unlike KillswitchOverlayService (full block), this overlay:
 * - Is semi-transparent (MT5 still visible underneath)
 * - Auto-dismisses after AUTO_DISMISS_SECONDS
 * - Has an X button in the top-right corner for immediate dismissal
 * - Shows a standalone notification in addition to the foreground service notification
 *
 * Supported triggers:
 *   fomo, new_pos_after_move, fast_entry, low_readiness,
 *   revenge_trading, overleveraging, overtrading
 */
class FomoGatekeeperOverlayService : Service() {

    companion object {
        private const val CHANNEL_ID = "piplock_fomo_gatekeeper"
        private const val NOTIF_ID = 1002
        private const val STANDALONE_NOTIF_ID = 2002
        const val EXTRA_TRIGGER = "trigger"
        private const val AUTO_DISMISS_SECONDS = 20

        var isRunning = false
            private set

        fun show(context: Context, trigger: String = "fast_entry") {
            if (!Settings.canDrawOverlays(context)) return
            if (isRunning) return // do not stack two FOMO overlays
            val intent = Intent(context, FomoGatekeeperOverlayService::class.java).apply {
                putExtra(EXTRA_TRIGGER, trigger)
            }
            context.startForegroundService(intent)
        }

        fun hide(context: Context) {
            context.stopService(Intent(context, FomoGatekeeperOverlayService::class.java))
        }
    }

    private var windowManager: WindowManager? = null
    private var overlayView: FrameLayout? = null
    private var trigger: String = "fast_entry"
    private val handler = Handler(Looper.getMainLooper())
    private val autoDismissRunnable = Runnable { stopSelf() }

    // Countdown hint runnable
    private var remainingSeconds = AUTO_DISMISS_SECONDS
    private var countdownTextView: TextView? = null
    private val countdownRunnable = object : Runnable {
        override fun run() {
            remainingSeconds--
            countdownTextView?.text = "Closes automatically in ${remainingSeconds}s"
            if (remainingSeconds > 0) handler.postDelayed(this, 1000L)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        trigger = intent?.getStringExtra(EXTRA_TRIGGER) ?: "fast_entry"
        startForeground(NOTIF_ID, buildForegroundNotification())

        // Post a standalone (non-ongoing) notification for the notification shade
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(STANDALONE_NOTIF_ID, buildStandaloneNotification())

        if (Settings.canDrawOverlays(this)) {
            showOverlay()
            remainingSeconds = AUTO_DISMISS_SECONDS
            handler.postDelayed(autoDismissRunnable, AUTO_DISMISS_SECONDS * 1000L)
            handler.postDelayed(countdownRunnable, 1000L)
        } else {
            stopSelf()
        }

        return START_NOT_STICKY
    }

    // ──────────────────────────────────────────────────────────────
    // Overlay UI
    // ──────────────────────────────────────────────────────────────

    private fun showOverlay() {
        if (overlayView != null) return

        val frame = buildLayout()
        overlayView = frame

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }

        try {
            windowManager?.addView(frame, params)
        } catch (e: Exception) {
            overlayView = null
            stopSelf()
        }
    }

    private fun buildLayout(): FrameLayout {
        val ctx = this

        // Root FrameLayout — holds content LinearLayout + X button on top
        val frame = FrameLayout(ctx)

        // ── Content LinearLayout ──────────────────────────────────
        val root = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setBackgroundColor(backgroundColorForTrigger(trigger))
            setPadding(64, 52, 64, 52)
        }

        // Title
        val title = TextView(ctx).apply {
            text = titleForTrigger(trigger)
            textSize = 18f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setTypeface(null, Typeface.BOLD)
            letterSpacing = 0.06f
            setPadding(0, 12, 0, 6)
        }

        // Main message
        val message = TextView(ctx).apply {
            text = messageForTrigger(trigger)
            textSize = 14f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 12)
        }

        // Secondary question (smaller, grey)
        val question = TextView(ctx).apply {
            text = questionForTrigger(trigger)
            textSize = 12f
            setTextColor(Color.parseColor("#AAAAAA"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 28)
        }

        // Divider
        val divider = android.view.View(ctx).apply {
            setBackgroundColor(Color.parseColor("#33FFFFFF"))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 1
            ).also { it.bottomMargin = 28 }
        }

        // Button row
        val btnRow = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }

        val btnYes = Button(ctx).apply {
            text = "Yes, it's valid"
            textSize = 12f
            setTextColor(Color.WHITE)
            setBackgroundColor(lighterColorForTrigger(trigger))
            setPadding(36, 18, 36, 18)
            setTypeface(null, Typeface.BOLD)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { marginEnd = 20 }
            setOnClickListener { stopSelf() }
        }

        val btnWait = Button(ctx).apply {
            text = "I'll wait"
            textSize = 12f
            setTextColor(Color.parseColor("#0A0A0A"))
            setBackgroundColor(Color.parseColor("#E0E0E0"))
            setPadding(36, 18, 36, 18)
            setTypeface(null, Typeface.BOLD)
            setOnClickListener { stopSelf() }
        }

        btnRow.addView(btnYes)
        btnRow.addView(btnWait)

        // Countdown hint — updated every second
        val hint = TextView(ctx).apply {
            text = "Closes automatically in ${AUTO_DISMISS_SECONDS}s"
            textSize = 10f
            setTextColor(Color.parseColor("#888888"))
            gravity = Gravity.CENTER
            setPadding(0, 16, 0, 0)
        }
        countdownTextView = hint

        root.addView(title)
        root.addView(message)
        root.addView(question)
        root.addView(divider)
        root.addView(btnRow)
        root.addView(hint)

        // ── X (close) button — top-right corner ──────────────────
        val closeBtn = TextView(ctx).apply {
            text = "✕"
            textSize = 20f
            setTextColor(Color.WHITE)
            setPadding(32, 24, 32, 24)
            setOnClickListener { stopSelf() }
        }
        val closeLp = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.TOP or Gravity.END
        )
        closeBtn.layoutParams = closeLp

        frame.addView(root)
        frame.addView(closeBtn)

        return frame
    }

    // ──────────────────────────────────────────────────────────────
    // Trigger-specific content helpers
    // ──────────────────────────────────────────────────────────────

    private fun backgroundColorForTrigger(t: String): Int = when (t) {
        "revenge_trading" -> Color.parseColor("#E87F2200")
        "overleveraging"  -> Color.parseColor("#E87F0000")
        "overtrading"     -> Color.parseColor("#E85F3800")
        else              -> Color.parseColor("#E8280050") // fomo / fast_entry / new_pos_after_move / low_readiness
    }

    private fun lighterColorForTrigger(t: String): Int = when (t) {
        "revenge_trading" -> Color.parseColor("#BF6000")
        "overleveraging"  -> Color.parseColor("#BF2000")
        "overtrading"     -> Color.parseColor("#9F5000")
        else              -> Color.parseColor("#3D2060")
    }

    private fun titleForTrigger(t: String): String = when (t) {
        "low_readiness"   -> "\uD83D\uDE14  LOW READINESS ALERT"
        "revenge_trading" -> "\uD83D\uDD04  REVENGE TRADING"
        "overleveraging"  -> "\u26A1  OVERLEVERAGING"
        "overtrading"     -> "\uD83D\uDCCA  OVERTRADING"
        else              -> "⚠️  FOMO ALERT" // fomo / fast_entry / new_pos_after_move
    }

    private fun messageForTrigger(t: String): String = when (t) {
        "new_pos_after_move" -> "You opened a position right after a sudden equity move. Was this planned?"
        "fast_entry"         -> "Rapid entry detected. Do you have a valid setup for this trade?"
        "low_readiness"      -> "Your readiness score is low today. Is this trade planned or emotional?"
        "revenge_trading"    -> "New trade within 5 min of a loss. Is this revenge trading?"
        "overleveraging"     -> "Your open loss is consuming over 50% of your daily risk limit."
        "overtrading"        -> "3+ positions opened in 60 seconds. Are you following your plan?"
        else                 -> "Possible FOMO entry detected."
    }

    private fun questionForTrigger(t: String): String = when (t) {
        "revenge_trading" -> "Are you trading on a valid setup, not trying to recover a loss?"
        "overleveraging"  -> "Is your position size within your risk plan?"
        "overtrading"     -> "Are you following your trading plan or acting on impulse?"
        else              -> "Was this setup planned before the market moved?"
    }

    // ──────────────────────────────────────────────────────────────
    // Notifications
    // ──────────────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "PipLock Behavioural Warnings",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Preventive alerts: FOMO, revenge trading, overleveraging, overtrading"
        }
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
            .createNotificationChannel(channel)
    }

    /** Foreground service notification (ongoing, required by Android 8+). */
    private fun buildForegroundNotification(): Notification {
        val openIntent = PendingIntent.getActivity(
            this, 0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE
        )
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle(notifTitleForTrigger(trigger))
            .setContentText(notifTextForTrigger(trigger))
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentIntent(openIntent)
            .setAutoCancel(false)
            .setOngoing(true)
            .build()
    }

    /** Standalone alert notification (auto-cancel, non-ongoing). */
    private fun buildStandaloneNotification(): Notification {
        val openIntent = PendingIntent.getActivity(
            this, 1,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE
        )
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle(notifTitleForTrigger(trigger))
            .setContentText(notifTextForTrigger(trigger))
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentIntent(openIntent)
            .setAutoCancel(true)
            .setOngoing(false)
            .build()
    }

    private fun notifTitleForTrigger(t: String): String = when (t) {
        "low_readiness"   -> "PipLock — Low Readiness"
        "revenge_trading" -> "PipLock — Revenge Trading Alert"
        "overleveraging"  -> "PipLock — Overleveraging Alert"
        "overtrading"     -> "PipLock — Overtrading Alert"
        else              -> "PipLock — FOMO Alert"
    }

    private fun notifTextForTrigger(t: String): String = when (t) {
        "new_pos_after_move" -> "Position opened after a sudden equity move. Was it planned?"
        "fast_entry"         -> "Rapid entry detected. Check your setup."
        "low_readiness"      -> "Your readiness score is low today. Trade with caution."
        "revenge_trading"    -> "New trade within 5 min of a loss. Confirm your setup."
        "overleveraging"     -> "Open loss > 50% of your daily risk limit."
        "overtrading"        -> "3+ trades in 60 seconds — are you following your plan?"
        else                 -> "Possible FOMO entry detected. Verify your setup."
    }

    // ──────────────────────────────────────────────────────────────
    // Cleanup
    // ──────────────────────────────────────────────────────────────

    private fun hideOverlay() {
        handler.removeCallbacks(autoDismissRunnable)
        handler.removeCallbacks(countdownRunnable)
        countdownTextView = null
        overlayView?.let {
            try { windowManager?.removeView(it) } catch (_: Exception) {}
            overlayView = null
        }
    }

    override fun onDestroy() {
        isRunning = false
        hideOverlay()
        super.onDestroy()
    }
}
