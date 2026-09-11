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
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * KillswitchOverlayService — 2-PHASE FLOW
 *
 * PHASE 1 — WARNING:
 *   - Dark-red panel at the top, partial height
 *   - Touches PASS THROUGH to MT5 (FLAG_NOT_TOUCH_MODAL)
 *   - 60-second countdown: "Close your losing positions. Killswitch activates in Xs."
 *   - Button: "I closed my positions — Activate Killswitch" → immediately moves to PHASE 2
 *   - When countdown expires → automatically moves to PHASE 2
 *
 * PHASE 2 — LOCKDOWN:
 *   - Overlay is hidden; PipLock is brought to foreground showing the premium KillswitchScreen.
 *   - The premium Flutter screen handles countdown, token unlock, and "Exit MT5".
 *
 * The overlay is BROKER-SPECIFIC: appears only when MT5/cTrader is in foreground,
 * hides when returning to PipLock or the home screen.
 */
class KillswitchOverlayService : Service() {

    // ── Fasi ──────────────────────────────────────────────────────────────────

    private enum class Phase { WARNING, LOCKDOWN }

    companion object {
        private const val CHANNEL_ID = "piplock_killswitch"
        private const val NOTIF_ID   = 1001
        const val EXTRA_DURATION_MINUTES  = "duration_minutes"
        const val EXTRA_REASON            = "reason"
        const val ACTION_OPEN_PIPLOCK     = "com.piplock.KILLSWITCH_OPEN_PIPLOCK"
        const val ACTION_USE_TOKEN_REQUEST = "com.piplock.KILLSWITCH_USE_TOKEN"

        /** Secondi di avviso prima del blocco totale. */
        private const val WARNING_SECONDS = 60

        var isRunning = false
            private set

        var instance: KillswitchOverlayService? = null
            private set

        var isOverlayVisible = false
            private set

        // ── Avvia sempre dalla FASE AVVISO (mostra sempre il warning da 60s) ──

        fun show(context: Context, durationMinutes: Int, reason: String = "daily_loss") {
            if (!Settings.canDrawOverlays(context)) return
            if (isRunning) return
            startService(context, durationMinutes, reason, skipWarning = false)
        }

        // ── Avvia dalla FASE AVVISO (trigger nativo dalla AccessibilityService) ──

        fun showWithWarning(context: Context, durationMinutes: Int, reason: String = "daily_loss") {
            if (!Settings.canDrawOverlays(context)) return
            if (isRunning) return
            startService(context, durationMinutes, reason, skipWarning = false)
        }

        /**
         * Blocco orari di trading: fase di avviso 60s (per chiudere i trade),
         * poi lockdown fino all'apertura del mercato.
         */
        fun showTradingHoursBlock(context: Context, minutesUntilStart: Int) {
            if (!Settings.canDrawOverlays(context)) return
            if (isRunning) return
            startService(context, minutesUntilStart, "trading_hours", skipWarning = false)
        }

        fun hide(context: Context) {
            context.stopService(Intent(context, KillswitchOverlayService::class.java))
        }

        private fun startService(
            context: Context,
            durationMinutes: Int,
            reason: String,
            skipWarning: Boolean
        ) {
            val intent = Intent(context, KillswitchOverlayService::class.java).apply {
                putExtra(EXTRA_DURATION_MINUTES, durationMinutes)
                putExtra(EXTRA_REASON, reason)
                putExtra("skip_warning", skipWarning)
            }
            context.startForegroundService(intent)
        }
    }

    // ── Stato interno ─────────────────────────────────────────────────────────

    private var windowManager: WindowManager? = null
    private var overlayView: LinearLayout? = null
    private var countdownTextView: TextView? = null
    private val handler = Handler(Looper.getMainLooper())

    @Volatile private var phase: Phase = Phase.WARNING
    @Volatile private var endTimeMillis: Long = 0          // scadenza killswitch reale (LOCKDOWN)
    @Volatile private var warningEndMillis: Long = 0       // scadenza avviso (WARNING)
    private var reason: String = "daily_loss"

