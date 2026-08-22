import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'accessibility_service.dart';

class CheckinService {
  static const _scoresKey = 'checkin_scores_history';
  static const _overrideKey = 'today_trade_limit_override';
  static const _questionScoresKey = 'checkin_question_history';

  // ─── Salva un check-in ────────────────────────────────────────────────────────

  /// Salva il punteggio totale del check-in e i punteggi per singola domanda.
  static Future<void> saveCheckIn(
    int totalScore,
    Map<String, int> questionScores,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();

    // Salva punteggio totale
    final scoresRaw = prefs.getString(_scoresKey);
    final scores = scoresRaw != null
        ? Map<String, dynamic>.from(jsonDecode(scoresRaw) as Map)
        : <String, dynamic>{};
    scores[today] = totalScore;
    await prefs.setString(_scoresKey, jsonEncode(scores));

    // Salva punteggi per domanda
    final qRaw = prefs.getString(_questionScoresKey);
    final qHistory = qRaw != null
        ? Map<String, dynamic>.from(jsonDecode(qRaw) as Map)
        : <String, dynamic>{};
    // qHistory[today] = { 'sleep': 2, 'emotion': 4, ... }
    qHistory[today] = questionScores;
    await prefs.setString(_questionScoresKey, jsonEncode(qHistory));

    // Sync score to native SharedPreferences so the Accessibility Service
    // can read it without calling back into Flutter (works in background).
    await AccessibilityService.syncCheckinScore(totalScore);
  }

  // ─── Lettura punteggi recenti ─────────────────────────────────────────────────

  /// Restituisce gli ultimi N punteggi totali giornalieri (dal più recente).
  static Future<List<int>> getRecentScores({int days = 7}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scoresKey);
    if (raw == null) return [];

    final scores =
        Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final result = <int>[];
    for (int i = 0; i < days; i++) {
      final key = _dayKey(DateTime.now().subtract(Duration(days: i)));
      if (scores.containsKey(key)) {
        result.add(scores[key] as int);
      }
    }
    return result;
  }

  /// Restituisce gli ultimi N punteggi per una domanda specifica (es. 'sleep').
  static Future<List<int>> getQuestionHistory(
    String questionKey, {
    int days = 7,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_questionScoresKey);
    if (raw == null) return [];

    final history =
        Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final result = <int>[];
    for (int i = 0; i < days; i++) {
      final key = _dayKey(DateTime.now().subtract(Duration(days: i)));
      if (history.containsKey(key)) {
        final dayData =
            Map<String, dynamic>.from(history[key] as Map);
        if (dayData.containsKey(questionKey)) {
          result.add(dayData[questionKey] as int);
        }
      }
    }
    return result;
  }

  // ─── Override trade limit ─────────────────────────────────────────────────────

  /// Restituisce il limite di trade override per oggi (null = nessun override).
  static Future<int?> getTodayTradeOverride() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_overrideKey);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['date'] != _todayKey()) return null;
      return data['limit'] as int?;
    } catch (_) {
      return null;
    }
  }

  /// Imposta un override al limite di trade per oggi.
  static Future<void> setTodayTradeOverride(int limit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _overrideKey,
      jsonEncode({'date': _todayKey(), 'limit': limit}),
    );
  }

  // ─── Pattern detection ────────────────────────────────────────────────────────

  /// Restituisce true se il punteggio del sonno è stato < 3 per 3+ giorni di fila.
  static Future<bool> hasPoorSleepStreak() async {
    final sleepScores = await getQuestionHistory('sleep', days: 7);
    if (sleepScores.length < 3) return false;

    int streak = 0;
    for (final score in sleepScores) {
      if (score < 3) {
        streak++;
        if (streak >= 3) return true;
      } else {
        break;
      }
    }
    return false;
  }

  /// Restituisce true se il punteggio totale di oggi era basso (< 5).
  static Future<bool> hasLowScoreToday() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scoresKey);
    if (raw == null) return false;
    final scores =
        Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final todayScore = scores[_todayKey()];
    if (todayScore == null) return false;
    return (todayScore as int) < 5;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  static String _todayKey() => _dayKey(DateTime.now());

  static String _dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
