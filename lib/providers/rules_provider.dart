import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../models/personal_rules.dart';
import '../services/accessibility_service.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../config/constants.dart';
import 'auth_provider.dart';
import 'personal_accounts_provider.dart';

class RulesState {
  final PersonalRules? rules;
  final int tradesToday;
  final double lossToday;
  final bool isLoading;
  /// Score del check-in giornaliero (0 = non ancora fatto, 1-5 = punteggio)
  final int checkinScore;

  const RulesState({
    this.rules,
    this.tradesToday = 0,
    this.lossToday = 0.0,
    this.isLoading = false,
    this.checkinScore = 0,
  });

  RulesState copyWith({
    PersonalRules? rules,
    int? tradesToday,
    double? lossToday,
    bool? isLoading,
    int? checkinScore,
  }) {
    return RulesState(
      rules: rules ?? this.rules,
      tradesToday: tradesToday ?? this.tradesToday,
      lossToday: lossToday ?? this.lossToday,
      isLoading: isLoading ?? this.isLoading,
      checkinScore: checkinScore ?? this.checkinScore,
    );
  }

  /// Limite trades effettivo per oggi, considerando lo score check-in.
  /// Se score è basso (1-4), riduce il limite del 30%.
  int get effectiveMaxTrades {
    final base = rules?.maxTradesPerDay ?? 3;
    if (checkinScore > 0 && checkinScore < 5) {
      return (base * 0.7).round().clamp(1, base);
    }
    return base;
  }

  /// Percentuale utilizzo trade oggi (0.0 - 1.0)
  double get tradeUsagePercent {
    final max = rules?.maxTradesPerDay ?? 0;
    if (max == 0) return 0;
    return tradesToday / max;
  }

  /// Percentuale utilizzo perdita oggi (0.0 - 1.0)
  double get lossUsagePercent {
    final max = rules?.maxDailyLoss ?? 0;
    if (max == 0) return 0;
    return lossToday / max;
  }

  bool get isKillswitchTriggeredByTrades {
    final max = rules?.maxTradesPerDay;
    if (max == null || max <= 0) return false;
    return tradesToday >= max;
  }

  bool get isKillswitchTriggeredByLoss {
    final max = rules?.maxDailyLoss;
    if (max == null || max <= 0) return false;
    return lossToday >= max;
  }

  bool get isKillswitchTriggered =>
      isKillswitchTriggeredByTrades || isKillswitchTriggeredByLoss;

  String? get killswitchReason {
    if (isKillswitchTriggeredByTrades) return 'max_trades';
    if (isKillswitchTriggeredByLoss) return 'daily_loss';
    return null;
  }
}

class RulesNotifier extends StateNotifier<RulesState> {
  final Ref _ref;
  bool _disposed = false;

  // ── Daily-counter persistence keys ─────────────────────────────────────────
  static String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  static const _kDate   = 'daily_counters_date';
  static const _kTrades = 'daily_trades_count';
  static const _kLoss   = 'daily_loss_amount';

  RulesNotifier(this._ref) : super(const RulesState()) {
    _loadRules();
    // Reload rules when the authenticated user changes
    _ref.listen<AuthState>(authProvider, (prev, next) {
      final prevId = prev?.profile?.id ?? '';
      final nextId = next.profile?.id ?? '';
      if (nextId.isNotEmpty && nextId != prevId) {
        _loadRules();
      }
    });
    // When the active personal account changes, update rules without resetting counters
    _ref.listen<PersonalAccountsState>(personalAccountsProvider, (_, next) {
      if (_disposed) return;
      final active = next.activeAccount;
      if (active == null) return;
      final rules = active.toPersonalRules();
      state = state.copyWith(rules: rules);
      _syncToNative(rules);
    });
  }

