import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';

/// Stream Supabase Realtime per il conteggio token dell'utente corrente.
final tokenRealtimeProvider = StreamProvider.autoDispose<int>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId.isEmpty) return Stream.value(0);

  return Supabase.instance.client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', userId)
      .map((rows) =>
          rows.isNotEmpty ? (rows.first['tokens_available'] as int? ?? 0) : 0);
});
