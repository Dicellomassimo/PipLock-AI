package com.piplock.piplock_ai

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.provider.Settings
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // FLAG_SECURE disabilitato temporaneamente per screenshots di sviluppo.
        // Riabilitare prima della submission al Play Store:
        // window.setFlags(
        //     WindowManager.LayoutParams.FLAG_SECURE,
        //     WindowManager.LayoutParams.FLAG_SECURE
        // )
    }

    companion object {
        const val METHOD_CHANNEL = "com.piplock/accessibility"
        const val EVENT_CHANNEL = "com.piplock/broker_events"
    }

    private var brokerEventSink: EventChannel.EventSink? = null

    // Receiver per eventi dall'Accessibility Service (dati broker)
    private val brokerReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != PipLockAccessibilityService.ACTION_BROKER_DETECTED) return

            val eventType = intent.getStringExtra("event_type") ?: ""

            val event: Map<String, Any?> = when (eventType) {
                "broker_data" -> mapOf(
                    "event_type" to "broker_data",
                    "equity" to intent.getDoubleExtra("equity", -1.0),
                    "balance" to intent.getDoubleExtra("balance", -1.0),
                    "profit" to intent.getDoubleExtra("profit", Double.NaN),
                    "positions" to intent.getIntExtra("positions", -1),
                    "account_number" to (intent.getStringExtra("account_number") ?: ""),
                    "timestamp" to intent.getLongExtra("timestamp", 0L)
                )
                "account_switched" -> mapOf(
                    "event_type" to "account_switched",
                    "from_account" to (intent.getStringExtra("from_account") ?: ""),
                    "to_account" to (intent.getStringExtra("to_account") ?: ""),
                    "timestamp" to intent.getLongExtra("timestamp", 0L)
                )
                else -> mapOf(
                    "event_type" to eventType,
                    "package_name" to (intent.getStringExtra(PipLockAccessibilityService.EXTRA_PACKAGE_NAME) ?: ""),
                    "app_name" to (intent.getStringExtra(PipLockAccessibilityService.EXTRA_APP_NAME) ?: ""),
                    "timestamp" to intent.getLongExtra("timestamp", 0L)
                )
            }

            runOnUiThread { brokerEventSink?.success(event) }
        }
    }

    // Receiver per "Apri PipLock" premuto nell'overlay killswitch
    // Notifica Flutter che il killswitch è attivo (caso di trigger nativo)
    private val killswitchOpenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != KillswitchOverlayService.ACTION_OPEN_PIPLOCK) return
            val reason = intent.getStringExtra("reason") ?: "daily_loss"
            val remainingMinutes = intent.getIntExtra("remaining_minutes", 360)
            val navigateTo = intent.getStringExtra("navigate_to") ?: ""
            runOnUiThread {
                brokerEventSink?.success(mapOf(
                    "event_type" to if (navigateTo == "rules") "navigate_to_rules" else "killswitch_native_active",
                    "reason" to reason,
                    "remaining_minutes" to remainingMinutes
                ))
            }
        }
    }

    // Receiver per richiesta di utilizzo token dall'overlay killswitch
    private val tokenUseReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != KillswitchOverlayService.ACTION_USE_TOKEN_REQUEST) return
            runOnUiThread {
                brokerEventSink?.success(mapOf(
                    "event_type" to "token_use_requested"
                ))
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // ── Accessibility ──────────────────────────────────
                    "isAccessibilityEnabled" ->
                        result.success(isAccessibilityServiceEnabled())

                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }

                    "isServiceRunning" ->
                        result.success(PipLockAccessibilityService.isServiceRunning)

                    "getCurrentBroker" ->
                        result.success(PipLockAccessibilityService.currentBrokerPackage)

                    // ── Overlay Killswitch ─────────────────────────────
                    "canDrawOverlays" ->
                        result.success(Settings.canDrawOverlays(this))

                    "requestOverlayPermission" -> {
                        startActivity(Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        ))
                        result.success(null)
                    }

                    "showKillswitchOverlay" -> {
                        val minutes = call.argument<Int>("durationMinutes") ?: 360
                        val reason = call.argument<String>("reason") ?: "daily_loss"
                        KillswitchOverlayService.show(this, minutes, reason)
                        result.success(null)
                    }

                    "hideKillswitchOverlay" -> {
                        KillswitchOverlayService.hide(this)
                        result.success(null)
                    }

                    // ── FOMO Gatekeeper ────────────────────────────────
                    "showFomoOverlay" -> {
                        val trigger = call.argument<String>("trigger") ?: "fast_entry"
                        FomoGatekeeperOverlayService.show(this, trigger)
                        result.success(null)
                    }

                    "hideFomoOverlay" -> {
                        FomoGatekeeperOverlayService.hide(this)
                        result.success(null)
                    }

                    "showTradeLimitOverlay" -> {
                        val current = call.argument<Int>("currentTrades") ?: 0
                        val max = call.argument<Int>("maxTrades") ?: 0
                        TradeLimitOverlayService.show(this, current, max)
                        result.success(null)
                    }

                    "hideTradeLimitOverlay" -> {
                        TradeLimitOverlayService.hide(this)
                        result.success(null)
                    }

                    "syncTokenCount" -> {
                        val count = call.argument<Int>("count") ?: 0
                        getSharedPreferences("piplock_tokens", Context.MODE_PRIVATE)
                            .edit().putInt("tokens_available", count).apply()
                        result.success(null)
                    }

                    "syncCheckinScore" -> {
                        val score = call.argument<Int>("score") ?: -1
                        getSharedPreferences("piplock_checkin", Context.MODE_PRIVATE)
                            .edit().putInt("score_today", score).apply()
                        result.success(null)
                    }

                    "goHome" -> {
                        // Try accessibility global action first (instant)
                        PipLockAccessibilityService.goHome()
                        // Also fire a home intent as fallback
                        try {
                            startActivity(android.content.Intent(android.content.Intent.ACTION_MAIN).apply {
                                addCategory(android.content.Intent.CATEGORY_HOME)
                                flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                            })
                        } catch (_: Exception) {}
                        result.success(null)
                    }

                    // ── Leggi ultimi dati broker salvati dall'AccessibilityService
                    "getLastBrokerData" -> {
                        val prefs = getSharedPreferences("piplock_broker_data", Context.MODE_PRIVATE)
                        val equity      = prefs.getFloat("equity",       -1f).toDouble()
                        val balance     = prefs.getFloat("balance",      -1f).toDouble()
                        val profitRaw   = prefs.getFloat("profit",       Float.NaN)
                        val profit      = if (profitRaw.isNaN()) Double.NaN else profitRaw.toDouble()
                        val positions   = prefs.getInt("positions",      -1)
                        val tradesToday = prefs.getInt("trades_today",   -1)
                        val timestamp   = prefs.getLong("timestamp",     0L)
                        result.success(mapOf(
                            "equity"       to equity,
                            "balance"      to balance,
                            "profit"       to profit,
                            "positions"    to positions,
                            "trades_today" to tradesToday,
                            "timestamp"    to timestamp
                        ))
                    }

                    // ── Sync mappa regole multi-account ───────────────────
                    // Flutter invia un JSON { "accountNumber": { rules... } }
                    // L'Accessibility Service lo legge in loadRulesForAccount()
                    // al momento del cambio account, senza dover contattare Flutter.
                    "syncMultiAccountRules" -> {
                        val json = call.argument<String>("rulesMapJson") ?: "{}"
                        getSharedPreferences("piplock_rules", Context.MODE_PRIVATE)
                            .edit().putString("account_rules_map", json).apply()
                        result.success(null)
                    }

                    // ── Sync regole da Flutter a SharedPreferences native
                    "syncRulesToNative" -> {
                        val prefs = getSharedPreferences("piplock_rules", Context.MODE_PRIVATE)
                        prefs.edit().apply {
                            putFloat("max_daily_loss_amount",
                                (call.argument<Double>("maxDailyLossAmount") ?: -1.0).toFloat())
                            putFloat("max_daily_loss_pct",
                                (call.argument<Double>("maxDailyLossPct") ?: -1.0).toFloat())
                            putInt("max_trades_per_day",
                                call.argument<Int>("maxTradesPerDay") ?: -1)
                            putInt("killswitch_duration_minutes",
                                call.argument<Int>("killswitchDurationMinutes") ?: 360)
                            putString("registered_account_number",
                                call.argument<String>("accountNumber") ?: "")
                            apply()
                        }
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    brokerEventSink = events
                    // Receiver dati broker
                    val brokerFilter = IntentFilter(PipLockAccessibilityService.ACTION_BROKER_DETECTED)
                    registerReceiver(brokerReceiver, brokerFilter, Context.RECEIVER_NOT_EXPORTED)
                    // Receiver per "Apri PipLock" dall'overlay killswitch
                    val ksFilter = IntentFilter(KillswitchOverlayService.ACTION_OPEN_PIPLOCK)
                    registerReceiver(killswitchOpenReceiver, ksFilter, Context.RECEIVER_NOT_EXPORTED)
                    // Receiver per richiesta token dall'overlay killswitch
                    val tokenFilter = IntentFilter(KillswitchOverlayService.ACTION_USE_TOKEN_REQUEST)
                    registerReceiver(tokenUseReceiver, tokenFilter, Context.RECEIVER_NOT_EXPORTED)
                }
                override fun onCancel(arguments: Any?) {
                    brokerEventSink = null
                    try { unregisterReceiver(brokerReceiver) } catch (_: Exception) {}
                    try { unregisterReceiver(killswitchOpenReceiver) } catch (_: Exception) {}
                    try { unregisterReceiver(tokenUseReceiver) } catch (_: Exception) {}
                }
            })
    }

    override fun onDestroy() {
        super.onDestroy()
        try { unregisterReceiver(brokerReceiver) } catch (_: Exception) {}
        try { unregisterReceiver(killswitchOpenReceiver) } catch (_: Exception) {}
        try { unregisterReceiver(tokenUseReceiver) } catch (_: Exception) {}
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val componentName = ComponentName(this, PipLockAccessibilityService::class.java)
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabledServices.split(':').any { service ->
            try {
                ComponentName.unflattenFromString(service)?.equals(componentName) == true
            } catch (_: Exception) { false }
        }
    }
}