  Future<void> _loadRules({int attempt = 0}) async {
    if (_disposed) return;
    state = state.copyWith(isLoading: true);
    try {
      final userId = _ref.read(currentUserIdProvider);
      if (userId.isEmpty) {
        // Nessun utente loggato: usa valori di default vuoti
        state = const RulesState();
        return;
      }
      var rules = await SupabaseService.getPersonalRules(userId);
      // Fallback: se Supabase non ha regole (trigger bug o primo avvio dopo reinstall),
      // usa la cache locale salvata in SharedPreferences dall'ultima sessione valida.
      if (rules == null) rules = await _loadLocalRulesCache(userId);
      final (trades, loss) = await _loadDailyCounters(userId);
      final checkinScore = await _loadTodayCheckinScore();
      if (_disposed) return;
      state = RulesState(
        rules: rules,
        tradesToday: trades,
        lossToday: loss,
        checkinScore: checkinScore,
      );
      // Sincronizza le regole alle SharedPreferences native
      // così PipLockAccessibilityService può triggerare il killswitch
      // anche quando Flutter è in background
      if (rules != null) _syncToNative(rules);
    } catch (_) {
      if (_disposed) return;
      if (attempt < 2) {
        // Retry con backoff esponenziale (2s, 4s)
        await Future.delayed(Duration(seconds: (attempt + 1) * 2));
        await _loadRules(attempt: attempt + 1);
      } else {
        // Ultimo tentativo fallito: prova la cache locale
        final userId = _ref.read(currentUserIdProvider);
        final cached = await _loadLocalRulesCache(userId);
        if (!_disposed && cached != null) {
          state = state.copyWith(rules: cached, isLoading: false);
          _syncToNative(cached);
        } else if (!_disposed) {
          state = const RulesState();
        }
      }
    }
  }

  // ── Cache locale regole (resilienza a Supabase trigger bug / reinstall) ────────

  static const _kCacheMaxLoss      = 'rules_cache_max_loss';
  static const _kCacheLossType     = 'rules_cache_loss_type';
  static const _kCacheMaxTrades    = 'rules_cache_max_trades';
  static const _kCacheDuration     = 'rules_cache_ks_duration';
  static const _kCacheAccountNum   = 'rules_cache_account_num';
  static const _kCacheTimezone     = 'rules_cache_timezone';
  static const _kCacheTradingHours = 'rules_cache_trading_hours_enabled';
  static const _kCacheHoursStart   = 'rules_cache_hours_start';
  static const _kCacheHoursEnd     = 'rules_cache_hours_end';

