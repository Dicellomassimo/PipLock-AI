package com.piplock.piplock_ai

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

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
    private val EXTRACTION_INTERVAL_MS = 2000L
    private val BROKER_DEBOUNCE_MS = 1000L

    // ---- FOMO detection state -----------------------------------
    private var lastPositionCount: Int = -1
    private var lastEquity: Double = -1.0
    private var lastEquityChangeTime: Long = 0
    private var lastFomoAlertTime: Long = 0
    private val FOMO_EQUITY_CHANGE_THRESHOLD = 0.003  // 0.3% di variazione dell'equity
    private val FOMO_WINDOW_MS = 60_000L               // finestra 60s per rilevare FOMO
    private val FOMO_ALERT_COOLDOWN_MS = 5 * 60_000L   // 5 min cooldown tra alert FOMO

    // ---- Revenge trading detection state --------------------------------
    private var lastBalanceForRevenge: Double = -1.0
    private var lastPositionCountForRevenge: Int = -1
    private var lastLossTime: Long = 0
    private var lastRevengeAlertTime: Long = 0
    private val REVENGE_WINDOW_MS = 5 * 60_000L
    private val REVENGE_ALERT_COOLDOWN_MS = 10 * 60_000L

    // ---- Overleveraging detection state ---------------------------------
    private var lastOverleveragingAlertTime: Long = 0
    private val OVERLEVERAGING_ALERT_COOLDOWN_MS = 10 * 60_000L

    // ---- Overtrading soft warning state ---------------------------------
    private var positionIncreaseTimes: MutableList<Long> = mutableListOf()
    private var lastOvertradingAlertTime: Long = 0
    private val OVERTRADING_SOFT_WINDOW_MS = 60_000L
    private val OVERTRADING_SOFT_THRESHOLD = 3
    private val OVERTRADING_ALERT_COOLDOWN_MS = 30 * 60_000L

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
                    or AccessibilityEvent.TYPE_VIEW_SCROLLED)
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            notificationTimeout = 100
            packageNames = null
            flags = (AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
                    or AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS)
        }
        sendBrokerEvent("service_started", packageName, "PipLock")
    }

    override fun onInterrupt() {
        isServiceRunning = false
        currentBrokerPackage = null
        instance = null
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
        val texts = mutableListOf<String>()
        collectTexts(root, texts)
        Log.d(TAG, "Testi raccolti: ${texts.size} — pkg: $currentBrokerPackage")
        if (texts.isNotEmpty()) Log.d(TAG, "Primi 5: ${texts.take(5)}")
        extractBrokerData(root)
    }

    private fun extractBrokerData(root: AccessibilityNodeInfo) {
        val texts = mutableListOf<String>()
        collectTexts(root, texts)
        if (texts.isEmpty()) return

        val pkg = currentBrokerPackage ?: return
        val appName = resolveBrokerName(pkg) ?: ""
        val result = when {
            appName.contains("MetaTrader") || pkg.contains("metatrader") || pkg.contains("metaquotes") ->
                extractMT5Data(texts)
            appName.contains("cTrader") || pkg.contains("ctrader") || pkg.contains("spotware") ->
                extractCTraderData(texts)
            else -> extractGenericData(texts)
        }
        if (result != null) {
            val accountNum = extractAccountNumber(texts)
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
            if (ref > 0) return ref
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
        "level"
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
                    "balance", "saldo", "bilancio")
                if (v != null) balance = v
            }
            if (equity == null) {
                val v = extractNumberFromLabeledText(text,
                    "equity", "equita", "equità", "patrimonio")
                if (v != null) equity = v
            }
            if (profit == null) {
                val v = extractNumberFromLabeledText(text,
                    "profit", "profitto", "profitto flott", "p/l", "p&l", "floating")
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
                    (t == "balance" || t == "saldo" || t == "bilancio") && balance == null ->
                        balance = findNumberInNext(texts, i)
                    (t == "equity" || t == "equita" || t == "equità" || t == "patrimonio") && equity == null ->
                        equity = findNumberInNext(texts, i)
                    // NOTA: "margine libero" / "free margin" RIMOSSO da questo bucket —
                    // è un campo contabile MT5 (Free Margin), NON il P&L della posizione.
                    (t == "profit" || t.contains("floating") || t == "p&l" || t == "p/l" ||
                     t.contains("profitto")) && profit == null ->
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

        // Se il P&L è positivo l'utente è in profitto → MAI attivare il killswitch
        if (data.profit != null && data.profit > 0) return

        var reason: String? = null

        // Controllo perdita giornaliera (solo se configurata dall'utente)
        // data.profit = dailyPnl = equity - referenceBalance (negativo = perdita)
        if (data.profit != null && data.profit < 0) {
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
     * Rileva possibili pattern FOMO:
     * - Una nuova posizione viene aperta (positions count aumenta rispetto all'ultimo valore STABILE)
     * - E c'è stata una variazione significativa dell'equity negli ultimi 60s
     * - Con cooldown di 5 minuti tra alert consecutivi per evitare spam
     *
     * Nota: lastPositionCount viene aggiornato SOLO quando le posizioni diminuiscono
     * (trade chiuso) o rimangono stabili, non ad ogni incremento — questo previene
     * falsi negativi se le posizioni salgono gradualmente.
     */
    private fun checkFomoNatively(data: ExtractedData) {
        if (FomoGatekeeperOverlayService.isRunning) return
        if (KillswitchOverlayService.isRunning) return

        val now = System.currentTimeMillis()
        val currentEquity = data.equity ?: return
        val currentPositions = data.positions ?: return

        // Cooldown: non mostrare più di un alert FOMO ogni 5 minuti
        if (now - lastFomoAlertTime < FOMO_ALERT_COOLDOWN_MS) {
            lastPositionCount = currentPositions
            lastEquity = currentEquity
            return
        }

        // Rileva variazione equity significativa
        if (lastEquity > 0 && currentEquity > 0) {
            val changePct = Math.abs(currentEquity - lastEquity) / lastEquity
            if (changePct >= FOMO_EQUITY_CHANGE_THRESHOLD) {
                lastEquityChangeTime = now
                Log.d(TAG, "Variazione equity rilevata: ${String.format("%.2f", changePct * 100)}%")
            }
        }
        lastEquity = currentEquity

        // If new position opened + recent equity change → FOMO
        if (lastPositionCount >= 0 && currentPositions > lastPositionCount) {
            val timeSinceEquityChange = now - lastEquityChangeTime
            if (lastEquityChangeTime > 0 && timeSinceEquityChange <= FOMO_WINDOW_MS) {
                Log.w(TAG, "Pattern FOMO rilevato: nuova posizione ${timeSinceEquityChange}ms dopo variazione equity")
                lastFomoAlertTime = now
                FomoGatekeeperOverlayService.show(this, "new_pos_after_move")
            }
        }

        // Extended FOMO: low readiness check-in score + new position
        if (lastPositionCount >= 0 && currentPositions > lastPositionCount) {
            val checkinPrefs = getSharedPreferences("piplock_checkin", Context.MODE_PRIVATE)
            val scoreToday = checkinPrefs.getInt("score_today", -1)
            if (scoreToday in 1..4 && now - lastFomoAlertTime > FOMO_ALERT_COOLDOWN_MS) {
                Log.w(TAG, "FOMO low_readiness: score=$scoreToday")
                lastFomoAlertTime = now
                FomoGatekeeperOverlayService.show(this, "low_readiness")
            }
        }

        // Aggiorna baseline SOLO se le posizioni sono stabili o diminuite
        // (così un incremento successivo è sempre rilevato come "nuova" posizione)
        if (currentPositions <= lastPositionCount || lastPositionCount < 0) {
            lastPositionCount = currentPositions
        }
    }

    private fun checkRevengeTrading(data: ExtractedData) {
        if (FomoGatekeeperOverlayService.isRunning) return
        if (KillswitchOverlayService.isRunning) return
        val now = System.currentTimeMillis()
        if (now - lastRevengeAlertTime < REVENGE_ALERT_COOLDOWN_MS) return
        val currentBalance = data.balance ?: return
        val currentPositions = data.positions ?: return
        // Detect a trade closed at a loss: positions decreased AND balance dropped
        if (lastPositionCountForRevenge >= 0 && currentPositions < lastPositionCountForRevenge) {
            if (lastBalanceForRevenge > 0 && currentBalance < lastBalanceForRevenge - 0.01) {
                lastLossTime = now
                Log.d(TAG, "Revenge: loss detected, balance $lastBalanceForRevenge -> $currentBalance")
            }
        }
        // Detect new position opened within the revenge window after a loss
        if (lastPositionCountForRevenge >= 0 && currentPositions > lastPositionCountForRevenge) {
            if (lastLossTime > 0 && (now - lastLossTime) < REVENGE_WINDOW_MS) {
                Log.w(TAG, "Revenge trading pattern detected: new pos ${now - lastLossTime}ms after loss")
                lastRevengeAlertTime = now
                FomoGatekeeperOverlayService.show(this, "revenge_trading")
            }
        }
        lastPositionCountForRevenge = currentPositions
        lastBalanceForRevenge = currentBalance
    }

    private fun checkOverleveraging(data: ExtractedData) {
        if (FomoGatekeeperOverlayService.isRunning) return
        if (KillswitchOverlayService.isRunning) return
        val now = System.currentTimeMillis()
        if (now - lastOverleveragingAlertTime < OVERLEVERAGING_ALERT_COOLDOWN_MS) return
        val profit = data.profit ?: return
        if (profit >= 0) return // only trigger when in loss
        val currentLoss = -profit
        val prefs = getSharedPreferences(RULES_PREFS, Context.MODE_PRIVATE)
        val maxLossAmount = prefs.getFloat("max_daily_loss_amount", -1f).toDouble()
        val maxLossPct = prefs.getFloat("max_daily_loss_pct", -1f).toDouble()
        val isOverleveraged = when {
            maxLossAmount > 0 -> currentLoss > maxLossAmount * 0.5
            maxLossPct > 0 -> {
                val balance = data.balance ?: data.equity ?: return
                (currentLoss / balance * 100.0) > maxLossPct * 0.5
            }
            else -> false
        }
        if (isOverleveraged) {
            Log.w(TAG, "Overleveraging detected: currentLoss=$currentLoss")
            lastOverleveragingAlertTime = now
            FomoGatekeeperOverlayService.show(this, "overleveraging")
        }
    }

    private fun checkOvertradingSoft(data: ExtractedData) {
        if (FomoGatekeeperOverlayService.isRunning) return
        if (KillswitchOverlayService.isRunning) return
        val now = System.currentTimeMillis()
        if (now - lastOvertradingAlertTime < OVERTRADING_ALERT_COOLDOWN_MS) return
        val currentPositions = data.positions ?: return
        // Track each new position opening within the time window
        if (lastPositionCount >= 0 && currentPositions > lastPositionCount) {
            positionIncreaseTimes.add(now)
        }
        // Remove entries older than the window
        positionIncreaseTimes.removeAll { now - it > OVERTRADING_SOFT_WINDOW_MS }
        if (positionIncreaseTimes.size >= OVERTRADING_SOFT_THRESHOLD) {
            Log.w(TAG, "Overtrading soft warning: ${positionIncreaseTimes.size} position increases in 60s")
            lastOvertradingAlertTime = now
            positionIncreaseTimes.clear()
            FomoGatekeeperOverlayService.show(this, "overtrading")
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
                putFloat("equity",    data.equity?.toFloat()  ?: -1f)
                putFloat("balance",   data.balance?.toFloat() ?: -1f)
                putFloat("profit",    data.profit?.toFloat()  ?: Float.NaN)
                putInt("positions",   data.positions          ?: -1)
                putLong("timestamp",  ts)
                apply()
            }
        }
        sendBroadcast(Intent(ACTION_BROKER_DETECTED).apply {
            setPackage(this@PipLockAccessibilityService.packageName)
            putExtra("event_type", "broker_data")
            putExtra("equity",    data.equity    ?: -1.0)
            putExtra("balance",   data.balance   ?: -1.0)
            putExtra("profit",    data.profit    ?: Double.NaN)
            putExtra("positions", data.positions ?: -1)
            putExtra("account_number", data.accountNumber ?: "")
            putExtra("timestamp", ts)
        })
    }

    private data class ExtractedData(
        val equity: Double?,
        val balance: Double?,
        val profit: Double?,
        val positions: Int?,
        val accountNumber: String? = null
    )
}
