import '../models/killswitch_event.dart';

/// Calcola il Weekly Discipline Report a partire dagli eventi killswitch.
class DisciplineService {
  DisciplineService._();

  static DisciplineReport computeWeekly(List<KillswitchEvent> allEvents) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1)); // lunedì
    final weekStartDay = DateTime(weekStart.year, weekStart.month, weekStart.day);

    final weekEvents = allEvents
        .where((e) => e.triggeredAt.isAfter(weekStartDay))
        .toList();

    final activations = weekEvents.length;
    final overridesUsed = weekEvents.where((e) => e.unlockedWithToken).length;
    final tradesAvoided = weekEvents.where((e) => !e.unlockedWithToken).length;

    // Score: base 100, penalità per attivazioni e override
    int score = 100;
    score -= (activations * 8).clamp(0, 40);   // max -40 per attivazioni
    score -= (overridesUsed * 15).clamp(0, 30); // max -30 per override
    if (overridesUsed == 0 && activations > 0) score += 5; // disciplina: nessun override
    if (activations == 0) score = 100; // settimana perfetta
    score = score.clamp(0, 100);

    // Pattern più frequente
    final reasonCounts = <String, int>{};
    for (final e in weekEvents) {
      reasonCounts[e.reason] = (reasonCounts[e.reason] ?? 0) + 1;
    }
    String? mostDangerousPattern;
    if (reasonCounts.isNotEmpty) {
      mostDangerousPattern = reasonCounts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }

    // Raccoglie i motivi dichiarati dall'utente per gli override con token.
    // Il P&L reale di ciascun override non è disponibile senza connessione broker attiva;
    // il motivo dichiarato è il proxy più affidabile per analisi comportamentale.
    final overrideReasons = weekEvents
        .where((e) => e.unlockedWithToken && e.overrideReason != null)
        .map((e) => e.overrideReason!)
        .toList();

    // Conteggio totale override del mese (per report mensile)
    final monthStart = DateTime(now.year, now.month, 1);
    final monthOverrides = allEvents
        .where((e) =>
            e.triggeredAt.isAfter(monthStart) && e.unlockedWithToken)
        .length;

    return DisciplineReport(
      score: score,
      activations: activations,
      overridesUsed: overridesUsed,
      tradesAvoided: tradesAvoided,
      mostDangerousPattern: mostDangerousPattern,
      overrideReasons: overrideReasons,
      monthlyOverrides: monthOverrides,
      weekStart: weekStartDay,
    );
  }
}

class DisciplineReport {
  final int score;           // 0–100
  final int activations;     // killswitch scattati questa settimana
  final int overridesUsed;   // override usati questa settimana
  final int tradesAvoided;   // attivazioni rispettate (non override)
  final String? mostDangerousPattern;  // reason più frequente
  final List<String> overrideReasons; // motivi dichiarati negli override
  final int monthlyOverrides;
  final DateTime weekStart;

  const DisciplineReport({
    required this.score,
    required this.activations,
    required this.overridesUsed,
    required this.tradesAvoided,
    required this.mostDangerousPattern,
    required this.overrideReasons,
    required this.monthlyOverrides,
    required this.weekStart,
  });

  String get scoreLabel {
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Good';
    if (score >= 55) return 'Fair';
    return 'Needs work';
  }

  String get mostDangerousPatternLabel {
    switch (mostDangerousPattern) {
      case 'daily_loss':        return 'Chasing losses';
      case 'max_trades':        return 'Overtrading';
      case 'revenge_pattern':   return 'Revenge trading after losses';
      case 'overleveraging':    return 'Overleveraging';
      case 'fomo_pattern':      return 'FOMO entries';
      case 'consecutive_losses': return 'Consecutive losses streak';
      case 'fast_reentry':      return 'Fast re-entry after loss';
      case 'plan_violation':    return 'Challenge plan violations';
      case 'trading_hours':     return 'Trading outside allowed hours';
      default:                  return mostDangerousPattern ?? '—';
    }
  }

  bool get isPerfectWeek => activations == 0;
}
