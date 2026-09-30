import 'package:firebase_analytics/firebase_analytics.dart';

/// Centralized, best-effort analytics events used by the app.
/// Analytics failures must never affect trading or killswitch behavior.
class AnalyticsService {
  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  static Future<void> logKillswitchTriggered({required String reason}) async {
    await _log(() => _analytics.logEvent(
          name: 'killswitch_triggered',
          parameters: {'reason': reason},
        ));
  }

  static Future<void> logChallengeCreated() async {
    await _log(() => _analytics.logEvent(name: 'challenge_created'));
  }

  static Future<void> logPlanGenerated({required String type}) async {
    await _log(() => _analytics.logEvent(
          name: 'plan_generated',
          parameters: {'type': type},
        ));
  }

  static Future<void> logObserverStarted() async {
    await _log(() => _analytics.logEvent(name: 'observer_started'));
  }

  static Future<void> logJournalEntryAdded() async {
    await _log(() => _analytics.logEvent(name: 'journal_entry_added'));
  }

  static Future<void> _log(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Telemetry is optional and must never break the user flow.
    }
  }
}
