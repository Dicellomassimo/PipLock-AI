import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../models/personal_account.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/personal_accounts_provider.dart';
import '../../widgets/ambient_blobs.dart';
import '../help/feedback_screen.dart';
import '../help/help_faq_screen.dart';
import '../help/privacy_policy_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _avatarPrefKey = 'profile_avatar_path';
  String? _avatarPath;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_avatarPrefKey);
    if (path != null && File(path).existsSync()) {
      if (mounted) setState(() => _avatarPath = path);
    }
  }

  void _showLanguagePicker(BuildContext context, AppStrings s) {
    final currentLocale = ref.read(localeProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Text(
                  s.langPickerTitle,
                  style: GoogleFonts.manrope(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: AppStrings.supportedLanguages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx2, index) {
                    final (code, nativeName, flag, englishName) =
                        AppStrings.supportedLanguages[index];
                    final locale = Locale(code);
                    final selected =
                        currentLocale.languageCode == locale.languageCode;
                    return _langOption(ctx2, selected, locale, flag, nativeName, englishName);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _langOption(
    BuildContext ctx,
    bool selected,
    Locale locale,
    String flag,
    String nativeName,
    String englishName,
  ) {
    return GestureDetector(
      onTap: () {
        ref.read(localeProvider.notifier).setLocale(locale);
        Navigator.pop(ctx);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.divider,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nativeName,
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (nativeName != englishName)
                    Text(
                      englishName,
                      style: GoogleFonts.manrope(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider).profile;
    final s = ref.watch(appStringsProvider);
    final email = Supabase.instance.client.auth.currentUser?.email ?? profile?.id ?? 'Trader';
    final displayName = email.contains('@') ? email.split('@').first : email;
    final isPro = profile?.subscriptionTier == 'pro';
    final joinYear = profile?.createdAt.year ?? DateTime.now().year;
    final accountsState = ref.watch(personalAccountsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(
              child: IgnorePointer(
                  child: AmbientBlobs(showViolet: true, showSilver: false))),
          ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Hero header ────────────────────────────────────────────────────
          _buildHeroHeader(displayName, email, isPro, joinYear, profile?.tokensAvailable ?? 0, s),
          const SizedBox(height: 28),

          // ── Sezione My Accounts ───────────────────────────────────────────
          _sectionLabel('My Accounts'),
          const SizedBox(height: 10),
          _buildAccountsSection(context, accountsState),
          const SizedBox(height: 24),

          // ── Sezione Configurazione ─────────────────────────────────────────
          _sectionLabel(s.settingsSectionGeneral),
          const SizedBox(height: 10),
          _sectionCard([
            _SettingRow(
              icon: Icons.tune_rounded,
              color: AppColors.accent,
              title: s.settingsTileRules,
              onTap: () => Navigator.pushNamed(context, '/personal_rules'),
            ),
            _SettingRow(
              icon: Icons.link_rounded,
              color: AppColors.warning,
              title: s.settingsTileBroker,
              onTap: () => Navigator.pushNamed(context, '/broker'),
            ),
            _SettingRow(
              icon: Icons.military_tech_rounded,
              color: AppColors.accent,
              title: s.settingsTileChallenges,
              onTap: () => Navigator.pushNamed(context, '/challenges'),
            ),
            _SettingRow(
              icon: Icons.notifications_rounded,
              color: const Color(0xFF4A90E2),
              title: s.settingsTileNotifications,
              onTap: () => Navigator.pushNamed(context, '/notification_settings'),
            ),
            _SettingRow(
              icon: Icons.language_rounded,
              color: const Color(0xFF9B59B6),
              title: s.settingsLanguage,
              subtitle: s.settingsLanguageSubtitle,
              onTap: () => _showLanguagePicker(context, s),
            ),
          ]),
          const SizedBox(height: 24),

          // ── Sezione Account ────────────────────────────────────────────────
          _sectionLabel(s.settingsSectionAccount),
          const SizedBox(height: 10),
          // Token balance card — inline, zero extra taps
          _TokenBalanceCard(
            tokensWeekly: profile?.tokensWeekly ?? 0,
          ),
          const SizedBox(height: 10),
          _sectionCard([
            _SettingRow(
              icon: Icons.diamond_rounded,
              color: AppColors.accent,
              title: s.settingsTileSubscription,
              subtitle: isPro ? s.settingsProActive : s.settingsUpgradePro,
              subtitleColor: isPro ? AppColors.accent : null,
              onTap: () => Navigator.pushNamed(context, '/paywall'),
            ),
            _SettingRow(
              icon: Icons.shield_rounded,
              color: AppColors.fomo,
              title: s.settingsTilePermissions,
              onTap: () => Navigator.pushNamed(context, '/permissions'),
            ),
          ]),
          const SizedBox(height: 24),

          // ── Sezione Supporto ───────────────────────────────────────────────
          _sectionLabel(s.settingsSectionSupport),
          const SizedBox(height: 10),
          _sectionCard([
            _SettingRow(
              icon: Icons.help_outline_rounded,
              color: AppColors.textSecondary,
              title: s.settingsTileHelp,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpFaqScreen()),
              ),
            ),
            _SettingRow(
              icon: Icons.feedback_outlined,
              color: AppColors.textSecondary,
              title: s.t('Feedback', 'Feedback'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FeedbackScreen()),
              ),
            ),
            _SettingRow(
              icon: Icons.description_outlined,
              color: AppColors.textSecondary,
              title: s.settingsTilePrivacy,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              ),
            ),
          ]),
          const SizedBox(height: 32),

          // ── Logout ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: AppColors.cardBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text(
                      s.settingsLogoutDialogTitle,
                      style: GoogleFonts.manrope(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                    ),
                    content: Text(
                      s.settingsLogoutDialogContent,
                      style: GoogleFonts.manrope(color: AppColors.textSecondary),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(s.settingsCancel,
                            style: GoogleFonts.manrope(color: AppColors.textSecondary)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(s.settingsTileLogout,
                            style: GoogleFonts.manrope(
                                color: AppColors.danger, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(authProvider.notifier).signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/auth', (_) => false);
                  }
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout_rounded, color: AppColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      s.settingsTileLogout,
                      style: GoogleFonts.manrope(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Versione ──────────────────────────────────────────────────────
          Center(
            child: Text(
              s.settingsVersion,
              style: GoogleFonts.manrope(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'PipLock AI is not a financial advisor. It does not provide investment advice or trading signals. Trading involves substantial risk of loss. All trading decisions are solely your responsibility.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: AppColors.textTertiary,
                fontSize: 10,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 36),
        ],
      ),
        ],
      ),
    );
  }

  // ── My Accounts Section ────────────────────────────────────────────────────

  Widget _buildAccountsSection(
      BuildContext context, PersonalAccountsState accountsState) {
    final accounts = accountsState.accounts;
    final activeId = accountsState.activeAccount?.id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            // Account rows
            for (int i = 0; i < accounts.length; i++) ...[
              _buildAccountRow(context, accounts[i], activeId, i, accounts.length),
              if (i < accounts.length - 1)
                const Divider(height: 1, color: AppColors.border, indent: 56),
            ],

            // Divider before Add row (only when there are existing accounts)
            if (accounts.isNotEmpty)
              const Divider(height: 1, color: AppColors.border, indent: 56),

            // Add account row
            _PressableRow(
              onTap: () => Navigator.pushNamed(context, '/broker'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: AppColors.success, size: 17),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Add account',
                        style: GoogleFonts.manrope(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textTertiary, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountRow(
    BuildContext context,
    PersonalAccount account,
    String? activeId,
    int index,
    int total,
  ) {
    final isActive = account.id == activeId;
    final connectionBadgeColor = _connectionColor(account.connectionMethod);

    return Dismissible(
      key: ValueKey(account.id),
      direction: isActive ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(0),
        ),
        child: const Icon(Icons.delete_rounded, color: AppColors.danger, size: 20),
      ),
      confirmDismiss: (_) async {
        if (isActive) return false;
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.cardBg,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Delete account?',
              style: GoogleFonts.manrope(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w700),
            ),
            content: Text(
              'This will remove "${account.name}" and all its rules. This cannot be undone.',
              style: GoogleFonts.manrope(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel',
                    style: GoogleFonts.manrope(
                        color: AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Delete',
                    style: GoogleFonts.manrope(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        ref.read(personalAccountsProvider.notifier).deleteAccount(account.id);
      },
      child: _PressableRow(
        onTap: () => ref
            .read(personalAccountsProvider.notifier)
            .setActiveAccount(account.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.accent.withValues(alpha: 0.15)
                      : AppColors.cardBg2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive
                        ? AppColors.accent.withValues(alpha: 0.4)
                        : Colors.transparent,
                  ),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: isActive ? AppColors.accent : AppColors.textSecondary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: GoogleFonts.manrope(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: connectionBadgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            account.connectionMethod,
                            style: GoogleFonts.manrope(
                              color: connectionBadgeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (account.accountNumber != null &&
                            account.accountNumber!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '#${account.accountNumber}',
                            style: GoogleFonts.manrope(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (isActive)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.accent, size: 18)
              else
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textTertiary, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Color _connectionColor(String method) {
    switch (method) {
      case 'ea':
        return AppColors.success;
      case 'accessibility':
        return AppColors.warning;
      case 'metaapi':
      case 'ctrader':
      case 'oanda':
        return const Color(0xFF4A90E2);
      default:
        return AppColors.textSecondary;
    }
  }

  // ── Hero Header ────────────────────────────────────────────────────────────

  Widget _buildHeroHeader(
    String name,
    String email,
    bool isPro,
    int joinYear,
    int tokens,
    AppStrings s,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
          child: Column(
            children: [
              // Avatar
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/profile').then((_) => _loadAvatar()),
                child: Stack(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: _avatarPath == null ? AppColors.logoGradient : null,
                        shape: BoxShape.circle,
                        image: _avatarPath != null
                            ? DecorationImage(
                                image: FileImage(File(_avatarPath!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.20),
                            blurRadius: 24,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: _avatarPath == null
                          ? Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'T',
                                style: GoogleFonts.manrope(
                                  color: Colors.black,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface, width: 2),
                        ),
                        child: const Icon(Icons.edit_rounded,
                            color: AppColors.textSecondary, size: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                name,
                style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                email,
                style: GoogleFonts.manrope(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              // Pro badge
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/tokens'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPro
                        ? AppColors.accent.withValues(alpha: 0.12)
                        : AppColors.cardBg2,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isPro
                          ? AppColors.accent.withValues(alpha: 0.35)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPro ? Icons.diamond_rounded : Icons.lock_open_rounded,
                        color: isPro ? AppColors.accent : AppColors.textSecondary,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isPro ? 'Pro Plan' : 'Free Plan · Upgrade',
                        style: GoogleFonts.manrope(
                          color: isPro ? AppColors.accent : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Quick stats row
              Row(
                children: [
                  _quickStat(Icons.toll_rounded, '$tokens', 'Token'),
                  _quickStatDivider(),
                  _quickStat(Icons.calendar_today_rounded, '$joinYear', 'Member since'),
                  _quickStatDivider(),
                  _quickStat(Icons.person_rounded, 'Profile', '',
                      onTap: () => Navigator.pushNamed(context, '/profile').then((_) => _loadAvatar())),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickStat(IconData icon, String value, String label, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Icon(icon, color: AppColors.accent, size: 18),
            const SizedBox(height: 5),
            Text(
              value,
              style: GoogleFonts.manrope(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (label.isNotEmpty)
              Text(
                label,
                style: GoogleFonts.manrope(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _quickStatDivider() {
    return Container(
      width: 1,
      height: 36,
      color: AppColors.border,
    );
  }

  // ── Section helpers ────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.manrope(
          color: AppColors.textTertiary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _sectionCard(List<_SettingRow> rows) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            for (int i = 0; i < rows.length; i++) ...[
              _buildRowWidget(rows[i]),
              if (i < rows.length - 1)
                const Divider(height: 1, color: AppColors.border, indent: 56),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRowWidget(_SettingRow row) {
    return _PressableRow(
      onTap: row.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: row.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(row.icon, color: row.color, size: 17),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title,
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (row.subtitle != null)
                    Text(
                      row.subtitle!,
                      style: GoogleFonts.manrope(
                        color: row.subtitleColor ?? AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── _PressableRow ──────────────────────────────────────────────────────────────

class _PressableRow extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _PressableRow({required this.child, this.onTap});
  @override
  State<_PressableRow> createState() => _PressableRowState();
}

class _PressableRowState extends State<_PressableRow> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _pressed ? AppColors.cardBg2 : Colors.transparent,
        child: widget.child,
      ),
    );
  }
}

class _SettingRow {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final VoidCallback onTap;

  const _SettingRow({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    required this.onTap,
  });
}

/// Inline token balance card shown in the Account section.
/// Shows weekly token count only — no purchases, by design.
class _TokenBalanceCard extends StatelessWidget {
  final int tokensWeekly;

  const _TokenBalanceCard({
    required this.tokensWeekly,
  });

  @override
  Widget build(BuildContext context) {
    final isLow = tokensWeekly == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLow
                ? AppColors.warning.withValues(alpha: 0.3)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.toll_rounded, color: AppColors.accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Killswitch Tokens',
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isLow ? 'Resets Sunday midnight' : '$tokensWeekly / 2 this week',
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isLow
                    ? AppColors.warning.withValues(alpha: 0.12)
                    : AppColors.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isLow
                      ? AppColors.warning.withValues(alpha: 0.3)
                      : AppColors.accent.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$tokensWeekly',
                    style: GoogleFonts.manrope(
                      color: isLow ? AppColors.warning : AppColors.accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'tokens',
                    style: GoogleFonts.manrope(
                      color: isLow ? AppColors.warning : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
}
