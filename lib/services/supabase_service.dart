import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env_config.dart';
import '../models/personal_rules.dart';
import '../models/challenge.dart';
import '../models/killswitch_event.dart';
import 'cache_service.dart';

class SupabaseService {
  static SupabaseClient get _client => Supabase.instance.client;

  static String? get currentUserId => _client.auth.currentUser?.id;

  // ---- Auth rate limiting ----
  // Prevents brute-force: 2s minimum between any auth attempt,
  // 30s backoff after 5 consecutive failures.
  static DateTime? _lastAuthAttempt;
  static int _consecutiveFailures = 0;
  static const _minInterval = Duration(seconds: 2);
  static const _backoffInterval = Duration(seconds: 30);
  static const _maxFailures = 5;

  static void _checkAuthRateLimit() {
    final now = DateTime.now();
    if (_lastAuthAttempt != null) {
      final elapsed = now.difference(_lastAuthAttempt!);
      if (elapsed < _minInterval) {
        throw Exception('Please wait before trying again.');
      }
      if (_consecutiveFailures >= _maxFailures && elapsed < _backoffInterval) {
        final remaining = (_backoffInterval - elapsed).inSeconds;
        throw Exception(
            'Too many failed attempts. Try again in $remaining seconds.');
      }
    }
    _lastAuthAttempt = now;
  }

  static void _onAuthSuccess() => _consecutiveFailures = 0;
  static void _onAuthFailure() => _consecutiveFailures++;

  /// Fire-and-forget audit log via security definer RPC.
  /// Failures are silently ignored — logging must never break app flow.
  static void _logEvent(String eventType, [Map<String, dynamic>? metadata]) {
    _client.rpc('log_security_event', params: {
      'p_event_type': eventType,
      'p_metadata': metadata,
    }).catchError((_) {});
  }

  // ---- Auth ----

