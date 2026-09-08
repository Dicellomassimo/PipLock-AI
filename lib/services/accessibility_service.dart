import 'dart:convert';
import 'package:flutter/services.dart';

class AccessibilityService {
  static const _method = MethodChannel('com.piplock/accessibility');
  static const _eventChannel = EventChannel('com.piplock/broker_events');

  // Stream condiviso — un EventChannel Android supporta UN solo listener attivo.
  // Tutti i consumer usano questo stream broadcast.
  static final Stream<Map<String, dynamic>> _shared = _eventChannel
      .receiveBroadcastStream()
      .map((event) {
        if (event is Map) return Map<String, dynamic>.from(event);
        return <String, dynamic>{};
      })
      .asBroadcastStream();

  // ── Accessibility Service ─────────────────────────────────────

  static Future<bool> isEnabled() async {
    try {
      return await _method.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openSettings() async {
    try {
      await _method.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }

  static Future<bool> isRunning() async {
    try {
      return await _method.invokeMethod<bool>('isServiceRunning') ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── Overlay Killswitch ────────────────────────────────────────

  static Future<bool> canDrawOverlays() async {
    try {
      return await _method.invokeMethod<bool>('canDrawOverlays') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestOverlayPermission() async {
    try {
      await _method.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }

  static Future<void> showKillswitchOverlay({
    required int durationMinutes,
    String reason = 'daily_loss',
  }) async {
    try {
      await _method.invokeMethod('showKillswitchOverlay', {
        'durationMinutes': durationMinutes,
        'reason': reason,
      });
    } catch (_) {}
  }

  static Future<void> hideKillswitchOverlay() async {
    try {
      await _method.invokeMethod('hideKillswitchOverlay');
    } catch (_) {}
  }

  // ── FOMO Gatekeeper Overlay ───────────────────────────────────

  static Future<void> showFomoOverlay({String trigger = 'fast_entry'}) async {
    try {
      await _method.invokeMethod('showFomoOverlay', {'trigger': trigger});
    } catch (_) {}
  }

  static Future<void> hideFomoOverlay() async {
    try {
      await _method.invokeMethod('hideFomoOverlay');
    } catch (_) {}
  }

  // ── Leggi ultimi dati broker dall'AccessibilityService ──────────

  /// Legge gli ultimi dati broker salvati dall'Accessibility Service
  /// nelle SharedPreferences native. Usato per popolare la dashboard
  /// all'avvio senza dover aspettare il prossimo ciclo di estrazione.
  static Future<Map<String, dynamic>?> getLastBrokerData() async {
    try {
      final result = await _method.invokeMethod<Map>('getLastBrokerData');
      if (result == null) return null;
      return Map<String, dynamic>.from(result);
    } catch (_) {
      return null;
    }
  }

  // ── Sync regole da Flutter a SharedPreferences native ─────────
  // Le regole vengono lette da PipLockAccessibilityService per il
  // controllo nativo dei limiti (funziona anche con Flutter in background)

  static Future<void> syncRulesToNative({
    double? maxDailyLossAmount,
    double? maxDailyLossPct,
    int? maxTradesPerDay,
    int killswitchDurationMinutes = 360,
    String? accountNumber,
    bool tradingHoursEnabled = false,
    String? tradingHoursStart,
    String? tradingHoursEnd,
  }) async {
    try {
      await _method.invokeMethod('syncRulesToNative', {
        'maxDailyLossAmount': maxDailyLossAmount ?? -1.0,
        'maxDailyLossPct': maxDailyLossPct ?? -1.0,
        'maxTradesPerDay': maxTradesPerDay ?? -1,
        'killswitchDurationMinutes': killswitchDurationMinutes,
        'accountNumber': accountNumber ?? '',
        'tradingHoursEnabled': tradingHoursEnabled,
        'tradingHoursStart': tradingHoursStart ?? '',
        'tradingHoursEnd': tradingHoursEnd ?? '',
      });
    } catch (_) {}
  }

  // ── Trade Limit Overlay ───────────────────────────────────────────────────────

  static Future<void> showTradeLimitOverlay({
    required int currentTrades,
    required int maxTrades,
  }) async {
    try {
      await _method.invokeMethod('showTradeLimitOverlay', {
        'currentTrades': currentTrades,
        'maxTrades': maxTrades,
      });
    } catch (_) {}
  }

  static Future<void> hideTradeLimitOverlay() async {
    try {
      await _method.invokeMethod('hideTradeLimitOverlay');
    } catch (_) {}
  }

  /// Triggers Android HOME action (exits MT5 / any foreground app).
  static Future<void> goHome() async {
    try {
      await _method.invokeMethod('goHome');
    } catch (_) {}
  }

  // ── Sync mappa regole multi-account ──────────────────────────
  // Invia a Kotlin un JSON { "accountNumber": { regole } } con le regole di
  // TUTTI gli account registrati dall'utente (personali + challenge).
  // L'Accessibility Service lo usa in loadRulesForAccount() al cambio account,
  // senza dover richiamare Flutter (funziona anche con app in background).
  //
  // Formato atteso per ogni account:
  // {
  //   "max_daily_loss_amount": 100.0,   // -1 = non configurato
  //   "max_daily_loss_pct":    -1.0,
  //   "max_trades_per_day":    3,
  //   "killswitch_duration_minutes": 360,
  //   "trading_hours_enabled": false,
  //   "trading_hours_start":  "08:00",
  //   "trading_hours_end":    "18:00"
  // }
  static Future<void> syncMultiAccountRules(
      Map<String, Map<String, dynamic>> accountRulesMap) async {
    try {
      await _method.invokeMethod('syncMultiAccountRules', {
        'rulesMapJson': jsonEncode(accountRulesMap),
      });
    } catch (_) {}
  }

  /// Writes the current token count to native SharedPreferences so the
  /// Kotlin overlay can check it without calling back into Flutter.
  static Future<void> syncTokenCount(int count) async {
    try {
      await _method.invokeMethod('syncTokenCount', {'count': count});
    } catch (_) {}
  }

  /// Writes today's check-in readiness score to native SharedPreferences
  /// ("piplock_checkin" / "score_today") so the Accessibility Service can
  /// trigger a low_readiness warning without calling back into Flutter.
  static Future<void> syncCheckinScore(int score) async {
    try {
      await _method.invokeMethod('syncCheckinScore', {'score': score});
    } catch (_) {}
  }

  // ── Event Streams ─────────────────────────────────────────────

  /// Tutti gli eventi broker (apertura app, dati estratti, ecc.)
  static Stream<Map<String, dynamic>> get brokerEvents => _shared;

  /// Solo i dati finanziari estratti dall'albero di accessibilità.
  static Stream<Map<String, dynamic>> get brokerDataStream =>
      _shared.where((e) => e['event_type'] == 'broker_data');

  /// Emesso quando l'utente cambia account su MT5 (switcher in alto a sinistra).
  /// Payload: { 'from_account': '12345678', 'to_account': '87654321' }
  static Stream<Map<String, dynamic>> get accountSwitchedStream =>
      _shared.where((e) => e['event_type'] == 'account_switched');
}
