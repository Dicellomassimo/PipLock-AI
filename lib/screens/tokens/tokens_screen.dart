import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/stat_ring_chart.dart';

class TokensScreen extends ConsumerWidget {
  const TokensScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final profile = ref.watch(authProvider).profile;
    final tokensWeekly = profile?.tokensWeekly ?? 0;

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
                  Text(
                    s.tokensTitle,
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Premium token hero card
                  AnimatedCard(
                    padding: const EdgeInsets.all(24),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                    child: Row(
                      children: [
                        StatRingChart(
                          value: (tokensWeekly / 2.0).clamp(0.0, 1.0),
                          color: AppColors.accent,
                          size: 80,
                          strokeWidth: 7,
                          center: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$tokensWeekly',
                                style: GoogleFonts.manrope(
                                  color: AppColors.accent,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$tokensWeekly',
                                style: GoogleFonts.manrope(
                                  color: AppColors.accent,
                                  fontSize: 56,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -3,
                                  height: 0.9,
                                ),
                              ),
                              Text(
                                s.t('tokens this week', 'token questa settimana'),
                                style: GoogleFonts.manrope(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                s.t('$tokensWeekly / 2 weekly tokens used', '$tokensWeekly / 2 token settimanali usati'),
                                style: GoogleFonts.manrope(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                s.tokensRenew,
                                style: GoogleFonts.manrope(
                                  color: AppColors.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Informational card — no purchases by design
                  AnimatedCard(
                    padding: const EdgeInsets.all(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
                          ),
                          child: const Icon(Icons.info_outline_rounded, color: AppColors.accent, size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            s.t(
                              '2 tokens per week, reset every Sunday at midnight. No purchases — this is by design: PipLock is a discipline tool, not a store.',
                              '2 token a settimana, reset ogni domenica a mezzanotte. Nessun acquisto — è una scelta voluta: PipLock è uno strumento di disciplina, non un negozio.',
                            ),
                            style: GoogleFonts.manrope(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
