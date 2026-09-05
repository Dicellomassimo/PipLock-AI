import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../models/journal_entry.dart';
import '../../providers/journal_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/share_service.dart';
import '../dashboard/dashboard_screen.dart' show QuickLogSheet;

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  void _showQuickLog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickLogSheet(
        onSubmit: (entry) => ref.read(journalProvider.notifier).addEntry(entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(journalProvider);
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          s.t('Trade Journal', 'Diario dei Trade'),
          style: GoogleFonts.manrope(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_outlined, color: AppColors.textSecondary),
            tooltip: s.t('Quick log', 'Log rapido'),
            onPressed: _showQuickLog,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.textSecondary),
            tooltip: s.t('Share stats', 'Condividi statistiche'),
            onPressed: () {
              final notifier = ref.read(journalProvider.notifier);
              final entries = state.entries;
              final text = ShareService.generateStatsText(
                ksEvents: 0,
                cleanDays: 0,
                totalTrades: entries.length,
                title: s.historyShareTitle,
                ksLabel: s.historyShareKsEvents(0),
                cleanDaysLabel: s.historyShareCleanDays(0),
                tradesLabel: s.historyShareTrades(entries.length),
                tagline: s.historyShareTagline,
              );
              ShareService.shareText(
                '$text\n\nWin rate: ${notifier.winRate.toStringAsFixed(0)}%',
              );
            },
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : state.error != null
              ? _ErrorState(
                  error: state.error!,
                  onRetry: () => ref.read(journalProvider.notifier).loadEntries(),
                )
              : state.entries.length < 3
                  ? _EmptyState(entries: state.entries)
                  : _JournalContent(state: state),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/journal/add'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends ConsumerWidget {
  final List<JournalEntry> entries;

  const _EmptyState({required this.entries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.book_outlined,
              size: 80,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              entries.isEmpty
                  ? s.t('No trades recorded', 'Nessun trade registrato')
                  : s.t('Add ${3 - entries.length} more trade${3 - entries.length == 1 ? '' : 's'}', 'Aggiungi ancora ${3 - entries.length} trade'),
              style: GoogleFonts.manrope(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              s.t('Start logging your trades to see patterns and insights about your trading psychology.', 'Inizia a registrare i tuoi trade per vedere pattern e insight sulla tua psicologia di trading.'),
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            if (entries.isNotEmpty) ...[
              const SizedBox(height: 24),
              ...entries.map((e) => _CompactEntryTile(entry: e)),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactEntryTile extends StatelessWidget {
  final JournalEntry entry;

  const _CompactEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Text(entry.emotionEmoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Text(
            entry.symbol,
            style: GoogleFonts.manrope(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (entry.pnl != null)
            Text(
              '${entry.pnl! >= 0 ? '+' : ''}${entry.pnl!.toStringAsFixed(0)}\$',
              style: GoogleFonts.manrope(
                color: entry.isProfitable ? AppColors.success : AppColors.danger,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Error state ──────────────────────────────────────────────────────────────

class _ErrorState extends ConsumerWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
            const SizedBox(height: 16),
            Text(
              error,
              style: GoogleFonts.manrope(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              child: Text(
                s.t('Retry', 'Riprova'),
                style: GoogleFonts.manrope(color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Full content ─────────────────────────────────────────────────────────────

class _JournalContent extends ConsumerWidget {
  final JournalState state;

  const _JournalContent({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(journalProvider.notifier);
    final entries = state.entries;

    // Raggruppa per data
    final grouped = <String, List<JournalEntry>>{};
    for (final e in entries) {
      final key = DateFormat('yyyy-MM-dd').format(e.date);
      grouped.putIfAbsent(key, () => []).add(e);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Summary row
        _SummaryRow(notifier: notifier, total: entries.length),
        const SizedBox(height: 12),

        // AI Insights card
        if (state.aiInsights != null) ...[
          _AiInsightsCard(insights: state.aiInsights!),
          const SizedBox(height: 12),
        ] else ...[
          _AnalyzeButton(
            onTap: () => ref.read(journalProvider.notifier).analyzeWithAI(),
            isLoading: state.isSaving,
          ),
          const SizedBox(height: 12),
        ],

        // Grouped entries
        for (final dateKey in sortedKeys) ...[
          _DateHeader(dateKey: dateKey),
          ...grouped[dateKey]!.map((e) => _EntryCard(
                entry: e,
                onDelete: () => _confirmDelete(context, ref, e.id),
              )),
        ],

        const SizedBox(height: 80), // FAB space
      ],
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String id) async {
    final s = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          s.t('Delete trade', 'Elimina trade'),
          style: GoogleFonts.manrope(color: AppColors.textPrimary),
        ),
        content: Text(
          s.t('Are you sure you want to delete this trade from the journal?', 'Sei sicuro di voler eliminare questo trade dal diario?'),
          style: GoogleFonts.manrope(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.t('Cancel', 'Annulla'),
                style: GoogleFonts.manrope(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.t('Delete', 'Elimina'),
                style: GoogleFonts.manrope(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(journalProvider.notifier).deleteEntry(id);
    }
  }
}

// ─── Summary row ──────────────────────────────────────────────────────────────

class _SummaryRow extends ConsumerWidget {
  final JournalNotifier notifier;
  final int total;

  const _SummaryRow({required this.notifier, required this.total});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final winRate = notifier.winRate;
    final emotion = notifier.mostCommonEmotion;
    final avgScore = notifier.avgEmotionScore;

    final emotionEmoji = {
      'calm': '😌',
      'confident': '🦁',
      'anxious': '😰',
      'frustrated': '😤',
      'fomo': '😱',
      'revenge': '🔥',
    }[emotion] ?? '😶';

    return Row(
      children: [
        _StatChip(label: s.t('Trade', 'Trade'), value: total.toString()),
        const SizedBox(width: 8),
        _StatChip(
          label: s.t('Win rate', 'Win rate'),
          value: '${winRate.toStringAsFixed(0)}%',
          color: winRate >= 50 ? AppColors.success : AppColors.danger,
        ),
        const SizedBox(width: 8),
        _StatChip(label: s.t('Emotion', 'Emozione'), value: emotionEmoji),
        const SizedBox(width: 8),
        _StatChip(
          label: s.t('Mood', 'Umore'),
          value: '${avgScore.toStringAsFixed(1)}⭐',
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatChip({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final hasColor = color != null;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: hasColor ? color!.withValues(alpha: 0.08) : AppColors.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasColor ? color!.withValues(alpha: 0.3) : AppColors.divider,
            width: hasColor ? 1.5 : 1,
          ),
          boxShadow: hasColor
              ? [BoxShadow(color: color!.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 3))]
              : null,
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.manrope(
                color: color ?? AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── AI Insights card ─────────────────────────────────────────────────────────

class _AiInsightsCard extends StatefulWidget {
  final String insights;

  const _AiInsightsCard({required this.insights});

  @override
  State<_AiInsightsCard> createState() => _AiInsightsCardState();
}

class _AiInsightsCardState extends State<_AiInsightsCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final s = ref.watch(appStringsProvider);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1040),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: Colors.deepPurple.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.smart_toy_rounded, color: Colors.deepPurple.shade300, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.t('AI analysis of your journal', 'Analisi AI del tuo diario'),
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white60,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding:
                  const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Text(
                widget.insights,
                style: GoogleFonts.manrope(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ),
        ],
      ),
    );
      },
    );
  }
}

// ─── Analyze button ───────────────────────────────────────────────────────────

class _AnalyzeButton extends ConsumerWidget {
  final VoidCallback onTap;
  final bool isLoading;

  const _AnalyzeButton({required this.onTap, required this.isLoading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    return OutlinedButton.icon(
      onPressed: isLoading ? null : onTap,
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child:
                  CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
            )
          : const Icon(Icons.smart_toy_rounded, size: 18),
      label: Text(
        s.t('Analyze with AI', 'Analizza con AI'),
        style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accent,
        side: const BorderSide(color: AppColors.accent),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ─── Date header ──────────────────────────────────────────────────────────────

class _DateHeader extends ConsumerWidget {
  final String dateKey;

  const _DateHeader({required this.dateKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final locale = ref.watch(localeProvider);
    final date = DateTime.parse(dateKey);
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    String label;
    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      label = s.t('Today', 'Oggi');
    } else if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      label = s.t('Yesterday', 'Ieri');
    } else {
      label = DateFormat('d MMMM yyyy', locale.languageCode).format(date);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Entry card ───────────────────────────────────────────────────────────────

class _EntryCard extends ConsumerStatefulWidget {
  final JournalEntry entry;
  final VoidCallback onDelete;

  const _EntryCard({required this.entry, required this.onDelete});

  @override
  ConsumerState<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends ConsumerState<_EntryCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final entry = widget.entry;
    final pnlColor = entry.pnl == null
        ? AppColors.textSecondary
        : entry.isProfitable
            ? AppColors.success
            : AppColors.danger;
    final stripeColor = entry.pnl == null
        ? AppColors.textTertiary
        : entry.isProfitable
            ? AppColors.success
            : AppColors.danger;

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      confirmDismiss: (_) async {
        widget.onDelete();
        return false;
      },
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(
          context,
          '/journal/add',
          arguments: entry,
        ),
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: _pressed
                  ? AppColors.cardBg.withValues(alpha: 0.85)
                  : AppColors.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _pressed
                    ? stripeColor.withValues(alpha: 0.4)
                    : AppColors.divider,
              ),
              boxShadow: _pressed
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              children: [
                // Left color stripe
                Container(
                  width: 4,
                  height: 80,
                  decoration: BoxDecoration(
                    color: stripeColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              entry.symbol,
                              style: GoogleFonts.manrope(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              entry.direction == 'long' ? '↑ Long' : '↓ Short',
                              style: GoogleFonts.manrope(
                                color: entry.direction == 'long'
                                    ? AppColors.success
                                    : AppColors.danger,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            if (entry.wasPlanned)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  s.journalPlanned,
                                  style: GoogleFonts.manrope(
                                    color: AppColors.accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (entry.pnl != null)
                              Text(
                                '${entry.pnl! >= 0 ? '+' : ''}${entry.pnl!.toStringAsFixed(2)}\$',
                                style: GoogleFonts.manrope(
                                  color: pnlColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            else
                              Text(
                                s.journalPnlNotRecorded,
                                style: GoogleFonts.manrope(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            const Spacer(),
                            Text(
                              '${entry.emotionEmoji} ${entry.emotionLabel}',
                              style: GoogleFonts.manrope(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        if (entry.setupDescription != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            entry.setupDescription!,
                            style: GoogleFonts.manrope(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
