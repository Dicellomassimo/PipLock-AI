import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../models/challenge.dart';
import '../../models/chat_session.dart';
import '../../providers/challenge_provider.dart';
import '../../providers/chat_history_provider.dart';
import '../../providers/pending_challenge_provider.dart';
import '../../widgets/ambient_blobs.dart';
import 'chat_session_screen.dart';

class AiPlannerScreen extends ConsumerStatefulWidget {
  const AiPlannerScreen({super.key});

  @override
  ConsumerState<AiPlannerScreen> createState() => _AiPlannerScreenState();
}

class _AiPlannerScreenState extends ConsumerState<AiPlannerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handlePendingChallenge());
  }

  /// Se c'è una challenge in sospeso (appena creata) apre subito una nuova sessione.
  Future<void> _handlePendingChallenge() async {
    final pending = ref.read(pendingChallengeProvider);
    if (pending == null) return;
    ref.read(pendingChallengeProvider.notifier).state = null;
    ref.read(challengeListProvider.notifier).addChallenge(pending);
    await _openNewSession(type: 'challenge', challenge: pending);
  }

  Future<void> _openNewSession({
    required String type,
    Challenge? challenge,
  }) async {
    final session = await ref.read(chatHistoryProvider.notifier).createSession(
          type: type,
          contextName: type == 'challenge'
              ? (challenge?.propFirmName ?? 'Challenge')
              : 'Personal',
          challengeId: challenge?.id,
        );
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatSessionScreen(
          session: session,
          initialChallenge: challenge,
        ),
      ),
    );
  }

  Future<void> _openExistingSession(ChatSession session) async {
    // Trova la challenge corrispondente se presente
    Challenge? challenge;
    if (session.type == 'challenge' && session.challengeId != null) {
      final challenges = ref.read(challengeListProvider);
      try {
        challenge =
            challenges.firstWhere((c) => c.id == session.challengeId);
      } catch (_) {}
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatSessionScreen(
          session: session,
          initialChallenge: challenge,
        ),
      ),
    );
  }

  void _showNewChatSheet() {
    final challenges = ref.read(challengeListProvider);
    final s = ref.read(appStringsProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.aiPlannerNewChat,
              style: GoogleFonts.manrope(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              s.aiPlannerSelectContext,
              style: GoogleFonts.manrope(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 20),
            // Conto personale
            _NewChatOption(
              icon: Icons.person_outline,
              title: s.aiPlannerPersonalAccount,
              subtitle: s.aiPlannerPersonalSubtitle,
              onTap: () {
                Navigator.pop(ctx);
                _openNewSession(type: 'personal');
              },
            ),
            if (challenges.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(color: AppColors.divider),
              const SizedBox(height: 6),
              Text(
                s.aiPlannerActiveChallenges,
                style: GoogleFonts.manrope(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...challenges.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _NewChatOption(
                      icon: Icons.emoji_events_outlined,
                      title: c.propFirmName ?? 'Prop Firm',
                      subtitle:
                          '\$${(c.accountSize / 1000).toStringAsFixed(0)}k · ${c.style}',
                      onTap: () {
                        Navigator.pop(ctx);
                        _openNewSession(type: 'challenge', challenge: c);
                      },
                    ),
                  )),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/challenge_setup');
                },
                icon: const Icon(Icons.add, size: 16),
                label: Text(s.aiPlannerNewChallenge,
                    style:
                        GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(chatHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          ref.watch(appStringsProvider).aiPlannerTitle,
          style: GoogleFonts.manrope(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square, color: AppColors.accent, size: 22),
            tooltip: ref.watch(appStringsProvider).aiPlannerNewChat,
            onPressed: _showNewChatSheet,
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: IgnorePointer(child: AmbientBlobs())),
          sessions.isEmpty ? _buildEmpty() : _buildSessionList(sessions),
        ],
      ),
      floatingActionButton: sessions.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _showNewChatSheet,
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add, size: 20),
              label: Text(ref.watch(appStringsProvider).aiPlannerNewChat,
                  style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
            ),
    );
  }

  Widget _buildEmpty() {
    final s = ref.watch(appStringsProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.auto_awesome,
                  color: AppColors.accent, size: 38),
            ),
            const SizedBox(height: 20),
            Text(
              s.aiPlannerEmptyTitle,
              style: GoogleFonts.manrope(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.aiPlannerEmptySubtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                  color: AppColors.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openNewSession(type: 'personal'),
                icon: const Icon(Icons.person_outline, size: 18),
                label: Text(s.aiPlannerCardPersonal,
                    style:
                        GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showNewChatSheet,
                icon: const Icon(Icons.emoji_events_outlined, size: 18),
                label: Text(s.aiPlannerCardChallenge,
                    style:
                        GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionList(List<ChatSession> sessions) {
    final s = ref.watch(appStringsProvider);
    // Raggruppa per data
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final todaySessions = sessions
        .where((sess) => sess.updatedAt.isAfter(today))
        .toList();
    final yesterdaySessions = sessions
        .where((sess) =>
            sess.updatedAt.isAfter(yesterday) && !sess.updatedAt.isAfter(today))
        .toList();
    final weekSessions = sessions
        .where((sess) =>
            sess.updatedAt.isAfter(weekAgo) && !sess.updatedAt.isAfter(yesterday))
        .toList();
    final olderSessions = sessions
        .where((sess) => !sess.updatedAt.isAfter(weekAgo))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        if (todaySessions.isNotEmpty) ...[
          _GroupHeader(s.aiPlannerGroupToday),
          ...todaySessions.map(_buildSessionTile),
        ],
        if (yesterdaySessions.isNotEmpty) ...[
          _GroupHeader(s.aiPlannerGroupYesterday),
          ...yesterdaySessions.map(_buildSessionTile),
        ],
        if (weekSessions.isNotEmpty) ...[
          _GroupHeader(s.aiPlannerGroupThisWeek),
          ...weekSessions.map(_buildSessionTile),
        ],
        if (olderSessions.isNotEmpty) ...[
          _GroupHeader(s.aiPlannerGroupPrevious),
          ...olderSessions.map(_buildSessionTile),
        ],
      ],
    );
  }

  Widget _buildSessionTile(ChatSession session) {
    final s = ref.watch(appStringsProvider);
    final lastMsg = session.messages.isNotEmpty
        ? session.messages.last.text
        : session.type == 'personal'
            ? s.aiPlannerSessionPersonal
            : s.aiPlannerSessionChallenge(session.contextName ?? '');

    final icon = session.type == 'personal'
        ? Icons.person_outline
        : Icons.emoji_events_outlined;

    return Dismissible(
      key: Key(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      onDismissed: (_) =>
          ref.read(chatHistoryProvider.notifier).deleteSession(session.id),
      child: GestureDetector(
        onTap: () => _openExistingSession(session),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      style: GoogleFonts.manrope(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lastMsg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(session.updatedAt),
                    style: GoogleFonts.manrope(
                        color: AppColors.textSecondary, fontSize: 10),
                  ),
                  if (session.messages.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${session.messages.length}',
                        style: GoogleFonts.manrope(
                          color: AppColors.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  color: AppColors.textSecondary, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (dt.isAfter(today)) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }
}

// ── Componenti interni ──────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  final String label;
  const _GroupHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: AppColors.textSecondary,
          fontSize: 11,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NewChatOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NewChatOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: AppColors.accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.manrope(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      )),
                  Text(subtitle,
                      style: GoogleFonts.manrope(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }
}
