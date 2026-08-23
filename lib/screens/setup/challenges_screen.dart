import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../config/app_theme.dart';
import '../../models/challenge.dart';
import '../../providers/auth_provider.dart';
import '../../providers/challenge_provider.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/glow_progress_bar.dart';

class ChallengesScreen extends ConsumerStatefulWidget {
  const ChallengesScreen({super.key});

  @override
  ConsumerState<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends ConsumerState<ChallengesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(currentUserIdProvider);
      ref.read(challengeListProvider.notifier).load(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final challenges = ref.watch(challengeListProvider);
    final s = ref.watch(appStringsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Inline header
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.pagePadding, 20, AppTheme.pagePadding, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.challengesTitle,
                      style: GoogleFonts.manrope(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      await Navigator.pushNamed(context, '/challenge_setup');
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
                      ),
                      child: const Icon(Icons.add, color: AppColors.accent, size: 22),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: challenges.isEmpty
                  ? _buildEmpty(context, s)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(AppTheme.pagePadding, 0, AppTheme.pagePadding, 20),
                      itemCount: challenges.length,
                      itemBuilder: (context, i) => _buildCard(context, challenges[i], s),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, AppStrings s) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
              ),
              child: const Icon(Icons.emoji_events_outlined, color: AppColors.warning, size: 38),
            ),
            const SizedBox(height: 20),
            Text(
              s.challengesEmpty,
              style: GoogleFonts.manrope(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.challengesEmptySubtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            PremiumButton(
              label: s.challengesAdd,
              icon: Icons.add,
              onTap: () async {
                await Navigator.pushNamed(context, '/challenge_setup');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, Challenge challenge, AppStrings s) {
    final statusColor = switch (challenge.status) {
      'passed' => AppColors.accent,
      'failed' => AppColors.danger,
      'abandoned' => AppColors.textSecondary,
      _ => AppColors.warning,
    };
    final statusLabel = switch (challenge.status) {
      'passed' => s.challengesStatusPassed,
      'failed' => s.challengesStatusFailed,
      'abandoned' => s.challengesStatusAbandoned,
      _ => s.challengesStatusActive,
    };
    final sizeK = (challenge.accountSize / 1000).toStringAsFixed(0);
    final startDate =
        '${challenge.startedAt.day.toString().padLeft(2, '0')}/'
        '${challenge.startedAt.month.toString().padLeft(2, '0')}/'
        '${challenge.startedAt.year}';
    final totalDays = challenge.durationDays;
    final currentDay = challenge.currentDay;
    final dayProgress = totalDays > 0 ? (currentDay / totalDays).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/ai_planner', arguments: challenge),
      child: AnimatedCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                  ),
                  child: Icon(Icons.emoji_events_outlined, color: statusColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge.propFirmName ?? 'Prop Firm',
                        style: GoogleFonts.manrope(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.challengesMeta(sizeK, startDate),
                        style: GoogleFonts.manrope(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.manrope(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
              ],
            ),
            if (challenge.status == 'active') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Day $currentDay of $totalDays',
                    style: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  Text(
                    '${(dayProgress * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.manrope(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              GlowProgressBar(
                value: dayProgress,
                fillColor: statusColor,
                trackColor: AppColors.divider,
                height: 4,
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}
