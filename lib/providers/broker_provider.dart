import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../config/constants.dart';
import '../models/broker_data.dart';
import '../models/challenge.dart';
import '../models/chat_session.dart';
import '../services/accessibility_service.dart';
import '../services/ai_service.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../services/fomo_detection_service.dart';
import '../services/metaapi_service.dart';
import 'challenge_provider.dart';
import 'chat_history_provider.dart';
import 'killswitch_provider.dart';
import 'locale_provider.dart';
import 'navigation_provider.dart';
import 'rules_provider.dart';
import 'auth_provider.dart';
import 'personal_accounts_provider.dart';

export '../models/broker_data.dart';

// ──────────────────────────────────────────────────────────────────────────────
// BrokerState
// ──────────────────────────────────────────────────────────────────────────────

class BrokerState {
  final BrokerConnectionMethod method;
  final BrokerConnectionStatus status;
  final BrokerData data;
  final String? error;
  final String? statusMessage;

  /// Segreto webhook usato dall'EA MQL5 per autenticarsi (metodo EA)
  final String? webhookSecret;

  /// Nome app broker rilevata dall'Accessibility Service (es. "MetaTrader 5")
  final String? detectedAppName;

  /// Account ID MetaAPI inserito dall'utente
  final String? metaApiAccountId;

  /// Numero account rilevato attualmente su MT5 dallo schermo
  final String? detectedAccountNumber;

  /// Segnale FOMO rilevato sull'ultimo trade aperto (null = nessun segnale)
  final FomoSignal? fomoSignal;

  const BrokerState({
    this.method = BrokerConnectionMethod.none,
    this.status = BrokerConnectionStatus.disconnected,
    this.data = const BrokerData(),
    this.error,
    this.statusMessage,
    this.webhookSecret,
    this.detectedAppName,
    this.metaApiAccountId,
    this.detectedAccountNumber,
    this.fomoSignal,
  });

  bool get isConnected => status == BrokerConnectionStatus.connected;
  bool get isConnecting => status == BrokerConnectionStatus.connecting;
  bool get hasAccount => method != BrokerConnectionMethod.none;

  // Getter di compatibilità per usare BrokerState come MetaApiState nella dashboard
  double? get equity => data.equity;
  double? get balance => data.balance;
  double? get dailyPnl => data.dailyPnl;
  double? get dailyLossUsd => data.dailyLossUsd;
  double? get dailyLossPct => data.dailyLossPct;
  double? get drawdownPct => data.drawdownPct;
  int? get openPositions => data.openPositions;
  int? get tradesToday => data.tradesToday;
  String? get currency => data.currency;
  DateTime? get lastUpdate => data.lastUpdate;

  BrokerState copyWith({
    BrokerConnectionMethod? method,
    BrokerConnectionStatus? status,
    BrokerData? data,
    Object? error = _sentinel,
    Object? statusMessage = _sentinel,
    Object? webhookSecret = _sentinel,
    Object? detectedAppName = _sentinel,
    Object? metaApiAccountId = _sentinel,
    Object? detectedAccountNumber = _sentinel,
    Object? fomoSignal = _sentinel,
  }) {
    return BrokerState(
      method: method ?? this.method,
      status: status ?? this.status,
      data: data ?? this.data,
      error: error == _sentinel ? this.error : error as String?,
      statusMessage: statusMessage == _sentinel ? this.statusMessage : statusMessage as String?,
      webhookSecret: webhookSecret == _sentinel ? this.webhookSecret : webhookSecret as String?,
      detectedAppName: detectedAppName == _sentinel ? this.detectedAppName : detectedAppName as String?,
      metaApiAccountId: metaApiAccountId == _sentinel ? this.metaApiAccountId : metaApiAccountId as String?,
      detectedAccountNumber: detectedAccountNumber == _sentinel ? this.detectedAccountNumber : detectedAccountNumber as String?,
      fomoSignal: fomoSignal == _sentinel ? this.fomoSignal : fomoSignal as FomoSignal?,
    );
  }

  static const Object _sentinel = Object();
}

// ──────────────────────────────────────────────────────────────────────────────
// BrokerNotifier
// ──────────────────────────────────────────────────────────────────────────────

class BrokerNotifier extends StateNotifier<BrokerState> {
  final Ref _ref;
  StreamSubscription? _realtimeSub;
  StreamSubscription? _accessibilitySub;
  Timer? _accessibilityTimer;
  Timer? _metaApiTimer;

  DateTime? _lastResetDate;
  Timer? _midnightTimer;
  bool _isActivating = false;
  bool _positionsBaselineSet = false;
  int _lastNonZeroPositions = 0;
  bool _positionsDroppedToZero = false;
  bool _soft80AlertSent = false;

  // ── Detection state per nuovi rilevamenti ─────────────────────────────
  int _prevTradesToday = 0;
  double? _prevDailyPnl;
  int _consecutiveLossesLocal = 0; // tracciato in Flutter (fallback quando EA non invia il campo)
  bool _consecutiveLossAlertSent = false;
  double? _baselineLotSizeToday; // primo lot size del giorno (per anomalia size)
  bool _lotSizeAlertSent = false;
  bool _planViolationAlertSent = false;
  int _prevOpenPositions = -1;
  DateTime? _lastPositionCloseTime;
  bool _fastReentryAlertSent = false;
  bool _dailyBriefingTriggered = false;

  BrokerNotifier(this._ref) : super(const BrokerState()) {
    _loadPersistedConnection();
    // Ricarica la connessione broker quando l'auth si risolve,
    // stesso race condition di rulesProvider.
    _ref.listen<AuthState>(authProvider, (prev, next) {
      final prevId = prev?.profile?.id ?? '';
      final nextId = next.profile?.id ?? '';
      if (nextId.isNotEmpty && nextId != prevId && state.method == BrokerConnectionMethod.none) {
        _loadPersistedConnection();
      }
    });
    // Trigger daily briefing when challenges first load
    _ref.listen<List<Challenge>>(challengeListProvider, (prev, next) {
      if ((prev?.isEmpty ?? true) && next.isNotEmpty && !_dailyBriefingTriggered) {
        _dailyBriefingTriggered = true;
        _triggerDailyChallengeBriefing();
      }
    });
  }