  static Future<AuthResponse> signUp(String email, String password) async {
    _checkAuthRateLimit();
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'piplock://auth-callback',
      );
      _onAuthSuccess();
      return res;
    } catch (e) {
      _onAuthFailure();
      rethrow;
    }
  }

  static Future<AuthResponse> signIn(String email, String password) async {
    _checkAuthRateLimit();
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      _onAuthSuccess();
      _logEvent('login_success');
      return res;
    } catch (e) {
      _onAuthFailure();
      _logEvent('login_failed');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Changes password and invalidates ALL active sessions on every device.
  /// The user must re-login after calling this.
  static Future<void> changePassword(String newPassword) async {
    if (newPassword.length < 8) {
      throw ArgumentError('Password must be at least 8 characters.');
    }
    await _client.auth.updateUser(UserAttributes(password: newPassword));
    _logEvent('password_changed');
    // Invalidate every active session globally (all devices, all tabs).
    await _client.auth.signOut(scope: SignOutScope.global);
  }

  /// Google Sign In — requires GOOGLE_WEB_CLIENT_ID in .env
  static Future<AuthResponse> signInWithGoogle() async {
    final webClientId = EnvConfig.googleWebClientId;
    final googleSignIn = GoogleSignIn(serverClientId: webClientId.isNotEmpty ? webClientId : null);
    await googleSignIn.signOut(); // force account picker every time
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google Sign In cancelled');
    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;
    if (idToken == null) throw Exception('No ID token from Google');
    return await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  static User? get currentUser => _client.auth.currentUser;

  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  // ---- Personal Rules ----

  static Future<PersonalRules?> getPersonalRules(String userId) async {
    // Check cache first
    final cached = await CacheService.read('rules_$userId');
    if (cached != null) {
      if (cached is Map) {
        return PersonalRules.fromJson(Map<String, dynamic>.from(cached));
      }
      return null;
    }

    final response = await _client
        .from('personal_rules')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (response == null) return null;

    // Cache the result for 24 hours
    await CacheService.write('rules_$userId', response, ttlHours: 24);
    return PersonalRules.fromJson(response);
  }

  /// Strips control characters and trims whitespace from user-supplied strings
  /// before they are written to the database.
  static String? _sanitize(String? value, {int maxLength = 500}) {
    if (value == null) return null;
    return value
        .trim()
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .substring(0, value.trim().length.clamp(0, maxLength));
  }

  static void _validatePersonalRules(PersonalRules rules) {
    if (rules.maxDailyLoss != null) {
      if (rules.maxDailyLoss! <= 0) {
        throw ArgumentError('Max daily loss must be positive.');
      }
      if (rules.maxDailyLossType == 'percent' && rules.maxDailyLoss! > 100) {
        throw ArgumentError('Max daily loss percent cannot exceed 100%.');
      }
    }
    if (rules.maxTradesPerDay != null &&
        (rules.maxTradesPerDay! <= 0 || rules.maxTradesPerDay! > 200)) {
      throw ArgumentError('Max trades per day must be between 1 and 200.');
    }
    if (rules.maxWeeklyLoss != null && rules.maxWeeklyLoss! <= 0) {
      throw ArgumentError('Max weekly loss must be positive.');
    }
    final validDurations = {'2h', '6h', 'midnight', '24h'};
    if (!validDurations.contains(rules.killswitchDuration)) {
      throw ArgumentError('Invalid killswitch duration.');
    }
    if (rules.accountNumber != null && rules.accountNumber!.isNotEmpty) {
      if (!RegExp(r'^\d{5,10}$').hasMatch(rules.accountNumber!)) {
        throw ArgumentError('Account number must be 5–10 digits.');
      }
    }
  }

  static Future<void> savePersonalRules(PersonalRules rules) async {
    _validatePersonalRules(rules);
    await CacheService.delete('rules_${rules.userId}');
    await _client
        .from('personal_rules')
        .upsert(rules.toJson(), onConflict: 'user_id');
    _logEvent('rules_updated');
  }

  // ---- Challenge ----

  static Future<List<Challenge>> getAllChallenges(String userId) async {
    // Check cache first (TTL 1 hour)
    final cached = await CacheService.read('challenges_$userId');
    if (cached is List) {
      return cached
          .whereType<Map>()
          .map((e) => Challenge.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final response = await _client
        .from('challenges')
        .select()
        .eq('user_id', userId)
        .order('started_at', ascending: false);
    final list = response as List<dynamic>;

    // Cache for 1 hour
    await CacheService.write('challenges_$userId', list, ttlHours: 1);
    return list
        .whereType<Map>()
        .map((e) => Challenge.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<List<Challenge>> getActiveChallenges(String userId) async {
    final response = await _client
        .from('challenges')
        .select()
        .eq('user_id', userId)
        .eq('status', 'active')
        .order('started_at', ascending: false);
    final activeList = response as List<dynamic>;
    return activeList
        .whereType<Map>()
        .map((e) => Challenge.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<Challenge?> getActiveChallenge(String userId) async {
    final response = await _client
        .from('challenges')
        .select()
        .eq('user_id', userId)
        .eq('status', 'active')
        .order('started_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (response == null) return null;
    return Challenge.fromJson(response);
  }

  static void _validateChallenge(Challenge c) {
    if (c.accountSize <= 0) {
      throw ArgumentError('Account size must be positive.');
    }
    if (c.profitTarget <= 0 || c.profitTarget > 100) {
      throw ArgumentError('Profit target must be between 0% and 100%.');
    }
    if (c.maxDailyLoss <= 0 || c.maxDailyLoss > 25) {
      throw ArgumentError('Max daily loss must be between 0% and 25%.');
    }
    if (c.maxTotalDrawdown <= 0 || c.maxTotalDrawdown > 50) {
      throw ArgumentError('Max total drawdown must be between 0% and 50%.');
    }
    if (c.durationDays < 1 || c.durationDays > 365) {
      throw ArgumentError('Duration must be between 1 and 365 days.');
    }
    const validStyles = {'conservative', 'moderate', 'aggressive'};
    if (!validStyles.contains(c.style)) {
      throw ArgumentError('Invalid style value.');
    }
  }

  /// Inserisce una nuova challenge lasciando che Supabase generi il UUID.
  /// Restituisce la challenge salvata con l'ID reale generato dal DB.
  static Future<Challenge> insertChallenge(Challenge challenge) async {
    _validateChallenge(challenge);
    // Sanitize free-text fields before DB insert
    final sanitized = challenge.copyWith(
      propFirmName: _sanitize(challenge.propFirmName, maxLength: 100),
      accountNumber: _sanitize(challenge.accountNumber, maxLength: 20),
    );
    final data = sanitized.toJson();
    data.remove('id'); // Supabase genera UUID via gen_random_uuid()
    final result = await _client
        .from('challenges')
        .insert(data)
        .select()
        .single();
    return Challenge.fromJson(result);
  }

  /// Aggiorna una challenge esistente (richiede ID UUID valido).
  static Future<void> saveChallenge(Challenge challenge) async {
    // Invalidate challenges cache
    await CacheService.delete('challenges_${challenge.userId}');
    await _client
        .from('challenges')
        .upsert(challenge.toJson(), onConflict: 'id');
  }

  static Future<void> updateChallengeStatus(
      String challengeId, String status) async {
    await _client
        .from('challenges')
        .update({'status': status})
        .eq('id', challengeId);
  }

  static Future<void> updateAiPlan(
      String challengeId, Map<String, dynamic> plan) async {
    await _client
        .from('challenges')
        .update({'ai_plan': plan})
        .eq('id', challengeId);
  }

  // ---- Killswitch Events ----

  static Future<List<KillswitchEvent>> getKillswitchHistory(
      String userId) async {
    // Check cache first (TTL 1 hour)
    final cached = await CacheService.read('ks_$userId');
    if (cached is List) {
      return cached
          .whereType<Map>()
          .map((e) => KillswitchEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final response = await _client
        .from('killswitch_events')
        .select()
        .eq('user_id', userId)
        .order('triggered_at', ascending: false)
        .limit(50);
    final list = response as List<dynamic>;

    // Cache for 1 hour
    await CacheService.write('ks_$userId', list, ttlHours: 1);
    return list
        .whereType<Map>()
        .map((e) => KillswitchEvent.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<String> triggerKillswitch(KillswitchEvent event) async {
    try {
      final response = await _client
          .from('killswitch_events')
          .insert(event.toJson())
          .select('id')
          .single();
      // Invalidate cache so history shows the new event immediately
      await CacheService.delete('ks_${event.userId}');
      _logEvent('killswitch_triggered', {'reason': event.reason, 'mode': event.accountMode});
      return response['id'] as String? ?? event.id;
    } catch (_) {
      return event.id; // fallback all'ID locale se il salvataggio fallisce
    }
  }

  static Future<void> resolveKillswitch(
      String eventId, bool withToken) async {
    await _client.from('killswitch_events').update({
      'resolved_at': DateTime.now().toIso8601String(),
      'unlocked_early': true,
      'unlocked_with_token': withToken,
    }).eq('id', eventId);
    // Invalidate cache for current user
    final uid = currentUserId;
    if (uid != null) await CacheService.delete('ks_$uid');
  }

  static Stream<List<Map<String, dynamic>>> watchKillswitchEvents(
      String userId) {
    return _client
        .from('killswitch_events')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('triggered_at', ascending: false);
  }

  // ---- Tokens ----

  static Future<int> getTokensAvailable(String userId) async {
    final response = await _client
        .from('profiles')
        .select('tokens_available')
        .eq('id', userId)
        .maybeSingle();
    return response?['tokens_available'] as int? ?? 0;
  }

  static Future<bool> consumeToken(String userId) async {
    // Decrementa di 1, solo se > 0
    final current = await getTokensAvailable(userId);
    if (current <= 0) return false;
    await _client
        .from('profiles')
        .update({'tokens_available': current - 1})
        .eq('id', userId);
    _logEvent('token_consumed', {'remaining': current - 1});
    return true;
  }

  // ---- Profiles ----

  static Future<void> ensureProfile(String userId) async {
    final existing = await _client
        .from('profiles')
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    if (existing == null) {
      await _client.from('profiles').insert({
        'id': userId,
        'account_mode': 'personal',
        'tokens_available': 2,
        'subscription_tier': 'free',
      });
    }
  }

  static Future<Map<String, dynamic>?> getProfile(String userId) async {
    return await _client
        .from('profiles')
        .select('id, account_mode, tokens_available, tokens_reset_at, subscription_tier, created_at')
        .eq('id', userId)
        .maybeSingle();
  }

  static Future<void> updateAccountMode(
      String userId, String mode) async {
    await _client
        .from('profiles')
        .update({'account_mode': mode})
        .eq('id', userId);
  }

  /// Elimina tutti i dati utente dalle tabelle Postgres.
  /// Nota: la riga in auth.users richiede una Edge Function con service role key.
  /// La sessione viene invalidata dal successivo signOut().
  static Future<void> deleteUserData(String userId) async {
    await _client.from('killswitch_events').delete().eq('user_id', userId);
    await _client.from('personal_rules').delete().eq('user_id', userId);
    await _client.from('challenges').delete().eq('user_id', userId);
    await _client.from('notification_prefs').delete().eq('user_id', userId);
    await _client.from('broker_connections').delete().eq('user_id', userId);
    await _client.from('profiles').delete().eq('id', userId);
  }

  // ---- Notification Prefs ----

  static Future<void> saveNotificationPrefs(
      String userId, Map<String, bool> prefs) async {
    await _client.from('notification_prefs').upsert(
      {'user_id': userId, ...prefs},
      onConflict: 'user_id',
    );
  }

  static Future<Map<String, dynamic>?> getNotificationPrefs(
      String userId) async {
    return await _client
        .from('notification_prefs')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
  }
}
