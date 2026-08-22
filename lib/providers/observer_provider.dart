import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ObserverState {
  final bool isActive;
  final DateTime? startedAt;
  final int consecutiveDays;
  final DateTime? lastCleanDate;

  const ObserverState({
    this.isActive = false,
    this.startedAt,
    this.consecutiveDays = 0,
    this.lastCleanDate,
  });

  ObserverState copyWith({
    bool? isActive,
    DateTime? startedAt,
    int? consecutiveDays,
    DateTime? lastCleanDate,
  }) {
    return ObserverState(
      isActive: isActive ?? this.isActive,
      startedAt: startedAt ?? this.startedAt,
      consecutiveDays: consecutiveDays ?? this.consecutiveDays,
      lastCleanDate: lastCleanDate ?? this.lastCleanDate,
    );
  }
}

class ObserverNotifier extends StateNotifier<ObserverState> {
  static const _activeKey = 'observer_active';
  static const _startedAtKey = 'observer_started_at';
  static const _consecutiveDaysKey = 'observer_consecutive_days';
  static const _lastDateKey = 'observer_last_date';

  ObserverNotifier() : super(const ObserverState()) {
    loadState();
  }

  Future<void> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final isActive = prefs.getBool(_activeKey) ?? false;
    final startedAtMs = prefs.getInt(_startedAtKey);
    final consecutiveDays = prefs.getInt(_consecutiveDaysKey) ?? 0;
    final lastDateMs = prefs.getInt(_lastDateKey);

    state = ObserverState(
      isActive: isActive,
      startedAt:
          startedAtMs != null ? DateTime.fromMillisecondsSinceEpoch(startedAtMs) : null,
      consecutiveDays: consecutiveDays,
      lastCleanDate:
          lastDateMs != null ? DateTime.fromMillisecondsSinceEpoch(lastDateMs) : null,
    );
  }

  Future<void> activate() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

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
        // Più di un giorno fa — streak azzerata
        consecutive = 1;
      }
      // Se è lo stesso giorno, non cambia
    } else {
      consecutive = 1;
    }

    await prefs.setBool(_activeKey, true);
    await prefs.setInt(_startedAtKey, now.millisecondsSinceEpoch);
    await prefs.setInt(_consecutiveDaysKey, consecutive);
    await prefs.setInt(_lastDateKey, now.millisecondsSinceEpoch);

    state = ObserverState(
      isActive: true,
      startedAt: now,
      consecutiveDays: consecutive,
      lastCleanDate: now,
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
