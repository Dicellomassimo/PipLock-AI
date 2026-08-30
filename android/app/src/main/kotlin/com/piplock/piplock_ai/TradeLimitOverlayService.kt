package com.piplock.piplock_ai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
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
import android.widget.LinearLayout
import android.widget.TextView

/**
 * TradeLimitOverlayService
 *
 * Overlay arancio in cima alla schermata (touch passthrough) mostrato quando
 * l'utente raggiunge il limite giornaliero di trade.
 * NON è un blocco completo: l'utente può ancora gestire le posizioni aperte.
 * Per rimuoverlo deve aprire PipLock e modificare i limiti.
 */
class TradeLimitOverlayService : Service() {

    companion object {
        private const val CHANNEL_ID = "piplock_trade_limit"
        // Channel name shown in Android Settings → App Notifications
        private const val NOTIF_ID   = 1002
        const val EXTRA_CURRENT_TRADES = "current_trades"
        const val EXTRA_MAX_TRADES     = "max_trades"

        var isRunning = false
            private set
        var instance: TradeLimitOverlayService? = null
            private set

        fun show(context: Context, currentTrades: Int, maxTrades: Int) {
            if (!Settings.canDrawOverlays(context)) return
            if (isRunning) return
            val intent = Intent(context, TradeLimitOverlayService::class.java).apply {
                putExtra(EXTRA_CURRENT_TRADES, currentTrades)
                putExtra(EXTRA_MAX_TRADES, maxTrades)
            }
            context.startForegroundService(intent)
        }

        fun hide(context: Context) {
            context.stopService(Intent(context, TradeLimitOverlayService::class.java))
        }
    }

    private var windowManager: WindowManager? = null
    private var overlayView: LinearLayout? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        instance  = this
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val current = intent?.getIntExtra(EXTRA_CURRENT_TRADES, 0) ?: 0
        val max     = intent?.getIntExtra(EXTRA_MAX_TRADES, 0) ?: 0

        startForeground(NOTIF_ID, buildNotification(current, max))

        if (!Settings.canDrawOverlays(this)) { stopSelf(); return START_NOT_STICKY }

        // Mostra solo se il broker è in foreground
        if (PipLockAccessibilityService.currentBrokerPackage != null) {
            showOverlay(current, max)
        }

        return START_NOT_STICKY
    }

    fun onBrokerFocused(current: Int, max: Int) {
        handler.post { showOverlay(current, max) }
    }

    fun onBrokerUnfocused() {
        handler.post { hideOverlayKeepRunning() }
    }

    private fun showOverlay(current: Int, max: Int) {
        if (overlayView != null) return
        if (!Settings.canDrawOverlays(this)) return
        if (PipLockAccessibilityService.currentBrokerPackage == null) return

        val ctx = this
        val root = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity     = Gravity.CENTER_VERTICAL
            setBackgroundColor(Color.parseColor("#F0B45309"))  // arancio scuro
            setPadding(40, 20, 40, 20)
        }

        val icon = TextView(ctx).apply {
            text     = "🚫"
            textSize = 22f
            setPadding(0, 0, 20, 0)
        }

        val col = LinearLayout(ctx).apply {
            orientation  = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }

        val title = TextView(ctx).apply {
            text      = "Trade limit reached ($current/$max)"
            textSize  = 13f
            setTextColor(Color.WHITE)
            setTypeface(null, Typeface.BOLD)
        }

        val sub = TextView(ctx).apply {
            text     = "Manage your open positions. Open PipLock to adjust your limits."
            textSize = 11f
            setTextColor(Color.parseColor("#FFDDBB"))
        }

        col.addView(title)
        col.addView(sub)

        val btn = Button(ctx).apply {
            text     = "PipLock"
            textSize = 12f
            setTextColor(Color.parseColor("#0A0A0A"))
            setBackgroundColor(Color.parseColor("#FFD070"))
            setPadding(28, 16, 28, 16)
            setTypeface(null, Typeface.BOLD)
            setOnClickListener { openPipLock() }
        }

        root.addView(icon)
        root.addView(col)
        root.addView(btn)
        overlayView = root

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.TOP or Gravity.START }

        try {
            windowManager?.addView(root, params)
        } catch (e: Exception) {
            overlayView = null
        }
    }

    private fun hideOverlayKeepRunning() {
        overlayView?.let {
            try { windowManager?.removeView(it) } catch (_: Exception) {}
            overlayView = null
        }
    }

    private fun openPipLock() {
        packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            startActivity(this)
        }
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID, "PipLock — Trade Limit", NotificationManager.IMPORTANCE_LOW
        )
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
            .createNotificationChannel(channel)
    }

    private fun buildNotification(current: Int, max: Int): Notification {
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("PipLock — Trade limit reached")
            .setContentText("You reached the limit ($current/$max). Open PipLock to adjust.")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setOngoing(true)
            .build()
    }

    override fun onDestroy() {
        isRunning = false
        instance  = null
        hideOverlayKeepRunning()
        super.onDestroy()
    }
}
