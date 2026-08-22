import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/personal_rules.dart';
import '../services/accessibility_service.dart';
import '../services/supabase_service.dart';
import 'auth_provider.dart';

class RulesState {
  final PersonalRules? rules;
  final int tradesToday;
  final double lossToday;
  final bool isLoading;

  const RulesState({
    this.rules,
    this.tradesToday = 0,
    this.lossToday = 0.0,
    this.isLoading = false,
  });

  RulesState copyWith({
    PersonalRules? rules,
    int? tradesToday,
    double? lossToday,
    bool? isLoading,
  }) {
    return RulesState(
      rules: rules ?? this.rules,
      tradesToday: tradesToday ?? this.tradesToday,
      lossToday: lossToday ?? this.lossToday,
      isLoading: isLoading ?? this.isLoading,
    );
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

  RulesNotifier(this._ref) : super(const RulesState()) {
    _loadRules();
    // Ricarica le regole quando l'autenticazione si risolve.
    // rulesProvider viene creato prima che authProvider finisca di caricare
    // il profilo → userId è vuoto al primo _loadRules() → regole mai caricate.
    _ref.listen<AuthState>(authProvider, (prev, next) {
      final prevId = prev?.profile?.id ?? '';
      final nextId = next.profile?.id ?? '';
      if (nextId.isNotEmpty && nextId != prevId) {
        _loadRules();
      }
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
      final rules = await SupabaseService.getPersonalRules(userId);
      if (_disposed) return;
      state = RulesState(
        rules: rules,
        tradesToday: 0,
        lossToday: 0.0,
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
        state = const RulesState();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> reload() => _loadRules();

  void setRules(PersonalRules rules) {
    state = state.copyWith(rules: rules);
    _syncToNative(rules);
  }

  void _syncToNative(PersonalRules rules) {
    final isPercent = rules.maxDailyLossType == 'percent';
    AccessibilityService.syncRulesToNative(
      maxDailyLossAmount: isPercent ? null : rules.maxDailyLoss,
      maxDailyLossPct: isPercent ? rules.maxDailyLoss : null,
      maxTradesPerDay: rules.maxTradesPerDay,
      killswitchDurationMinutes: _durationMinutes(rules.killswitchDuration),
      accountNumber: rules.accountNumber,
    );
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
    state = state.copyWith(tradesToday: state.tradesToday + 1);
  }

  void trackLoss(double amount) {
    state = state.copyWith(lossToday: state.lossToday + amount);
  }

  void resetDay() {
    state = state.copyWith(tradesToday: 0, lossToday: 0.0);
  }

  bool isKillswitchTriggered() => state.isKillswitchTriggered;
}

final rulesProvider =
    StateNotifierProvider<RulesNotifier, RulesState>((ref) {
  return RulesNotifier(ref);
});
