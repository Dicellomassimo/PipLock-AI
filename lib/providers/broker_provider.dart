import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../config/constants.dart';
import '../models/broker_data.dart';
import '../services/accessibility_service.dart';
import '../services/ctrader_service.dart';
import '../services/metaapi_service.dart';
import '../services/oanda_service.dart';
import 'challenge_provider.dart';
import 'killswitch_provider.dart';
import 'navigation_provider.dart';
import 'rules_provider.dart';
import 'auth_provider.dart';

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

  /// ID account cTrader (metodo cTrader)
  final String? ctraderId;

  /// Nome app broker rilevata dall'Accessibility Service (es. "MetaTrader 5")
  final String? detectedAppName;

  /// Account ID MetaAPI inserito dall'utente
  final String? metaApiAccountId;

  /// Numero account rilevato attualmente su MT5 dallo schermo
  final String? detectedAccountNumber;

  /// OANDA account ID
  final String? oandaAccountId;

  /// cTrader access token
  final String? ctraderAccessToken;

  const BrokerState({
    this.method = BrokerConnectionMethod.none,
    this.status = BrokerConnectionStatus.disconnected,
    this.data = const BrokerData(),
    this.error,
    this.statusMessage,
    this.webhookSecret,
    this.ctraderId,
    this.detectedAppName,
    this.metaApiAccountId,
    this.detectedAccountNumber,
    this.oandaAccountId,
    this.ctraderAccessToken,
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
    Object? ctraderId = _sentinel,
    Object? detectedAppName = _sentinel,
    Object? metaApiAccountId = _sentinel,
    Object? detectedAccountNumber = _sentinel,
    Object? oandaAccountId = _sentinel,
    Object? ctraderAccessToken = _sentinel,
  }) {
    return BrokerState(
      method: method ?? this.method,
      status: status ?? this.status,
      data: data ?? this.data,
      error: error == _sentinel ? this.error : error as String?,
      statusMessage: statusMessage == _sentinel ? this.statusMessage : statusMessage as String?,
      webhookSecret: webhookSecret == _sentinel ? this.webhookSecret : webhookSecret as String?,
      ctraderId: ctraderId == _sentinel ? this.ctraderId : ctraderId as String?,
      detectedAppName: detectedAppName == _sentinel ? this.detectedAppName : detectedAppName as String?,
      metaApiAccountId: metaApiAccountId == _sentinel ? this.metaApiAccountId : metaApiAccountId as String?,
      detectedAccountNumber: detectedAccountNumber == _sentinel ? this.detectedAccountNumber : detectedAccountNumber as String?,
      oandaAccountId: oandaAccountId == _sentinel ? this.oandaAccountId : oandaAccountId as String?,
      ctraderAccessToken: ctraderAccessToken == _sentinel ? this.ctraderAccessToken : ctraderAccessToken as String?,
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
  Timer? _ctraderTimer;
  Timer? _oandaTimer;

  DateTime? _lastResetDate;
  Timer? _midnightTimer;
  bool _isActivating = false;
  bool _positionsBaselineSet = false;
  int _lastNonZeroPositions = 0;
  bool _positionsDroppedToZero = false;

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
          }
        }
      }

      // 2. Check persisted cTrader credentials
      final prefs = await SharedPreferences.getInstance();
      final ctraderToken = prefs.getString('ctrader_access_token');
      final ctraderId = prefs.getString('ctrader_account_id');
      if (ctraderToken != null && ctraderId != null) {
        await connectCTrader(ctraderToken, ctraderId);
        _scheduleMidnightReset();
        return;
      }

      // 3. Check persisted OANDA credentials
      final oandaKey = prefs.getString('oanda_api_key');
      final oandaId = prefs.getString('oanda_account_id');
      if (oandaKey != null && oandaId != null) {
        final isDemo = prefs.getBool('oanda_is_demo') ?? false;
        await connectOanda(oandaKey, oandaId, isDemo: isDemo);
        _scheduleMidnightReset();
        return;
      }

      // 4. Se nessun EA/cTrader/OANDA, controlla se l'Accessibility Service è già abilitato
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

      final equity    = lastData['equity']    as double?;
      final balance   = lastData['balance']   as double?;
      final profitRaw = lastData['profit']    as double?;
      final positions = lastData['positions'] as int?;

      final dataDate = DateTime.fromMillisecondsSinceEpoch(ts);
      final now2 = DateTime.now();
      final isToday = dataDate.year == now2.year &&
                      dataDate.month == now2.month &&
                      dataDate.day == now2.day;

      updateFromAccessibility(
        equity:    (equity    != null && equity    >= 0)    ? equity    : null,
        balance:   (balance   != null && balance   >= 0)    ? balance   : null,
        profit:    isToday ? ((profitRaw != null && !profitRaw.isNaN) ? profitRaw : null) : null,
        positions: (positions != null && positions >= 0)    ? positions : null,
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

  // ── Connessione cTrader ─────────────────────────────────────────────────────

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
        final accountNumRaw   = event['account_number'] as String?;

        if (accountNumRaw != null && accountNumRaw.isNotEmpty) {
          state = state.copyWith(detectedAccountNumber: accountNumRaw);
        }

        updateFromAccessibility(
          equity:    (equityRaw    != null && equityRaw    >= 0)  ? equityRaw    : null,
          balance:   (balanceRaw   != null && balanceRaw   >= 0)  ? balanceRaw   : null,
          profit:    (profitRaw    != null && !profitRaw.isNaN)   ? profitRaw    : null,
          positions: (positionsRaw != null && positionsRaw >= 0)  ? positionsRaw : null,
        );
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

  /// Connect via cTrader REST API using an access token + account ID.
  /// Persists credentials to SharedPreferences and polls every 5 seconds.
  Future<void> connectCTrader(String accessToken, String accountId) async {
    if (accessToken.isEmpty || accountId.isEmpty) return;

    _ctraderTimer?.cancel();
    state = BrokerState(
      method: BrokerConnectionMethod.ctrader,
      status: BrokerConnectionStatus.connecting,
      ctraderId: accountId,
      ctraderAccessToken: accessToken,
      statusMessage: 'Connecting to cTrader...',
    );

    CTraderService.configure(accessToken, accountId);

    // Immediate first fetch
    final data = await CTraderService.fetchAccountData();
    if (!mounted) return;

    if (data == null) {
      state = state.copyWith(
        status: BrokerConnectionStatus.error,
        error: 'Unable to connect to cTrader. Check your access token and account ID.',
      );
      return;
    }

    final newData = _brokerDataFromCTrader(data);
    state = state.copyWith(
      status: BrokerConnectionStatus.connected,
      data: newData,
      error: null,
      statusMessage: null,
    );
    _checkLimits(newData);

    // Persist credentials
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ctrader_access_token', accessToken);
      await prefs.setString('ctrader_account_id', accountId);
    } catch (_) {}

    // Poll every 5 seconds
    _ctraderTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _pollCTrader();
    });
  }

  Future<void> _pollCTrader() async {
    final data = await CTraderService.fetchAccountData();
    if (!mounted) return;
    if (data == null) return;

    final newData = _brokerDataFromCTrader(data);
    state = state.copyWith(
      status: BrokerConnectionStatus.connected,
      data: newData,
      error: null,
      statusMessage: null,
    );
    _checkLimits(newData);
  }

  BrokerData _brokerDataFromCTrader(Map<String, dynamic> data) {
    final equity = data['equity'] as double?;
    final balance = data['balance'] as double?;
    final unrealizedPL = data['unrealizedPL'] as double?;
    final openPositions = data['openPositions'] as int?;
    final currency = data['currency'] as String?;

    // Use unrealizedPL as dailyPnl approximation
    final dailyPnl = unrealizedPL;
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

  /// Connect via OANDA REST API using an API key + account ID.
  /// Persists credentials to SharedPreferences and polls every 5 seconds.
  Future<void> connectOanda(
    String apiKey,
    String accountId, {
    bool isDemo = false,
  }) async {
    if (apiKey.isEmpty || accountId.isEmpty) return;

    _oandaTimer?.cancel();
    state = BrokerState(
      method: BrokerConnectionMethod.oanda,
      status: BrokerConnectionStatus.connecting,
      oandaAccountId: accountId,
      statusMessage: 'Connecting to OANDA...',
    );

    OandaService.configure(apiKey, accountId, isDemo: isDemo);

    // Immediate first fetch
    final data = await OandaService.fetchAccountSummary();
    if (!mounted) return;

    if (data == null) {
      state = state.copyWith(
        status: BrokerConnectionStatus.error,
        error: 'Unable to connect to OANDA. Check your API key and account ID.',
      );
      return;
    }

    final newData = _brokerDataFromOanda(data);
    state = state.copyWith(
      status: BrokerConnectionStatus.connected,
      data: newData,
      error: null,
      statusMessage: null,
    );
    _checkLimits(newData);

    // Persist credentials
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('oanda_api_key', apiKey);
      await prefs.setString('oanda_account_id', accountId);
      await prefs.setBool('oanda_is_demo', isDemo);
    } catch (_) {}

    // Poll every 5 seconds
    _oandaTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _pollOanda();
    });
  }

  Future<void> _pollOanda() async {
    final data = await OandaService.fetchAccountSummary();
    if (!mounted) return;
    if (data == null) return;

    final newData = _brokerDataFromOanda(data);
    state = state.copyWith(
      status: BrokerConnectionStatus.connected,
      data: newData,
      error: null,
      statusMessage: null,
    );
    _checkLimits(newData);
  }

  BrokerData _brokerDataFromOanda(Map<String, dynamic> data) {
    final equity = data['equity'] as double?;
    final balance = data['balance'] as double?;
    final unrealizedPL = data['unrealizedPL'] as double?;
    final openPositions = data['openPositionCount'] as int?;
    final currency = data['currency'] as String?;

    final dailyPnl = unrealizedPL;
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
  void updateFromAccessibility({
    double? equity,
    double? balance,
    double? profit,
    int? positions,
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

    // Traccia i trade aperti oggi: quando il conteggio posizioni aumenta,
    // significa che l'utente ha aperto nuovi trade — incrementa tradesToday.
    // La prima lettura stabilisce il baseline (posizioni già aperte prima dell'avvio)
    // e non viene contata come nuovi trade per evitare falsi positivi.
    final prevPositions = state.data.openPositions ?? 0;
    int? newTradesToday = state.data.tradesToday;
    if (validPositions != null) {
      if (!_positionsBaselineSet) {
        _positionsBaselineSet = true;
        _lastNonZeroPositions = validPositions;
        // Prima lettura: registra baseline senza contare come nuovi trade
      } else if (validPositions == 0) {
        // MT5 backgrounded or no positions — save last known count, don't count as closed trades
        if (prevPositions > 0) {
          _lastNonZeroPositions = prevPositions;
          _positionsDroppedToZero = true;
        }
      } else if (_positionsDroppedToZero && validPositions <= _lastNonZeroPositions) {
        // Came back from zero with same or fewer positions — same trades, not new
        _positionsDroppedToZero = false;
      } else if (_positionsDroppedToZero && validPositions > _lastNonZeroPositions) {
        // Came back from zero with MORE positions — only count the genuine new ones
        _positionsDroppedToZero = false;
        final newlyOpened = validPositions - _lastNonZeroPositions;
        newTradesToday = (state.data.tradesToday ?? 0) + newlyOpened;
        _lastNonZeroPositions = validPositions;
        for (var i = 0; i < newlyOpened; i++) {
          try { _ref.read(rulesProvider.notifier).trackTrade(); } catch (_) {}
        }
      } else if (validPositions > _lastNonZeroPositions) {
        // Normal case: new positions opened while MT5 was open.
        // Compares against _lastNonZeroPositions (not prevPositions) so that the
        // very first trade is counted even when baseline was 0.
        final newlyOpened = validPositions - _lastNonZeroPositions;
        newTradesToday = (state.data.tradesToday ?? 0) + newlyOpened;
        _lastNonZeroPositions = validPositions;
        for (var i = 0; i < newlyOpened; i++) {
          try { _ref.read(rulesProvider.notifier).trackTrade(); } catch (_) {}
        }
      } else if (validPositions > 0) {
        _lastNonZeroPositions = validPositions;
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
    _ctraderTimer?.cancel();
    _ctraderTimer = null;
    _oandaTimer?.cancel();
    _oandaTimer = null;

    // Clear ALL persisted connection data
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ctrader_access_token');
      await prefs.remove('ctrader_account_id');
      await prefs.remove('oanda_api_key');
      await prefs.remove('oanda_account_id');
      await prefs.remove('oanda_is_demo');
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

  // ── Controllo limiti → killswitch ───────────────────────────────────────────

  void _checkLimits(BrokerData data) {
    _checkAndResetDailyIfNeeded();
    final ksState = _ref.read(killswitchProvider);
    if (ksState.isActive || _isActivating) return;

    final rules = _ref.read(rulesProvider).rules;
    if (rules == null) return;

    final dayLossUsd = data.dailyLossUsd ?? 0.0;
    final dayLossPct = data.dailyLossPct ?? 0.0;
    final tradesToday = data.tradesToday ?? 0;

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
        final activeChallenges = challenges.where((c) => c.status == 'active');
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

    // Nota: rimosso il check drawdown hardcoded al 10% — era fonte di falsi positivi.
    // Il drawdown verrà gestito tramite i parametri della challenge (piano AI) in futuro.

    if (reason == 'max_trades') {
      // Trade limit: overlay arancio su MT5, non killswitch rosso
      // L'utente può ancora gestire le posizioni aperte
      AccessibilityService.showTradeLimitOverlay(
        currentTrades: tradesToday,
        maxTrades: rules.maxTradesPerDay ?? 0,
      );
    } else if (reason != null) {
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
    );
  }

  Future<void> _upsertBrokerConnection({
    required String userId,
    required String connectionType,
    required String broker,
    required String webhookSecret,
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

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _accessibilitySub?.cancel();
    _accessibilityTimer?.cancel();
    _metaApiTimer?.cancel();
    _ctraderTimer?.cancel();
    _oandaTimer?.cancel();
    _midnightTimer?.cancel();
    super.dispose();
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
