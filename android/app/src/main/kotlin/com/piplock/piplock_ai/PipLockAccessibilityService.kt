package com.piplock.piplock_ai

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.KeyEvent

/**
 * PipLockAccessibilityService
 *
 * 1. Rileva quale app broker e in foreground (MT4, MT5, cTrader, ecc.)
 * 2. Legge equity, balance, P&L e posizioni aperte dall'UI dell'app
 * 3. Invia tutto a Flutter via broadcast -> MainActivity -> EventChannel
 *
 * NON legge password, NON modifica nulla, NON esegue azioni.
 */
class PipLockAccessibilityService : AccessibilityService() {

    companion object {
        const val TAG = "PipLockAS"
        const val ACTION_BROKER_DETECTED = "com.piplock.BROKER_DETECTED"
        const val EXTRA_PACKAGE_NAME = "package_name"
        const val EXTRA_APP_NAME = "app_name"

        val BROKER_PACKAGES = mapOf(
            "net.metaquotes.metatrader4"     to "MetaTrader 4",
            "net.metaquotes.metatrader5"     to "MetaTrader 5",
            "com.metaquotes.metatrader5"     to "MetaTrader 5",
            "com.tradingview.tradingviewapp" to "TradingView",
            "com.ig.client.production"       to "IG Markets",
            "com.etoro.trading"              to "eToro",
            "eu.quantfury.trading"           to "Quantfury",
            "com.ctrader.mobile"             to "cTrader",
            "com.spotware.ct"                to "cTrader",
            "com.brokergroup.ctrader"        to "cTrader",
            "com.xm.global"                  to "XM",
            "com.oanda.mobile"               to "OANDA"
        )

        var currentBrokerPackage: String? = null
            private set
        var isServiceRunning = false
            private set

        /** Porta l'utente alla home screen tramite l'AccessibilityService (più affidabile di startActivity) */
        fun goHome() {
            instance?.performGlobalAction(android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_HOME)
        }

        private var instance: PipLockAccessibilityService? = null
    }

    private var lastDetectedPackage: String? = null
    private var lastDetectedTime: Long = 0
    private var lastExtractionTime: Long = 0
    private val EXTRACTION_INTERVAL_MS = 1500L
    private val BROKER_DEBOUNCE_MS = 1000L

    // ---- FOMO detection state -----------------------------------
    // Finestra FOMO post-news (basata su trading psychology research):
    // T+0 → T+2 min: spike algoritmico — il retail non riesce ad eseguire qui
    // T+2 → T+30 min: finestra FOMO primaria — il retail vede il movimento e lo insegue
    // T+30 → T+45 min: finestra FOMO secondaria — chasers del secondo onda
    // Oltre T+45 min: segnale FOMO troppo debole per essere affidabile
    private var lastPositionCount: Int = -1
    private var lastFomoAlertTime: Long = 0
    private val FOMO_MIN_AFTER_NEWS_MS = 2 * 60_000L        // ignora i primi 2 min (spike algo)
    private val FOMO_MAX_AFTER_NEWS_MS = 30 * 60_000L       // finestra primaria: entro 30 min
    private val FOMO_ALERT_COOLDOWN_MS = 5 * 60_000L        // 5 min cooldown tra alert FOMO

    // ---- Revenge trading detection state --------------------------------
    private var lastBalanceForRevenge: Double = -1.0
    private var lastPositionCountForRevenge: Int = -1
    private var consecutiveLosses: Int = 0                  // perdite consecutive senza profitto
    private var lastLossTime: Long = 0
    private var lastRevengeAlertTime: Long = 0
    private val REVENGE_WINDOW_MS = 5 * 60_000L             // la nuova pos deve aprirsi entro 5min dall'ultima perdita
    private val REVENGE_ALERT_COOLDOWN_MS = 10 * 60_000L

    // ---- Overleveraging detection state ---------------------------------
    private var lastDetectedTradeMarginDelta: Double = 0.0  // margin del trade appena aperto
    private var lastOverleveragingAlertTime: Long = 0
    private val OVERLEVERAGING_ALERT_COOLDOWN_MS = 10 * 60_000L

    // ---- Overtrading soft warning state ---------------------------------
    private var lastOvertradingAlertTime: Long = 0
    private val OVERTRADING_ALERT_COOLDOWN_MS = 30 * 60_000L

    // ---- Multi-account switch detection state ---------------------------
    // Traccia l'ultimo numero account confermato visibile su schermo.
    // When this changes, an "account_switched" event is broadcast to Flutter.
    private var lastActiveAccountNumber: String? = null

    // ---- Debounce broker unfocused (evita scatti per dialog/notifiche) -----
    private val brokerHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private val BROKER_UNFOCUS_DEBOUNCE_MS = 4000L     // 4s debounce prima di nascondere overlay
    private var pendingUnfocusRunnable: Runnable? = null

    // ---- Prefs key per le regole sincronizzate da Flutter -------
    private val RULES_PREFS = "piplock_rules"

    override fun onServiceConnected() {
        super.onServiceConnected()
        isServiceRunning = true
        instance = this
        Log.d(TAG, "PipLock Accessibility Service avviato")
        serviceInfo = AccessibilityServiceInfo().apply {
            eventTypes = (AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
                    or AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
                    or AccessibilityEvent.TYPE_VIEW_SCROLLED
                    or AccessibilityEvent.TYPE_WINDOWS_CHANGED)
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            notificationTimeout = 80
            packageNames = null
            flags = (AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
                    or AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
                    or AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS)
        }
        sendBrokerEvent("service_started", packageName, "PipLock")
    }

    override fun onInterrupt() {
        isServiceRunning = false
        currentBrokerPackage = null
        instance = null
    }

    /**
     * Intercetta i tasti hardware BACK e RECENTS durante il Killswitch LOCKDOWN.
     * Tecnica ispirata ad Opal: impedisce all'utente di bypassare l'overlay
     * premendo Back all'interno di MT5 o aprendo il pannello Recenti.
     * Richiede FLAG_REQUEST_FILTER_KEY_EVENTS nell'AccessibilityServiceInfo.
     */
    override fun onKeyEvent(event: KeyEvent?): Boolean {
        if (event == null) return false
        if (KillswitchOverlayService.isRunning && KillswitchOverlayService.isOverlayVisible) {
            if (event.action == KeyEvent.ACTION_DOWN) {
                when (event.keyCode) {
                    KeyEvent.KEYCODE_BACK -> {
                        Log.d(TAG, "BACK intercettato durante Killswitch LOCKDOWN")
                        return true  // consumato — Back non fa nulla
                    }
                    KeyEvent.KEYCODE_APP_SWITCH -> {
                        Log.d(TAG, "RECENTS intercettato durante Killswitch LOCKDOWN")
                        return true  // consumato — Recenti non apre il pannello
                    }
                }
            }
        }
        return false
    }

    override fun onDestroy() {
        super.onDestroy()
        isServiceRunning = false
        currentBrokerPackage = null
        instance = null
    }