  Future<void> _saveLocalRulesCache(PersonalRules rules) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kCacheMaxLoss, rules.maxDailyLoss ?? -1.0);
      await prefs.setString(_kCacheLossType, rules.maxDailyLossType ?? 'amount');
      await prefs.setInt(_kCacheMaxTrades, rules.maxTradesPerDay ?? -1);
      await prefs.setString(_kCacheDuration, rules.killswitchDuration);
      await prefs.setString(_kCacheAccountNum, rules.accountNumber ?? '');
      await prefs.setString(_kCacheTimezone, rules.timezone ?? '');
      await prefs.setBool(_kCacheTradingHours, rules.tradingHoursEnabled);
      await prefs.setString(_kCacheHoursStart, rules.tradingHoursStart ?? '');
      await prefs.setString(_kCacheHoursEnd, rules.tradingHoursEnd ?? '');
    } catch (_) {}
  }

  Future<PersonalRules?> _loadLocalRulesCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final maxLoss = prefs.getDouble(_kCacheMaxLoss);
      if (maxLoss == null || maxLoss < 0) return null; // nessuna cache valida
      final maxTrades = prefs.getInt(_kCacheMaxTrades);
      final accountNum = prefs.getString(_kCacheAccountNum) ?? '';
      return PersonalRules(
        userId: userId,
        maxDailyLoss: maxLoss,
        maxDailyLossType: prefs.getString(_kCacheLossType) ?? 'amount',
        maxTradesPerDay: (maxTrades != null && maxTrades >= 0) ? maxTrades : null,
        killswitchDuration: prefs.getString(_kCacheDuration) ?? '6h',
        accountNumber: accountNum.isNotEmpty ? accountNum : null,
        timezone: prefs.getString(_kCacheTimezone),
        tradingHoursEnabled: prefs.getBool(_kCacheTradingHours) ?? false,
        tradingHoursStart: prefs.getString(_kCacheHoursStart),
        tradingHoursEnd: prefs.getString(_kCacheHoursEnd),
      );
    } catch (_) {
      return null;
    }
  }

  Future<int> _loadTodayCheckinScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('checkin_score_today') ?? 0;
  }

  /// Aggiorna lo score check-in e ricalcola effectiveMaxTrades.
  void updateCheckinScore(int score) {
    state = state.copyWith(checkinScore: score);
  }

  // ── Daily counter helpers ───────────────────────────────────────────────────

  Future<(int, double)> _loadDailyCounters(String userId) async {
    final today = _todayKey();
    final prefs = await SharedPreferences.getInstance();

    if (prefs.getString(_kDate) == today) {
      return (prefs.getInt(_kTrades) ?? 0, prefs.getDouble(_kLoss) ?? 0.0);
    }

    // New day — query today's journal entries to reconstruct counters
    if (!kDevMode && userId.isNotEmpty) {
      try {
        final now = DateTime.now();
        final dayStart = DateTime(now.year, now.month, now.day);
        final response = await Supabase.instance.client
            .from('journal_entries')
            .select('pnl')
            .eq('user_id', userId)
            .gte('date', dayStart.toIso8601String())
            .lt('date', dayStart.add(const Duration(days: 1)).toIso8601String());

        final entries = response as List;
        int trades = entries.length;
        double loss = 0.0;
        for (final e in entries) {
          final pnl = (e['pnl'] as num?)?.toDouble() ?? 0.0;
          if (pnl < 0) loss += pnl.abs();
        }
        await _writeCounters(prefs, today, trades, loss);
        return (trades, loss);
      } catch (_) {}
    }

    await _writeCounters(prefs, today, 0, 0.0);
    return (0, 0.0);
  }

  Future<void> _writeCounters(
      SharedPreferences prefs, String date, int trades, double loss) async {
    await prefs.setString(_kDate, date);
    await prefs.setInt(_kTrades, trades);
    await prefs.setDouble(_kLoss, loss);
  }

  Future<void> _persistCounters(int trades, double loss) async {
    final prefs = await SharedPreferences.getInstance();
    await _writeCounters(prefs, _todayKey(), trades, loss);
  }

  // ── Public methods ─────────────────────────────────────────────────────────

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> reload() => _loadRules();

  void setRules(PersonalRules rules) {
    state = state.copyWith(rules: rules);
    _syncToNative(rules);
    _scheduleSessionNotifications(rules);
  }

  void _scheduleSessionNotifications(PersonalRules rules) {
    if (!rules.tradingHoursEnabled) {
      NotificationService.cancelSessionReminder();
      NotificationService.cancelSessionEndNotification();
      return;
    }
    if (rules.tradingHoursStart != null) {
      final parts = rules.tradingHoursStart!.split(':');
      if (parts.length == 2) {
        NotificationService.scheduleSessionReminder(
          startHour: int.tryParse(parts[0]) ?? 0,
          startMinute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
    if (rules.tradingHoursEnd != null) {
      final parts = rules.tradingHoursEnd!.split(':');
      if (parts.length == 2) {
        NotificationService.scheduleSessionEndNotification(
          endHour: int.tryParse(parts[0]) ?? 0,
          endMinute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
  }

  void _syncToNative(PersonalRules rules) {
    final isPercent = rules.maxDailyLossType == 'percent';
    AccessibilityService.syncRulesToNative(
      maxDailyLossAmount: isPercent ? null : rules.maxDailyLoss,
      maxDailyLossPct: isPercent ? rules.maxDailyLoss : null,
      maxTradesPerDay: rules.maxTradesPerDay,
      killswitchDurationMinutes: _durationMinutes(rules.killswitchDuration),
      accountNumber: rules.accountNumber,
      tradingHoursEnabled: rules.tradingHoursEnabled,
      tradingHoursStart: rules.tradingHoursStart,
      tradingHoursEnd: rules.tradingHoursEnd,
    );
    // Salva in cache locale così sopravvive a reinstall/trigger bug Supabase
    _saveLocalRulesCache(rules);
  }

  int _durationMinutes(String d) {
    switch (d) {
      case '2h':  return 120;
      case '6h':  return 360;
      case '24h': return 1440;
      default:
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day + 1)
            .difference(now)
            .inMinutes;
    }
  }

  void trackTrade() {
    final n = state.tradesToday + 1;
    state = state.copyWith(tradesToday: n);
    _persistCounters(n, state.lossToday);
  }

  /// Imposta il conteggio trade a [n] (usato quando Kotlin invia un valore
  /// più accurato via margin-delta, che sovrascrive il counter Flutter).
  void setTradesToday(int n) {
    if (n <= state.tradesToday) return;
    state = state.copyWith(tradesToday: n);
    _persistCounters(n, state.lossToday);
  }

  void trackLoss(double amount) {
    final l = state.lossToday + amount;
    state = state.copyWith(lossToday: l);
    _persistCounters(state.tradesToday, l);
  }

  void resetDay() {
    state = state.copyWith(tradesToday: 0, lossToday: 0.0);
    _persistCounters(0, 0.0);
  }

  bool isKillswitchTriggered() => state.isKillswitchTriggered;
}

final rulesProvider =
    StateNotifierProvider<RulesNotifier, RulesState>((ref) {
  return RulesNotifier(ref);
});
