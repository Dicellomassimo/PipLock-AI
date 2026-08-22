import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/purchase_service.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/stat_ring_chart.dart';

class TokensScreen extends ConsumerStatefulWidget {
  const TokensScreen({super.key});

  @override
  ConsumerState<TokensScreen> createState() => _TokensScreenState();
}

class _TokensScreenState extends ConsumerState<TokensScreen> {
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final profile = ref.watch(authProvider).profile;
    final tokens = profile?.tokensAvailable ?? 0;

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
                  value: tokens / 7.0,
                  color: AppColors.accent,
                  size: 80,
                  strokeWidth: 7,
                  center: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$tokens',
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
                        '$tokens',
                        style: GoogleFonts.manrope(
                          color: AppColors.accent,
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -3,
                          height: 0.9,
                        ),
                      ),
                      Text(
                        'tokens available',
                        style: GoogleFonts.manrope(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
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
          const SizedBox(height: 24),
          Text(
            s.tokensBuyExtra,
            style: GoogleFonts.manrope(
              color: AppColors.textSecondary,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _purchaseCard(
            quantity: 1,
            price: '€2.99',
            badge: null,
          ),
          const SizedBox(height: 10),
          _purchaseCard(
            quantity: 3,
            price: '€6.99',
            badge: s.tokensBadgePopular,
            isPopular: true,
          ),
          const SizedBox(height: 10),
          _purchaseCard(
            quantity: 5,
            price: '€9.99',
            badge: s.tokensBadgeBestValue,
          ),
          const SizedBox(height: 16),
          // Bottone "Ripristina acquisti" (obbligatorio per policy store)
          Center(
            child: TextButton(
              onPressed: () async {
                final restored = await PurchaseService.restorePurchases();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                    restored
                        ? s.tokensPurchasesRestored
                        : s.tokensNothingToRestore,
                    style: GoogleFonts.manrope(),
                  ),
                  backgroundColor: AppColors.cardBg,
                ));
              },
              child: Text(
                s.tokensRestorePurchases,
                style: GoogleFonts.manrope(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _purchaseCard({
    required int quantity,
    required String price,
    String? badge,
    bool isPopular = false,
  }) {
    final s = ref.watch(appStringsProvider);
    return GestureDetector(
      onTap: () async {
        // Mappa quantità → productId RevenueCat
        final productId = quantity == 1
            ? 'piplock_token_1'
            : quantity == 3
                ? 'piplock_token_3'
                : 'piplock_token_5';

        final added = await PurchaseService.purchaseTokens(productId);
        if (!mounted) return;
        if (added > 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                s.t('$added tokens added!', '$added token aggiunti!'),
                style: GoogleFonts.manrope()),
            backgroundColor: AppColors.accent,
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(s.tokensPurchaseIncomplete, style: GoogleFonts.manrope()),
            backgroundColor: AppColors.cardBg,
          ));
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPopular
                ? AppColors.accent.withValues(alpha: 0.4)
                : AppColors.divider,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.toll, color: AppColors.accent, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '$quantity ${quantity == 1 ? 'token' : 'token'}',
                        style: GoogleFonts.manrope(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            badge,
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
                  Text(
                    s.t(
                      'Unlock Killswitch early ${quantity == 1 ? '1 time' : '$quantity times'}',
                      'Sblocca anticipatamente il Killswitch $quantity ${quantity == 1 ? 'volta' : 'volte'}',
                    ),
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              price,
              style: GoogleFonts.manrope(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _comparisonTable() {
    final s = ref.watch(appStringsProvider);
    final rows = [
      ('Killswitch base', true, true),
      ('AI Planner', false, true),
      (s.t('Dynamic plan progression', 'Progressione dinamica piano'), false, true),
      (s.t('Pre-session check-in', 'Check-in pre-sessione'), true, true),
      (s.t('Advanced FOMO Gatekeeper', 'Gatekeeper FOMO avanzato'), false, true),
      (s.t('2 tokens/week', '2 token/settimana'), true, false),
      (s.t('Unlimited tokens', 'Token illimitati'), false, true),
      (s.t('Extended history (1 year)', 'Storico esteso (1 anno)'), false, true),
      ('Soft + Hard Killswitch', false, true),
    ];

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          children: [
            const SizedBox.shrink(),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Free',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Pro',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        ...rows.map((r) => TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text(
                    r.$1,
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    r.$2 ? Icons.check : Icons.close,
                    color: r.$2 ? AppColors.accent : AppColors.divider,
                    size: 16,
                  ),
                ),
                Center(
                  child: Icon(
                    r.$3 ? Icons.check : Icons.close,
                    color: r.$3 ? AppColors.accent : AppColors.divider,
                    size: 16,
                  ),
                ),
              ],
            )),
      ],
    );
  }
}
