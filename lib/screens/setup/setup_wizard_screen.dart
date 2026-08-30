import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_colors.dart';
import '../../config/app_theme.dart';
import '../../providers/broker_provider.dart';
import '../../providers/challenge_provider.dart';
import '../../providers/rules_provider.dart';
import '../../services/accessibility_service.dart';
import '../../widgets/ambient_blobs.dart';
import '../../widgets/glass_card.dart';

// ── SharedPreferences keys ─────────────────────────────────────────────────────
const _kWizardCompleted = 'setup_wizard_completed';
const _kWizardStep      = 'setup_wizard_step';

/// Returns true if the wizard has been completed (or skipped) by the user.
Future<bool> isSetupWizardCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kWizardCompleted) ?? false;
}

// ── SetupWizardScreen ──────────────────────────────────────────────────────────

/// Guided first-time setup flow.
///
/// Steps:
///   0 — Permissions (overlay + accessibility)
///   1 — Account type: Personal or Challenge
///   2 — Broker connection  (Personal only; Challenge skips to step 3)
///   3 — Rules setup        (Manual rules OR AI Planner)
///   4 — Notification preferences
///   5 — Done → pop
///
/// Visual progress bar shows 4 steps (permissions, connect, rules, notifications).
/// Can be resumed from a partially completed state (step is persisted in prefs).
class SetupWizardScreen extends ConsumerStatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  ConsumerState<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends ConsumerState<SetupWizardScreen>
    with SingleTickerProviderStateMixin {
  int    _step        = 0;       // current step index
  String _accountType = '';      // 'personal' | 'challenge'
  bool   _loading     = false;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  // Maps internal step to the progress bar step (4 visual steps)
  int get _progressStep {
    if (_step <= 0) return 0;
    if (_step == 1) return 0;
    if (_step == 2) return 1;
    if (_step == 3) return 2;
    return 3;
  }

  static const int _totalProgressSteps = 4;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _restoreStep();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _restoreStep() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_kWizardStep) ?? 0;
    if (mounted && saved > 0 && saved < 5) {
      setState(() => _step = saved);
    }
  }

  Future<void> _persistStep(int step) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kWizardStep, step);
  }

  Future<void> _markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWizardCompleted, true);
    await prefs.remove(_kWizardStep);
  }

  void _goToStep(int step) {
    _fadeCtrl.reset();
    setState(() => _step = step);
    _fadeCtrl.forward();
    _persistStep(step);
  }

  void _next() => _goToStep(_step + 1);

  Future<void> _finish() async {
    setState(() => _loading = true);
    await _markComplete();
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _skip() async {
    await _markComplete();
    if (mounted) Navigator.of(context).pop(false);
  }

  // ── Navigation helpers ─────────────────────────────────────────────────────

  Future<void> _openPermissions() async {
    await Navigator.of(context).pushNamed('/permissions');
    // Refresh step after returning from permissions screen
    if (mounted) setState(() {});
  }

  Future<void> _openBroker() async {
    await Navigator.of(context).pushNamed('/broker');
    if (mounted) setState(() {});
  }

  Future<void> _openPersonalRules() async {
    await Navigator.of(context).pushNamed('/personal_rules');
    if (!mounted) return;
    // Smart warnings after saving rules
    final rules = ref.read(rulesProvider).rules;
    if (rules != null && rules.tradingHoursEnabled &&
        rules.tradingHoursStart != null && rules.tradingHoursEnd != null) {
      await _checkTradingHoursWarning(
          rules.tradingHoursStart!, rules.tradingHoursEnd!);
    }
    if (mounted) setState(() {});
  }

  Future<void> _openChallengeSetup() async {
    await Navigator.of(context).pushNamed('/challenge_setup');
    if (mounted) setState(() {});
  }

  Future<void> _openNotificationSettings() async {
    await Navigator.of(context).pushNamed('/notification_settings');
    if (mounted) setState(() {});
  }

  // Trading hours smart warning: if current time is OUTSIDE configured window
  Future<void> _checkTradingHoursWarning(String start, String end) async {
    final now = TimeOfDay.now();
    final startParts = start.split(':');
    final endParts   = end.split(':');
    if (startParts.length < 2 || endParts.length < 2) return;
    final startH = int.tryParse(startParts[0]) ?? 0;
    final startM = int.tryParse(startParts[1]) ?? 0;
    final endH   = int.tryParse(endParts[0]) ?? 0;
    final endM   = int.tryParse(endParts[1]) ?? 0;
    final nowMins   = now.hour * 60 + now.minute;
    final startMins = startH  * 60 + startM;
    final endMins   = endH    * 60 + endM;
    final isOutside = nowMins < startMins || nowMins >= endMins;
    if (!isOutside || !mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _SmartWarningDialog(
        icon: Icons.schedule_rounded,
        title: 'Heads up — trading blocked right now',
        body: 'You set your trading hours to $start–$end, '
              "but it's currently ${now.format(context)}. "
              'PipLock will block MT5 until your session starts. '
              'Is that intentional?',
        confirmLabel: 'Yes, that\'s fine',
        cancelLabel: 'Change hours',
        onCancel: () => Navigator.of(context).pushNamed('/personal_rules'),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: IgnorePointer(child: AmbientBlobs())),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(),
                _buildProgressBar(),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: _buildCurrentStep(),
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x88000000),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => _SmartWarningDialog(
                  icon: Icons.exit_to_app_rounded,
                  title: 'Exit setup?',
                  body: 'You can complete the setup later from the Home screen banner.',
                  confirmLabel: 'Exit',
                  cancelLabel: 'Continue setup',
                ),
              );
              if (confirmed == true && mounted) {
                Navigator.of(context).pop(false);
              }
            },
          ),
          const SizedBox(width: 4),
          Text(
            'Quick Setup',
            style: GoogleFonts.manrope(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _skip,
            child: Text(
              'Skip all',
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final stepLabels = ['Permissions', 'Connect', 'Rules', 'Notifications'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(_totalProgressSteps, (i) {
              final filled = i <= _progressStep;
              final isCurrent = i == _progressStep;
              return Expanded(
                child: AnimatedContainer(
                  duration: AppTheme.dMedium,
                  height: isCurrent ? 4 : 3,
                  margin: EdgeInsets.only(right: i < _totalProgressSteps - 1 ? 4 : 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: filled
                        ? AppColors.accent
                        : AppColors.surface,
                    boxShadow: isCurrent
                        ? [BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.4),
                            blurRadius: 6,
                          )]
                        : null,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            stepLabels[_progressStep.clamp(0, 3)],
            style: GoogleFonts.manrope(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    return switch (_step) {
      0 => _PermissionsStep(onContinue: _next, onOpenSettings: _openPermissions),
      1 => _AccountTypeStep(onSelected: (type) {
          _accountType = type;
          // Challenge skips broker-connection step — goes straight to rules
          _goToStep(type == 'challenge' ? 3 : 2);
        }),
      2 => _ConnectBrokerStep(
          brokerConnected: ref.watch(brokerProvider).isConnected,
          onOpenBroker: _openBroker,
          onContinue: _next,
        ),
      3 => _RulesStep(
          accountType: _accountType,
          rulesConfigured: _areRulesConfigured(),
          challengeConfigured: _isChallengeConfigured(),
          onOpenPersonalRules: _openPersonalRules,
          onOpenChallengeSetup: _openChallengeSetup,
          onOpenAiPlanner: () async {
            // Push AI Planner tab via main nav, return here after
            await Navigator.of(context).pushNamed('/challenge_setup');
            if (mounted) setState(() {});
          },
          onContinue: _next,
        ),
      4 => _NotificationsStep(
          onOpenSettings: _openNotificationSettings,
          onContinue: _finish,
        ),
      _ => const SizedBox(),
    };
  }

  bool _areRulesConfigured() =>
      ref.read(rulesProvider).rules != null;

  bool _isChallengeConfigured() =>
      ref.read(challengeListProvider).any((c) => c.status == 'active');
}

// ── Step 0: Permissions ────────────────────────────────────────────────────────

class _PermissionsStep extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onOpenSettings;
  const _PermissionsStep({required this.onContinue, required this.onOpenSettings});
  @override
  State<_PermissionsStep> createState() => _PermissionsStepState();
}

class _PermissionsStepState extends State<_PermissionsStep> {
  bool _accessOk = false;
  bool _overlayOk = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final access  = await AccessibilityService.isEnabled();
    final overlay = await AccessibilityService.canDrawOverlays();
    if (mounted) {
      setState(() {
        _accessOk  = access;
        _overlayOk = overlay;
        _checking  = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepIcon(Icons.shield_rounded, AppColors.accent),
          const SizedBox(height: 20),
          Text(
            'Two permissions\nto activate PipLock',
            style: GoogleFonts.manrope(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'These let PipLock read your MT5 data and show the block screen on top of it.',
            style: GoogleFonts.manrope(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          if (_checking)
            const Center(child: CircularProgressIndicator(color: AppColors.accent))
          else ...[
            _PermissionRow(
              icon: Icons.accessibility_new_rounded,
              title: 'Accessibility Service',
              subtitle: 'Reads equity, P&L, open positions from MT5',
              granted: _accessOk,
              onTap: () async {
                await AccessibilityService.openSettings();
                // Re-check after user returns
                await Future.delayed(const Duration(seconds: 1));
                _check();
              },
            ),
            const SizedBox(height: 12),
            _PermissionRow(
              icon: Icons.layers_rounded,
              title: 'Display over other apps',
              subtitle: 'Shows the killswitch block screen on top of MT5',
              granted: _overlayOk,
              onTap: () async {
                await AccessibilityService.requestOverlayPermission();
                await Future.delayed(const Duration(seconds: 1));
                _check();
              },
            ),
            const SizedBox(height: 10),
            if (_accessOk && _overlayOk)
              _infoChip(Icons.check_circle_outline_rounded,
                  'Both permissions granted — PipLock is fully active.',
                  const Color(0xFF4CAF50)),
            if (!_accessOk || !_overlayOk)
              _infoChip(Icons.info_outline_rounded,
                  'You can still continue and grant permissions later from Settings.',
                  AppColors.textSecondary),
            const SizedBox(height: 32),
            _primaryButton('Continue', widget.onContinue),
          ],
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   subtitle;
  final bool     granted;
  final VoidCallback onTap;
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: (granted ? const Color(0xFF4CAF50) : AppColors.accent)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon,
              color: granted ? const Color(0xFF4CAF50) : AppColors.accent,
              size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.manrope(
                  color: AppColors.textPrimary, fontSize: 14,
                  fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.manrope(
                  color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (granted)
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF4CAF50), size: 22)
          else
            OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.accent),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Grant', style: GoogleFonts.manrope(
                color: AppColors.accent, fontSize: 12,
                fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

// ── Step 1: Account Type ───────────────────────────────────────────────────────

class _AccountTypeStep extends StatelessWidget {
  final void Function(String type) onSelected;
  const _AccountTypeStep({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepIcon(Icons.account_balance_wallet_rounded, AppColors.accent),
          const SizedBox(height: 20),
          Text(
            'Which account are\nyou setting up?',
            style: GoogleFonts.manrope(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose one — you can add more accounts later from your profile.',
            style: GoogleFonts.manrope(
              color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 32),
          _TypeCard(
            icon: Icons.person_rounded,
            title: 'Personal Account',
            subtitle: 'Your own capital — set daily loss limits, trade count, and trading hours.',
            color: AppColors.accent,
            onTap: () => onSelected('personal'),
          ),
          const SizedBox(height: 14),
          _TypeCard(
            icon: Icons.military_tech_rounded,
            title: 'Challenge / Prop Firm',
            subtitle: 'FTMO, FundedNext, etc. — AI Planner generates a custom strategy with success probability.',
            color: const Color(0xFFFFB74D),
            onTap: () => onSelected('challenge'),
          ),
        ],
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   subtitle;
  final Color    color;
  final VoidCallback onTap;
  const _TypeCard({
    required this.icon, required this.title, required this.subtitle,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: AppTheme.bLg,
          color: AppColors.surface,
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 16),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.manrope(
                    color: AppColors.textPrimary, fontSize: 16,
                    fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: GoogleFonts.manrope(
                    color: AppColors.textSecondary, fontSize: 12.5,
                    height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}

// ── Step 2: Connect Broker ─────────────────────────────────────────────────────

class _ConnectBrokerStep extends StatelessWidget {
  final bool         brokerConnected;
  final VoidCallback onOpenBroker;
  final VoidCallback onContinue;
  const _ConnectBrokerStep({
    required this.brokerConnected,
    required this.onOpenBroker,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepIcon(Icons.link_rounded, const Color(0xFF26A69A)),
          const SizedBox(height: 20),
          Text(
            'Connect your\nMT5 account',
            style: GoogleFonts.manrope(
              color: AppColors.textPrimary, fontSize: 28,
              fontWeight: FontWeight.w900, letterSpacing: -1.2, height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'PipLock reads equity, P&L, and open positions. It never executes or closes trades.',
            style: GoogleFonts.manrope(
              color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 28),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      brokerConnected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: brokerConnected
                          ? const Color(0xFF4CAF50)
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      brokerConnected ? 'Account connected' : 'Not connected yet',
                      style: GoogleFonts.manrope(
                        color: brokerConnected
                            ? const Color(0xFF4CAF50)
                            : AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _outlineButton(
                  Icons.add_link_rounded,
                  brokerConnected ? 'Change connection' : 'Set up connection',
                  onOpenBroker,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _infoChip(
            Icons.info_outline_rounded,
            'You can also skip this and connect later from the Profile → Broker page.',
            AppColors.textSecondary,
          ),
          const SizedBox(height: 32),
          _primaryButton('Continue', onContinue),
        ],
      ),
    );
  }
}

// ── Step 3: Rules Setup ────────────────────────────────────────────────────────

class _RulesStep extends StatelessWidget {
  final String       accountType;
  final bool         rulesConfigured;
  final bool         challengeConfigured;
  final VoidCallback onOpenPersonalRules;
  final VoidCallback onOpenChallengeSetup;
  final VoidCallback onOpenAiPlanner;
  final VoidCallback onContinue;
  const _RulesStep({
    required this.accountType,
    required this.rulesConfigured,
    required this.challengeConfigured,
    required this.onOpenPersonalRules,
    required this.onOpenChallengeSetup,
    required this.onOpenAiPlanner,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepIcon(Icons.rule_rounded, const Color(0xFFEF5350)),
          const SizedBox(height: 20),
          Text(
            accountType == 'challenge'
                ? 'Set up your\nchallenge'
                : 'Set your\ntrading rules',
            style: GoogleFonts.manrope(
              color: AppColors.textPrimary, fontSize: 28,
              fontWeight: FontWeight.w900, letterSpacing: -1.2, height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            accountType == 'challenge'
                ? 'Enter your prop firm parameters — the AI generates a day-by-day plan with a success probability.'
                : 'These limits activate the killswitch. You can change them anytime (with a 24h lock to keep you accountable).',
            style: GoogleFonts.manrope(
              color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 28),
          if (accountType == 'challenge') ...[
            _ActionCard(
              icon: Icons.military_tech_rounded,
              title: challengeConfigured ? 'Challenge configured' : 'Configure challenge',
              subtitle: challengeConfigured
                  ? 'AI plan generated. Tap to view or edit.'
                  : 'Enter prop firm parameters (account size, profit target, max drawdown…)',
              color: const Color(0xFFFFB74D),
              done: challengeConfigured,
              onTap: onOpenChallengeSetup,
            ),
          ] else ...[
            _ActionCard(
              icon: Icons.tune_rounded,
              title: rulesConfigured ? 'Rules configured' : 'Set rules manually',
              subtitle: rulesConfigured
                  ? 'Your limits are saved. Tap to review.'
                  : 'Set daily loss limit, max trades, trading hours, killswitch duration.',
              color: AppColors.accent,
              done: rulesConfigured,
              onTap: onOpenPersonalRules,
            ),
            const SizedBox(height: 14),
            _ActionCard(
              icon: Icons.auto_awesome_rounded,
              title: 'Use AI Planner instead',
              subtitle: 'Let the AI generate your daily limits based on your trading style and goals.',
              color: const Color(0xFF26A69A),
              done: false,
              onTap: onOpenAiPlanner,
            ),
          ],
          const SizedBox(height: 12),
          _infoChip(
            Icons.info_outline_rounded,
            'You can configure this later from Profile → ${accountType == 'challenge' ? 'Challenges' : 'Rules'}.',
            AppColors.textSecondary,
          ),
          const SizedBox(height: 32),
          _primaryButton(
            (rulesConfigured || challengeConfigured) ? 'Continue' : 'Skip for now',
            onContinue,
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData     icon;
  final String       title;
  final String       subtitle;
  final Color        color;
  final bool         done;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon, required this.title, required this.subtitle,
    required this.color, required this.done, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: AppTheme.bLg,
          color: AppColors.surface,
          border: Border.all(
            color: done
                ? const Color(0xFF4CAF50).withValues(alpha: 0.5)
                : color.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: (done ? const Color(0xFF4CAF50) : color)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                done ? Icons.check_rounded : icon,
                color: done ? const Color(0xFF4CAF50) : color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.manrope(
                    color: AppColors.textPrimary, fontSize: 14,
                    fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: GoogleFonts.manrope(
                    color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              done
                  ? Icons.check_circle_rounded
                  : Icons.arrow_forward_ios_rounded,
              color: done ? const Color(0xFF4CAF50) : color,
              size: done ? 22 : 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 4: Notifications ──────────────────────────────────────────────────────

class _NotificationsStep extends StatelessWidget {
  final VoidCallback onOpenSettings;
  final Future<void> Function() onContinue;
  const _NotificationsStep({
    required this.onOpenSettings, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepIcon(Icons.notifications_rounded, const Color(0xFF7E57C2)),
          const SizedBox(height: 20),
          Text(
            'Stay informed,\nnot distracted',
            style: GoogleFonts.manrope(
              color: AppColors.textPrimary, fontSize: 28,
              fontWeight: FontWeight.w900, letterSpacing: -1.2, height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose which alerts matter to you — NFP, FOMC, session changes, risk warnings.',
            style: GoogleFonts.manrope(
              color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 28),
          for (final item in [
            (Icons.newspaper_rounded,     'Economic news',      'NFP, CPI, central bank decisions'),
            (Icons.access_time_rounded,   'Session changes',    'London, New York, Tokyo, Sydney'),
            (Icons.warning_amber_rounded, 'Risk warnings',      '80% of daily limit, soft killswitch'),
            (Icons.psychology_rounded,    'FOMO / Revenge',     'Behavioral pattern alerts'),
          ]) ...[
            GlassCard(
              child: Row(
                children: [
                  Icon(item.$1, color: const Color(0xFF7E57C2), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.$2, style: GoogleFonts.manrope(
                          color: AppColors.textPrimary, fontSize: 13,
                          fontWeight: FontWeight.w700)),
                        Text(item.$3, style: GoogleFonts.manrope(
                          color: AppColors.textSecondary, fontSize: 11.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          _outlineButton(
            Icons.tune_rounded, 'Configure notifications', onOpenSettings),
          const SizedBox(height: 32),
          _primaryButton('Finish setup', onContinue),
        ],
      ),
    );
  }
}

// ── Smart Warning Dialog ───────────────────────────────────────────────────────

class _SmartWarningDialog extends StatelessWidget {
  final IconData  icon;
  final String    title;
  final String    body;
  final String    confirmLabel;
  final String    cancelLabel;
  final VoidCallback? onCancel;
  const _SmartWarningDialog({
    required this.icon,
    required this.title,
    required this.body,
    required this.confirmLabel,
    this.cancelLabel = 'Cancel',
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.bLg),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.accent, size: 22),
          ),
          const SizedBox(height: 16),
          Text(title, style: GoogleFonts.manrope(
            color: AppColors.textPrimary, fontSize: 16,
            fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(body, style: GoogleFonts.manrope(
            color: AppColors.textSecondary, fontSize: 13.5, height: 1.5)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                    onCancel?.call();
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(cancelLabel, style: GoogleFonts.manrope(
                    color: AppColors.textSecondary, fontSize: 13,
                    fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(confirmLabel, style: GoogleFonts.manrope(
                    color: Colors.black, fontSize: 13,
                    fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────

Widget _stepIcon(IconData icon, Color color) {
  return Container(
    width: 56, height: 56,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Icon(icon, color: color, size: 28),
  );
}

Widget _infoChip(IconData icon, String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.15)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: GoogleFonts.manrope(
            color: color, fontSize: 12, height: 1.4)),
        ),
      ],
    ),
  );
}

Widget _primaryButton(String label, FutureOr<void> Function() onPressed) {
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: Text(label, style: GoogleFonts.manrope(
        fontSize: 15, fontWeight: FontWeight.w800)),
    ),
  );
}

Widget _outlineButton(IconData icon, String label, VoidCallback onPressed) {
  return SizedBox(
    width: double.infinity,
    height: 48,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: AppColors.accent),
      label: Text(label, style: GoogleFonts.manrope(
        color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.w700)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.accent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