    /**
     * Permesso esplicito di mostrare l'overlay.
     * Diventa true SOLO quando il broker torna in foreground (onBrokerFocused).
     * Viene azzerato quando l'utente apre PipLock — garantisce che l'overlay
     * non riappaia su PipLock anche in presenza di race condition.
     * AtomicBoolean per sicurezza in caso di letture da thread diversi.
     */
    private val overlayAllowed = AtomicBoolean(false)

    // ── Service lifecycle ─────────────────────────────────────────────────────

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        instance  = this
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val minutes     = intent?.getIntExtra(EXTRA_DURATION_MINUTES, 360) ?: 360
        reason          = intent?.getStringExtra(EXTRA_REASON) ?: "daily_loss"
        val skipWarning = intent?.getBooleanExtra("skip_warning", false) ?: false

        endTimeMillis    = System.currentTimeMillis() + minutes * 60 * 1000L
        warningEndMillis = System.currentTimeMillis() + WARNING_SECONDS * 1000L

        phase = if (skipWarning) Phase.LOCKDOWN else Phase.WARNING

        startForeground(NOTIF_ID, buildNotification())

        if (!Settings.canDrawOverlays(this)) { stopSelf(); return START_NOT_STICKY }

        if (PipLockAccessibilityService.currentBrokerPackage != null) {
            overlayAllowed.set(true)
            showOverlayIfNeeded()
        }

