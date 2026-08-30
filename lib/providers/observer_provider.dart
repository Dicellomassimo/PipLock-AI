import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ObserverState {
  final bool isActive;
  final DateTime? startedAt;
  final int consecutiveDays;
  final DateTime? lastCleanDate;
  final int sessionsToday;
  final int bestStreak;

  const ObserverState({
    this.isActive = false,
    this.startedAt,
    this.consecutiveDays = 0,
    this.lastCleanDate,
    this.sessionsToday = 0,
    this.bestStreak = 0,
  });

  ObserverState copyWith({
    bool? isActive,
    DateTime? startedAt,
    int? consecutiveDays,
    DateTime? lastCleanDate,
    int? sessionsToday,
    int? bestStreak,
  }) {
    return ObserverState(
      isActive: isActive ?? this.isActive,
      startedAt: startedAt ?? this.startedAt,
      consecutiveDays: consecutiveDays ?? this.consecutiveDays,
      lastCleanDate: lastCleanDate ?? this.lastCleanDate,
      sessionsToday: sessionsToday ?? this.sessionsToday,
      bestStreak: bestStreak ?? this.bestStreak,
    );
  }
}

class ObserverNotifier extends StateNotifier<ObserverState> {
  static const _activeKey = 'observer_active';
  static const _startedAtKey = 'observer_started_at';
  static const _consecutiveDaysKey = 'observer_consecutive_days';
  static const _lastDateKey = 'observer_last_date';
  static const _sessionsTodayKey = 'observer_sessions_today';
  static const _sessionsTodayDateKey = 'observer_sessions_today_date';
  static const _bestStreakKey = 'observer_best_streak';

  ObserverNotifier() : super(const ObserverState()) {
    loadState();
  }

  Future<void> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final isActive = prefs.getBool(_activeKey) ?? false;
    final startedAtMs = prefs.getInt(_startedAtKey);
    final consecutiveDays = prefs.getInt(_consecutiveDaysKey) ?? 0;
    final lastDateMs = prefs.getInt(_lastDateKey);
    final bestStreak = prefs.getInt(_bestStreakKey) ?? 0;

    // Reset sessionsToday if last session date != today
    final sessionsTodayDate = prefs.getString(_sessionsTodayDateKey);
    final todayStr = _dateKey(DateTime.now());
    final sessionsToday = sessionsTodayDate == todayStr
        ? (prefs.getInt(_sessionsTodayKey) ?? 0)
        : 0;
    if (sessionsTodayDate != todayStr) {
      await prefs.setInt(_sessionsTodayKey, 0);
      await prefs.setString(_sessionsTodayDateKey, todayStr);
    }

    state = ObserverState(
      isActive: isActive,
      startedAt:
          startedAtMs != null ? DateTime.fromMillisecondsSinceEpoch(startedAtMs) : null,
      consecutiveDays: consecutiveDays,
      lastCleanDate:
          lastDateMs != null ? DateTime.fromMillisecondsSinceEpoch(lastDateMs) : null,
      sessionsToday: sessionsToday,
      bestStreak: bestStreak,
    );
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> activate() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStr = _dateKey(now);

    // Calcola la streak
    int consecutive = state.consecutiveDays;
    final lastClean = state.lastCleanDate;
    if (lastClean != null) {
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final lastDay =
          DateTime(lastClean.year, lastClean.month, lastClean.day);
      if (lastDay == yesterday) {
        consecutive += 1;
      } else if (lastDay != DateTime(now.year, now.month, now.day)) {
        consecutive = 1;
      }
    } else {
      consecutive = 1;
    }

    // Aggiorna sessionsToday
    final sessionsTodayDate = prefs.getString(_sessionsTodayDateKey);
    int sessionsToday = sessionsTodayDate == todayStr
        ? (prefs.getInt(_sessionsTodayKey) ?? 0) + 1
        : 1;
    await prefs.setInt(_sessionsTodayKey, sessionsToday);
    await prefs.setString(_sessionsTodayDateKey, todayStr);

    // Aggiorna bestStreak
    final bestStreak = consecutive > state.bestStreak ? consecutive : state.bestStreak;
    await prefs.setInt(_bestStreakKey, bestStreak);

    await prefs.setBool(_activeKey, true);
    await prefs.setInt(_startedAtKey, now.millisecondsSinceEpoch);
    await prefs.setInt(_consecutiveDaysKey, consecutive);
    await prefs.setInt(_lastDateKey, now.millisecondsSinceEpoch);

    state = ObserverState(
      isActive: true,
      startedAt: now,
      consecutiveDays: consecutive,
      lastCleanDate: now,
      sessionsToday: sessionsToday,
      bestStreak: bestStreak,
    );
  }

  Future<void> deactivate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activeKey, false);
    await prefs.remove(_startedAtKey);

    state = state.copyWith(isActive: false, startedAt: null);
  }
}

final observerProvider =
    StateNotifierProvider<ObserverNotifier, ObserverState>((ref) {
  return ObserverNotifier();
});
