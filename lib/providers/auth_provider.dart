import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../services/supabase_service.dart';
import '../services/purchase_service.dart';
import '../config/constants.dart';

final _mockProfile = Profile(
  id: 'dev-user-000',
  accountMode: 'personal',
  tokensWeekly: 2,
  tokensPurchased: 0,
  tokensResetAt: DateTime.now().add(const Duration(days: 4)),
  subscriptionTier: 'free',
  createdAt: DateTime(2026, 1, 1),
);

class AuthState {
  final Profile? profile;
  final bool isLoading;

  const AuthState({
    this.profile,
    this.isLoading = false,
  });

  bool get isLoggedIn => profile != null;

  AuthState copyWith({
    Profile? profile,
    bool? isLoading,
  }) {
    return AuthState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(isLoading: true)) {
    _init();
  }

  void _init() {
    if (kDevMode) {
      state = AuthState(profile: _mockProfile);
      return;
    }
    // Ascolta i cambiamenti di stato auth
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;
      if (user != null) {
        await _loadProfile(user.id);
      } else {
        state = const AuthState();
      }
    });

    // Controlla se c'è già una sessione attiva
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      _loadProfile(session.user.id);
    } else {
      state = const AuthState();
    }
  }

  Future<void> _loadProfile(String userId, {int attempt = 0}) async {
    state = state.copyWith(isLoading: true);
    try {
      await SupabaseService.ensureProfile(userId);
      await SupabaseService.checkAndResetWeeklyTokens(userId);
      final data = await SupabaseService.getProfile(userId);
      if (data != null) {
        state = AuthState(profile: Profile.fromJson(data));
        // Inizializza RevenueCat (fire and forget)
        PurchaseService.initialize(userId: userId);
      } else {
        state = const AuthState();
      }
    } catch (_) {
      // Retry up to 2 times with exponential backoff.
      if (attempt < 2) {
        await Future.delayed(Duration(seconds: (attempt + 1) * 2));
        await _loadProfile(userId, attempt: attempt + 1);
      } else {
        // After all retries: if a profile was already loaded (e.g. from a previous
        // successful load this session), keep it rather than forcing a logout.
        // Only clear state if there was genuinely no profile at all.
        if (state.profile == null) {
          state = const AuthState();
        } else {
          state = state.copyWith(isLoading: false);
        }
      }
    }
  }

  Future<void> signOut() async {
    await SupabaseService.signOut();
    state = const AuthState();
  }

  void updateProfile(Profile profile) {
    state = state.copyWith(profile: profile);
  }

  void consumeToken() {
    final current = state.profile;
    if (current == null) return;
    // Consume weekly tokens first, then purchased
    int newWeekly = current.tokensWeekly;
    int newPurchased = current.tokensPurchased;
    if (newWeekly > 0) {
      newWeekly = newWeekly - 1;
    } else if (newPurchased > 0) {
      newPurchased = newPurchased - 1;
    }
    state = state.copyWith(
      profile: current.copyWith(
        tokensWeekly: newWeekly,
        tokensPurchased: newPurchased,
      ),
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

final currentUserIdProvider = Provider<String>((ref) {
  return ref.watch(authProvider).profile?.id ?? '';
});