        return START_NOT_STICKY
    }

    // ── API pubblica (chiamata da PipLockAccessibilityService) ────────────────

    fun onBrokerFocused() {
        handler.post {
            // Il broker è tornato in foreground: ora è sicuro mostrare l'overlay.
            overlayAllowed.set(true)
            showOverlayIfNeeded()
        }
    }

    fun onBrokerUnfocused(foregroundPackage: String = "") {
        handler.post {
            if (phase == Phase.LOCKDOWN) {
                // During LOCKDOWN the overlay must stay permanently visible on MT5.
                // The only case where we hide it is when the user deliberately opens
                // PipLock (to use the token). Every other app — home screen, dialogs,
                // keyboard, notifications — keeps the overlay in place.
                if (foregroundPackage != packageName) return@post
            }
            overlayAllowed.set(false)
            hideOverlayKeepRunning()
        }
    }

    // ── Overlay — mostra/nasconde ─────────────────────────────────────────────

    private fun showOverlayIfNeeded() {
        if (overlayView != null) return
        if (!Settings.canDrawOverlays(this)) return
        // Doppio controllo: flag esplicito + stato accessibilità.
        // overlayAllowed è false finché onBrokerFocused() non viene chiamato,
        // quindi l'overlay non può MAI apparire su PipLock o qualsiasi altra app.
        if (!overlayAllowed.get()) return
        if (PipLockAccessibilityService.currentBrokerPackage == null) return

        val layout = when (phase) {
            Phase.WARNING  -> buildWarningLayout()
            Phase.LOCKDOWN -> buildLockdownLayout()
        }
        overlayView = layout

        val params = buildLayoutParams(phase)
        try {
            isOverlayVisible = true
            windowManager?.addView(layout, params)
            // Gesture di navigazione sistema (swipe su per home, swipe laterali per back)
            // devono passare SEMPRE attraverso l'overlay — l'utente deve poter uscire da MT5.
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                layout.systemGestureExclusionRects = emptyList()
            }
            handler.removeCallbacks(tickRunnable)
            handler.post(tickRunnable)
        } catch (e: Exception) {
            isOverlayVisible = false
            overlayView = null
            stopSelf()
        }
    }

    private fun hideOverlayKeepRunning() {
        overlayView?.let {
            try { windowManager?.removeView(it) } catch (_: Exception) {}
            overlayView = null
            countdownTextView = null
        }
        isOverlayVisible = false
        handler.removeCallbacks(tickRunnable)
    }

    /** Warning phase expired or user confirmed → show full-screen LOCKDOWN overlay on MT5. */
    private fun transitionToLockdown() {
        hideOverlayKeepRunning()
        phase = Phase.LOCKDOWN
        // Update notification
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_ID, buildNotification())
        // Show the full-screen Kotlin overlay that physically blocks MT5.
        // overlayAllowed is still true here (broker is in foreground).
        showOverlayIfNeeded()
    }

    // ── WindowManager params ──────────────────────────────────────────────────

    private fun buildLayoutParams(p: Phase): WindowManager.LayoutParams {
        return when (p) {
            Phase.WARNING -> WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                // FLAG_NOT_TOUCH_MODAL: i tocchi fuori dal pannello passano a MT5
                // L'utente può ancora interagire con MT5 per chiudere posizioni
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.START  // ← era BOTTOM, ora TOP
            }

            Phase.LOCKDOWN -> WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.FILL
            }
        }
    }

    // ── Layout FASE 1 — AVVISO ────────────────────────────────────────────────

    private fun buildWarningLayout(): LinearLayout {
        val isTradingHours = reason == "trading_hours"
        return if (isTradingHours) buildTradingHoursWarningLayout()
               else               buildKillswitchWarningLayout()
    }

    /** Warning overlay for trading hours end — premium black/silver palette */
    private fun buildTradingHoursWarningLayout(): LinearLayout {
        val ctx = this

        val root = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            gravity     = Gravity.CENTER_HORIZONTAL
            background  = android.graphics.drawable.GradientDrawable(
                android.graphics.drawable.GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(Color.parseColor("#F2080C14"), Color.parseColor("#F21C2030"))
            )
            setPadding(56, 36, 56, 52)
        }

        // Top row: icon + text + countdown
        val topRow = LinearLayout(ctx).apply {
            orientation  = LinearLayout.HORIZONTAL
            gravity      = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        val clockEmoji = TextView(ctx).apply {
            text    = "🕐"
            textSize = 28f
            setPadding(0, 0, 20, 0)
            gravity = Gravity.CENTER_VERTICAL
        }

        val textCol = LinearLayout(ctx).apply {
            orientation  = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }

        textCol.addView(TextView(ctx).apply {
            text          = "TRADING SESSION ENDED"
            textSize      = 13f
            setTextColor(Color.WHITE)
            setTypeface(null, Typeface.BOLD)
            letterSpacing = 0.06f
        })
        textCol.addView(TextView(ctx).apply {
            text     = "Close all open positions now"
            textSize = 11f
            setTextColor(Color.parseColor("#A0B8C8"))
        })

        val warningCountdown = TextView(ctx).apply {
            text     = "$WARNING_SECONDS"
            textSize = 28f
            setTextColor(Color.parseColor("#B0BEC5"))  // silver
            typeface  = Typeface.MONOSPACE
            gravity   = Gravity.END or Gravity.CENTER_VERTICAL
            setPadding(16, 0, 0, 0)
        }
        countdownTextView = warningCountdown

        topRow.addView(clockEmoji)
        topRow.addView(textCol)
        topRow.addView(warningCountdown)
        root.addView(topRow)

        // Instructions
        root.addView(TextView(ctx).apply {
            text     = "MT5 will be locked in the seconds shown ↗\nClose positions before time runs out."
            textSize = 12f
            setTextColor(Color.parseColor("#80B0C0D0"))
            gravity  = Gravity.CENTER_HORIZONTAL
            setPadding(0, 24, 0, 24)
        })

        // Confirm button — silver/dark style
        root.addView(Button(ctx).apply {
            text     = "✓  I've closed all positions — lock now"
            textSize = 13f
            setTextColor(Color.parseColor("#0A0C10"))
            background = android.graphics.drawable.GradientDrawable().apply {
                shape        = android.graphics.drawable.GradientDrawable.RECTANGLE
                cornerRadius = 28f
                setColor(Color.parseColor("#B0BEC5"))  // silver
            }
            setPadding(48, 28, 48, 28)
            setTypeface(null, Typeface.BOLD)
            letterSpacing = 0.02f
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            setOnClickListener { transitionToLockdown() }
        })

        return root
    }

    /** Warning overlay for killswitch — existing red palette */
    private fun buildKillswitchWarningLayout(): LinearLayout {
        val ctx = this

        val root = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            gravity     = Gravity.CENTER_HORIZONTAL
            setBackgroundColor(Color.parseColor("#F0B71C1C"))  // rosso scuro, semi-trasparente
            setPadding(56, 36, 56, 52)
        }

        // Riga: icona avviso + testo principale
        val topRow = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity     = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        val warningEmoji = TextView(ctx).apply {
            text     = "⚠️"
            textSize = 30f
            setPadding(0, 0, 20, 0)
            gravity  = Gravity.CENTER_VERTICAL
        }

        val textCol = LinearLayout(ctx).apply {
            orientation  = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }

        val titleWarn = TextView(ctx).apply {
            text     = "LIMIT REACHED — WARNING"
            textSize = 14f
            setTextColor(Color.WHITE)
            setTypeface(null, Typeface.BOLD)
            letterSpacing = 0.05f
        }

        val subtitleWarn = TextView(ctx).apply {
            text     = reasonLabel(reason)
            textSize = 12f
            setTextColor(Color.parseColor("#FF9999"))
        }

        textCol.addView(titleWarn)
        textCol.addView(subtitleWarn)

        // Countdown avviso (XX secondi)
        val warningCountdown = TextView(ctx).apply {
            text     = "$WARNING_SECONDS"
            textSize = 28f
            setTextColor(Color.parseColor("#FFD700"))
            typeface = Typeface.MONOSPACE
            gravity  = Gravity.END or Gravity.CENTER_VERTICAL
            setPadding(16, 0, 0, 0)
        }
        countdownTextView = warningCountdown

        topRow.addView(warningEmoji)
        topRow.addView(textCol)
        topRow.addView(warningCountdown)
        root.addView(topRow)

        // Messaggio istruzioni
        val instrMsg = TextView(ctx).apply {
            text     = "Close your LOSING positions. You may keep profitable ones.\n" +
                       "Full MT5 lockdown activates in the seconds shown ↗"
            textSize = 13f
            setTextColor(Color.parseColor("#FFDDAA"))
            gravity  = Gravity.CENTER_HORIZONTAL
            setPadding(0, 24, 0, 24)
        }
        root.addView(instrMsg)

        // Bottone conferma chiusura
        val confirmBtn = Button(ctx).apply {
            text     = "✓  I closed my losing positions"
            textSize = 14f
            setTextColor(Color.parseColor("#0A0A0A"))
            setBackgroundColor(Color.parseColor("#00E5CC"))
            setPadding(48, 28, 48, 28)
            setTypeface(null, Typeface.BOLD)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            setOnClickListener { transitionToLockdown() }
        }
        root.addView(confirmBtn)

        return root
    }


    // ── Layout PHASE 2 — FULL-SCREEN LOCKDOWN ────────────────────────────────

    private fun buildLockdownLayout(): LinearLayout {
        val ctx = this
        val density = resources.displayMetrics.density
        fun dp(v: Int) = (v * density).toInt()

        // Root is TRANSPARENT — topSpacer lets the MT5 account switcher show through
        val root = LinearLayout(ctx).apply {
            orientation  = LinearLayout.VERTICAL
            setBackgroundColor(Color.TRANSPARENT)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.MATCH_PARENT
            )
        }

        // Content area carries the gradient background and all visible UI
        // Trading hours: dark navy; Killswitch: dark red
        val bgTop    = if (reason == "trading_hours") "#00050F" else "#0D0000"
        val bgBottom = if (reason == "trading_hours") "#0A1020" else "#1A0000"
        val contentLayout = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            gravity     = Gravity.CENTER_HORIZONTAL
            background  = android.graphics.drawable.GradientDrawable(
                android.graphics.drawable.GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(Color.parseColor(bgTop), Color.parseColor(bgBottom))
            )
            setPadding(dp(28), 0, dp(28), 0)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f
            )
        }

        fun spacer(weight: Float) = View(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(1, 0, weight)
        }
        fun hairline() = View(ctx).apply {
            setBackgroundColor(Color.parseColor("#20FFFFFF"))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(1)
            ).also { it.topMargin = dp(20); it.bottomMargin = dp(20) }
        }

        contentLayout.addView(spacer(1f))

        // ── Icon ──────────────────────────────────────────────────────────────
        contentLayout.addView(TextView(ctx).apply {
            text     = if (reason == "trading_hours") "🕐" else "🔒"
            textSize = 48f
            gravity  = Gravity.CENTER_HORIZONTAL
        })

        // ── Title ─────────────────────────────────────────────────────────────
        contentLayout.addView(TextView(ctx).apply {
            text          = if (reason == "trading_hours") "TRADING HOURS BLOCK" else "KILLSWITCH ACTIVE"
            textSize      = 20f
            setTextColor(Color.WHITE)
            setTypeface(null, Typeface.BOLD)
            gravity       = Gravity.CENTER_HORIZONTAL
            letterSpacing = 0.12f
            setPadding(0, dp(10), 0, 0)
        })

        // ── Reason pill ───────────────────────────────────────────────────────
        contentLayout.addView(LinearLayout(ctx).apply {
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(0, dp(10), 0, 0)
            addView(TextView(ctx).apply {
                text      = reasonLabel(reason).uppercase()
                textSize  = 10f
                setTextColor(Color.parseColor("#FF8A80"))
                setTypeface(null, Typeface.BOLD)
                letterSpacing = 0.10f
                background = android.graphics.drawable.GradientDrawable().apply {
                    shape        = android.graphics.drawable.GradientDrawable.RECTANGLE
                    cornerRadius = dp(20).toFloat()
                    setColor(Color.parseColor("#20FF0000"))
                    setStroke(dp(1), Color.parseColor("#40FF8A80"))
                }
                setPadding(dp(14), dp(5), dp(14), dp(5))
            })
        })

        contentLayout.addView(hairline())

        // ── Countdown block ───────────────────────────────────────────────────
        val countdownBlock = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            gravity     = Gravity.CENTER_HORIZONTAL
            background  = android.graphics.drawable.GradientDrawable().apply {
                shape        = android.graphics.drawable.GradientDrawable.RECTANGLE
                cornerRadius = dp(16).toFloat()
                setColor(Color.parseColor("#12FFFFFF"))
                setStroke(dp(1), Color.parseColor("#20FFFFFF"))
            }
            setPadding(dp(24), dp(16), dp(24), dp(16))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
        countdownBlock.addView(TextView(ctx).apply {
            text          = if (reason == "trading_hours") "OPENS IN" else "UNLOCKS IN"
            textSize      = 9f
            setTextColor(Color.parseColor("#80FFFFFF"))
            gravity       = Gravity.CENTER_HORIZONTAL
            letterSpacing = 0.20f
            setTypeface(null, Typeface.BOLD)
        })
        val countdownTv = TextView(ctx).apply {
            text     = "--:--:--"
            textSize = 52f
            setTextColor(Color.WHITE)
            typeface = Typeface.MONOSPACE
            gravity  = Gravity.CENTER_HORIZONTAL
            setPadding(0, dp(4), 0, 0)
        }
        countdownBlock.addView(countdownTv)
        countdownTextView = countdownTv
        contentLayout.addView(countdownBlock)

        if (reason == "trading_hours") {
            // ── Trading hours: info text only — no token unlock ───────────────
            contentLayout.addView(TextView(ctx).apply {
                text     = "Wait until your trading window opens."
                textSize = 12f
                setTextColor(Color.parseColor("#AAFFFFFF"))
                gravity  = Gravity.CENTER_HORIZONTAL
                setPadding(0, dp(18), 0, dp(14))
            })
        } else {
        // ── Info text ─────────────────────────────────────────────────────────
        contentLayout.addView(TextView(ctx).apply {
            text     = "Hold the button below to unlock early with a token."
            textSize = 12f
            setTextColor(Color.parseColor("#AAFFFFFF"))
            gravity  = Gravity.CENTER_HORIZONTAL
            setPadding(0, dp(18), 0, dp(14))
        })

        // ── Hold-to-unlock progress bar ───────────────────────────────────────
        val holdProgress = ProgressBar(ctx, null, android.R.attr.progressBarStyleHorizontal).apply {
            max      = 100
            progress = 0
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(4)
            ).also { it.bottomMargin = dp(8) }
            progressDrawable = android.graphics.drawable.LayerDrawable(arrayOf(
                android.graphics.drawable.GradientDrawable().apply {
                    setColor(Color.parseColor("#20FFFFFF"))
                },
                android.graphics.drawable.ClipDrawable(
                    android.graphics.drawable.GradientDrawable().apply {
                        setColor(Color.parseColor("#00E5CC"))
                    },
                    android.view.Gravity.START,
                    android.graphics.drawable.ClipDrawable.HORIZONTAL
                )
            )).also { it.setId(0, android.R.id.background); it.setId(1, android.R.id.progress) }
        }
        contentLayout.addView(holdProgress)

        // ── Token button ──────────────────────────────────────────────────────
        val hasTokens = getTokensAvailable() > 0
        val tokenBtn = Button(ctx).apply {
            text = if (hasTokens) "🔑   USE TOKEN — HOLD TO UNLOCK"
                   else           "❌   NO TOKENS — Wait for Sunday reset (2/week)"
            textSize      = 13f
            setTextColor(if (hasTokens) Color.parseColor("#0D0D0D") else Color.parseColor("#CCFFFFFF"))
            background    = android.graphics.drawable.GradientDrawable().apply {
                shape        = android.graphics.drawable.GradientDrawable.RECTANGLE
                cornerRadius = dp(14).toFloat()
                setColor(if (hasTokens) Color.parseColor("#00E5CC") else Color.parseColor("#30FFFFFF"))
                if (!hasTokens) setStroke(dp(1), Color.parseColor("#50FFFFFF"))
            }
            setPadding(dp(20), dp(18), dp(20), dp(18))
            setTypeface(null, Typeface.BOLD)
            letterSpacing = 0.03f
            layoutParams  = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
        var holdStarted = false
        val holdSteps   = 20
        var holdCount   = 0
        val holdRunnable = object : Runnable {
            override fun run() {
                if (!holdStarted) return
                holdCount++
                holdProgress.progress = (holdCount * 100 / holdSteps).coerceAtMost(100)
                if (holdCount >= holdSteps) {
                    holdStarted = false; holdCount = 0; holdProgress.progress = 0
                    requestTokenUse()
                } else {
                    handler.postDelayed(this, 100L)
                }
            }
        }
        tokenBtn.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    if (!hasTokens) return@setOnTouchListener true // block hold if no tokens
                    holdStarted = true; holdCount = 0; holdProgress.progress = 0
                    handler.post(holdRunnable)
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    holdStarted = false; holdCount = 0; holdProgress.progress = 0
                    handler.removeCallbacks(holdRunnable)
                }
            }
            true
        }
        contentLayout.addView(tokenBtn)
        } // end else (not trading_hours)

        // ── Exit MT5 button ───────────────────────────────────────────────────
        contentLayout.addView(Button(ctx).apply {
            text          = "↩   EXIT MT5"
            textSize      = 13f
            setTextColor(Color.parseColor("#CCFFFFFF"))
            background    = android.graphics.drawable.GradientDrawable().apply {
                shape        = android.graphics.drawable.GradientDrawable.RECTANGLE
                cornerRadius = dp(14).toFloat()
                setColor(Color.parseColor("#15FFFFFF"))
                setStroke(dp(1), Color.parseColor("#40FFFFFF"))
            }
            setPadding(dp(20), dp(16), dp(20), dp(16))
            setTypeface(null, Typeface.BOLD)
            letterSpacing = 0.03f
            layoutParams  = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).also { it.topMargin = dp(10) }
            setOnTouchListener { _, event ->
                if (event.action == MotionEvent.ACTION_UP) {
                    // Hide overlay first so it doesn't appear over the home screen
                    hideOverlayKeepRunning()
                    overlayAllowed.set(false)
                    try {
                        startActivity(android.content.Intent(android.content.Intent.ACTION_MAIN).apply {
                            addCategory(android.content.Intent.CATEGORY_HOME)
                            flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                        })
                    } catch (_: Exception) {}
                    PipLockAccessibilityService.goHome()
                }
                true
            }
        })

        contentLayout.addView(spacer(1.2f))

        root.addView(contentLayout)
        return root
    }

    // ── Tick — handles both phases ────────────────────────────────────────────

    private val tickRunnable = object : Runnable {
        override fun run() {
            val now = System.currentTimeMillis()

            when (phase) {
                Phase.WARNING -> {
                    val remaining = (warningEndMillis - now) / 1000L
                    if (remaining <= 0) {
                        // Avviso scaduto → passa al blocco totale
                        transitionToLockdown()
                        return
                    }
                    countdownTextView?.text = remaining.toString()
                    handler.postDelayed(this, 500)
                }

                Phase.LOCKDOWN -> {
                    val remaining = endTimeMillis - now
                    if (remaining <= 0) {
                        hideOverlay()
                        stopSelf()
                        return
                    }
                    val h = TimeUnit.MILLISECONDS.toHours(remaining)
                    val m = TimeUnit.MILLISECONDS.toMinutes(remaining) % 60
                    val s = TimeUnit.MILLISECONDS.toSeconds(remaining) % 60
                    countdownTextView?.text = String.format("%02d:%02d:%02d", h, m, s)
                    handler.postDelayed(this, 1000)
                }
            }
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun reasonLabel(reason: String): String = when (reason) {
        "daily_loss"      -> "Daily loss limit reached"
        "max_trades"      -> "Maximum trades limit reached"
        "revenge_pattern" -> "Revenge trading pattern detected"
        "overleveraging"  -> "Excessive drawdown detected"
        "trading_hours"   -> "Outside your trading hours"
        else              -> "Risk limit reached"
    }

    private fun getTokensAvailable(): Int =
        getSharedPreferences("piplock_tokens", Context.MODE_PRIVATE)
            .getInt("tokens_available", 0)

    private fun requestTokenUse() {
        // Hide overlay and stop service — Flutter will deduct the token and navigate to rules
        hideOverlay()
        openPipLockForRules()
        stopSelf()
    }

    private fun openPipLockForRules() {
        overlayAllowed.set(false)
        hideOverlayKeepRunning()
        val remainingMin = maxOf(0L, (endTimeMillis - System.currentTimeMillis()) / 60000L).toInt()
        sendBroadcast(Intent(ACTION_OPEN_PIPLOCK).apply {
            setPackage(packageName)
            putExtra("reason", reason)
            putExtra("remaining_minutes", remainingMin)
            putExtra("navigate_to", "rules")
        })
        packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            startActivity(this)
        }
    }

    private fun openPipLock() {
        // CRITICO: disabilita l'overlay PRIMA di aprire PipLock.
        // overlayAllowed.set(false) garantisce che, anche se c'è una race condition
        // con l'AccessibilityService, l'overlay non può riapparire su PipLock.
        // Sarà riabilitato solo quando il broker tornerà in foreground (onBrokerFocused).
        overlayAllowed.set(false)
        hideOverlayKeepRunning()

        val remainingMin = maxOf(0L, (endTimeMillis - System.currentTimeMillis()) / 60000L).toInt()
        sendBroadcast(Intent(ACTION_OPEN_PIPLOCK).apply {
            setPackage(packageName)
            putExtra("reason", reason)
            putExtra("remaining_minutes", remainingMin)
        })
        packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            startActivity(this)
        }
    }

    // ── Notification ──────────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "PipLock Killswitch",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description         = "Active notification during Killswitch"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
            .createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val openIntent = PendingIntent.getActivity(
            this, 0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE
        )
        val text = when {
            reason == "trading_hours" -> "🕐 Outside trading hours. MT5 blocked until market opens."
            phase == Phase.WARNING    -> "⚠️ Close losing positions — lockdown in $WARNING_SECONDS s"
            else                      -> "🔒 Killswitch active. Open PipLock to unlock."
        }
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("PipLock Killswitch")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(openIntent)
            .setOngoing(true)
            .build()
    }

    // ── Cleanup ───────────────────────────────────────────────────────────────

    private fun hideOverlay() {
        handler.removeCallbacks(tickRunnable)
        overlayView?.let {
            try { windowManager?.removeView(it) } catch (_: Exception) {}
            overlayView      = null
            countdownTextView = null
        }
        isOverlayVisible = false
    }

    override fun onDestroy() {
        isRunning = false
        instance  = null
        hideOverlay()
        super.onDestroy()
    }
}
