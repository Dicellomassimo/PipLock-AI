import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/killswitch_event.dart';
import '../services/supabase_service.dart';
import '../services/accessibility_service.dart';
import 'auth_provider.dart';

class KillswitchState {
  final bool isActive;
  final DateTime? activatedAt;
  final String? reason;
  final int lockDurationMinutes;
  final int tokensAvailable;
  final String? eventId; // ID dell'evento su Supabase, null se non ancora salvato

  const KillswitchState({
    this.isActive = false,
    this.activatedAt,
    this.reason,
    this.lockDurationMinutes = 360,
    this.tokensAvailable = 2,
    this.eventId,
  });

  Duration get remainingTime {
    if (!isActive || activatedAt == null) return Duration.zero;
    final end = activatedAt!.add(Duration(minutes: lockDurationMinutes));
    final remaining = end.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get isExpired => isActive && remainingTime == Duration.zero;

  KillswitchState copyWith({
    bool? isActive,
    DateTime? activatedAt,
    String? reason,
    int? lockDurationMinutes,
    int? tokensAvailable,
    String? eventId,
  }) {
    return KillswitchState(
      isActive: isActive ?? this.isActive,
      activatedAt: activatedAt ?? this.activatedAt,
      reason: reason ?? this.reason,
      lockDurationMinutes: lockDurationMinutes ?? this.lockDurationMinutes,
      tokensAvailable: tokensAvailable ?? this.tokensAvailable,
      eventId: eventId ?? this.eventId,
    );
  }
}

class KillswitchNotifier extends StateNotifier<KillswitchState> {
  final Ref _ref;
  Timer? _autoDeactivateTimer;
  bool _disposed = false;

  KillswitchNotifier(this._ref) : super(const KillswitchState());

  void _startAutoDeactivateTimer(int durationMinutes) {
    _autoDeactivateTimer?.cancel();
    _autoDeactivateTimer = Timer(Duration(minutes: durationMinutes), () {
      if (!_disposed) deactivate();
    });
  }

  void activate(String reason, int durationMinutes) {
    state = KillswitchState(
      isActive: true,
      activatedAt: DateTime.now(),
      reason: reason,
      lockDurationMinutes: durationMinutes,
      tokensAvailable: state.tokensAvailable,
    );
    // Mostra overlay sopra app broker se il permesso è disponibile
    AccessibilityService.showKillswitchOverlay(
      durationMinutes: durationMinutes,
      reason: reason,
    );
    _startAutoDeactivateTimer(durationMinutes);
  }

  /// Attiva il killswitch e salva l'evento su Supabase (fire and forget).
  Future<void> activateAndSave(
    String reason,
    int durationMinutes,
    String userId,
    String accountMode,
  ) async {
    state = KillswitchState(
      isActive: true,
      activatedAt: DateTime.now(),
      reason: reason,
      lockDurationMinutes: durationMinutes,
      tokensAvailable: state.tokensAvailable,
    );

    // Mostra overlay di sistema sopra l'app broker (MT5/cTrader/ecc.)
    AccessibilityService.showKillswitchOverlay(
      durationMinutes: durationMinutes,
      reason: reason,
    );
    _startAutoDeactivateTimer(durationMinutes);

    if (userId.isNotEmpty) {
      try {
        final event = KillswitchEvent(
          id: '', // generato da Supabase
          userId: userId,
          triggeredAt: DateTime.now(),
          reason: reason,
          accountMode: accountMode,
          lockDurationMinutes: durationMinutes,
          unlockedEarly: false,
          unlockedWithToken: false,
          resolvedAt: null,
        );
        final id = await SupabaseService.triggerKillswitch(event);
        state = state.copyWith(eventId: id);
      } catch (_) {
        // Errore silenzioso — il killswitch resta attivo anche senza DB
      }
    }
  }

  void deactivate() {
    _autoDeactivateTimer?.cancel();
    state = KillswitchState(
      isActive: false,
      activatedAt: null,
      reason: null,
      lockDurationMinutes: state.lockDurationMinutes,
      tokensAvailable: state.tokensAvailable,
    );
    // Rimuove l'overlay sopra le app broker
    AccessibilityService.hideKillswitchOverlay();
  }

  /// Usa un token per sbloccare anticipatamente il killswitch.
  Future<bool> useToken() async {
    final tokens = _ref.read(authProvider).profile?.tokensAvailable ?? 0;
    if (tokens <= 0) return false;

    final currentEventId = state.eventId;

    _ref.read(authProvider.notifier).consumeToken();
    state = state.copyWith(
      tokensAvailable: (state.tokensAvailable - 1).clamp(0, 999),
    );
    deactivate();

    // Aggiorna l'evento su Supabase come risolto con token
    if (currentEventId != null && currentEventId.isNotEmpty) {
      try {
        await SupabaseService.resolveKillswitch(currentEventId, true);
      } catch (_) {}
    }

    return true;
  }

  int _durationFromString(String duration) {
    switch (duration) {
      case '2h':
        return 120;
      case '6h':
        return 360;
      case 'midnight':
        final now = DateTime.now();
        final midnight =
            DateTime(now.year, now.month, now.day + 1);
        return midnight.difference(now).inMinutes;
      case '24h':
        return 1440;
      default:
        return 360;
    }
  }

  void activateWithDurationString(String reason, String durationStr) {
    activate(reason, _durationFromString(durationStr));
  }

  /// Attiva lo stato Flutter killswitch senza mostrare l'overlay nativo
  /// (già attivo lato Kotlin). Usato quando l'utente apre PipLock dall'overlay
  /// e il killswitch era stato triggherato nativamente senza passare da Flutter.
  void activateNative(String reason, int remainingMinutes) {
    // Usa remainingMinutes come durata totale a partire da ora:
    // remainingTime = activatedAt + lockDurationMinutes - now
    //               = now + remainingMinutes - now = remainingMinutes ✓
    final durationMinutes = remainingMinutes > 0 ? remainingMinutes : 360;
    state = KillswitchState(
      isActive: true,
      activatedAt: DateTime.now(),
      reason: reason,
      lockDurationMinutes: durationMinutes,
      tokensAvailable: state.tokensAvailable,
    );
    _startAutoDeactivateTimer(durationMinutes);
  }

  @override
  void dispose() {
    _disposed = true;
    _autoDeactivateTimer?.cancel();
    super.dispose();
  }
}

final killswitchProvider =
    StateNotifierProvider<KillswitchNotifier, KillswitchState>((ref) {
  return KillswitchNotifier(ref);
});
