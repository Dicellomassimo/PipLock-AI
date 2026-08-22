import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_session.dart';

class ChatHistoryNotifier extends StateNotifier<List<ChatSession>> {
  static const _prefsKey = 'ai_chat_sessions_v1';
  static const _maxSessions = 30;

  ChatHistoryNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final list = jsonDecode(raw) as List<dynamic>;
      state = list
          .map((e) => ChatSession.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefsKey, jsonEncode(state.map((s) => s.toJson()).toList()));
    } catch (_) {}
  }

  /// Crea una nuova sessione e la aggiunge in cima alla lista.
  Future<ChatSession> createSession({
    required String type,
    String? contextName,
    String? challengeId,
  }) async {
    final now = DateTime.now();
    final dateLabel = '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}';
    final title = type == 'personal'
        ? 'Personale · $dateLabel'
        : '${contextName ?? "Challenge"} · $dateLabel';

    final session = ChatSession(
      id: '${now.millisecondsSinceEpoch}',
      title: title,
      type: type,
      contextName: contextName,
      challengeId: challengeId,
      plan: null,
      messages: [],
      createdAt: now,
      updatedAt: now,
    );

    final updated = [session, ...state];
    state = updated.length > _maxSessions
        ? updated.take(_maxSessions).toList()
        : updated;
    await _save();
    return session;
  }

  Future<void> updateSession(ChatSession session) async {
    state = state
        .map((s) => s.id == session.id ? session : s)
        .toList();
    await _save();
  }

  Future<void> deleteSession(String id) async {
    state = state.where((s) => s.id != id).toList();
    await _save();
  }
}

final chatHistoryProvider =
    StateNotifierProvider<ChatHistoryNotifier, List<ChatSession>>(
  (ref) => ChatHistoryNotifier(),
);
