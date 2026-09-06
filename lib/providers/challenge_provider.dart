import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../models/challenge.dart';
import '../services/supabase_service.dart';
import 'auth_provider.dart';

class ChallengeNotifier extends StateNotifier<List<Challenge>> {
  final Ref _ref;

  ChallengeNotifier(this._ref) : super([]) {
    // Auto-load when auth is ready or changes
    _ref.listen<AuthState>(authProvider, (prev, next) {
      final prevId = prev?.profile?.id ?? '';
      final nextId = next.profile?.id ?? '';
      if (nextId.isNotEmpty && nextId != prevId) {
        load(nextId);
      }
    });
    // Load immediately if already logged in
    final userId = _ref.read(currentUserIdProvider);
    if (userId.isNotEmpty) load(userId);
  }

  Future<void> load(String userId) async {
    if (kDevMode) return; // in devMode la lista è mantenuta in memoria
    if (userId.isEmpty) return;
    try {
      final all = await SupabaseService.getAllChallenges(userId);
      if (mounted) state = all;
    } catch (e) {
      debugPrint('[ChallengeProvider] load error: $e');
    }
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
  (ref) => ChallengeNotifier(ref),
);
