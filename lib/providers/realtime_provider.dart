import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/realtime_service.dart';
import 'auth_provider.dart';
import 'killswitch_provider.dart';

class RealtimeNotifier extends StateNotifier<void> {
  final Ref _ref;

  RealtimeNotifier(this._ref) : super(null) {
    _init();
  }

  void _init() {
    // Ascolta i cambiamenti di auth per avviare/fermare le subscription
    _ref.listen(authProvider, (previous, next) {
      if (next.isLoggedIn && next.profile?.id != null) {
        _startRealtime(next.profile!.id);
      } else {
        RealtimeService.stopListening();
      }
    });

    // Avvia subito se già loggato
    final auth = _ref.read(authProvider);
    if (auth.isLoggedIn && auth.profile?.id != null) {
      _startRealtime(auth.profile!.id);
    }
  }

  void _startRealtime(String userId) {
    RealtimeService.startListening(
      userId: userId,
      onKillswitchEvent: (event) {
        // EA ha triggerato un killswitch → attiva nella UI
        final reason = event['reason'] as String? ?? 'daily_loss';
        final duration = event['lock_duration_minutes'] as int? ?? 360;
        final ksState = _ref.read(killswitchProvider);
        if (!ksState.isActive) {
          _ref.read(killswitchProvider.notifier).activate(reason, duration);
        }
      },
      onBrokerStatusChange: (status) {
        // Aggiornamento stato connessione broker — per ora solo log
        // In futuro: aggiornare un provider dedicato per la UI broker screen
      },
      onRiskAlert: (alert) {
        // Risk alert da EA (soft warning) — per ora solo log
        // In futuro: mostrare l'overlay Gatekeeper
      },
    );
  }

  @override
  void dispose() {
    RealtimeService.stopListening();
    super.dispose();
  }
}

final realtimeProvider = StateNotifierProvider<RealtimeNotifier, void>((ref) {
  return RealtimeNotifier(ref);
});