  void _checkAndResetDailyIfNeeded() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_lastResetDate == null) {
      _lastResetDate = today;
      return;
    }
    if (_lastResetDate!.isBefore(today)) {
      _lastResetDate = today;
      // Reset daily fields in broker data
      _soft80AlertSent = false;
      _prevTradesToday = 0;
      _prevDailyPnl = null;
      _consecutiveLossesLocal = 0;
      _consecutiveLossAlertSent = false;
      _baselineLotSizeToday = null;
      _lotSizeAlertSent = false;
      _planViolationAlertSent = false;
      _prevOpenPositions = -1;
      _lastPositionCloseTime = null;
      _fastReentryAlertSent = false;
      state = state.copyWith(
        data: state.data.copyWith(
          dailyPnl: null,
          dailyLossUsd: null,
          dailyLossPct: null,
          tradesToday: null,
        ),
      );
      // Reset rules daily counter
      try { _ref.read(rulesProvider.notifier).resetDay(); } catch (_) {}
      // Deactivate killswitch if it was triggered yesterday
      final ks = _ref.read(killswitchProvider);
      if (ks.isActive && ks.activatedAt != null) {
        final activatedDay = DateTime(ks.activatedAt!.year, ks.activatedAt!.month, ks.activatedAt!.day);
        if (activatedDay.isBefore(today)) {
          _ref.read(killswitchProvider.notifier).deactivate();
        }
      }
      _dailyBriefingTriggered = false; // reset so next day briefing can fire
      _triggerDailyChallengeBriefing(); // fire briefing for new day
    }
  }

  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final duration = nextMidnight.difference(now);
    _midnightTimer = Timer(duration, () {
      if (!mounted) return;
      _checkAndResetDailyIfNeeded();
      _scheduleMidnightReset();
    });
  }

  // ── Caricamento connessione persistente ─────────────────────────────────────

  Future<void> _loadPersistedConnection() async {
    if (kDevMode) return;
    try {
      // 1. Prova a ripristinare connessione EA da Supabase
      final userId = _ref.read(currentUserIdProvider);
      if (userId.isNotEmpty) {
        final rows = await Supabase.instance.client
            .from('broker_connections')
            .select('connection_type, webhook_secret, live_data, status')
            .eq('user_id', userId)
            .order('last_sync_at', ascending: false)
            .limit(1);

        if ((rows as List).isNotEmpty) {
          final row = Map<String, dynamic>.from(rows.first as Map);
          final connType = row['connection_type'] as String? ?? '';
          if (connType == 'ea_webhook') {
            final secret = row['webhook_secret'] as String?;
            if (secret != null && secret.isNotEmpty) {
              state = BrokerState(
                method: BrokerConnectionMethod.ea,
                status: BrokerConnectionStatus.connecting,
                webhookSecret: secret,
                statusMessage: 'Restoring EA connection...',
              );
              await _startEaRealtimeSubscription(userId, secret);
              _scheduleMidnightReset();
              return; // EA trovato, non serve accessibility
            }
          } else if (connType == 'accessibility') {
            // Accessibility connection saved to Supabase — restore it
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('connection_method', 'accessibility');
            } catch (_) {}
            state = BrokerState(
              method: BrokerConnectionMethod.accessibility,
              status: BrokerConnectionStatus.connecting,
              statusMessage: 'Reading MT5 data...',
            );
            _startAccessibilityStream();
            _startAccessibilityPolling();
            _scheduleMidnightReset();
            return;
          }
        }
      }

      // 2. Se nessun EA, controlla se l'Accessibility Service è già abilitato
      final prefs = await SharedPreferences.getInstance();
      // Controlliamo sia il flag salvato che lo stato reale del sistema (ridondanza)
      final savedMethod = prefs.getString('connection_method');
      final isEnabled = await AccessibilityService.isEnabled();
      if (!isEnabled && savedMethod != 'accessibility') return;

      // Imposta metodo accessibility e avvia subscription realtime + polling iniziale
      state = BrokerState(
        method: BrokerConnectionMethod.accessibility,
        status: BrokerConnectionStatus.connecting,
        statusMessage: 'Reading MT5 data...',
      );
      _startAccessibilityStream();
      _startAccessibilityPolling();

      // 3. Carica gli ultimi dati salvati dall'accessibility service
      //    (persistiti nelle SharedPreferences da PipLockAccessibilityService)
      final lastData = await AccessibilityService.getLastBrokerData();
      if (lastData == null) return;

      final ts = lastData['timestamp'] as int? ?? 0;
      final ageMs = DateTime.now().millisecondsSinceEpoch - ts;
      if (ageMs > 86400000) return; // scarta dati più vecchi di 24h

      final equity      = lastData['equity']       as double?;
      final balance     = lastData['balance']      as double?;
      final profitRaw   = lastData['profit']       as double?;
      final positions   = lastData['positions']    as int?;
      final tradesRaw   = lastData['trades_today'] as int?;

      final dataDate = DateTime.fromMillisecondsSinceEpoch(ts);
      final now2 = DateTime.now();
      final isToday = dataDate.year == now2.year &&
                      dataDate.month == now2.month &&
                      dataDate.day == now2.day;

      updateFromAccessibility(
        equity:      (equity      != null && equity      >= 0)  ? equity      : null,
        balance:     (balance     != null && balance     >= 0)  ? balance     : null,
        profit:      isToday ? ((profitRaw != null && !profitRaw.isNaN) ? profitRaw : null) : null,
        positions:   (positions   != null && positions   >= 0)  ? positions   : null,
        tradesToday: isToday ? ((tradesRaw != null && tradesRaw >= 0)  ? tradesRaw  : null) : null,
      );
    } catch (_) {}

    _scheduleMidnightReset();
  }

  // ── Connessione EA MQL5 ─────────────────────────────────────────────────────

  /// Configura la connessione tramite EA MQL5 webhook.
  /// Genera un webhook_secret UUID, lo salva su Supabase e avvia la subscription realtime.
  Future<String> connectEA() async {
    final userId = _ref.read(currentUserIdProvider);
    final secret = _generateSecret();

    state = BrokerState(
      method: BrokerConnectionMethod.ea,
      status: BrokerConnectionStatus.connecting,
      webhookSecret: secret,
      statusMessage: 'Configuring EA...',
    );

    try {
      if (!kDevMode) {
        await _upsertBrokerConnection(
          userId: userId,
          connectionType: 'ea_webhook',
          broker: 'mt5',
          webhookSecret: secret,
        );
      }

      await _startEaRealtimeSubscription(userId, secret);
      return secret;
    } catch (e) {
      state = BrokerState(
        method: BrokerConnectionMethod.none,
        status: BrokerConnectionStatus.error,
        error: 'EA configuration error: ${e.toString().replaceAll('Exception: ', '')}',
      );
      return secret;
    }
  }

  Future<void> _startEaRealtimeSubscription(String userId, String secret) async {
    await _realtimeSub?.cancel();

    if (kDevMode) {
      // In modalità dev: simula stato attesa senza subscription reale
      state = state.copyWith(
        status: BrokerConnectionStatus.connecting,
        statusMessage: 'Waiting for EA data...',
        error: null,
      );
      return;
    }

    try {
      _realtimeSub = Supabase.instance.client
          .from('broker_connections')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .listen((rows) {
            if (rows.isEmpty) return;

            // Cerca la riga con il webhook_secret corrispondente
            final matchingRows = rows.where(
              (r) => r['webhook_secret'] == secret && r['connection_type'] == 'ea_webhook',
            );
            if (matchingRows.isEmpty) return;

            final row = matchingRows.first;
            final liveData = row['live_data'] as Map<String, dynamic>?;

            if (liveData != null) {
              final newData = _brokerDataFromMap(liveData);
              state = state.copyWith(
                status: BrokerConnectionStatus.connected,
                data: newData,
                error: null,
                statusMessage: null,
              );
              _checkLimits(newData);
            } else {
              // Connessione configurata ma ancora nessun dato dall'EA
              state = state.copyWith(
                status: BrokerConnectionStatus.connecting,
                statusMessage: 'Waiting for EA data...',
              );
            }
          }, onError: (_) {
            state = state.copyWith(
              status: BrokerConnectionStatus.error,
              error: 'Error receiving realtime data.',
            );
          });

      state = state.copyWith(
        statusMessage: 'Waiting for EA data...',
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: BrokerConnectionStatus.error,
        error: 'Realtime connection error: ${e.toString()}',
      );
    }
  }

  // ── Connessione Accessibility Service (mobile) ──────────────────────────────

  /// Attiva il monitoraggio via Accessibility Service.
  /// Verifica subito se il servizio è attivo, poi polling ogni 2s fino a conferma.
  Future<void> connectAccessibility() async {
    state = BrokerState(
      method: BrokerConnectionMethod.accessibility,
      status: BrokerConnectionStatus.connecting,
      statusMessage: 'Checking accessibility permissions...',
    );
    // Persisti il metodo scelto così viene ripristinato al prossimo avvio app
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('connection_method', 'accessibility');
    } catch (_) {}
    // Also save to Supabase so connection survives a reinstall
    try {
      if (!kDevMode) {
        final userId = _ref.read(currentUserIdProvider);
        if (userId.isNotEmpty) {
          await _upsertBrokerConnection(
            userId: userId,
            connectionType: 'accessibility',
            broker: 'mt5',
          );
        }
      }
    } catch (_) {}
    _startAccessibilityStream();
    await _checkAccessibilityAndUpdate();
    _startAccessibilityPolling();
    _scheduleMidnightReset();
  }

  Future<void> _checkAccessibilityAndUpdate() async {
    try {
      final enabled = await AccessibilityService.isEnabled();
      final running = await AccessibilityService.isRunning();
      if (!mounted) return;
      if (state.method != BrokerConnectionMethod.accessibility) return;

      if (enabled && running) {
        state = state.copyWith(
          status: BrokerConnectionStatus.connected,
          statusMessage: 'Service active — open MT5 to read data',
          error: null,
        );
        _accessibilityTimer?.cancel();
      } else if (enabled) {
        state = state.copyWith(
          statusMessage: 'Permission OK — restart service in Settings → Accessibility',
        );
      } else {
        state = state.copyWith(
          statusMessage: 'Enable PipLock in Settings → Accessibility → Downloaded apps',
        );
      }
    } catch (_) {}
  }

  void _startAccessibilityPolling() {
    _accessibilityTimer?.cancel();
    _accessibilityTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) { _accessibilityTimer?.cancel(); return; }
      if (state.method != BrokerConnectionMethod.accessibility) {
        _accessibilityTimer?.cancel();
        return;
      }
      if (state.status == BrokerConnectionStatus.connected &&
          state.data.equity != null) {
        _accessibilityTimer?.cancel();
        return;
      }
      await _checkAccessibilityAndUpdate();
    });
  }

  /// Subscription realtime all'EventChannel dell'Accessibility Service.
  /// Riceve ogni estrazione dati da Kotlin e aggiorna il provider Flutter.
  void _startAccessibilityStream() {
    _accessibilitySub?.cancel();
    _accessibilitySub = AccessibilityService.brokerEvents.listen((event) async {
      if (!mounted) return;
      final eventType = event['event_type'] as String? ?? '';

      if (eventType == 'broker_data') {
        final equityRaw       = event['equity']         as double?;
        final balanceRaw      = event['balance']        as double?;
        final profitRaw       = event['profit']         as double?;
        final positionsRaw    = event['positions']      as int?;
        final tradesTodayRaw  = event['trades_today']   as int?;
        final accountNumRaw   = event['account_number'] as String?;

        if (accountNumRaw != null && accountNumRaw.isNotEmpty) {
          state = state.copyWith(detectedAccountNumber: accountNumRaw);
        }

        updateFromAccessibility(
          equity:      (equityRaw      != null && equityRaw      >= 0)  ? equityRaw      : null,
          balance:     (balanceRaw     != null && balanceRaw     >= 0)  ? balanceRaw     : null,
          profit:      (profitRaw      != null && !profitRaw.isNaN)     ? profitRaw      : null,
          positions:   (positionsRaw   != null && positionsRaw   >= 0)  ? positionsRaw   : null,
          tradesToday: (tradesTodayRaw != null && tradesTodayRaw >= 0)  ? tradesTodayRaw : null,
        );
      } else if (eventType == 'account_switched') {
        final toAccount = event['to_account'] as String? ?? '';
        final fromAccount = event['from_account'] as String? ?? '';
        if (toAccount.isNotEmpty) {
          // Update detected account number
          state = state.copyWith(detectedAccountNumber: toAccount);

          // Reset ALL daily tracking state — new account = fresh session
          _positionsBaselineSet = false;
          _lastNonZeroPositions = 0;
          _positionsDroppedToZero = false;
          _soft80AlertSent = false;
          _prevTradesToday = 0;
          _prevDailyPnl = null;
          _consecutiveLossesLocal = 0;
          _consecutiveLossAlertSent = false;
          _baselineLotSizeToday = null;
          _lotSizeAlertSent = false;
          _planViolationAlertSent = false;
          _prevOpenPositions = -1;
          _lastPositionCloseTime = null;
          _fastReentryAlertSent = false;

          // Reset broker data to avoid showing yesterday's data for new account
          state = state.copyWith(
            data: state.data.copyWith(
              tradesToday: 0,
              dailyPnl: null,
              dailyLossUsd: null,
              dailyLossPct: null,
            ),
          );

          // Sync the correct rules for the newly active account to native
          _syncRulesForDetectedAccount(toAccount);

          // Notify user
          NotificationService.showLocalNotification(
            title: 'Account switched',
            body: fromAccount.isNotEmpty
                ? 'Active account: $toAccount (was $fromAccount). Rules updated.'
                : 'Active account: $toAccount. Rules updated.',
            id: 8011,
          );
        }
      } else if (eventType == 'revenge_detected') {
        if (event['revenge_detected'] == true) {
          try {
            _ref.read(killswitchProvider.notifier).activateWithDurationString('revenge_pattern', 'midnight');
          } catch (_) {}
        }
      } else if (eventType == 'fomo_detected') {
        if (event['fomo_detected'] == true) {
          try {
            await AccessibilityService.showFomoOverlay();
          } catch (_) {}
          try {
            _ref.read(gatekeeperActiveProvider.notifier).state = true;
          } catch (_) {}
        }
      } else if (eventType == 'killswitch_native_active') {
        final reason = event['reason'] as String? ?? 'daily_loss';
        final remainingMin = event['remaining_minutes'] as int? ?? 360;
        try {
          _ref.read(killswitchProvider.notifier).activateNative(reason, remainingMin);
        } catch (_) {}
      } else if (eventType == 'navigate_to_rules') {
        // Token used on MT5 overlay → deduct token, bypass rules lock, navigate
        try {
          await _ref.read(killswitchProvider.notifier).useToken();
        } catch (_) {}
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('killswitch_token_used', true);
        } catch (_) {}
        if (mounted) {
          _ref.read(pendingNavigationProvider.notifier).state = '/personal_rules';
        }
      }
    });
  }

  /// Aggiorna il nome dell'app broker rilevata (es. "MetaTrader 5").
  void setDetectedApp(String appName) {
    state = state.copyWith(
      detectedAppName: appName,
      method: BrokerConnectionMethod.accessibility,
      status: state.status == BrokerConnectionStatus.disconnected
          ? BrokerConnectionStatus.connecting
          : state.status,
      statusMessage: 'Reading from $appName...',
    );
  }

  // ── Connessione MetaAPI ─────────────────────────────────────────────────────

  /// Connette l'account tramite MetaAPI Cloud (polling ogni 30s).
  Future<void> connectMetaApi(String accountId) async {
    if (accountId.isEmpty) return;

    _metaApiTimer?.cancel();
    state = BrokerState(
      method: BrokerConnectionMethod.metaApi,
      status: BrokerConnectionStatus.connecting,
      metaApiAccountId: accountId,
      statusMessage: 'Connecting to MetaAPI...',
    );

    // Verifica immediata
    final data = await MetaApiService.fetchFullData(accountId);
    if (!mounted) return;

    if (data == null) {
      state = state.copyWith(
        status: BrokerConnectionStatus.error,
        error: 'Unable to connect to MetaAPI. Check your Account ID and token.',
      );
      return;
    }

    final newData = _brokerDataFromMetaApi(data);
    state = state.copyWith(
      status: BrokerConnectionStatus.connected,
      data: newData,
      error: null,
      statusMessage: null,
    );
    _checkLimits(newData);

    // Polling ogni 30 secondi
    _metaApiTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _pollMetaApi(accountId);
    });
  }

  Future<void> _pollMetaApi(String accountId) async {
    final data = await MetaApiService.fetchFullData(accountId);
    if (!mounted) return;
    if (data == null) return; // mantieni l'ultimo stato valido in caso di errore transitorio

    final newData = _brokerDataFromMetaApi(data);
    state = state.copyWith(
      status: BrokerConnectionStatus.connected,
      data: newData,
      error: null,
      statusMessage: null,
    );
    _checkLimits(newData);
  }

  BrokerData _brokerDataFromMetaApi(Map<String, dynamic> data) {
    final equity = data['equity'] as double?;
    final balance = data['balance'] as double?;
    final dailyPnl = data['dailyPnl'] as double?;
    final openPositions = data['openPositions'] as int?;
    final currency = data['currency'] as String?;

    final lossUsd = dailyPnl != null && dailyPnl < 0 ? dailyPnl.abs() : null;
    final lossPct = (lossUsd != null && balance != null && balance > 0)
        ? lossUsd / balance * 100
        : null;
    final drawdownPct = (equity != null && balance != null && balance > 0 && equity < balance)
        ? (balance - equity) / balance * 100
        : null;

    return BrokerData(
      equity: equity,
      balance: balance,
      dailyPnl: dailyPnl,
      dailyLossUsd: lossUsd,
      dailyLossPct: lossPct,
      drawdownPct: drawdownPct,
      openPositions: openPositions,
      currency: currency,
      lastUpdate: DateTime.now(),
    );
  }

  // ── Aggiornamento manuale ───────────────────────────────────────────────────

  /// Aggiorna i dati broker inseriti manualmente dall'utente.
  void updateManual({
    double? equity,
    double? balance,
    double? dailyPnl,
    int? openPositions,
    int? tradesToday,
    String? currency,
  }) {
    // Calcola perdita giornaliera dal P&L (se negativo)
    final lossUsd = dailyPnl != null ? (dailyPnl < 0 ? dailyPnl.abs() : 0.0) : null;
    final startBalance = balance ?? state.data.balance;
    final lossPct = (lossUsd != null && startBalance != null && startBalance > 0)
        ? (lossUsd / startBalance * 100)
        : null;

    final newData = BrokerData(
      equity: equity ?? state.data.equity,
      balance: balance ?? state.data.balance,
      dailyPnl: dailyPnl ?? state.data.dailyPnl,
      dailyLossUsd: lossUsd ?? state.data.dailyLossUsd,
      dailyLossPct: lossPct ?? state.data.dailyLossPct,
      openPositions: openPositions ?? state.data.openPositions,
      tradesToday: tradesToday ?? state.data.tradesToday,
      currency: currency ?? state.data.currency,
      lastUpdate: DateTime.now(),
    );

    // Se non era ancora in modalità manuale, imposta il metodo
    final currentMethod = state.method == BrokerConnectionMethod.none
        ? BrokerConnectionMethod.manual
        : state.method;

    state = state.copyWith(
      method: currentMethod,
      status: BrokerConnectionStatus.connected,
      data: newData,
      error: null,
      statusMessage: null,
    );

    _checkLimits(newData);
  }

  /// Attiva la modalità manuale senza ancora inserire dati.
  void activateManualMode() {
    state = BrokerState(
      method: BrokerConnectionMethod.manual,
      status: BrokerConnectionStatus.connected,
      data: const BrokerData(),
    );
  }

  // ── Aggiornamento da Accessibility Service ──────────────────────────────────

  /// Aggiorna i dati estratti dall'Accessibility Service (MT5/cTrader mobile).
  ///
  /// [tradesToday] — conteggio cumulativo dei trade aperti oggi, calcolato dal
  /// lato Kotlin via delta-margine (disponibile solo quando extractMT5ByViewId
  /// funziona, cioè MT5 Trade tab con resource ID leggibili). Se null, Flutter
  /// calcola il conteggio in modo autonomo tramite le variazioni di [positions].
  void updateFromAccessibility({
    double? equity,
    double? balance,
    double? profit,
    int? positions,
    int? tradesToday,
  }) {
    // Ignora valori sentinella (-1 per i doppi, -1 per gli int)
    final validEquity = (equity != null && equity >= 0) ? equity : null;
    final validBalance = (balance != null && balance >= 0) ? balance : null;
    final validProfit = (profit != null && !profit.isNaN) ? profit : null;
    final validPositions = (positions != null && positions >= 0) ? positions : null;

    if (validEquity == null && validBalance == null && validProfit == null) return;

    final prevBalance = validBalance ?? state.data.balance;
    final dayLossUsd = validProfit != null && validProfit < 0 ? validProfit.abs() : null;
    final dayLossPct = (dayLossUsd != null && prevBalance != null && prevBalance > 0)
        ? dayLossUsd / prevBalance * 100
        : null;
    final drawdownPct = (validEquity != null && validBalance != null && validBalance > 0 && validEquity < validBalance)
        ? (validBalance - validEquity) / validBalance * 100
        : null;

    // ── Conteggio trade aperti oggi ─────────────────────────────────────────
    // Due percorsi:
    // A) Kotlin invia trades_today (margin-delta, preciso, funziona con >9 trade):
    //    → usiamo direttamente il valore nativo; aggiorniamo il baseline per coerenza.
    // B) Kotlin non invia trades_today (text-based fallback, usa childCount visibile):
    //    → Flutter conta i nuovi trade confrontando le variazioni di positions.
    int? newTradesToday = state.data.tradesToday;

    if (tradesToday != null) {
      // ── Percorso A: valore accurato da Kotlin ────────────────────────────
      newTradesToday = tradesToday;
      // Aggiorna il baseline Flutter così se in futuro Kotlin smette di inviare
      // trades_today (cambio tab) non ripartiamo da zero.
      if (validPositions != null && validPositions > 0) {
        _positionsBaselineSet = true;
        _lastNonZeroPositions = validPositions;
        _positionsDroppedToZero = false;
      }
    } else {
      // ── Percorso B: fallback Flutter (text-based extraction) ─────────────
      if (validPositions != null) {
        if (!_positionsBaselineSet) {
          _positionsBaselineSet = true;
          _lastNonZeroPositions = validPositions;
          // Prima lettura: registra baseline senza contare come nuovi trade
        } else if (validPositions == 0) {
          // MT5 in background o nessuna posizione — salva ultimo conteggio noto
          if (validPositions == 0 && _lastNonZeroPositions > 0) {
            _positionsDroppedToZero = true;
          }
        } else if (_positionsDroppedToZero) {
          // Posizioni tornate da zero: sono SEMPRE nuovi trade
          _positionsDroppedToZero = false;
          final newlyOpened = validPositions;
          newTradesToday = (state.data.tradesToday ?? 0) + newlyOpened;
          _lastNonZeroPositions = validPositions;
          for (var i = 0; i < newlyOpened; i++) {
            try { _ref.read(rulesProvider.notifier).trackTrade(); } catch (_) {}
          }
        } else if (validPositions > _lastNonZeroPositions) {
          // Caso normale: nuove posizioni aperte mentre MT5 era aperto.
          final newlyOpened = validPositions - _lastNonZeroPositions;
          newTradesToday = (state.data.tradesToday ?? 0) + newlyOpened;
          _lastNonZeroPositions = validPositions;
          for (var i = 0; i < newlyOpened; i++) {
            try { _ref.read(rulesProvider.notifier).trackTrade(); } catch (_) {}
          }
          _checkFomoOnNewPosition(null);
        } else if (validPositions > 0) {
          _lastNonZeroPositions = validPositions;
        }
      }
    }

    final newData = state.data.copyWith(
      equity: validEquity ?? state.data.equity,
      balance: validBalance ?? state.data.balance,
      dailyPnl: validProfit ?? state.data.dailyPnl,
      dailyLossUsd: dayLossUsd ?? state.data.dailyLossUsd,
      dailyLossPct: dayLossPct ?? state.data.dailyLossPct,
      drawdownPct: drawdownPct ?? state.data.drawdownPct,
      // When positions = 0, keep the last known non-zero count (MT5 likely backgrounded or tab changed)
      openPositions: (validPositions != null && validPositions > 0) ? validPositions : state.data.openPositions,
      tradesToday: newTradesToday ?? state.data.tradesToday,
      lastUpdate: DateTime.now(),
    );

    final wasConnected = state.status == BrokerConnectionStatus.connected;
    state = state.copyWith(
      status: BrokerConnectionStatus.connected,
      data: newData,
      error: null,
      statusMessage: null,
    );

    if (!wasConnected) {
      // Prima volta che riceviamo dati dall'accessibility
    }

    _checkLimits(newData);
  }

  // ── Disconnessione ──────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    await _realtimeSub?.cancel();
    _realtimeSub = null;
    _accessibilitySub?.cancel();
    _accessibilitySub = null;
    _metaApiTimer?.cancel();
    _metaApiTimer = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('connection_method');
    } catch (_) {}

    try {
      final userId = _ref.read(currentUserIdProvider);
      if (userId.isNotEmpty && !kDevMode) {
        await Supabase.instance.client
            .from('broker_connections')
            .delete()
            .eq('user_id', userId);
      }
    } catch (_) {}

    state = const BrokerState();
  }

  // ── Refresh manuale ─────────────────────────────────────────────────────────

  Future<void> refresh() async {
    // Per EA e accessibility: i dati arrivano in push, non serve polling.
    // Per manual: non si può aggiornare automaticamente.
    // Questo metodo esiste per compatibilità con la dashboard (bottone refresh).
  }

  // ── FOMO detection ─────────────────────────────────────────────────────────

  /// Checks Finnhub for a price spike on [symbol] when a new position is opened.
  /// If [symbol] is null, no Finnhub call is made (Accessibility Service limitation).
  /// The result is stored in [BrokerState.fomoSignal] for the UI to display.
  Future<void> _checkFomoOnNewPosition(String? symbol) async {
    if (symbol == null || symbol.isEmpty) return;
    try {
      final signal = await FomoDetectionService.checkSpike(symbol);
      if (!mounted || signal == null) return;
      state = state.copyWith(fomoSignal: signal);
      // Also surface as a local notification
      NotificationService.showLocalNotification(
        title: '⚠️ FOMO Alert — $symbol',
        body: signal.alertMessage,
        id: 8010,
      );
    } catch (_) {}
  }

  // ── Multi-account rules sync ────────────────────────────────────────────────

  /// Called after an "account_switched" event. Looks up the registered rules
  /// for [accountNumber] across personal accounts and active challenges, then
  /// calls [AccessibilityService.syncRulesToNative] so the Kotlin layer enforces
  /// the correct limits immediately — even if Flutter is in the background.
  void _syncRulesForDetectedAccount(String accountNumber) {
    try {
      // 1. Look for a personal account with this number
      final accounts = _ref.read(personalAccountsProvider).accounts;
      final matched = accounts.where(
        (a) => a.accountNumber != null && a.accountNumber == accountNumber,
      ).toList();

      if (matched.isNotEmpty) {
        final a = matched.first;
        final durationMin = _durationMinutes(a.killswitchDuration);
        final isPct = a.maxDailyLossType == 'percent';
        AccessibilityService.syncRulesToNative(
          maxDailyLossAmount: isPct ? null : a.maxDailyLoss,
          maxDailyLossPct:    isPct ? a.maxDailyLoss : null,
          maxTradesPerDay:    a.maxTradesPerDay,
          killswitchDurationMinutes: durationMin,
          accountNumber: accountNumber,
        );
        return;
      }

      // 2. Look for an active challenge with this account number
      final challenges = _ref.read(challengeListProvider);
      final challengeMatch = challenges.where(
        (c) => c.status == 'active' &&
               c.accountNumber != null &&
               c.accountNumber == accountNumber,
      ).toList();

      if (challengeMatch.isNotEmpty) {
        final c = challengeMatch.first;
        final plan = c.aiPlan;
        final hardPct = (plan?['hardKillswitchThreshold'] as num?)?.toDouble();
        final hardUsd = (hardPct != null && c.accountSize > 0)
            ? c.accountSize * hardPct / 100
            : null;
        AccessibilityService.syncRulesToNative(
          maxDailyLossAmount: hardUsd,
          maxDailyLossPct: hardPct,
          maxTradesPerDay: (plan?['recommendedTradesPerDay'] as num?)?.toInt(),
          killswitchDurationMinutes: 1440, // challenges: lock until midnight
          accountNumber: accountNumber,
        );
        // Scrivi il lot size raccomandato dal piano AI in SharedPreferences.
        // L'AccessibilityService Kotlin lo legge come metadata per il rilevamento
        // overleveraging (chiave: flutter.recommended_lot_size).
        final recommendedLotSize = (plan?['recommendedLotSize'] as num?)?.toDouble();
        if (recommendedLotSize != null && recommendedLotSize > 0) {
          SharedPreferences.getInstance().then((prefs) {
            prefs.setDouble('recommended_lot_size', recommendedLotSize);
          });
        }
        return;
      }

      // 3. No rules registered for this account — disable enforcement
      AccessibilityService.syncRulesToNative(
        maxDailyLossAmount: null,
        maxDailyLossPct: null,
        maxTradesPerDay: null,
        killswitchDurationMinutes: 360,
        accountNumber: accountNumber,
      );
    } catch (_) {}
  }

  /// Builds the full account→rules map and pushes it to native SharedPreferences
  /// so the Kotlin service can load rules instantly on account switch without
  /// needing to call back into Flutter.
  ///
  /// Call this on app start and whenever accounts or challenges change.
  Future<void> syncAllAccountsToNative() async {
    try {
      final rulesMap = <String, Map<String, dynamic>>{};

      // Personal accounts
      final accounts = _ref.read(personalAccountsProvider).accounts;
      for (final a in accounts) {
        final num = a.accountNumber;
        if (num == null || num.isEmpty) continue;
        final isPct = a.maxDailyLossType == 'percent';
        rulesMap[num] = {
          'max_daily_loss_amount': isPct ? -1.0 : (a.maxDailyLoss ?? -1.0),
          'max_daily_loss_pct':    isPct ? (a.maxDailyLoss ?? -1.0) : -1.0,
          'max_trades_per_day':    a.maxTradesPerDay ?? -1,
          'killswitch_duration_minutes': _durationMinutes(a.killswitchDuration),
          'trading_hours_enabled': a.tradingHoursEnabled,
          'trading_hours_start':   a.tradingHoursStart ?? '',
          'trading_hours_end':     a.tradingHoursEnd ?? '',
        };
      }

      // Challenges
      final challenges = _ref.read(challengeListProvider);
      for (final c in challenges.where((x) => x.status == 'active')) {
        final accNum = c.accountNumber;
        if (accNum == null || accNum.isEmpty) continue;
        final plan = c.aiPlan;
        final hardPct = (plan?['hardKillswitchThreshold'] as num?)?.toDouble() ?? -1.0;
        final hardUsd = (hardPct > 0 && c.accountSize > 0)
            ? c.accountSize * hardPct / 100
            : -1.0;
        rulesMap[accNum] = {
          'max_daily_loss_amount': hardUsd,
          'max_daily_loss_pct':    hardPct,
          'max_trades_per_day':
              (plan?['recommendedTradesPerDay'] as num?)?.toInt() ?? -1,
          'killswitch_duration_minutes': 1440,
          'trading_hours_enabled': false,
          'trading_hours_start':   '',
          'trading_hours_end':     '',
        };
      }

      if (rulesMap.isNotEmpty) {
        await AccessibilityService.syncMultiAccountRules(rulesMap);
      }
    } catch (_) {}
  }

  // ── Controllo limiti → killswitch ───────────────────────────────────────────

  /// Filtra le challenge attive per l'account attualmente rilevato su MT5.
  /// Se non c'è account number rilevato, restituisce tutte le challenge attive.
  List<Challenge> _challengesForCurrentAccount(List<Challenge> challenges) {
    final detected = state.detectedAccountNumber;
    final active = challenges.where((c) => c.status == 'active').toList();
    if (detected == null || detected.isEmpty) return active;
    final matched = active.where((c) =>
      c.accountNumber != null && c.accountNumber!.isNotEmpty &&
      c.accountNumber == detected
    ).toList();
    return matched.isNotEmpty ? matched : active;
  }

  void _checkLimits(BrokerData data) {
    _checkAndResetDailyIfNeeded();
    final ksState = _ref.read(killswitchProvider);
    if (ksState.isActive || _isActivating) return;

    final rules = _ref.read(rulesProvider).rules;
    if (rules == null) return;

    final dayLossUsd = data.dailyLossUsd ?? 0.0;
    final dayLossPct = data.dailyLossPct ?? 0.0;
    final tradesToday = data.tradesToday ?? 0;

    // ── 1. Perdite consecutive ────────────────────────────────────────────
    // Usa il valore dell'EA se disponibile, altrimenti traccia in Flutter
    final consecutiveLossesFromEa = data.consecutiveLosses;
    if (consecutiveLossesFromEa != null) {
      _consecutiveLossesLocal = consecutiveLossesFromEa;
    } else {
      // Flutter-side tracking: rileva quando tradesToday aumenta e confronta daily PnL
      final currentTrades = data.tradesToday ?? 0;
      if (currentTrades > _prevTradesToday && _prevTradesToday >= 0) {
        final currPnl = data.dailyPnl ?? 0.0;
        final prevPnl = _prevDailyPnl ?? currPnl;
        if (currPnl < prevPnl) {
          _consecutiveLossesLocal++;
        } else {
          _consecutiveLossesLocal = 0;
        }
        _prevTradesToday = currentTrades;
        _prevDailyPnl = data.dailyPnl;
      }
    }
    // Alert a 3 perdite consecutive
    if (_consecutiveLossesLocal >= 3 && !_consecutiveLossAlertSent) {
      _consecutiveLossAlertSent = true;
      NotificationService.showLocalNotification(
        title: '⚠️ $_consecutiveLossesLocal consecutive losses',
        body: 'You have lost $_consecutiveLossesLocal trades in a row. Consider stepping back.',
        id: 8006,
      );
    }

    // ── 2. Aumento anomalo della size (lot size) ─────────────────────────
    final lotSize = data.lastLotSize;
    if (lotSize != null && lotSize > 0) {
      _baselineLotSizeToday ??= lotSize;
      if (!_lotSizeAlertSent && lotSize > (_baselineLotSizeToday! * 2.0)) {
        _lotSizeAlertSent = true;
        NotificationService.showLocalNotification(
          title: '⚠️ Lot size anomaly',
          body:
              'Your position size (${lotSize.toStringAsFixed(2)}) is 2× your usual size today. Check your risk.',
          id: 8007,
        );
      }
    }

    // ── 3. Re-entry troppo veloce ────────────────────────────────────────
    final currentPositions = data.openPositions ?? 0;
    if (_prevOpenPositions > 0 && currentPositions < _prevOpenPositions) {
      _lastPositionCloseTime = DateTime.now();
      _fastReentryAlertSent = false;
    }
    if (_lastPositionCloseTime != null &&
        _prevOpenPositions >= 0 &&
        currentPositions > _prevOpenPositions &&
        !_fastReentryAlertSent) {
      final secondsFromClose =
          DateTime.now().difference(_lastPositionCloseTime!).inSeconds;
      if (secondsFromClose < 120) {
        _fastReentryAlertSent = true;
        NotificationService.showLocalNotification(
          title: '⚡ Fast re-entry',
          body:
              'You re-entered the market ${secondsFromClose}s after closing. Is this intentional?',
          id: 8008,
        );
      }
    }
    _prevOpenPositions = currentPositions;

    // ── Alert all'80% del limite giornaliero ────────────────────────────────
    if (rules.maxDailyLoss != null && rules.maxDailyLoss! > 0) {
      final lossValue = rules.maxDailyLossType == 'percent' ? dayLossPct : dayLossUsd;
      final lossPercent = lossValue / rules.maxDailyLoss!;
      if (lossPercent >= 0.80 && lossPercent < 1.0 && !_soft80AlertSent) {
        _soft80AlertSent = true;
        NotificationService.showLocalNotification(
          title: '⚠️ 80% of daily limit reached',
          body: 'You are close to your daily loss limit. Consider stopping.',
          id: 8001,
        );
      }
      if (lossPercent < 0.80) _soft80AlertSent = false;
    }

    String? reason;

    if (rules.maxDailyLoss != null && rules.maxDailyLoss! > 0) {
      if (rules.maxDailyLossType == 'percent') {
        if (dayLossPct >= rules.maxDailyLoss!) reason = 'daily_loss';
      } else {
        if (dayLossUsd >= rules.maxDailyLoss!) reason = 'daily_loss';
      }
    }

    // Controlla anche le soglie del piano AI per le challenge attive
    if (reason == null) {
      try {
        final challenges = _ref.read(challengeListProvider);
        final activeChallenges = _challengesForCurrentAccount(challenges);
        for (final challenge in activeChallenges) {
          final plan = challenge.aiPlan;
          if (plan == null) continue;
          final accountSize = challenge.accountSize;
          final hardThresholdPct = (plan['hardKillswitchThreshold'] as num?)?.toDouble();
          final softThresholdPct = (plan['softKillswitchThreshold'] as num?)?.toDouble();
          if (hardThresholdPct != null && hardThresholdPct > 0 && accountSize > 0) {
            final hardThresholdUsd = accountSize * hardThresholdPct / 100;
            if (dayLossUsd >= hardThresholdUsd) {
              reason = 'daily_loss';
              break;
            }
          }
          if (reason == null && softThresholdPct != null && softThresholdPct > 0 && accountSize > 0) {
            final softThresholdUsd = accountSize * softThresholdPct / 100;
            if (dayLossUsd >= softThresholdUsd) {
              // Soft killswitch: solo alert, non full lock
              AccessibilityService.showTradeLimitOverlay(
                currentTrades: data.tradesToday ?? 0,
                maxTrades: 0,
              );
              break;
            }
          }
        }
      } catch (_) {}
    }

    final maxTrades = rules.maxTradesPerDay;
    if (reason == null && maxTrades != null && maxTrades > 0 && tradesToday >= maxTrades) {
      reason = 'max_trades';
    }

    // ── 4. Violazione del piano AI (trades > recommendedTradesPerDay) ────
    if (reason == null && !_planViolationAlertSent) {
      try {
        final challenges = _ref.read(challengeListProvider);
        for (final c in _challengesForCurrentAccount(challenges)) {
          final plan = c.aiPlan;
          if (plan == null) continue;
          final recTrades = (plan['recommendedTradesPerDay'] as num?)?.toInt();
          if (recTrades != null && tradesToday > recTrades) {
            _planViolationAlertSent = true;
            NotificationService.showLocalNotification(
              title: '📋 AI Plan exceeded',
              body:
                  'You have made $tradesToday trades today. Your AI plan recommends max $recTrades.',
              id: 8009,
            );
            break;
          }
        }
      } catch (_) {}
    }

    // ── 5. Killswitch a 5 perdite consecutive ────────────────────────────
    if (reason == null && _consecutiveLossesLocal >= 5) {
      reason = 'consecutive_losses';
    }

    // Nota: rimosso il check drawdown hardcoded al 10% — era fonte di falsi positivi.
    // Il drawdown verrà gestito tramite i parametri della challenge (piano AI) in futuro.

    // ── Check drawdown totale per challenge attiva ──────────────────────────
    if (reason == null) {
      try {
        final challenges = _ref.read(challengeListProvider);
        final activeChallengesForAccount = _challengesForCurrentAccount(challenges);
        final activeChallenge = activeChallengesForAccount.isNotEmpty
            ? activeChallengesForAccount.first
            : null;
        if (activeChallenge != null) {
          final maxTotalDrawdown = activeChallenge.maxTotalDrawdown;
          final currentEquity = data.equity ?? 0;
          final startEquity = activeChallenge.accountSize;
          if (startEquity > 0 && currentEquity > 0) {
            final drawdownPct = (startEquity - currentEquity) / startEquity * 100;
            if (drawdownPct >= maxTotalDrawdown) {
              reason = 'daily_loss';
              SupabaseService.updateChallengeStatus(activeChallenge.id, 'failed').catchError((_) {});
              NotificationService.showLocalNotification(
                title: '❌ Challenge Failed',
                body: 'Max drawdown reached. Your challenge has been marked as failed.',
                id: 8003,
              );
            }
          }
        }
      } catch (_) {}
    }

    if (reason != null) {
      _isActivating = true;
      final userId = _ref.read(currentUserIdProvider);
      final durationMin = _durationMinutes(rules.killswitchDuration);
      _ref.read(killswitchProvider.notifier).activateAndSave(
            reason,
            durationMin,
            userId,
            'personal',
          );
      // Reset after microtask — ksState.isActive will be true by then
      Future.microtask(() { _isActivating = false; });
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  BrokerData _brokerDataFromMap(Map<String, dynamic> map) {
    final equity = (map['equity'] as num?)?.toDouble();
    final balance = (map['balance'] as num?)?.toDouble();
    final dailyPnl = (map['daily_pnl'] as num?)?.toDouble();
    final dailyLossUsd = (map['daily_loss_usd'] as num?)?.toDouble();
    final dailyLossPct = (map['daily_loss_pct'] as num?)?.toDouble();
    final drawdownPct = (map['drawdown_pct'] as num?)?.toDouble();
    final openPositions = (map['open_positions'] as num?)?.toInt();
    final tradesToday = (map['trades_today'] as num?)?.toInt();
    final currency = map['currency'] as String?;
    final consecutiveLosses = (map['consecutive_losses'] as num?)?.toInt();
    final lastLotSize = (map['last_lot_size'] as num?)?.toDouble();

    return BrokerData(
      equity: equity,
      balance: balance,
      dailyPnl: dailyPnl,
      dailyLossUsd: dailyLossUsd,
      dailyLossPct: dailyLossPct,
      drawdownPct: drawdownPct,
      openPositions: openPositions,
      tradesToday: tradesToday,
      currency: currency,
      lastUpdate: DateTime.now(),
      consecutiveLosses: consecutiveLosses,
      lastLotSize: lastLotSize,
    );
  }

  Future<void> _upsertBrokerConnection({
    required String userId,
    required String connectionType,
    required String broker,
    String? webhookSecret,
  }) async {
    final existing = await Supabase.instance.client
        .from('broker_connections')
        .select('id')
        .eq('user_id', userId)
        .eq('connection_type', connectionType)
        .maybeSingle();

    final data = {
      'user_id': userId,
      'connection_type': connectionType,
      'broker': broker,
      'webhook_secret': webhookSecret,
      'status': 'connected',
      'last_sync_at': DateTime.now().toIso8601String(),
    };

    if (existing != null) {
      await Supabase.instance.client
          .from('broker_connections')
          .update(data)
          .eq('user_id', userId)
          .eq('connection_type', connectionType);
    } else {
      await Supabase.instance.client.from('broker_connections').insert(data);
    }
  }

  /// Genera un UUID v4 casuale senza dipendenze esterne
  String _generateSecret() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // versione 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC4122
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  int _durationMinutes(String d) {
    switch (d) {
      case '2h':
        return 120;
      case '6h':
        return 360;
      case '24h':
        return 1440;
      default:
        final now = DateTime.now();
        final midnight = DateTime(now.year, now.month, now.day + 1);
        return midnight.difference(now).inMinutes;
    }
  }

  // ── Aggiornamento da EA MQL5 via Supabase Realtime ─────────────────────────

  /// Chiamato da RealtimeProvider quando un UPDATE arriva su broker_connections.
  /// Aggiorna status e last_sync_at nella UI senza toccare i dati finanziari
  /// (quelli arrivano tramite il webhook EA direttamente a Supabase).
  void updateConnectionStatusFromEa(String status) {
    final mapped = switch (status) {
      'connected' => BrokerConnectionStatus.connected,
      'error' => BrokerConnectionStatus.error,
      'disconnected' => BrokerConnectionStatus.disconnected,
      _ => BrokerConnectionStatus.disconnected,
    };
    if (state.status != mapped) {
      state = state.copyWith(status: mapped);
    }
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _accessibilitySub?.cancel();
    _accessibilityTimer?.cancel();
    _metaApiTimer?.cancel();
    _midnightTimer?.cancel();
    super.dispose();
  }

  // ── Daily challenge briefing ────────────────────────────────────────────────

  /// Genera il briefing giornaliero della challenge e lo aggiunge come nuova sessione
  /// nell'AI Planner. Chiamato una volta al giorno (al reset di mezzanotte o al primo
  /// caricamento delle challenge). È idempotente: verifica che non sia già stato
  /// generato oggi per questa challenge.
  Future<void> _triggerDailyChallengeBriefing() async {
    if (kDevMode) return;
    try {
      final challenges = _ref.read(challengeListProvider);
      final active = challenges.where((c) => c.status == 'active').toList();
      if (active.isEmpty) return;

      final challenge = active.first;

      // Controlla se il briefing è già stato generato oggi per questa challenge
      final prefs = await SharedPreferences.getInstance();
      final todayKey = _todayBriefingKey();
      final lastBriefingDate = prefs.getString('daily_briefing_${challenge.id}');
      if (lastBriefingDate == todayKey) return; // già fatto oggi

      // Segna subito come fatto (evita doppie generazioni se l'app viene riaperta)
      await prefs.setString('daily_briefing_${challenge.id}', todayKey);

      // Dati broker per contestualizzare il briefing
      final brokerData = state.isConnected
          ? {
              'equity': state.equity,
              'dailyPnl': state.dailyPnl,
              'tradesToday': state.tradesToday,
            }
          : <String, dynamic>{};

      // Giorno corrente calcolato da startedAt (non dipende dal campo DB)
      final currentDay = DateTime.now().difference(challenge.startedAt).inDays + 1;

      // Lingua dell'app (it o en)
      String locale = 'it';
      try {
        locale = _ref.read(localeProvider).languageCode;
      } catch (_) {}

      // Genera briefing via Groq
      final briefingText = await AiService.generateDailyChallengeBriefing(
        challenge: challenge,
        currentDay: currentDay,
        brokerData: brokerData,
        locale: locale,
      );

      // Crea nuova sessione nell'AI Planner con il briefing come primo messaggio
      final session = await _ref.read(chatHistoryProvider.notifier).createSession(
        type: 'challenge',
        contextName: challenge.propFirmName,
        challengeId: challenge.id,
      );
      final updatedSession = session.copyWith(
        plan: challenge.aiPlan,
        messages: [
          ChatMessage(
            text: briefingText,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        ],
        updatedAt: DateTime.now(),
      );
      await _ref.read(chatHistoryProvider.notifier).updateSession(updatedSession);

      // Notifica push
      NotificationService.showLocalNotification(
        title: locale.startsWith('it')
            ? '📋 Giorno $currentDay — piano pronto'
            : '📋 Day $currentDay — plan ready',
        body: locale.startsWith('it')
            ? 'Il tuo briefing per ${challenge.propFirmName ?? "la challenge"} è pronto.'
            : 'Your briefing for ${challenge.propFirmName ?? "the challenge"} is ready.',
        id: 9001,
      );
    } catch (_) {
      // Fail silently — daily briefing is non-critical
    }
  }

  static String _todayBriefingKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Provider
// ──────────────────────────────────────────────────────────────────────────────

final brokerProvider = StateNotifierProvider<BrokerNotifier, BrokerState>((ref) {
  return BrokerNotifier(ref);
});

// Alias per compatibilità con dashboard_screen.dart che usava metaApiProvider
final metaApiProvider = brokerProvider;

// Typedef per compatibilità con codice che usa MetaApiState
typedef MetaApiState = BrokerState;

/// True quando il Gatekeeper FOMO overlay deve essere mostrato nella dashboard.
/// Resettato a false quando l'utente lo chiude.
final gatekeeperActiveProvider = StateProvider<bool>((ref) => false);
