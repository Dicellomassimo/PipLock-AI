import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/personal_account.dart';
import '../models/personal_rules.dart';
import '../services/supabase_service.dart';
import '../config/constants.dart';
import 'auth_provider.dart';

// ── State ──────────────────────────────────────────────────────────────────────

class PersonalAccountsState {
  final List<PersonalAccount> accounts;
  final String? activeAccountId;
  final bool isLoading;
  final String? error;

  const PersonalAccountsState({
    this.accounts = const [],
    this.activeAccountId,
    this.isLoading = false,
    this.error,
  });

  /// Returns the active account by id, falls back to first if none selected,
  /// returns null if no accounts exist.
  PersonalAccount? get activeAccount {
    if (accounts.isEmpty) return null;
    if (activeAccountId != null) {
      try {
        return accounts.firstWhere((a) => a.id == activeAccountId);
      } catch (_) {
        // id stored in prefs no longer in list — fall through to first
      }
    }
    return accounts.first;
  }

  PersonalAccountsState copyWith({
    List<PersonalAccount>? accounts,
    Object? activeAccountId = _sentinel,
    bool? isLoading,
    Object? error = _sentinel,
  }) {
    return PersonalAccountsState(
      accounts: accounts ?? this.accounts,
      activeAccountId: activeAccountId == _sentinel
          ? this.activeAccountId
          : activeAccountId as String?,
      isLoading: isLoading ?? this.isLoading,
      error: error == _sentinel ? this.error : error as String?,
    );
  }

  static const Object _sentinel = Object();
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class PersonalAccountsNotifier extends StateNotifier<PersonalAccountsState> {
  final Ref _ref;
  bool _disposed = false;

  static const _kActiveId = 'active_personal_account_id';

  PersonalAccountsNotifier(this._ref) : super(const PersonalAccountsState()) {
    _load();
    // Re-load when the authenticated user changes
    _ref.listen<AuthState>(authProvider, (prev, next) {
      final prevId = prev?.profile?.id ?? '';
      final nextId = next.profile?.id ?? '';
      if (nextId != prevId) _load();
    });
  }

  Future<void> _load() async {
    if (_disposed) return;
    state = state.copyWith(isLoading: true, error: null);

    if (kDevMode) {
      // Provide a mock account so the app works in dev mode without Supabase
      final mock = PersonalAccount(
        id: 'mock-account-001',
        userId: 'dev-user-000',
        name: 'Main Account (Dev)',
        connectionMethod: 'manual',
        maxDailyLoss: 100.0,
        maxDailyLossType: 'amount',
        maxTradesPerDay: 3,
        maxWeeklyLoss: 300.0,
        tradingHoursEnabled: true,
        tradingHoursStart: '08:00',
        tradingHoursEnd: '18:00',
        killswitchDuration: '6h',
        timezone: 'Europe/Rome',
      );
      if (_disposed) return;
      state = PersonalAccountsState(
        accounts: [mock],
        activeAccountId: mock.id,
        isLoading: false,
      );
      return;
    }

    final userId = _ref.read(currentUserIdProvider);
    if (userId.isEmpty) {
      if (_disposed) return;
      state = const PersonalAccountsState(isLoading: false);
      return;
    }

    try {
      final accounts = await SupabaseService.getPersonalAccounts(userId);
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_kActiveId);
      if (_disposed) return;
      state = PersonalAccountsState(
        accounts: accounts,
        activeAccountId: savedId,
        isLoading: false,
      );
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addAccount(PersonalAccount account) async {
    final hadNone = state.accounts.isEmpty;
    try {
      final saved = await SupabaseService.upsertPersonalAccount(account);
      if (_disposed) return;
      final updated = [...state.accounts, saved];
      state = state.copyWith(accounts: updated);
      // Make the first-ever account active automatically
      if (hadNone) {
        await setActiveAccount(saved.id);
      }
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateAccount(PersonalAccount account) async {
    try {
      final saved = await SupabaseService.upsertPersonalAccount(account);
      if (_disposed) return;
      final updated = [
        for (final a in state.accounts)
          if (a.id == saved.id) saved else a,
      ];
      state = state.copyWith(accounts: updated);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteAccount(String id) async {
    try {
      await SupabaseService.deletePersonalAccount(id);
      if (_disposed) return;
      final updated = state.accounts.where((a) => a.id != id).toList();
      String? newActiveId = state.activeAccountId;
      if (newActiveId == id) {
        newActiveId = updated.isNotEmpty ? updated.first.id : null;
        final prefs = await SharedPreferences.getInstance();
        if (newActiveId != null) {
          await prefs.setString(_kActiveId, newActiveId);
        } else {
          await prefs.remove(_kActiveId);
        }
      }
      if (_disposed) return;
      state = state.copyWith(accounts: updated, activeAccountId: newActiveId);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> setActiveAccount(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveId, id);
    if (_disposed) return;
    state = state.copyWith(activeAccountId: id);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final personalAccountsProvider =
    StateNotifierProvider<PersonalAccountsNotifier, PersonalAccountsState>(
  (ref) => PersonalAccountsNotifier(ref),
);
