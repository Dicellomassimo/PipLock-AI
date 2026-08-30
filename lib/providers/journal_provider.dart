import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/journal_entry.dart';
import '../config/constants.dart';
import '../services/ai_service.dart';
import 'auth_provider.dart';
import 'killswitch_provider.dart';
import 'rules_provider.dart';

class JournalState {
  final List<JournalEntry> entries;
  final bool isLoading;  // initial load (no entries shown yet)
  final bool isSaving;   // saving/deleting a single entry (entries remain visible)
  final String? error;
  final String? aiInsights;

  const JournalState({
    this.entries = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.aiInsights,
  });

  JournalState copyWith({
    List<JournalEntry>? entries,
    bool? isLoading,
    bool? isSaving,
    String? error,
    String? aiInsights,
    bool clearError = false,
    bool clearInsights = false,
  }) {
    return JournalState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : error ?? this.error,
      aiInsights: clearInsights ? null : aiInsights ?? this.aiInsights,
    );
  }
}

class JournalNotifier extends StateNotifier<JournalState> {
  final Ref _ref;

  JournalNotifier(this._ref) : super(const JournalState()) {
    loadEntries();
  }

  String get _userId => _ref.read(currentUserIdProvider);

  Future<void> loadEntries() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (kDevMode) {
        await Future.delayed(const Duration(milliseconds: 300));
        state = state.copyWith(
          entries: JournalEntry.mockList,
          isLoading: false,
        );
        return;
      }

      final userId = _userId;
      if (userId.isEmpty) {
        state = state.copyWith(entries: [], isLoading: false);
        return;
      }

      final response = await Supabase.instance.client
          .from('journal_entries')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false)
          .limit(100);

      final entries = (response as List)
          .map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(entries: entries, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Errore nel caricamento del diario: $e',
      );
    }
  }

  Future<void> addEntry(JournalEntry entry) async {
    try {
      if (!kDevMode) {
        await Supabase.instance.client
            .from('journal_entries')
            .insert(entry.toJson());
      }
      final updated = [entry, ...state.entries];
      state = state.copyWith(entries: updated, clearInsights: true);

      // Aggiorna RulesProvider così il killswitch funziona anche in modalità manuale.
      _ref.read(rulesProvider.notifier).trackTrade();
      final pnl = entry.pnl;
      if (pnl != null && pnl < 0) {
        _ref.read(rulesProvider.notifier).trackLoss(-pnl);
      }
      // Controlla se i limiti sono stati superati e attiva il killswitch
      final rulesState = _ref.read(rulesProvider);
      if (rulesState.isKillswitchTriggered) {
        try {
          final ks = _ref.read(killswitchProvider);
          if (!ks.isActive) {
            final userId = _userId;
            final rules = rulesState.rules;
            final reason = rulesState.killswitchReason ?? 'daily_loss';
            final durationStr = rules?.killswitchDuration ?? '6h';
            final durationMin = switch (durationStr) {
              '2h' => 120,
              '6h' => 360,
              '24h' => 1440,
              _ => () {
                  final now = DateTime.now();
                  return DateTime(now.year, now.month, now.day + 1).difference(now).inMinutes;
                }(),
            };
            _ref.read(killswitchProvider.notifier).activateAndSave(
              reason, durationMin, userId, 'personal',
            );
          }
        } catch (_) {}
      }
    } catch (e) {
      state = state.copyWith(error: 'Errore nel salvataggio: $e');
    }
  }

  Future<void> deleteEntry(String id) async {
    try {
      if (!kDevMode) {
        await Supabase.instance.client
            .from('journal_entries')
            .delete()
            .eq('id', id);
      }
      final updated = state.entries.where((e) => e.id != id).toList();
      state = state.copyWith(entries: updated, clearInsights: true);
    } catch (e) {
      state = state.copyWith(error: 'Errore nella cancellazione: $e');
    }
  }

  Future<void> analyzeWithAI() async {
    if (state.entries.isEmpty) return;
    state = state.copyWith(isSaving: true);
    try {
      final entriesMaps = state.entries
          .take(20)
          .map((e) => e.toJson())
          .toList();
      final insights = await AiService.analyzeJournal(entriesMaps);
      state = state.copyWith(aiInsights: insights, isSaving: false);
    } catch (e) {
      // Fallback to local insights on error
      final insights = _generateLocalInsights();
      state = state.copyWith(aiInsights: insights, isSaving: false);
    }
  }

  String _generateLocalInsights() {
    final entries = state.entries;
    final profitable = entries.where((e) => e.isProfitable).length;
    final total = entries.length;
    final winRate = total > 0 ? (profitable / total * 100).round() : 0;

    final emotionCounts = <String, int>{};
    for (final e in entries) {
      emotionCounts[e.emotion] = (emotionCounts[e.emotion] ?? 0) + 1;
    }
    final topEmotion = emotionCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    final unplanned =
        entries.where((e) => !e.wasPlanned).length;
    final unplannedLosses =
        entries.where((e) => !e.wasPlanned && !e.isProfitable).length;

    final buf = StringBuffer();
    buf.writeln('📊 Analisi del tuo diario (${entries.length} trade):');
    buf.writeln('');
    buf.writeln('• Win rate: $winRate% ($profitable/$total trade in profitto)');
    buf.writeln('• Emozione prevalente: ${_italianEmotion(topEmotion)}');

    if (unplanned > 0) {
      final pct = (unplannedLosses / unplanned * 100).round();
      buf.writeln(
          '• Trade non pianificati: $unplanned ($pct% in perdita) — ridurli è la priorità');
    }

    if (winRate < 40) {
      buf.writeln('');
      buf.writeln(
          '⚠️ Il tuo win rate è sotto il 40%. Rivedi i setup di entrata e considera di ridurre il numero di trade giornalieri.');
    } else if (winRate >= 60) {
      buf.writeln('');
      buf.writeln(
          '✅ Ottimo win rate! Mantieni la disciplina e non aumentare il rischio per euforia.');
    }

    return buf.toString().trim();
  }

  String _italianEmotion(String emotion) {
    const map = {
      'calm': 'Calmo',
      'confident': 'Fiducioso',
      'anxious': 'Ansioso',
      'frustrated': 'Frustrato',
      'fomo': 'FOMO',
      'revenge': 'Revenge',
    };
    return map[emotion] ?? emotion;
  }

  // ─── Stats computed ───────────────────────────────────────────────────────────

  double get winRate {
    final entries = state.entries;
    if (entries.isEmpty) return 0.0;
    final profitable = entries.where((e) => e.isProfitable).length;
    return profitable / entries.length * 100;
  }

  String get mostCommonEmotion {
    final entries = state.entries;
    if (entries.isEmpty) return 'calm';
    final counts = <String, int>{};
    for (final e in entries) {
      counts[e.emotion] = (counts[e.emotion] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  double get avgEmotionScore {
    final entries = state.entries;
    if (entries.isEmpty) return 0.0;
    final sum = entries.fold<int>(0, (acc, e) => acc + e.emotionScore);
    return sum / entries.length;
  }
}

final journalProvider =
    StateNotifierProvider<JournalNotifier, JournalState>((ref) {
  return JournalNotifier(ref);
});
