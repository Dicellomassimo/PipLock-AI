import 'package:supabase_flutter/supabase_flutter.dart';

/// Gestisce le subscription Supabase Realtime.
/// Usato per ricevere eventi dall'EA MQL5 in tempo reale:
/// - Nuovi killswitch_events → l'app mostra la schermata rossa
/// - Aggiornamenti broker_connections → dashboard mostra stato connessione EA
/// - Nuovi risk_alerts → mostra overlay Gatekeeper
class RealtimeService {
  static final _client = Supabase.instance.client;

  static RealtimeChannel? _killswitchChannel;
  static RealtimeChannel? _brokerChannel;
  static RealtimeChannel? _riskAlertsChannel;

  /// Avvia tutte le subscription per l'utente specificato.
  static void startListening({
    required String userId,
    required void Function(Map<String, dynamic> event) onKillswitchEvent,
    required void Function(Map<String, dynamic> status) onBrokerStatusChange,
    required void Function(Map<String, dynamic> alert) onRiskAlert,
  }) {
    stopListening(); // cancella subscription precedenti

    // Subscription killswitch_events (INSERT)
    _killswitchChannel = _client
        .channel('killswitch:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'killswitch_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => onKillswitchEvent(payload.newRecord),
        )
        .subscribe();

    // Subscription broker_connections (UPDATE)
    _brokerChannel = _client
        .channel('broker:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'broker_connections',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => onBrokerStatusChange(payload.newRecord),
        )
        .subscribe();

    // Subscription risk_alerts (INSERT)
    _riskAlertsChannel = _client
        .channel('alerts:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'risk_alerts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => onRiskAlert(payload.newRecord),
        )
        .subscribe();
  }

  /// Cancella tutte le subscription attive.
  static void stopListening() {
    _killswitchChannel?.unsubscribe();
    _brokerChannel?.unsubscribe();
    _riskAlertsChannel?.unsubscribe();
    _killswitchChannel = null;
    _brokerChannel = null;
    _riskAlertsChannel = null;
  }
}