    /** Restituisce il nome app broker se il package è riconosciuto (exact o partial match). */
    private fun resolveBrokerName(pkg: String): String? {
        // 1. Exact match (priorità)
        BROKER_PACKAGES[pkg]?.let { return it }
        // 2. Partial match: qualunque package che contenga una keyword broker nota
        val lower = pkg.lowercase()
        return when {
            lower.contains("metatrader") || lower.contains("metaquotes") -> "MetaTrader"
            lower.contains("ctrader") || lower.contains("spotware") -> "cTrader"
            lower.contains("tradingview") -> "TradingView"
            lower.contains("etoro") -> "eToro"
            lower.contains("xm.global") || lower.contains("xm.com") -> "XM"
            lower.contains("oanda") -> "OANDA"
            lower.contains("ig.client") || lower.contains("iggroup") -> "IG Markets"
            else -> null
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val pkg = event.packageName?.toString() ?: return
        val appName = resolveBrokerName(pkg)

        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                if (appName != null) {
                    val now = System.currentTimeMillis()
                    if (pkg != lastDetectedPackage || (now - lastDetectedTime) > BROKER_DEBOUNCE_MS) {
                        lastDetectedPackage = pkg
                        lastDetectedTime = now
                        currentBrokerPackage = pkg
                        sendBrokerEvent("broker_opened", pkg, appName)
                    }
                    // Cancella eventuale debounce di unfocus in corso (es. dialog di sistema chiusa)
                    pendingUnfocusRunnable?.let { brokerHandler.removeCallbacks(it) }
                    pendingUnfocusRunnable = null
                    // Segnala al killswitch che il broker è in foreground
                    KillswitchOverlayService.instance?.onBrokerFocused()
                    // NON estraiamo dati subito su TYPE_WINDOW_STATE_CHANGED: la pagina
                    // potrebbe essere a metà transizione → dati parziali → falsi positivi.
                    // L'estrazione avverrà sui successivi TYPE_WINDOW_CONTENT_CHANGED.
                } else {
                    // App non-broker in foreground (dialog sistema, notifica, home, PipLock…)

                    // IMPORTANTE: se il pkg è il nostro package (com.piplock.piplock_ai)
                    // e l'overlay è visibile, l'evento è generato dall'overlay stesso
                    // (TYPE_APPLICATION_OVERLAY della nostra app), non da una navigazione
                    // volontaria dell'utente. In questo caso NON nascondiamo l'overlay
                    // (altrimenti scatterebbe il loop: overlay → evento piplock → hide → MT5 → show → loop)
                    val isOwnOverlay = pkg == packageName &&
                            KillswitchOverlayService.isOverlayVisible

                    if (!isOwnOverlay && currentBrokerPackage != null && KillswitchOverlayService.instance != null) {
                        pendingUnfocusRunnable?.let { brokerHandler.removeCallbacks(it) }
                        val foregroundPkg = pkg
                        val r = Runnable { KillswitchOverlayService.instance?.onBrokerUnfocused(foregroundPkg) }
                        pendingUnfocusRunnable = r
                        brokerHandler.postDelayed(r, BROKER_UNFOCUS_DEBOUNCE_MS)
                    }
                }
            }
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED,
            AccessibilityEvent.TYPE_VIEW_SCROLLED -> {
                // Il contenuto è stabile: estraiamo i dati solo qui, non durante transizioni
                if (pkg == currentBrokerPackage) tryExtractData()
            }
            AccessibilityEvent.TYPE_WINDOWS_CHANGED -> {
                // Dialog/popup MT5 aperto/chiuso: ri-estrai dati se il broker è attivo.
                // TYPE_WINDOWS_CHANGED può non avere packageName → usiamo currentBrokerPackage.
                if (currentBrokerPackage != null) tryExtractData()
            }
        }
    }

    // ---- Estrazione dati ----------------------------------------

    private fun tryExtractData() {
        val now = System.currentTimeMillis()
        if (now - lastExtractionTime < EXTRACTION_INTERVAL_MS) return
        lastExtractionTime = now
        val root = rootInActiveWindow
        if (root == null) {
            Log.w(TAG, "rootInActiveWindow è null — canRetrieveWindowContent potrebbe non essere attivo")
            return
        }
        extractBrokerData(root)
    }

    private fun extractBrokerData(root: AccessibilityNodeInfo) {
        val texts = mutableListOf<String>()
        collectTexts(root, texts)
        if (texts.isEmpty()) return

        val pkg = currentBrokerPackage ?: return
        val appName = resolveBrokerName(pkg) ?: ""

        // MT5: prova prima la lettura per resource-ID (stabile, non dipende dal testo)
        val result = when {
            appName.contains("MetaTrader") || pkg.contains("metatrader") || pkg.contains("metaquotes") ->
                extractMT5ByViewId(root, pkg) ?: extractMT5Data(texts)
            appName.contains("cTrader") || pkg.contains("ctrader") || pkg.contains("spotware") ->
                extractCTraderData(texts)
            else -> extractGenericData(texts)
        }
        if (result != null) {
            val accountNum = extractAccountNumber(texts)

            // ── Multi-account switch detection ────────────────────────────────
            // Broadcast "account_switched" when the visible account number changes
            // so Flutter can reset daily counters and apply the correct rules.
            if (accountNum != null && accountNum.isNotEmpty()) {
                if (lastActiveAccountNumber != null && lastActiveAccountNumber != accountNum) {
                    Log.d(TAG, "Account switch: $lastActiveAccountNumber → $accountNum")
                    sendAccountSwitchEvent(lastActiveAccountNumber!!, accountNum)
                    loadRulesForAccount(accountNum)
                }
                lastActiveAccountNumber = accountNum
            }

            val withAccount = result.copy(accountNumber = accountNum)
            val adjusted = computeDailyPnl(withAccount)
            Log.d(TAG, "Dati estratti: eq=${adjusted.equity} bal=${adjusted.balance} pnl=${adjusted.profit} pos=${adjusted.positions} acc=${adjusted.accountNumber}")

            // IMPORTANTE: checkLimitsNatively PRIMA di sendExtractedData.
            // Così il servizio nativo ha la precedenza: se triggera showWithWarning(),
            // isRunning=true blocca il tentativo di Flutter di chiamare show() (skipWarning=true).
            val wasAlreadyRunning = KillswitchOverlayService.isRunning
            checkLimitsNatively(adjusted)

            // Invia i dati a Flutter DOPO il check nativo
            sendExtractedData(adjusted)

            if (!wasAlreadyRunning && !KillswitchOverlayService.isRunning) {
                checkFomoNatively(adjusted)
                checkRevengeTrading(adjusted)
                checkOverleveraging(adjusted)
                checkOvertradingSoft(adjusted)
            }
        }
    }

    /**
     * Calcola il P&L giornaliero usando il balance di riferimento di inizio giornata.
     * Formula: dailyPnl = equity - referenceBalance
     *
     * Protezione anti-corruzione reference:
     * Se la perdita calcolata supera il 40% del balance attuale, significa quasi
     * certamente che il reference è stato impostato su un valore sbagliato
     * (es. margine libero invece del balance reale). In quel caso reset il reference
     * e ritorna un P&L neutro per evitare falsi killswitch.
     */
    private fun computeDailyPnl(data: ExtractedData): ExtractedData {
        val balance = data.balance ?: return data
        val equity  = data.equity  ?: return data
        val refBalance = getReferenceBalance(balance)
        val dailyPnl = equity - refBalance

        // Sanity check: perdita > 40% del balance → reference corrotto, reset
        if (dailyPnl < 0 && Math.abs(dailyPnl) > balance * 0.40) {
            Log.w(TAG, "Reference corrotto (pnl=$dailyPnl balance=$balance) — reset reference")
            resetReferenceBalance(balance)
            return data.copy(profit = 0.0)  // P&L neutro fino al prossimo ciclo
        }

        return data.copy(profit = dailyPnl)
    }

    /**
     * Restituisce il balance di riferimento per oggi.
     *
     * Prima di impostare un nuovo reference, verifica che il balance corrente
     * sia plausibile rispetto all'equity. Se differiscono di più del 30%,
     * l'estrazione potrebbe aver letto valori sbagliati → non impostare il reference.
     */
    private fun getReferenceBalance(currentBalance: Double): Double {
        val prefs = getSharedPreferences("piplock_broker_data", Context.MODE_PRIVATE)
        val todayKey = java.text.SimpleDateFormat("yyyyMMdd", java.util.Locale.getDefault())
            .format(java.util.Date())
        val savedKey = prefs.getString("reference_date", "")

        if (savedKey == todayKey) {
            val ref = prefs.getFloat("reference_balance", -1f).toDouble()
            // Sanity: il reference deve essere entro ±50% del balance corrente.
            // Se è fuori da questo range è quasi certamente corrotto (es. valore di margine
            // salvato per errore da una versione precedente del service).
            if (ref > 0 && ref >= currentBalance * 0.5 && ref <= currentBalance * 1.5) {
                return ref
            } else if (ref > 0) {
                Log.w(TAG, "Reference balance corrotto (ref=$ref, balance=$currentBalance) — reset")
                // non fare return: scendi a resettare il reference
            }
        }

        // Nuovo giorno: imposta il reference con il balance corrente
        prefs.edit().apply {
            putString("reference_date", todayKey)
            putFloat("reference_balance", currentBalance.toFloat())
            putLong("reference_set_time", System.currentTimeMillis())
            apply()
        }
        Log.d(TAG, "Reference balance impostato: $currentBalance")
        return currentBalance
    }

    private fun resetReferenceBalance(newBalance: Double) {
        val prefs = getSharedPreferences("piplock_broker_data", Context.MODE_PRIVATE)
        val todayKey = java.text.SimpleDateFormat("yyyyMMdd", java.util.Locale.getDefault())
            .format(java.util.Date())
        prefs.edit().apply {
            putString("reference_date", todayKey)
            putFloat("reference_balance", newBalance.toFloat())
            putLong("reference_set_time", System.currentTimeMillis())
            apply()
        }
    }

    // ── Contatore trade giornalieri ──────────────────────────────────────────
    // Traccia quante posizioni sono state aperte OGGI (non quelle correnti).
    // Resetta a mezzanotte. Non diminuisce quando le posizioni vengono chiuse.
    // Usa il delta del margine (id/margin) invece del childCount del ListView —
    // il childCount funziona solo per ≤9 posizioni visibili (limite ListView recycling),
    // mentre il margine cresce ogni volta che si apre una nuova posizione, indipendentemente
    // da quante sono visibili sullo schermo.

    private var lastKnownMargin: Double = -1.0
    private var estimatedMarginPerTrade: Double = -1.0
    private val MARGIN_INCREASE_THRESHOLD = 0.50  // $0.50 minimo per considerare un nuovo trade
    private var tradesOpenedToday: Int = 0
    private var tradeCounterDate: String = ""

    private fun resetTradeCounterIfNewDay() {
        val today = java.text.SimpleDateFormat("yyyyMMdd", java.util.Locale.getDefault())
            .format(java.util.Date())
        if (tradeCounterDate != today) {
            tradeCounterDate = today
            tradesOpenedToday = 0
            lastKnownMargin = -1.0
            estimatedMarginPerTrade = -1.0
        }
    }

    /**
     * Estrae dati MT5 tramite resource-ID stabili (non dipende dal testo visibile).
     * Molto più affidabile del text-matching in lingue diverse o layout variabili.
     * Fallback su extractMT5Data(texts) se la lettura per ID fallisce.
     */
    private fun extractMT5ByViewId(root: AccessibilityNodeInfo, pkg: String): ExtractedData? {
        fun nodeText(id: String): String? =
            try { root.findAccessibilityNodeInfosByViewId("$pkg:id/$id").firstOrNull()?.text?.toString() }
            catch (_: Exception) { null }

        fun parseId(id: String): Double? = nodeText(id)?.let { parseFinancialNumber(it) }

        val balance = parseId("balance")
        val equity  = parseId("equity")
        if (balance == null && equity == null) return null  // non siamo sulla schermata Trade

        // P&L floating in left_subtitle appare come "10.75 EUR" o "-3.20 USD" — rimuovi valuta
        val pnlRaw = nodeText("left_subtitle")?.trim() ?: ""
        val profit  = parseFinancialNumber(pnlRaw.replace(Regex("[A-Za-zА-Яа-я€$£¥%]+"), "").trim())

        // ── Conteggio posizioni aperte ATTUALMENTE ────────────────────────────
        // Il ListView 'trades' ha childCount = 2 fixed (account summary + header) + N per posizione.
        // Empiricamente: ogni posizione aggiunge ~3 RelativeLayout (riga, separatore, action panel).
        // Formula: positionCount ≈ (relLayoutCount) / 3
        // LIMITE: ListView recycling tiene in memoria solo ~9 righe visibili → undercount con >9 trade.
        // Usiamo currentOpenPositions SOLO per self-calibrare il margine per trade.
        resetTradeCounterIfNewDay()
        var currentOpenPositions: Int? = null
        try {
            val tradesList = root.findAccessibilityNodeInfosByViewId("$pkg:id/trades").firstOrNull()
            if (tradesList != null) {
                val childCount = tradesList.childCount
                val relCount = (0 until childCount)
                    .mapNotNull { try { tradesList.getChild(it) } catch (_: Exception) { null } }
                    .count { it.className?.contains("RelativeLayout") == true }
                currentOpenPositions = if (relCount > 0) Math.round(relCount / 3.0).toInt() else 0
            }
        } catch (_: Exception) {}

        // ── Trade aperti OGGI via delta-margine ───────────────────────────────
        // Il margine (id/margin) aumenta ogni volta che si apre una nuova posizione, indipendentemente
        // da quante posizioni sono visibili nel ListView. Ogni volta che il margine sale di una
        // quantità >= MARGIN_INCREASE_THRESHOLD, stimiamo quanti trade sono stati aperti.
        // Autocalibrazione: stimatedMarginPerTrade = media mobile (85/15) di (margin / posizioni visibili).
        val margin = parseId("margin")
        if (margin != null && margin > 0) {
            // Autocalibrazione: aggiorna la stima del margine per singolo trade
            if (currentOpenPositions != null && currentOpenPositions > 0) {
                val est = margin / currentOpenPositions
                estimatedMarginPerTrade = if (estimatedMarginPerTrade < 0) est
                    else estimatedMarginPerTrade * 0.85 + est * 0.15
            }

            if (lastKnownMargin < 0) {
                // Prima lettura della sessione: init contatore con le posizioni visibili correnti
                lastKnownMargin = margin
                if (tradesOpenedToday == 0 && currentOpenPositions != null)
                    tradesOpenedToday = currentOpenPositions
                Log.d(TAG, "Trade oggi (init): $tradesOpenedToday, margine=$margin, est/trade=$estimatedMarginPerTrade")
            } else {
                val delta = margin - lastKnownMargin
                if (delta >= MARGIN_INCREASE_THRESHOLD && estimatedMarginPerTrade > 0) {
                    val newTrades = maxOf(1, Math.round(delta / estimatedMarginPerTrade).toInt())
                    tradesOpenedToday += newTrades
                    lastDetectedTradeMarginDelta = delta  // usato da checkOverleveraging
                    Log.d(TAG, "Nuovi trade (Δmargin=$delta, est/trade=$estimatedMarginPerTrade): +$newTrades → oggi=$tradesOpenedToday")
                } else {
                    lastDetectedTradeMarginDelta = 0.0
                }
                lastKnownMargin = margin
            }
        }

        Log.d(TAG, "ViewID: eq=$equity bal=$balance pnl=$profit openNow=$currentOpenPositions today=$tradesOpenedToday margin=$margin")
        return ExtractedData(
            equity    = equity,
            balance   = balance,
            profit    = profit,
            positions = currentOpenPositions,                                       // posizioni CORRENTI per FOMO/revenge
            tradesToday = if (tradesOpenedToday > 0) tradesOpenedToday else null   // trade OGGI per killswitch/dashboard
        )
    }

    // Etichette MT5 che NON devono mai essere lette come balance/equity/profit.
    // Include termini in EN, IT, ES, DE, FR, PT, RU (traslitterato).
    private val MARGIN_BLACKLIST = setOf(
        // English
        "margin", "free margin", "margin level", "margin level %", "free",
        // Italian
        "margine", "margine libero", "livello margine",
        // Spanish
        "margen", "margen libre", "nivel de margen", "nivel margen", "nivel",
        // German
        "marge", "freie marge", "margin-level", "freier saldo",
        // French
        "marge libre", "niveau de marge", "marge disponible",
        // Portuguese
        "margem", "margem livre", "nível de margem", "margem disponível",
        // Russian transliterated (common in MT5 Russian UI)
        "marzha", "svobodnaya marzha",
        // Common cross-language
        "credit", "credito", "crédito", "crédit", "kredit",
        "swap", "commission", "commissione", "comisión", "provision",
        "level",
        // Russian (MT5 Russian UI — transliterated and Cyrillic)
        "маржа", "своб. маржа", "свободная маржа", "уровень маржи",
        "marzha", "svobodnaya", "uroven",
        // Polish
        "depozyt", "wolny depozyt", "poziom depozytu",
        // Turkish
        "teminat", "serbest teminat", "teminat seviyesi"
    )

    // MT5 / MT4: la tab Trade mostra Balance, Equity, Margin, Free Margin, Profit
    private fun extractMT5Data(texts: List<String>): ExtractedData? {
        var balance: Double? = null
        var equity: Double? = null
        var profit: Double? = null
        var positions: Int? = null

        // --- Pass 1: combined scan (label + number in the SAME string) ---
        for (text in texts) {
            val lower = text.lowercase().trim()
            // Salta testi che sono solo etichette margin — non assegnare il loro numero
            if (MARGIN_BLACKLIST.any { lower == it || lower.startsWith("$it:") || lower.startsWith("$it ") }) continue

            if (balance == null) {
                val v = extractNumberFromLabeledText(text,
                    "balance", "saldo", "bilancio",
                    "баланс", "saldo konta")
                if (v != null) balance = v
            }
            if (equity == null) {
                val v = extractNumberFromLabeledText(text,
                    "equity", "equita", "equità", "patrimonio",
                    "эквитет", "эквити", "kapitał")
                if (v != null) equity = v
            }
            if (profit == null) {
                val v = extractNumberFromLabeledText(text,
                    "profit", "profitto", "profitto flott", "p/l", "p&l", "floating",
                    "прибыль", "профит", "zysk")
                if (v != null) profit = v
            }
            if (positions == null) {
                val v = extractNumberFromLabeledText(text,
                    "position", "posizioni")
                // Validate: must be a whole number between 1 and 50
                if (v != null && v >= 1.0 && v <= 50.0 && v == kotlin.math.floor(v)) {
                    positions = v.toInt()
                }
            }
        }

        // --- Pass 2: label-then-lookahead fallback ---
        if (balance == null || equity == null) {
            var i = 0
            while (i < texts.size) {
                val t = texts[i].trim().lowercase()

                // BLACKLIST: quando troviamo un'etichetta margin, saltiamo anche il valore
                // successivo per evitare che venga assegnato a balance/equity/profit
                if (MARGIN_BLACKLIST.any { t == it || t.startsWith("$it:") }) {
                    i += 2  // salta l'etichetta E il suo valore
                    continue
                }

                when {
                    (t == "balance" || t == "saldo" || t == "bilancio" ||
                     t == "баланс" || t == "saldo konta") && balance == null ->
                        balance = findNumberInNext(texts, i)
                    (t == "equity" || t == "equita" || t == "equità" || t == "patrimonio" ||
                     t == "эквитет" || t == "эквити" || t == "kapitał") && equity == null ->
                        equity = findNumberInNext(texts, i)
                    // NOTA: "margine libero" / "free margin" RIMOSSO da questo bucket —
                    // è un campo contabile MT5 (Free Margin), NON il P&L della posizione.
                    (t == "profit" || t.contains("floating") || t == "p&l" || t == "p/l" ||
                     t.contains("profitto") || t == "прибыль" || t.contains("профит") ||
                     t == "zysk") && profit == null ->
                        profit = findNumberInNext(texts, i)
                    (t == "positions" || t == "position" || t == "posizioni" ||
                     t.startsWith("positions (") || t.startsWith("position (")) && positions == null -> {
                        val v = findNumberInNext(texts, i, lookahead = 3)
                        // Validate: must be a whole integer between 1 and 50
                        if (v != null && v >= 1.0 && v <= 50.0 && v == kotlin.math.floor(v)) {
                            positions = v.toInt()
                        }
                    }
                    // Numero con segno esplicito (+/-) → probabile P&L floating
                    t.matches(Regex("^[+\\-]\\s*[\\d,. ]+$")) && profit == null ->
                        profit = parseFinancialNumber(t)
                }
                i++
            }
        }

        // --- Pass 3: last resort fallback ---
        if (equity == null && balance == null) {
            val fallback = extractFallback(texts)
            if (fallback != null) return fallback
        }

        if (equity == null && balance == null) return null
        if (equity == null && balance != null && profit != null) equity = balance + profit

        // Nota: la validazione ratio equity/balance è rimossa qui.
        // checkLimitsNatively ha già il proprio check più conservativo (0.80–1.25)
        // che opera sui dati finali. Fare un check più aggressivo qui (0.50–2.0)
        // causava falsi scartamenti in conti con P&L estremi intraday.

        return ExtractedData(equity, balance, profit, positions)
    }

    // cTrader: tab Portfolio mostra Net P&L, Balance, Equity
    private fun extractCTraderData(texts: List<String>): ExtractedData? {
        var balance: Double? = null
        var equity: Double? = null
        var profit: Double? = null
        var positions: Int? = null

        // --- Pass 1: combined scan ---
        for (text in texts) {
            if (balance == null) {
                val v = extractNumberFromLabeledText(text, "balance", "saldo")
                if (v != null) balance = v
            }
            if (equity == null) {
                val v = extractNumberFromLabeledText(text, "equity", "equita", "equità")
                if (v != null) equity = v
            }
            if (profit == null) {
                val v = extractNumberFromLabeledText(text,
                    "net p", "unrealized", "profit", "profitto", "p/l", "p&l")
                if (v != null) profit = v
            }
            if (positions == null) {
                val v = extractNumberFromLabeledText(text, "position", "posizioni")
                if (v != null) positions = v.toInt()
            }
        }

        // --- Pass 2: label-then-lookahead fallback ---
        if (balance == null || equity == null) {
            var i = 0
            while (i < texts.size) {
                val t = texts[i].trim().lowercase()
                when {
                    t.startsWith("balance") && balance == null -> balance = findNumberInNext(texts, i)
                    (t == "equity" || t == "equita" || t == "equità") && equity == null ->
                        equity = findNumberInNext(texts, i)
                    (t.contains("net p") || t.contains("unrealized") || t.contains("profit") ||
                     t.contains("profitto")) && profit == null ->
                        profit = findNumberInNext(texts, i)
                    t.contains("position") && positions == null ->
                        positions = findNumberInNext(texts, i)?.toInt()
                }
                i++
            }
        }

        // --- Pass 3: last resort fallback ---
        if (equity == null && balance == null) {
            val fallback = extractFallback(texts)
            if (fallback != null) return fallback
        }

        if (equity == null && balance == null) return null
        return ExtractedData(equity, balance, profit, positions)
    }

    // Generico: cerca label comuni senza dipendere dall'ordine specifico
    private fun extractGenericData(texts: List<String>): ExtractedData? {
        var balance: Double? = null
        var equity: Double? = null
        var profit: Double? = null
        var i = 0
        while (i < texts.size) {
            val t = texts[i].trim().lowercase()
            when {
                t.contains("balance") && balance == null -> balance = findNumberInNext(texts, i)
                t.contains("equity") && equity == null -> equity = findNumberInNext(texts, i)
                (t.contains("profit") || t.contains("p&l")) && profit == null ->
                    profit = findNumberInNext(texts, i)
            }
            i++
        }
        if (equity == null && balance == null) return null
        return ExtractedData(equity, balance, profit, null)
    }

    // ---- Helper --------------------------------------------------

    /**
     * Prova a estrarre un numero finanziario da un testo che contiene ANCHE un'etichetta.
     * Esempio: "Balance: 10,000.00" → 10000.0
     */
    private fun extractNumberFromLabeledText(text: String, vararg labels: String): Double? {
        val lower = text.lowercase().trim()
        for (label in labels) {
            val idx = lower.indexOf(label)
            if (idx < 0) continue
            // Prendi il testo DOPO l'etichetta
            val rest = text.substring(idx + label.length).trim().trimStart(':', ' ', '\n', '\r')
            val n = parseFinancialNumber(rest.split(Regex("[A-Za-z]"))[0])
            if (n != null) return n
            // Prova anche il testo PRIMA (nel caso il numero sia prima dell'etichetta)
            val before = text.substring(0, idx).trim()
            val n2 = parseFinancialNumber(before.split(Regex("[A-Za-z]")).lastOrNull() ?: "")
            if (n2 != null) return n2
        }
        return null
    }

    /**
     * Last resort: find largest financial numbers on screen.
     * MT5 typically shows balance then equity — use largest as balance, second-largest as equity.
     */
    private fun extractFallback(texts: List<String>): ExtractedData? {
        val numbers = texts.mapNotNull { parseFinancialNumber(it) }
            .filter { it > 50.0 }  // plausible account values
            .sortedDescending()
        if (numbers.size < 2) return null
        // Don't try to infer position count from fallback — too unreliable (lot sizes, swaps, etc.)
        return ExtractedData(
            equity = numbers[1],      // second largest
            balance = numbers[0],     // largest
            profit = null,
            positions = null          // unknown — EA or manual input more reliable
        )
    }

    private fun collectTexts(node: AccessibilityNodeInfo, out: MutableList<String>) {
        val text = node.text?.toString()
        val desc = node.contentDescription?.toString()
        if (!text.isNullOrBlank()) out.add(text.trim())
        if (!desc.isNullOrBlank() && desc != text) out.add(desc.trim())
        for (i in 0 until node.childCount) {
            try { node.getChild(i)?.let { collectTexts(it, out) } } catch (_: Exception) {}
        }
    }

    private fun findNumberInNext(texts: List<String>, idx: Int, lookahead: Int = 10): Double? {
        // Forward search (aumentato da 5 a 10 per UI più distanziate)
        for (j in (idx + 1)..(idx + lookahead).coerceAtMost(texts.lastIndex)) {
            val n = parseFinancialNumber(texts[j])
            if (n != null) return n
        }
        // Backward search: alcune UI mostrano il valore PRIMA dell'etichetta
        if (idx > 0) {
            val prev = parseFinancialNumber(texts[idx - 1])
            if (prev != null) return prev
        }
        return null
    }

    private fun parseFinancialNumber(raw: String): Double? {
        // Strip currency symbols, letters, percent, and whitespace (handles "10 000.00" space-thousands)
        var s = raw.trim().replace(Regex("[A-Za-z$\u20ac\u00a3\u00a5%\\s]"), "")
        if (s.isBlank()) return null
        val negative = s.startsWith("-")
        s = s.trimStart('+', '-')
        s = when {
            s.contains(',') && s.contains('.') -> {
                val lastComma = s.lastIndexOf(',')
                val lastDot = s.lastIndexOf('.')
                if (lastComma > lastDot) s.replace(".", "").replace(",", ".")
                else s.replace(",", "")
            }
            s.contains(',') -> {
                val parts = s.split(',')
                if (parts.last().length <= 2) s.replace(",", ".") else s.replace(",", "")
            }
            else -> s
        }
        val n = s.toDoubleOrNull() ?: return null
        if (n < 0.01 && n > -0.01) return null
        return if (negative) -n else n
    }

    // ---- Check nativo limiti (funziona anche con Flutter in background) ------

    /**
     * Controlla i limiti letti dalle SharedPreferences (sincronizzate da Flutter)
     * e avvia direttamente KillswitchOverlayService se necessario.
     * Questo è il backup nativo per quando Flutter è in background/pausa.
     *
     * IMPORTANTE: non trigghera mai il killswitch se:
     * - I dati sembrano parziali/non plausibili (valori troppo bassi o ratio anomalo)
     * - Nessuna regola utente è configurata (tutte a -1)
     * - Il numero account su schermo non corrisponde a quello registrato (se configurato)
     * - Il P&L giornaliero è positivo (l'utente è in profitto)
     */
    private fun checkLimitsNatively(data: ExtractedData) {
        if (KillswitchOverlayService.isRunning) return

        // Grace period: non triggerare il killswitch nei primi 90s dopo reset riferimento
        val prefs2 = getSharedPreferences("piplock_broker_data", Context.MODE_PRIVATE)
        val refSetTime = prefs2.getLong("reference_set_time", 0L)
        if (System.currentTimeMillis() - refSetTime < 90_000L) return

        val prefs = getSharedPreferences(RULES_PREFS, Context.MODE_PRIVATE)

        // ── Validazione numero account ───────────────────────────────────────────
        // Se l'utente ha registrato un numero account su PipLock, verifichiamo che
        // il numero visibile su MT5 corrisponda. Se non corrisponde → ignora i dati.
        // Se nessun account è registrato → procedi normalmente (backward compat).
        val registeredAccount = prefs.getString("registered_account_number", "") ?: ""
        if (registeredAccount.isNotEmpty()) {
            val accountOnScreen = data.accountNumber
            if (accountOnScreen != null && accountOnScreen != registeredAccount) {
                Log.d(TAG, "Account mismatch: registrato=$registeredAccount, schermo=$accountOnScreen — skip")
                return
            }
            // Se accountOnScreen è null (non trovato su schermo), procediamo con cautela
            // ma solo se i dati sembrano plausibili (la validazione sotto protegge)
        }

        // ── Trading hours check (priority — blocks regardless of P&L) ────────────
        val tradingHoursEnabled = prefs.getBoolean("trading_hours_enabled", false)
        if (tradingHoursEnabled && !KillswitchOverlayService.isRunning) {
            val startStr  = prefs.getString("trading_hours_start", "") ?: ""
            val endStr    = prefs.getString("trading_hours_end",   "") ?: ""
            val startMins = parseTimeMins(startStr)
            val endMins   = parseTimeMins(endStr)
            if (startMins >= 0 && endMins >= 0) {
                val cal     = java.util.Calendar.getInstance()
                val nowMins = cal.get(java.util.Calendar.HOUR_OF_DAY) * 60 +
                              cal.get(java.util.Calendar.MINUTE)
                val isOutside = nowMins < startMins || nowMins >= endMins
                if (isOutside) {
                    val minutesUntilStart = if (nowMins < startMins) {
                        startMins - nowMins
                    } else {
                        (24 * 60 - nowMins) + startMins
                    }
                    Log.w(TAG, "Fuori orario di trading — blocco per $minutesUntilStart min")
                    KillswitchOverlayService.showTradingHoursBlock(this, minutesUntilStart)
                    return
                }
            }
        }

        val maxLossAmount = prefs.getFloat("max_daily_loss_amount", -1f).toDouble()
        val maxLossPct    = prefs.getFloat("max_daily_loss_pct",    -1f).toDouble()
        val maxTrades     = prefs.getInt("max_trades_per_day", -1)
        val durationMin   = prefs.getInt("killswitch_duration_minutes", 360)

        // Se nessuna regola è configurata, esci subito
        if (maxLossAmount < 0 && maxLossPct < 0 && maxTrades < 0) return

        // Validazione plausibilità dati: evita falsi positivi con dati parziali
        // (durante transizioni di pagina MT5 l'estrazione può restituire valori errati)
        val equity  = data.equity
        val balance = data.balance
        if (equity != null && balance != null) {
            // Scarta valori chiaramente errati (troppo piccoli per un conto reale)
            if (equity < 50.0 || balance < 50.0) return
            // Scarta ratio implausibili equity/balance (fuori range 0.80 – 1.25)
            // In trading normale senza posizioni aperte enormi, equity ≈ balance.
            // Ratio fuori da questo range = dati parziali o campo Margin letto per errore.
            val ratio = equity / balance
            if (ratio < 0.80 || ratio > 1.25) return
        }

        var reason: String? = null

        // ── Overtrading: limite trade giornalieri (indipendente dal P&L — vale anche in profitto) ──
        // Bug fix: maxTrades era letto ma mai usato per triggerare il killswitch.
        if (maxTrades > 0 && tradesOpenedToday >= maxTrades) {
            reason = "max_trades"
            Log.w(TAG, "Limite trade raggiunto: $tradesOpenedToday/$maxTrades — killswitch")
        }

        // ── Perdita giornaliera (solo quando in perdita) ──────────────────────────
        // Se il P&L è positivo l'utente è in profitto → non triggerare per perdita,
        // ma il check max_trades sopra può comunque aver già settato reason.
        if (reason == null && data.profit != null && data.profit < 0) {
            val lossUsd = -data.profit

            if (maxLossAmount > 0 && lossUsd >= maxLossAmount) {
                reason = "daily_loss"
            } else if (maxLossPct > 0) {
                // Usa il balance di riferimento (inizio giornata) per il calcolo %
                val refBal = prefs2.getFloat("reference_balance", -1f).toDouble()
                val divBal = if (refBal > 0) refBal else (balance ?: equity ?: return)
                val lossPct = lossUsd / divBal * 100
                if (lossPct >= maxLossPct) reason = "daily_loss"
            }
        }

        if (reason != null) {
            Log.w(TAG, "Limite raggiunto nativamente: $reason — avvio avviso pre-Killswitch")
            KillswitchOverlayService.showWithWarning(this, durationMin, reason)
        }
    }

    /**
     * Estrae il numero account dai testi visibili.
     * Supporta:
     * - Numerico puro 5-12 cifre (MT4/MT5 standard)
     * - Alfanumerico con prefisso lettera: "MT12345678", "FX1234567" (alcune prop firm)
     */
    private fun extractAccountNumber(texts: List<String>): String? {
        val numericPattern = Regex("""^\d{5,12}$""")
        val alphaNumericPattern = Regex("""^[A-Z]{1,4}\d{4,10}$""")
        for (text in texts) {
            val trimmed = text.trim()
            if (numericPattern.matches(trimmed) || alphaNumericPattern.matches(trimmed)) {
                return trimmed
            }
        }
        return null
    }

    // ---- FOMO detection -----------------------------------------

    /**
     * Rileva possibili pattern FOMO (Fear Of Missing Out).
     *
     * Il FOMO nel trading = aprire una posizione DOPO che un movimento significativo
     * è già avvenuto, o aprire durante un evento di mercato ad alto impatto senza
     * un setup valido — guidati dalla paura di "perdere il treno".
     *
     * Trigger implementati (in ordine di affidabilità):
     * 1. Nuova posizione aperta entro 5 min da un evento news ad alto impatto
     *    (Flutter scrive i timestamp delle news in piplock_news_cache.upcoming_events)
     * 2. Nuova posizione aperta con punteggio readiness basso (check-in pre-sessione ≤4/10)
     *
     * NON usiamo più la variazione di equity come segnale FOMO: l'equity cambia ad
     * ogni tick di ogni posizione aperta → troppi falsi positivi.
     */
    private fun checkFomoNatively(data: ExtractedData) {
        if (FomoGatekeeperOverlayService.isRunning) return
        if (KillswitchOverlayService.isRunning) return

        val now = System.currentTimeMillis()
        val currentPositions = data.positions ?: return

        if (now - lastFomoAlertTime < FOMO_ALERT_COOLDOWN_MS) {
            if (currentPositions <= lastPositionCount || lastPositionCount < 0) lastPositionCount = currentPositions
            return
        }

        // Nuova posizione appena aperta?
        val newPositionOpened = lastPositionCount >= 0 && currentPositions > lastPositionCount

        if (newPositionOpened) {
            // ── Trigger 1: nuova posizione T+2→T+30 dopo evento news high-impact ───
            //
            // Flutter scrive i timestamp degli eventi high-impact (ultimi 45 min + prossime 24h)
            // in SharedPreferences con chiave 'flutter.piplock_news_upcoming'.
            // Il file è 'FlutterSharedPreferences' (default Flutter SharedPreferences).
            //
            // Finestra di rilevamento (da trading psychology research):
            //   T+0→T+2 min: spike algoritmico — ignoriamo (retail non esegue qui)
            //   T+2→T+30 min: finestra FOMO primaria — retail insegue il movimento
            //   T+30→T+45 min: finestra secondaria (chasers del secondo wave)
            val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val newsJson = flutterPrefs.getString("flutter.piplock_news_upcoming", null)
            val isInFomoWindow = if (newsJson != null) {
                try {
                    val arr = org.json.JSONArray(newsJson)
                    (0 until arr.length()).any { i ->
                        val eventTime = arr.getLong(i)
                        val elapsed = now - eventTime   // ms trascorsi dall'evento (negativo = evento futuro)
                        elapsed in FOMO_MIN_AFTER_NEWS_MS..FOMO_MAX_AFTER_NEWS_MS
                    }
                } catch (_: Exception) { false }
            } else false

            if (isInFomoWindow) {
                Log.w(TAG, "FOMO rilevato: nuova posizione nella finestra T+2→T+30 dopo evento high-impact")
                lastFomoAlertTime = now
                FomoGatekeeperOverlayService.show(this, "news_event")
                sendFomoEvent("news_event")
            }

            // ── Trigger 2: readiness score basso (check-in pre-sessione) ─────────
            if (now - lastFomoAlertTime > FOMO_ALERT_COOLDOWN_MS) {
                val checkinPrefs = getSharedPreferences("piplock_checkin", Context.MODE_PRIVATE)
                val scoreToday = checkinPrefs.getInt("score_today", -1)
                // score_today è su scala 1-10; score ≤ 4 = prontezza bassa
                if (scoreToday in 1..4) {
                    Log.w(TAG, "FOMO rilevato: nuova posizione con readiness=$scoreToday/10")
                    lastFomoAlertTime = now
                    FomoGatekeeperOverlayService.show(this, "low_readiness")
                    sendFomoEvent("low_readiness")
                }
            }
        }

        // Aggiorna baseline SOLO se le posizioni sono stabili o diminuite
        if (currentPositions <= lastPositionCount || lastPositionCount < 0) {
            lastPositionCount = currentPositions
        }
    }

    private fun sendFomoEvent(subtype: String) {
        sendBroadcast(Intent(ACTION_BROKER_DETECTED).apply {
            setPackage(this@PipLockAccessibilityService.packageName)
            putExtra("event_type", "fomo_detected")
            putExtra("fomo_subtype", subtype)
            putExtra("fomo_detected", true)
            putExtra("timestamp", System.currentTimeMillis())
        })
    }

    /**
     * Rileva il revenge trading: aprire nuove posizioni subito dopo N perdite consecutive,
     * mossi dall'emozione di "rifarsi" invece che da un setup valido.
     *
     * Soglia dinamica basata su max_trades_per_day configurato dall'utente:
     * - Max trade ≤ 3 → non rilevabile (troppo pochi dati per distinguere pattern)
     * - Max trade 4-6 → 2 perdite consecutive
     * - Max trade 7-12 → 3 perdite consecutive
     * - Max trade > 12 → max(3, maxTrades/4) perdite consecutive
     *
     * Il contatore perdite si azzera quando un trade si chiude in profitto.
     * L'alert scatta quando: consecutiveLosses ≥ soglia AND nuova posizione aperta
     * entro REVENGE_WINDOW_MS dall'ultima perdita.
     */
    private fun checkRevengeTrading(data: ExtractedData) {
        if (FomoGatekeeperOverlayService.isRunning) return
        if (KillswitchOverlayService.isRunning) return
        val now = System.currentTimeMillis()
        if (now - lastRevengeAlertTime < REVENGE_ALERT_COOLDOWN_MS) return

        val currentBalance = data.balance ?: return
        val currentPositions = data.positions ?: return

        val prefs = getSharedPreferences(RULES_PREFS, Context.MODE_PRIVATE)
        val maxTrades = prefs.getInt("max_trades_per_day", -1)

        // Con ≤ 3 trade massimi non ha senso rilevare il revenge (troppo pochi per un pattern)
        if (maxTrades in 1..3) {
            lastPositionCountForRevenge = currentPositions
            lastBalanceForRevenge = currentBalance
            return
        }

        // Soglia: quante perdite consecutive = revenge
        val revengeThreshold = when {
            maxTrades <= 0 -> 3      // nessun limite configurato → usa default 3
            maxTrades <= 6 -> 2
            maxTrades <= 12 -> 3
            else -> maxOf(3, maxTrades / 4)
        }

        // ── Rilevamento chiusura trade ────────────────────────────────────────────
        if (lastPositionCountForRevenge >= 0 && currentPositions < lastPositionCountForRevenge) {
            if (lastBalanceForRevenge > 0) {
                if (currentBalance < lastBalanceForRevenge - 0.01) {
                    // Trade chiuso in perdita
                    consecutiveLosses++
                    lastLossTime = now
                    Log.d(TAG, "Revenge: perdita #$consecutiveLosses (soglia=$revengeThreshold), balance $lastBalanceForRevenge → $currentBalance")
                } else if (currentBalance >= lastBalanceForRevenge - 0.01) {
                    // Trade chiuso in profitto o pareggio → reset counter
                    if (consecutiveLosses > 0) Log.d(TAG, "Revenge: trade profittevole, reset counter (era $consecutiveLosses)")
                    consecutiveLosses = 0
                }
            }
        }

        // ── Rilevamento nuova apertura dopo perdite consecutive ───────────────────
        if (lastPositionCountForRevenge >= 0 && currentPositions > lastPositionCountForRevenge) {
            if (consecutiveLosses >= revengeThreshold &&
                lastLossTime > 0 &&
                (now - lastLossTime) < REVENGE_WINDOW_MS) {
                Log.w(TAG, "Revenge trading: $consecutiveLosses perdite consecutive (soglia=$revengeThreshold), nuova pos a ${now - lastLossTime}ms dall'ultima perdita")
                lastRevengeAlertTime = now
                consecutiveLosses = 0  // reset dopo alert
                FomoGatekeeperOverlayService.show(this, "revenge_trading")
                sendBroadcast(Intent(ACTION_BROKER_DETECTED).apply {
                    setPackage(this@PipLockAccessibilityService.packageName)
                    putExtra("event_type", "revenge_detected")
                    putExtra("revenge_detected", true)
                    putExtra("timestamp", now)
                })
            }
        }

        lastPositionCountForRevenge = currentPositions
        lastBalanceForRevenge = currentBalance
    }

    /**
     * Rileva overleveraging: aprire un trade con un lot size molto più grande
     * di quello consigliato o della media della sessione.
     *
     * MT5 non espone il lot size via accessibility (righe custom-drawn).
     * Usiamo il margin delta come proxy: quando si apre un nuovo trade,
     * il margine richiesto è proporzionale al lot size → se il Δmargin del nuovo
     * trade è > 2x la media della sessione, è probabile overleveraging.
     *
     * Se Flutter ha scritto recommended_margin_per_trade (dal AI Planner),
     * quello ha priorità: soglia = 1.5x il valore raccomandato.
     *
     * Flutter può scrivere recommended_margin_per_trade in piplock_rules
     * quando genera il piano AI (calcolato da recommendedLotSize × leverage).
     */
    private fun checkOverleveraging(data: ExtractedData) {
        if (FomoGatekeeperOverlayService.isRunning) return
        if (KillswitchOverlayService.isRunning) return
        val now = System.currentTimeMillis()
        if (now - lastOverleveragingAlertTime < OVERLEVERAGING_ALERT_COOLDOWN_MS) return

        // Controlliamo solo se c'è stato un nuovo trade rilevato in questo ciclo
        val tradeMargin = lastDetectedTradeMarginDelta
        if (tradeMargin <= 0) return
        lastDetectedTradeMarginDelta = 0.0  // consuma il segnale

        // Serve la media calibrata (almeno qualche ciclo di calibrazione)
        if (estimatedMarginPerTrade <= 0) return

        val prefs = getSharedPreferences(RULES_PREFS, Context.MODE_PRIVATE)
        // Flutter SharedPreferences usa il file 'FlutterSharedPreferences' con prefisso 'flutter.'
        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        // Soglia 1 (prioritaria): margine consigliato dal AI Planner (scritto da Flutter)
        val recommendedMargin = prefs.getFloat("recommended_margin_per_trade", -1f).toDouble()
        val isOverleveraged = if (recommendedMargin > 0) {
            // Nuovo trade usa >1.5x il margine raccomandato dall'AI Planner
            tradeMargin > recommendedMargin * 1.5
        } else {
            // Fallback: nuovo trade usa >2x la media della sessione
            tradeMargin > estimatedMarginPerTrade * 2.0
        }

        if (isOverleveraged) {
            val ratio = if (recommendedMargin > 0) tradeMargin / recommendedMargin else tradeMargin / estimatedMarginPerTrade
            // Log anche il lot size raccomandato dal AI Planner (se disponibile)
            val recLot = flutterPrefs.getFloat("flutter.recommended_lot_size", -1f)
            Log.w(TAG, "Overleveraging: trade margin=$tradeMargin, avg/recommended=${if (recommendedMargin > 0) recommendedMargin else estimatedMarginPerTrade}, ratio=${String.format("%.1f", ratio)}x, AI plan lot=$recLot")
            lastOverleveragingAlertTime = now
            FomoGatekeeperOverlayService.show(this, "overleveraging")
        }
    }

    private fun parseTimeMins(timeStr: String): Int {
        val parts = timeStr.trim().split(":")
        if (parts.size < 2) return -1
        val h = parts[0].toIntOrNull() ?: return -1
        val m = parts[1].toIntOrNull() ?: return -1
        if (h < 0 || h > 23 || m < 0 || m > 59) return -1
        return h * 60 + m
    }

    /**
     * Avviso soft di overtrading: scatta quando tradesOpenedToday raggiunge
     * l'80% del limite giornaliero configurato (o a 1 trade dal limite se è piccolo).
     *
     * Il killswitch hard scatta in checkLimitsNatively quando si raggiunge il 100%.
     * Questo serve come "early warning" prima del blocco definitivo.
     *
     * Esempio: max 6 trade → soft warning al 5° (83%)
     *          max 10 trade → soft warning all'8° (80%)
     */
    private fun checkOvertradingSoft(data: ExtractedData) {
        if (FomoGatekeeperOverlayService.isRunning) return
        if (KillswitchOverlayService.isRunning) return
        val now = System.currentTimeMillis()
        if (now - lastOvertradingAlertTime < OVERTRADING_ALERT_COOLDOWN_MS) return

        val prefs = getSharedPreferences(RULES_PREFS, Context.MODE_PRIVATE)
        val maxTrades = prefs.getInt("max_trades_per_day", -1)
        if (maxTrades <= 0) return

        // Soglia soft: 80% del limite, ma almeno 1 trade prima del limite
        val softThreshold = maxOf(maxTrades - 1, (maxTrades * 0.8).toInt()).coerceAtLeast(1)

        if (tradesOpenedToday >= softThreshold && tradesOpenedToday < maxTrades) {
            val remaining = maxTrades - tradesOpenedToday
            Log.w(TAG, "Overtrading soft: $tradesOpenedToday/$maxTrades trade oggi (rimane $remaining)")
            lastOvertradingAlertTime = now
            FomoGatekeeperOverlayService.show(this, "overtrading")
        }
    }

    // ---- Multi-account helpers ----------------------------------

    /**
     * Broadcasts an "account_switched" intent so Flutter can:
     * 1. Reset daily counters (trades, P&L tracking)
     * 2. Apply the rules registered for [toAccount]
     * 3. Notify the user that a different account is now active
     */
    private fun sendAccountSwitchEvent(fromAccount: String, toAccount: String) {
        sendBroadcast(Intent(ACTION_BROKER_DETECTED).apply {
            setPackage(this@PipLockAccessibilityService.packageName)
            putExtra("event_type", "account_switched")
            putExtra("from_account", fromAccount)
            putExtra("to_account", toAccount)
            putExtra("timestamp", System.currentTimeMillis())
        })
    }

    /**
     * Reads the pre-populated "account_rules_map" JSON from SharedPreferences
     * (written by Flutter via syncMultiAccountRules) and overwrites the active
     * rule keys so [checkLimitsNatively] immediately uses the correct limits.
     *
     * JSON format: { "accountNumber": { "max_daily_loss_amount": 100.0, ... } }
     */
    private fun loadRulesForAccount(accountNumber: String) {
        val prefs = getSharedPreferences(RULES_PREFS, Context.MODE_PRIVATE)
        val mapJson = prefs.getString("account_rules_map", null) ?: return
        try {
            val map = org.json.JSONObject(mapJson)
            if (!map.has(accountNumber)) {
                Log.d(TAG, "No rules registered for account $accountNumber — enforcement paused")
                // Clear active rules so we don't enforce rules that belong to a different account
                prefs.edit().apply {
                    putFloat("max_daily_loss_amount", -1f)
                    putFloat("max_daily_loss_pct", -1f)
                    putInt("max_trades_per_day", -1)
                    putString("registered_account_number", accountNumber)
                    apply()
                }
                return
            }
            val rules = map.getJSONObject(accountNumber)
            prefs.edit().apply {
                putFloat("max_daily_loss_amount",
                    rules.optDouble("max_daily_loss_amount", -1.0).toFloat())
                putFloat("max_daily_loss_pct",
                    rules.optDouble("max_daily_loss_pct", -1.0).toFloat())
                putInt("max_trades_per_day",
                    rules.optInt("max_trades_per_day", -1))
                putInt("killswitch_duration_minutes",
                    rules.optInt("killswitch_duration_minutes", 360))
                putBoolean("trading_hours_enabled",
                    rules.optBoolean("trading_hours_enabled", false))
                putString("trading_hours_start",
                    rules.optString("trading_hours_start", ""))
                putString("trading_hours_end",
                    rules.optString("trading_hours_end", ""))
                putString("registered_account_number", accountNumber)
                apply()
            }
            Log.d(TAG, "Rules loaded for account $accountNumber: " +
                "maxLoss=${rules.optDouble("max_daily_loss_amount")} " +
                "maxTrades=${rules.optInt("max_trades_per_day")}")
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing account_rules_map: $e")
        }
    }

    // ---- Broadcast ----------------------------------------------

    private fun sendBrokerEvent(eventType: String, packageName: String, appName: String) {
        sendBroadcast(Intent(ACTION_BROKER_DETECTED).apply {
            setPackage(this@PipLockAccessibilityService.packageName)
            putExtra("event_type", eventType)
            putExtra(EXTRA_PACKAGE_NAME, packageName)
            putExtra(EXTRA_APP_NAME, appName)
            putExtra("timestamp", System.currentTimeMillis())
        })
    }

    private fun sendExtractedData(data: ExtractedData) {
        val ts = System.currentTimeMillis()
        // Persisti gli ultimi dati validi nelle SharedPreferences
        // Flutter li legge all'avvio per popolare la dashboard subito
        if (data.equity != null || data.balance != null) {
            getSharedPreferences("piplock_broker_data", Context.MODE_PRIVATE).edit().apply {
                putFloat("equity",       data.equity?.toFloat()   ?: -1f)
                putFloat("balance",      data.balance?.toFloat()  ?: -1f)
                putFloat("profit",       data.profit?.toFloat()   ?: Float.NaN)
                putInt("positions",      data.positions           ?: -1)
                putInt("trades_today",   data.tradesToday         ?: -1)
                putLong("timestamp",     ts)
                apply()
            }
        }
        sendBroadcast(Intent(ACTION_BROKER_DETECTED).apply {
            setPackage(this@PipLockAccessibilityService.packageName)
            putExtra("event_type",    "broker_data")
            putExtra("equity",        data.equity      ?: -1.0)
            putExtra("balance",       data.balance     ?: -1.0)
            putExtra("profit",        data.profit      ?: Double.NaN)
            putExtra("positions",     data.positions   ?: -1)
            putExtra("trades_today",  data.tradesToday ?: -1)
            putExtra("account_number", data.accountNumber ?: "")
            putExtra("timestamp",     ts)
        })
    }

    private data class ExtractedData(
        val equity: Double?,
        val balance: Double?,
        val profit: Double?,
        val positions: Int?,           // posizioni CORRENTEMENTE aperte (per FOMO/revenge)
        val tradesToday: Int? = null,  // trade aperti OGGI cumulativi (per killswitch/dashboard)
        val accountNumber: String? = null
    )
}
