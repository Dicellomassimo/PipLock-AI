import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/killswitch_event.dart';
import '../services/supabase_service.dart';
import '../services/accessibility_service.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';

class KillswitchState {
  final bool isActive;
  final DateTime? activatedAt;
  final String? reason;
  final int lockDurationMinutes;
  final int tokensAvailable;
  final String? eventId; // ID dell'evento su Supabase, null se non ancora salvato
  /// True se il disclaimer legale non è ancora stato mostrato all'utente.
  /// La KillswitchScreen usa questo flag per mostrare il modale una sola volta.
  final bool needsDisclaimer;

  const KillswitchState({
    this.isActive = false,
    this.activatedAt,
    this.reason,
    this.lockDurationMinutes = 360,
    this.tokensAvailable = 2,
    this.eventId,
    this.needsDisclaimer = false,
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
    bool? needsDisclaimer,
  }) {
    return KillswitchState(
      isActive: isActive ?? this.isActive,
      activatedAt: activatedAt ?? this.activatedAt,
      reason: reason ?? this.reason,
      lockDurationMinutes: lockDurationMinutes ?? this.lockDurationMinutes,
      tokensAvailable: tokensAvailable ?? this.tokensAvailable,
      eventId: eventId ?? this.eventId,
      needsDisclaimer: needsDisclaimer ?? this.needsDisclaimer,
    );
  }
}

class KillswitchNotifier extends StateNotifier<KillswitchState> {
  final Ref _ref;
  Timer? _autoDeactivateTimer;
  bool _disposed = false;
  bool _disclaimerAlreadyShown = false;

  static const _disclaimerKey = 'killswitch_disclaimer_shown';

  KillswitchNotifier(this._ref) : super(const KillswitchState()) {
    _loadDisclaimerFlag();
  }

  static const _disclaimerDateKey = 'killswitch_disclaimer_shown_date';
  static const _disclaimerExpiryDays = 30;

  Future<void> _loadDisclaimerFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString(_disclaimerDateKey);
    if (dateStr != null) {
      final shownDate = DateTime.tryParse(dateStr);
      if (shownDate != null &&
          DateTime.now().difference(shownDate).inDays < _disclaimerExpiryDays) {
        _disclaimerAlreadyShown = true;
        return;
      }
    }
    // Fallback: check legacy bool key
    _disclaimerAlreadyShown = prefs.getBool(_disclaimerKey) ?? false;
  }

  /// Chiamato dalla KillswitchScreen dopo aver mostrato il disclaimer.
  Future<void> markDisclaimerShown() async {
    _disclaimerAlreadyShown = true;
    state = state.copyWith(needsDisclaimer: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_disclaimerKey, true);
    await prefs.setString(_disclaimerDateKey, DateTime.now().toIso8601String());
  }

  void _startAutoDeactivateTimer(int durationMinutes) {
    _autoDeactivateTimer?.cancel();
    _autoDeactivateTimer = Timer(Duration(minutes: durationMinutes), () {
      if (!_disposed) {
        // Scaduto naturalmente (non con token) — invia notifica immediata
        NotificationService.sendKillswitchLiftedNotification();
        deactivate();
      }
    });
  }

  Future<void> _setKillswitchActivePref(bool isActive) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('killswitch_active', isActive);
  }

  void activate(String reason, int durationMinutes) {
    state = KillswitchState(
      isActive: true,
      activatedAt: DateTime.now(),
      reason: reason,
      lockDurationMinutes: durationMinutes,
      tokensAvailable: state.tokensAvailable,
      // Mostra il disclaimer la prima volta che il killswitch viene attivato
      needsDisclaimer: !_disclaimerAlreadyShown,
    );
    // Mostra overlay sopra app broker se il permesso è disponibile
    AccessibilityService.showKillswitchOverlay(
      durationMinutes: durationMinutes,
      reason: reason,
    );
    _setKillswitchActivePref(true);
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
      needsDisclaimer: !_disclaimerAlreadyShown,
    );

    // Mostra overlay di sistema sopra l'app broker (MT5/cTrader/ecc.)
    AccessibilityService.showKillswitchOverlay(
      durationMinutes: durationMinutes,
      reason: reason,
    );
    _setKillswitchActivePref(true);
    _startAutoDeactivateTimer(durationMinutes);

    // Schedula notifica "sblocco tra 30 minuti"
    final unlockTime = DateTime.now().add(Duration(minutes: durationMinutes));
    final notifTime = unlockTime.subtract(const Duration(minutes: 30));
    if (notifTime.isAfter(DateTime.now())) {
      NotificationService.scheduleUnlockReminder(notifTime);
    }

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
    _setKillswitchActivePref(false);
    // Cancella la notifica "sblocco tra 30 min" se il killswitch viene rimosso anticipatamente
    NotificationService.cancelUnlockReminder();
  }

  /// Usa un Override Token per sbloccare anticipatamente il killswitch.
  /// [overrideReason]: il motivo dichiarato dall'utente (es. "Strong setup").
  Future<bool> useToken([String? overrideReason]) async {
    final profile = _ref.read(authProvider).profile;
    final tokens = profile?.tokensAvailable ?? 0;
    if (tokens <= 0) return false;

    final currentEventId = state.eventId;

    // consumeToken in auth_provider handles weekly-first, then purchased logic
    _ref.read(authProvider.notifier).consumeToken();
    state = state.copyWith(
      tokensAvailable: (state.tokensAvailable - 1).clamp(0, 999),
    );
    deactivate();

    // Aggiorna l'evento su Supabase come override con motivo
    if (currentEventId != null && currentEventId.isNotEmpty) {
      try {
        await SupabaseService.resolveKillswitch(
          currentEventId, true,
          overrideReason: overrideReason,
        );
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
      needsDisclaimer: !_disclaimerAlreadyShown,
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
