import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).profile;
    final s = ref.watch(appStringsProvider);
    final isPro = profile?.subscriptionTier == 'pro';
    final email = kDevMode
        ? 'dev@piplock.ai'
        : Supabase.instance.client.auth.currentUser?.email ?? 'Utente';
    final displayName = email.split('@').first;
    final joinYear = profile?.createdAt.year ?? DateTime.now().year;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: AppColors.textPrimary, size: 20),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          s.accountTitle,
          style: GoogleFonts.manrope(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildProfileHero(displayName, email, isPro),
          const SizedBox(height: 24),
          _buildSubscriptionCard(context, isPro, s),
          const SizedBox(height: 20),
          _sectionLabel(s.accountSectionInfo),
          const SizedBox(height: 10),
          _infoTile(
            icon: Icons.mail_outline_rounded,
            label: s.accountEmail,
            value: email,
            onTap: () => _copyToClipboard(context, email, s),
          ),
          _infoTile(
            icon: Icons.badge_outlined,
            label: s.accountUserId,
            value: profile?.id ?? '—',
            onTap: () => _copyToClipboard(context, profile?.id ?? '', s),
          ),
          _infoTile(
            icon: Icons.calendar_today_outlined,
            label: s.accountMemberSince,
            value: joinYear.toString(),
          ),
          _infoTile(
            icon: Icons.toll_rounded,
            label: s.accountTokensAvailable,
            value: '${profile?.tokensAvailable ?? 0} / 2',
            valueColor: AppColors.accent,
            onTap: () => Navigator.pushNamed(context, '/tokens'),
          ),
          const SizedBox(height: 20),
          _sectionLabel(s.accountSectionMode),
          const SizedBox(height: 10),
          _modeCard(profile?.accountMode ?? 'personal', s),
          const SizedBox(height: 20),
          _sectionLabel(s.accountSectionActions),
          const SizedBox(height: 10),
          _actionTile(
            context: context,
            icon: Icons.lock_reset_outlined,
            label: s.accountChangePassword,
            onTap: () => Navigator.pushNamed(context, '/forgot_password'),
          ),
          _actionTile(
            context: context,
            icon: Icons.delete_outline_rounded,
            label: s.accountDeleteAccount,
            color: AppColors.danger,
            onTap: () => _showDeleteDialog(context, ref, s),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              s.accountVersion,
              style: GoogleFonts.manrope(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProfileHero(String name, String email, bool isPro) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Ambient glow blob
        Positioned(
          top: 0, left: 0, right: 0, bottom: 0,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: RadialGradient(
                  center: const Alignment(-0.8, -0.5),
                  radius: 1.2,
                  colors: [
                    AppColors.accent.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppColors.logoGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'T',
                style: GoogleFonts.manrope(
                  color: Colors.black,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.manrope(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: GoogleFonts.manrope(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPro
                        ? AppColors.accent.withValues(alpha: 0.12)
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isPro
                          ? AppColors.accent.withValues(alpha: 0.4)
                          : AppColors.border,
                    ),
                  ),
                  child: Text(
                    isPro ? 'Pro' : 'Free',
                    style: GoogleFonts.manrope(
                      color: isPro ? AppColors.accent : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
      ],
    );
  }

  Widget _buildSubscriptionCard(BuildContext context, bool isPro, AppStrings s) {
    if (isPro) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: AppColors.heroGradientOk,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.star_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.accountProActive,
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    s.accountManagePlay,
                    style: GoogleFonts.manrope(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/tokens'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star_outline_rounded,
                  color: AppColors.accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.accountUpgradePro,
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    s.accountUpgradeSubtitle,
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _modeCard(String mode, AppStrings s) {
    final isChallenge = mode == 'challenge';
    return Container(
      padding: const EdgeInsets.all(16),
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
            child: Icon(
              isChallenge ? Icons.emoji_events_rounded : Icons.person_rounded,
              color: AppColors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isChallenge ? s.accountModePropFirm : s.accountModePersonal,
                  style: GoogleFonts.manrope(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  s.accountChangeMode,
                  style: GoogleFonts.manrope(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.manrope(
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.3,
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          highlightColor: AppColors.accent.withValues(alpha: 0.07),
          splashColor: AppColors.accent.withValues(alpha: 0.10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.textSecondary, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.manrope(
                    color: valueColor ?? AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.copy_outlined,
                      color: AppColors.textTertiary, size: 14),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          highlightColor: (color ?? AppColors.accent).withValues(alpha: 0.07),
          splashColor: (color ?? AppColors.accent).withValues(alpha: 0.10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color != null
                    ? color.withValues(alpha: 0.2)
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: c, size: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.manrope(
                      color: c,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Delete Account Dialog ────────────────────────────────────────────────────

  void _copyToClipboard(BuildContext context, String text, AppStrings s) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.accountCopied, style: GoogleFonts.manrope()),
        backgroundColor: AppColors.cardBg,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, AppStrings s) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeleteAccountDialog(s: s, parentRef: ref),
    );
  }
}

// ─── Delete Account Dialog ─────────────────────────────────────────────────────

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  final AppStrings s;
  final WidgetRef parentRef;
  const _DeleteAccountDialog({required this.s, required this.parentRef});

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  bool _loading = false;

  Future<void> _deleteAccount() async {
    setState(() => _loading = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    if (userId != null) {
      try {
        // Delete all user data in dependency order
        await client
            .from('killswitch_events')
            .delete()
            .eq('user_id', userId);
        await client
            .from('broker_connections')
            .delete()
            .eq('user_id', userId);
        await client
            .from('notification_prefs')
            .delete()
            .eq('user_id', userId);
        await client
            .from('challenges')
            .delete()
            .eq('user_id', userId);
        await client
            .from('personal_rules')
            .delete()
            .eq('user_id', userId);
        await client
            .from('profiles')
            .delete()
            .eq('id', userId);
      } catch (_) {
        // Best-effort: continue to sign out even if some deletes fail
      }
    }

    try {
      await client.auth.signOut();
    } catch (_) {}

    if (mounted) {
      Navigator.of(context).pop(); // close dialog
      Navigator.of(context).pushNamedAndRemoveUntil('/auth', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return AlertDialog(
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        s.accountDeleteDialogTitle,
        style: GoogleFonts.manrope(
            color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.accountDeleteDialogContent,
            style: GoogleFonts.manrope(
                color: AppColors.textSecondary, height: 1.5, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.danger, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.t(
                      'This action cannot be undone. All your data, rules, challenges and history will be permanently deleted.',
                      'Questa azione è irreversibile. Tutti i tuoi dati, regole, challenge e storico verranno eliminati definitivamente.',
                    ),
                    style: GoogleFonts.manrope(
                        color: AppColors.danger, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text(s.accountCancel,
              style:
                  GoogleFonts.manrope(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _deleteAccount,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.danger.withValues(alpha: 0.4),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  s.t('Delete account', 'Elimina account'),
                  style:
                      GoogleFonts.manrope(fontWeight: FontWeight.w700),
                ),
        ),
      ],
    );
  }
}
