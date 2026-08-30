import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/realtime_service.dart';
import '../services/accessibility_service.dart';
import 'auth_provider.dart';
import 'broker_provider.dart';
import 'killswitch_provider.dart';

class RealtimeNotifier extends StateNotifier<void> {
  final Ref _ref;

  RealtimeNotifier(this._ref) : super(null) {
    _init();
  }

  void _init() {
    _ref.listen(authProvider, (previous, next) {
      if (next.isLoggedIn && next.profile?.id != null) {
        _startRealtime(next.profile!.id);
      } else {
        RealtimeService.stopListening();
      }
    });

    final auth = _ref.read(authProvider);
    if (auth.isLoggedIn && auth.profile?.id != null) {
      _startRealtime(auth.profile!.id);
    }
  }

  void _startRealtime(String userId) {
    RealtimeService.startListening(
      userId: userId,

      // ── Killswitch da EA MQL5 ─────────────────────────────────────────────
      // L'EA ha scritto un nuovo killswitch_event su Supabase → attiva nella UI.
      onKillswitchEvent: (event) {
        final reason = event['reason'] as String? ?? 'daily_loss';
        final duration = event['lock_duration_minutes'] as int? ?? 360;
        final ksState = _ref.read(killswitchProvider);
        if (!ksState.isActive) {
          _ref.read(killswitchProvider.notifier).activate(reason, duration);
        }
      },

      // ── Stato connessione broker aggiornato da EA ─────────────────────────
      // L'EA ha aggiornato broker_connections.status → aggiorna la UI broker.
      onBrokerStatusChange: (record) {
        final status = record['status'] as String?;
        if (status != null) {
          try {
            _ref.read(brokerProvider.notifier).updateConnectionStatusFromEa(status);
          } catch (_) {}
        }
      },

      // ── Risk alert da EA (soft warning) ──────────────────────────────────
      // L'EA ha inserito un alert su risk_alerts → mostra Gatekeeper overlay
      // oppure, se è un alert critico, attiva direttamente il killswitch.
      onRiskAlert: (alert) {
        final alertType = alert['alert_type'] as String? ?? 'risk';
        final reason = alert['reason'] as String? ?? alertType;
        final isCritical = alert['is_critical'] as bool? ?? false;

        if (isCritical) {
          // Alert critico: triggera il killswitch direttamente
          final duration = alert['lock_duration_minutes'] as int? ?? 360;
          final ksState = _ref.read(killswitchProvider);
          if (!ksState.isActive) {
            _ref.read(killswitchProvider.notifier).activate(reason, duration);
          }
        } else {
          // Soft warning: mostra il Gatekeeper FOMO overlay sopra MT5.
          // Il trigger viene mappato ai tipi che FomoGatekeeperOverlayService conosce.
          final trigger = switch (alertType) {
            'revenge_trading' => 'revenge_trading',
            'overleveraging' => 'overleveraging',
            'overtrading' => 'overtrading',
            'fomo' => 'fomo',
            _ => 'fast_entry',
          };
          AccessibilityService.showFomoOverlay(trigger: trigger);
        }
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
