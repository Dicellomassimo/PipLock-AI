import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../models/challenge.dart';
import '../services/supabase_service.dart';

class ChallengeNotifier extends StateNotifier<List<Challenge>> {
  ChallengeNotifier() : super([]);

  Future<void> load(String userId) async {
    if (kDevMode) return; // in devMode la lista è mantenuta in memoria
    if (userId.isEmpty) return;
    try {
      final all = await SupabaseService.getAllChallenges(userId);
      state = all;
    } catch (_) {}
  }

  void addChallenge(Challenge c) {
    state = [c, ...state.where((e) => e.id != c.id)];
  }

  void updateChallenge(Challenge c) {
    state = state.map((e) => e.id == c.id ? c : e).toList();
  }
}

final challengeListProvider =
    StateNotifierProvider<ChallengeNotifier, List<Challenge>>(
  (ref) => ChallengeNotifier(),
);
