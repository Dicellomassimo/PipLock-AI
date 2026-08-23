import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../config/app_theme.dart';
import '../../config/app_strings.dart';
import '../../config/constants.dart';
import '../../models/challenge.dart';
import '../../providers/ai_plan_provider.dart';
import '../../providers/killswitch_provider.dart';
import '../../providers/broker_provider.dart';
import '../../providers/rules_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/challenge_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/accessibility_service.dart';
import '../../widgets/ambient_blobs.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/animated_counter.dart';
import '../../widgets/checkin_modal.dart';
import '../../widgets/gatekeeper_overlay.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glow_progress_bar.dart';
import '../../widgets/stat_ring_chart.dart';
import '../../widgets/staggered_list.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  bool _checkinDone = false;
  int _checkinScore = 5;
  bool _showGatekeeper = false;
  bool _showDevTools = false;
  Challenge? _activeChallenge;
  String? _avatarPath;
  static const _avatarPrefKey = 'profile_avatar_path';

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_avatarPrefKey);
    if (mounted) setState(() => _avatarPath = (path != null && File(path).existsSync()) ? path : null);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAvatar();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_checkinDone) {
        CheckinModal.showIfNeeded(context).then((result) async {
          if (!mounted) return;
          if (result != null) {
            setState(() {
              _checkinDone = true;
              _checkinScore = result.score;
            });
          } else {
            // Già completato oggi — carica l'ultimo score
            final last = await CheckinModal.lastScore();
            if (mounted) setState(() { _checkinDone = true; _checkinScore = last; });
          }
        });
      }
      _loadActiveChallenge();
      // Aggiorna la challenge quando il provider cambia (es. dopo setup)
      ref.listenManual(challengeListProvider, (_, next) {
        if (!mounted || next.isEmpty) return;
        if (_activeChallenge == null) {
          setState(() => _activeChallenge = next.firstWhere(
            (c) => c.status == 'active', orElse: () => next.first));
        }
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadAvatar();
  }

  Future<void> _loadActiveChallenge() async {
    // Prima controlla il provider in memoria (funziona in devMode e dopo setup)
    final memoryChallenges = ref.read(challengeListProvider);
    if (memoryChallenges.isNotEmpty) {
      final active = memoryChallenges.firstWhere(
        (c) => c.status == 'active',
        orElse: () => memoryChallenges.first,
      );
      if (mounted) setState(() => _activeChallenge = active);
      return;
    }
    final userId = ref.read(currentUserIdProvider);
    if (userId.isEmpty) return;
    try {
      final c = await SupabaseService.getActiveChallenge(userId);
      if (mounted && c != null) setState(() => _activeChallenge = c);
    } catch (_) {}
  }

  String _todayLabel(AppStrings s) {
    return DateFormat.yMMMMd(s.locale).format(DateTime.now());
  }

  /// Forex sessions in UTC:
  /// Sydney:   22:00 – 07:00
  /// Asia:     00:00 – 09:00
  /// London:   08:00 – 17:00
  /// New York: 13:00 – 22:00
  /// Closed:   Fri 22:00 UTC → Sun 22:00 UTC (full weekend)
  bool _isWeekendClosed() {
    final now = DateTime.now().toUtc();
    final wd = now.weekday; // Mon=1 … Sat=6, Sun=7
    final h = now.hour;
    if (wd == 6) return true;                    // Saturday all day
    if (wd == 5 && h >= 22) return true;         // Friday after 22:00 UTC
    if (wd == 7 && h < 22) return true;          // Sunday before 22:00 UTC
    return false;
  }

  String _sessionName(AppStrings s) {
    if (_isWeekendClosed()) return s.dashSessionClosed;
    final h = DateTime.now().toUtc().hour;
    if (h >= 8 && h < 13) return s.dashSessionLondon;
    if (h >= 13 && h < 22) return s.dashSessionNewYork;
    if (h >= 22 || h < 7) return s.dashSessionSydney;
    return s.dashSessionAsia; // 07:00–08:00 transition
  }

  String _sessionSub(AppStrings s) {
    if (_isWeekendClosed()) return s.dashSessionClosedSub;
    final h = DateTime.now().toUtc().hour;
    if (h >= 8 && h < 13) return s.dashSessionClosesLondon;
    if (h >= 13 && h < 22) return s.dashSessionClosesNY;
    if (h >= 22 || h < 7) return s.dashSessionClosesSydney;
    return s.dashSessionOpensLondon; // 07:00–08:00
  }

  String _lossLimitLabel(double pnlLimit, bool brokerConnected, String? currency) {
    final rulesState = ref.read(rulesProvider);
    final isPercent = rulesState.rules?.maxDailyLossType == 'percent';
    final value = pnlLimit.abs().toStringAsFixed(isPercent ? 1 : 0);
    if (isPercent) return '$value%';
    if (brokerConnected) return '${currency ?? ''}$value';
    return '€$value';
  }

  @override
  Widget build(BuildContext context) {
    // La navigazione al killswitch è gestita in main_nav_screen.dart via ref.listen.
    // NON ripetiamo qui addPostFrameCallback: verrebbe chiamato ogni rebuild
    // causando multipli push della route /killswitch sullo stack.
    ref.watch(killswitchProvider); // watch per rebuild se cambia, ma non naviga da qui

    final profile = ref.watch(authProvider).profile;
    final rulesState = ref.watch(rulesProvider);
    final metaState = ref.watch(metaApiProvider);
    final personalPlan = ref.watch(personalPlanProvider);

    // Trade: da MetaAPI se connesso, altrimenti da rules provider (tracking manuale)
    final tradesToday = metaState.isConnected
        ? (metaState.tradesToday ?? rulesState.tradesToday)
        : rulesState.tradesToday;
    final maxTrades = rulesState.rules?.maxTradesPerDay ?? 3;

    // P&L: da MetaAPI se connesso (positivo = profitto, negativo = perdita)
    // Guardia NaN/Infinity: l'accessibility service può inviare Double.NaN per il profit
    // se la schermata MT5 era a metà transizione. Senza guardia, (NaN*100).round() crasha.
    final rawPnl = metaState.isConnected ? (metaState.dailyPnl ?? 0.0) : 0.0;
    final pnlToday = (rawPnl.isNaN || rawPnl.isInfinite) ? 0.0 : rawPnl;
    final pnlLimit = -(rulesState.rules?.maxDailyLoss ?? 200.0);

    final rawTradePercent = maxTrades > 0 ? tradesToday / maxTrades : 0.0;
    final tradePercent = (rawTradePercent.isNaN || rawTradePercent.isInfinite)
        ? 0.0
        : rawTradePercent.clamp(0.0, 1.0);
    // lossPercent è rilevante SOLO quando il PnL è negativo (perdita)
    // Se l'utente è in profit, lossPercent = 0 — il container non deve diventare rosso
    final rawLossPercent = (pnlLimit != 0 && pnlToday < 0) ? pnlToday.abs() / pnlLimit.abs() : 0.0;
    final lossPercent = (rawLossPercent.isNaN || rawLossPercent.isInfinite)
        ? 0.0
        : rawLossPercent.clamp(0.0, 1.0);
    final maxPercent = tradePercent > lossPercent ? tradePercent : lossPercent;

    final heroGradient = maxPercent < 0.7
        ? AppColors.heroGradientOk
        : maxPercent < 0.9
            ? AppColors.heroGradientWarning
            : AppColors.heroGradientDanger;

    final s = ref.watch(appStringsProvider);

    final statusText = maxPercent < 0.7
        ? s.dashStatusOk
        : maxPercent < 0.9
            ? s.dashStatusWarning
            : s.dashStatusStop;

    final statusBadge = maxPercent < 0.7
        ? s.dashBadgeNormal
        : maxPercent < 0.9
            ? s.dashBadgeWarning
            : s.dashBadgeCritical;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Ambient glow blobs ──
          const Positioned.fill(child: IgnorePointer(child: AmbientBlobs())),
          // ── Main content ──
          SafeArea(
            child: Column(
              children: [
                // ── Killswitch banner (non bloccante — PipLock resta usabile) ──
                _KillswitchBanner(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: StaggeredList(
                      key: ValueKey(metaState.isConnected),
                      children: [
                        const SizedBox(height: 28),
                        _buildHeader(profile?.tokensAvailable ?? 2),
                        const SizedBox(height: 20),
                        _buildHeroCard(
                          s: s,
                          heroGradient: heroGradient,
                          statusText: statusText,
                          statusBadge: statusBadge,
                          maxPercent: maxPercent,
                          lossPercent: lossPercent,
                          tradesToday: tradesToday,
                          maxTrades: maxTrades,
                          pnlToday: pnlToday,
                          pnlLimit: pnlLimit,
                          brokerConnected: metaState.isConnected,
                          currency: metaState.currency,
                        ),
                        const SizedBox(height: 16),
                        _buildStatsRow(),
                        const SizedBox(height: 16),
                        _buildAccountsSection(s),
                        const SizedBox(height: 16),
                        _buildCheckinRow(),
                        const SizedBox(height: 22),
                        _buildRecentActivity(),
                        if (metaState.isConnected) ...[
                          const SizedBox(height: 16),
                          _buildBrokerLiveCard(metaState),
                        ],
                        const SizedBox(height: 16),
                        _buildAiPlanCard(personalPlan, _activeChallenge),
                        const SizedBox(height: 16),
                        _buildLimitsCard(rulesState, metaState),
                        if (kDevMode) ...[
                          const SizedBox(height: 24),
                          _buildDevToggle(),
                          if (_showDevTools) ...[
                            const SizedBox(height: 10),
                            _buildDevSection(),
                          ],
                        ],
                        // Extra padding per la floating nav bar
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
          ),
              ],
            ),
          ),
          if (_showGatekeeper)
            GatekeeperOverlay(
              onStop: () => setState(() => _showGatekeeper = false),
              onProceed: () => setState(() => _showGatekeeper = false),
            ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(int tokens) {
    final s = ref.watch(appStringsProvider);
    final email = kDevMode
        ? null
        : Supabase.instance.client.auth.currentUser?.email;
    final name = email?.split('@').first ?? 'Trader';

    return Row(
      children: [
        // Avatar con glow teal + pulse ring animato
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/profile'),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulse ring
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(seconds: 3),
                curve: Curves.easeOut,
                builder: (_, v, _) => Opacity(
                  opacity: (1 - v) * 0.4,
                  child: Container(
                    width: 44 + v * 14,
                    height: 44 + v * 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accent, width: 1),
                    ),
                  ),
                ),
                onEnd: () => setState(() {}), // re-trigger
              ),
              // Avatar
              Container(
                width: 44,
                height: 44,
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
                      color: AppColors.accent.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _avatarPath == null
                    ? Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'T',
                          style: GoogleFonts.manrope(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.dashHello(name),
                style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              Text(
                _todayLabel(s),
                style: GoogleFonts.manrope(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
        // Notifiche — rounded square (more modern than circle)
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/notifications'),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: const Icon(
              Icons.notifications_outlined,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Badge token
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/tokens'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.toll_rounded, color: AppColors.accent, size: 14),
                const SizedBox(width: 5),
                Text(
                  '$tokens',
                  style: GoogleFonts.manrope(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Hero Card ─────────────────────────────────────────────────────────────
  Widget _buildHeroCard({
    required AppStrings s,
    required LinearGradient heroGradient,
    required String statusText,
    required String statusBadge,
    required double maxPercent,
    required double lossPercent,
    required int tradesToday,
    required int maxTrades,
    required double pnlToday,
    required double pnlLimit,
    required bool brokerConnected,
    String? currency,
  }) {
    final tradeStr = s.dashTradeCount(tradesToday, maxTrades);
    final pctUsed = (maxPercent * 100).round();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: heroGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl), // 32 — più rotondo
        boxShadow: [
          BoxShadow(
            color: heroGradient.colors.first.withValues(alpha: 0.30),
            blurRadius: 40,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        child: Stack(
          children: [
            // Radial glow top-left
            Positioned(
              top: -50,
              left: -30,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Silver shimmer line — firma del tema argento
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppColors.accentBright.withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 24, 26, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: label + status badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s.dashToday.toUpperCase(),
                        style: GoogleFonts.manrope(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          statusBadge,
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Status label (small, above the number)
                  Text(
                    statusText.toUpperCase(),
                    style: GoogleFonts.manrope(
                      color: Colors.white.withValues(alpha: 0.50),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Big animated P&L number (main focal point)
                  AnimatedCounter(
                    value: pnlToday,
                    prefix: '${brokerConnected ? (currency ?? '€') : '€'}${pnlToday >= 0 ? '+' : ''}',
                    suffix: '',
                    decimalPlaces: 0,
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2.0,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Trade count pill
                  Row(
                    children: [
                      _heroPill(tradeStr),
                    ],
                  ),
                  const SizedBox(height: 22),
                  // Risk meter label row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s.dashRiskUsed,
                        style: GoogleFonts.manrope(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$pctUsed%',
                        style: GoogleFonts.manrope(
                          color: Colors.white.withValues(alpha: 0.90),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Glow progress bar
                  GlowProgressBar(
                    value: lossPercent.clamp(0.0, 1.0),
                    fillColor: Colors.white,
                    trackColor: Colors.white.withValues(alpha: 0.18),
                    height: 7,
                    showGlow: true,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.dashLossLimitPerDay(_lossLimitLabel(pnlLimit, brokerConnected, currency)),
                    style: GoogleFonts.manrope(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
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

  Widget _heroPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 0.5),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
      ),
    );
  }

  // ── Stats Row ─────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    final s = ref.watch(appStringsProvider);
    final metaState = ref.watch(metaApiProvider);
    final checkinLabel = _checkinScore >= 8
        ? s.dashReadinessOptimal
        : _checkinScore >= 6
            ? s.dashReadinessGood
            : _checkinScore >= 4
                ? s.dashReadinessLow
                : s.dashReadinessCritical;

    // Challenge attiva: dati reali se disponibili
    final challenge = _activeChallenge;
    final now = DateTime.now();
    final challengeDay = challenge != null
        ? now.difference(challenge.startedAt).inDays + 1
        : 0;
    final challengeDuration = challenge?.durationDays ?? 30;
    final challengeProgress = challengeDuration > 0
        ? (challengeDay / challengeDuration).clamp(0.0, 1.0)
        : 0.0;

    // Broker: mostra equity se connesso
    final brokerLabel = metaState.isConnected
        ? '${metaState.currency ?? ''} ${metaState.equity?.toStringAsFixed(0) ?? '—'}'
        : s.dashNotConnected;
    final brokerSub = metaState.isConnected
        ? s.dashBrokerEquityLive
        : s.dashBrokerConnectInSettings;

    // Griglia 2×2 — più leggibile, più Opal, niente scroll orizzontale
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.public_rounded,
                label: s.dashStatSession,
                value: _sessionName(s),
                sub: _sessionSub(s),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                icon: Icons.flag_rounded,
                label: s.dashStatChallenge,
                value: challenge != null ? s.dashDay(challengeDay) : '—',
                sub: challenge != null
                    ? s.dashDayOf(challengeDay, challengeDuration)
                    : s.dashNoActiveChallenge,
                progress: challenge != null ? challengeProgress : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.psychology_rounded,
                label: s.dashStatReadiness,
                value: '$_checkinScore/10',
                sub: checkinLabel,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                icon: Icons.account_balance_wallet_outlined,
                label: s.dashStatBroker,
                value: brokerLabel,
                sub: brokerSub,
                iconColor: metaState.isConnected ? AppColors.success : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required String sub,
    double? progress,
    Color? iconColor,
  }) {
    final ic = iconColor ?? AppColors.accent;
    return GlassCard(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      glowColor: ic == AppColors.accent ? AppColors.accent : null,
      glassOpacity: 0.04,
      child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          child: progress != null
              ? Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: ic.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Icon(icon, color: ic, size: 11),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  label,
                                  style: GoogleFonts.manrope(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            value,
                            style: GoogleFonts.manrope(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sub,
                            style: GoogleFonts.manrope(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatRingChart(
                      value: progress.clamp(0.0, 1.0),
                      color: ic,
                      size: 44,
                      strokeWidth: 4,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: ic.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, color: ic, size: 13),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            label,
                            style: GoogleFonts.manrope(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      value,
                      style: GoogleFonts.manrope(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sub,
                      style: GoogleFonts.manrope(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
      ),
    );
  }

  // ── Check-in Row ──────────────────────────────────────────────────────────
  Widget _buildCheckinRow() {
    final color = _checkinScore >= 8
        ? AppColors.accent
        : _checkinScore >= 6
            ? const Color(0xFF4CAF50)
            : _checkinScore >= 4
                ? AppColors.warning
                : AppColors.danger;

    final scoreLabel = _checkinScore >= 8
        ? ref.watch(appStringsProvider).dashReadinessOptimal
        : _checkinScore >= 6
            ? ref.watch(appStringsProvider).dashReadinessGood
            : _checkinScore >= 4
                ? ref.watch(appStringsProvider).dashReadinessLow
                : ref.watch(appStringsProvider).dashReadinessCritical;

    return AnimatedCard(
      onTap: () => CheckinModal.show(context).then((result) {
        if (result != null && mounted) {
          setState(() => _checkinScore = result.score);
        }
      }),
      child: GlassCard(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        glowColor: color,
        glassOpacity: 0.04,
        customBorder: Border.all(
          color: color.withValues(alpha: 0.22),
          width: 0.5,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
          child: Row(
            children: [
              // Icon container with glow
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.20),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Icon(Icons.psychology_rounded, color: color, size: 23),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ref.watch(appStringsProvider).dashCheckinTitle,
                      style: GoogleFonts.manrope(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Mini progress dots 1-10
                    Row(
                      children: List.generate(10, (i) {
                        final filled = i < _checkinScore;
                        return Container(
                          width: filled ? 6 : 4,
                          height: filled ? 6 : 4,
                          margin: const EdgeInsets.only(right: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled
                                ? color
                                : AppColors.textTertiary.withValues(alpha: 0.4),
                            boxShadow: filled
                                ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)]
                                : null,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scoreLabel,
                      style: GoogleFonts.manrope(
                        color: color.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Big score number
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$_checkinScore',
                    style: GoogleFonts.manrope(
                      color: color,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    '/ 10',
                    style: GoogleFonts.manrope(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Recent Activity ───────────────────────────────────────────────────────
  Widget _buildRecentActivity() {
    final s = ref.watch(appStringsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              s.dashRecentActivity.toUpperCase(),
              style: GoogleFonts.manrope(
                color: AppColors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/history'),
              child: Text(
                s.dashSeeAll,
                style: GoogleFonts.manrope(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedCard(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          backgroundColor: AppColors.cardBg,
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: const [],
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.success,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.dashNoEventsToday,
                      style: GoogleFonts.manrope(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.dashRespectingRules,
                      style: GoogleFonts.manrope(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Broker Live Card ──────────────────────────────────────────────────────
  Widget _buildBrokerLiveCard(BrokerState metaState) {
    final s = ref.watch(appStringsProvider);
    final currency = metaState.currency ?? '';

    String minutesAgo() {
      if (metaState.lastUpdate == null) return '';
      final diff = DateTime.now().difference(metaState.lastUpdate!).inMinutes;
      return s.dashUpdatedAgo(diff == 0 ? 1 : diff);
    }

    Widget chip(String label, String value, {Color? valueColor}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.manrope(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ],
      );
    }

    final pnl = metaState.dailyPnl;
    final pnlColor = pnl == null
        ? AppColors.textPrimary
        : pnl >= 0
            ? AppColors.accent
            : AppColors.danger;
    final pnlStr = pnl == null
        ? '—'
        : '${pnl >= 0 ? '+' : ''}${pnl.toStringAsFixed(2)}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                s.dashMt5Live,
                style: GoogleFonts.manrope(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  s.brokerLive,
                  style: GoogleFonts.manrope(
                    color: AppColors.accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: chip(
                  s.brokerEquityLabel,
                  metaState.equity != null
                      ? '$currency ${metaState.equity!.toStringAsFixed(2)}'
                      : '—',
                ),
              ),
              Expanded(
                child: chip(
                  s.brokerBalanceLabel,
                  metaState.balance != null
                      ? '$currency ${metaState.balance!.toStringAsFixed(2)}'
                      : '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: chip(s.dashPnlToday, pnlStr, valueColor: pnlColor),
              ),
              Expanded(
                child: chip(
                  s.brokerOpenPositions,
                  metaState.openPositions?.toString() ?? '—',
                ),
              ),
            ],
          ),
          if (metaState.lastUpdate != null) ...[
            const SizedBox(height: 10),
            Text(
              minutesAgo(),
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── AI Plan Card ──────────────────────────────────────────────────────────
  Widget _buildAiPlanCard(
      Map<String, dynamic>? personalPlan, Challenge? challenge) {
    final s = ref.watch(appStringsProvider);
    // Nessun piano attivo
    if (personalPlan == null &&
        (challenge == null || challenge.aiPlan == null)) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_outlined,
                color: AppColors.accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                s.dashNoActivePlan,
                style: GoogleFonts.manrope(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/ai_planner'),
              child: Text(
                s.dashGeneratePlan,
                style: GoogleFonts.manrope(
                  color: AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Determina se mostrare piano challenge o personale
    final challengeWithPlan =
        (challenge != null && challenge.aiPlan != null) ? challenge : null;
    final bool showChallenge = challengeWithPlan != null;
    final Map<String, dynamic> plan =
        showChallenge ? challengeWithPlan.aiPlan! : personalPlan!;

    String title;
    Widget planBody;

    if (showChallenge) {
      title =
          '${s.dashChallengePlan} — ${challengeWithPlan.propFirmName ?? 'Prop Firm'}'.toUpperCase();
      final pct = plan['successPercentage'];
      final lotSize = plan['recommendedLotSize'];
      final risk = plan['riskPerTrade'];
      final milestones =
          (plan['milestones'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
              [];
      // Trova la milestone più vicina alla settimana attuale
      final currentWeek =
          (DateTime.now().difference(challengeWithPlan.startedAt).inDays / 7).ceil();
      Map<String, dynamic>? currentMilestone;
      for (final m in milestones) {
        final w = m['week'] as int? ?? 0;
        if (w >= currentWeek) {
          currentMilestone = m;
          break;
        }
      }
      currentMilestone ??= milestones.isNotEmpty ? milestones.last : null;

      planBody = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _planChip(s.dashSuccessPct(pct is int ? pct : (pct as num).toInt())),
              _planChip(s.dashLotSize(lotSize.toString())),
              _planChip(s.dashRiskPerTrade(risk.toString())),
            ],
          ),
          if (currentMilestone != null) ...[
            const SizedBox(height: 10),
            Text(
              '${s.chatMilestoneWeek(currentMilestone['week'] as int, currentMilestone['profitTarget'].toString())} — ${currentMilestone['description']}',
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      );
    } else {
      title = s.dashPersonalPlan;
      final dailyTarget = plan['dailyTarget'];
      final maxLoss = plan['maxDailyLossUsd'];
      final maxTrades = plan['maxTradesPerDay'];
      final advice = plan['sessionAdvice'] as String?;

      planBody = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (dailyTarget != null) _planChip('${s.dashAiTarget} $dailyTarget'),
              if (maxLoss != null) _planChip('${s.dashAiMaxLoss} $maxLoss'),
              if (maxTrades != null) _planChip('${s.dashAiMaxTrades} $maxTrades'),
            ],
          ),
          if (advice != null && advice.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              advice,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      );
    }

    return AnimatedCard(
      onTap: () => Navigator.pushNamed(context, '/ai_planner'),
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      backgroundColor: AppColors.cardBg,
      border: Border.all(color: AppColors.border, width: 0.5),
      boxShadow: const [],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            planBody,
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                s.dashDetails,
                style: GoogleFonts.manrope(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.cardBg2,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Limits Card ───────────────────────────────────────────────────────────
  Widget _buildLimitsCard(RulesState rulesState, BrokerState metaState) {
    final s = ref.watch(appStringsProvider);
    return AnimatedCard(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      backgroundColor: AppColors.cardBg,
      border: Border.all(color: AppColors.border, width: 0.5),
      boxShadow: const [],
      child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.dashYourLimitsToday.toUpperCase(),
            style: GoogleFonts.manrope(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          if (rulesState.rules == null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.dashRulesNotConfigured,
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/personal_rules'),
                  child: Text(
                    s.dashConfigureRules,
                    style: GoogleFonts.manrope(
                      color: AppColors.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            )
          else ...[
            // Riga 1 — Max perdita
            _buildLimitRow(
              label: s.dashMaxLossLabel,
              value: rulesState.rules!.maxDailyLossType == 'percent'
                  ? '${rulesState.rules!.maxDailyLoss ?? 0}%'
                  : '€${(rulesState.rules!.maxDailyLoss ?? 0).toStringAsFixed(0)}',
              progress: () {
                if (rulesState.rules!.maxDailyLoss == null ||
                    rulesState.rules!.maxDailyLoss! <= 0) return 0.0;
                final rawPnl = metaState.dailyPnl ?? 0.0;
                final safePnl = (rawPnl.isNaN || rawPnl.isInfinite) ? 0.0 : rawPnl;
                // Only show loss progress when actually losing; profit → 0.
                final loss = safePnl < 0 ? safePnl.abs() : 0.0;
                final r = loss / rulesState.rules!.maxDailyLoss!;
                return (r.isNaN || r.isInfinite) ? 0.0 : r.clamp(0.0, 1.0);
              }(),
            ),
            const SizedBox(height: 12),
            // Riga 2 — Max trade
            _buildLimitRow(
              label: s.dashMaxTradesLabel,
              value:
                  '${rulesState.tradesToday} / ${rulesState.rules!.maxTradesPerDay ?? '—'}',
              progress: rulesState.rules!.maxTradesPerDay != null &&
                      rulesState.rules!.maxTradesPerDay! > 0
                  ? (rulesState.tradesToday /
                          rulesState.rules!.maxTradesPerDay!)
                      .clamp(0.0, 1.0)
                  : 0.0,
            ),
            // Riga 3 — Orari trading (opzionale)
            if (rulesState.rules!.tradingHoursEnabled &&
                rulesState.rules!.tradingHoursStart != null &&
                rulesState.rules!.tradingHoursEnd != null) ...[
              const SizedBox(height: 12),
              _buildLimitRowIcon(
                label: s.dashTradingHoursLabel,
                value:
                    '${rulesState.rules!.tradingHoursStart} - ${rulesState.rules!.tradingHoursEnd}',
                icon: Icons.access_time_rounded,
              ),
            ],
            // Riga 4 — Durata killswitch
            const SizedBox(height: 12),
            _buildLimitRowIcon(
              label: s.dashKillswitchLockLabel,
              value: rulesState.rules!.killswitchDuration,
              icon: Icons.lock_outline_rounded,
            ),
          ],
        ],
      ),
      ),
    );
  }

  Widget _buildLimitRow({
    required String label,
    required String value,
    required double progress,
  }) {
    final Color barColor = progress < 0.5
        ? AppColors.accent
        : progress < 0.8
            ? AppColors.warning
            : AppColors.danger;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.manrope(
                  color: barColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        StatRingChart(
          value: progress.clamp(0.0, 1.0),
          color: barColor,
          size: 44,
          strokeWidth: 4,
        ),
      ],
    );
  }

  Widget _buildLimitRowIcon({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.manrope(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.manrope(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ── Accounts Section ──────────────────────────────────────────────────────
  Widget _buildAccountsSection(AppStrings s) {
    final rulesState = ref.watch(rulesProvider);
    final challenges = ref.watch(challengeListProvider);
    final broker = ref.watch(brokerProvider);
    final detectedAccount = broker.detectedAccountNumber;

    final personalAccount = rulesState.rules?.accountNumber;
    final activeAccounts = <Widget>[];

    // Account personale
    if (personalAccount != null && personalAccount.isNotEmpty) {
      final isActive = detectedAccount == personalAccount;
      activeAccounts.add(_accountCard(
        s: s,
        icon: Icons.person_rounded,
        label: s.dashPersonalAccountLabel,
        accountNumber: personalAccount,
        subtitle: rulesState.rules?.maxDailyLoss != null
            ? s.dashPersonalLimit(rulesState.rules!.maxDailyLossType == 'percent'
                ? '${rulesState.rules!.maxDailyLoss!.round()}%'
                : '€${rulesState.rules!.maxDailyLoss!.round()}')
            : s.dashNoLimitSet,
        isActive: isActive,
      ));
    }

    // Challenge attive con account number
    for (final c in challenges.where((c) => c.status == 'active' && c.accountNumber != null)) {
      final isActive = detectedAccount == c.accountNumber;
      activeAccounts.add(_accountCard(
        s: s,
        icon: Icons.emoji_events_rounded,
        label: c.propFirmName ?? 'Challenge',
        accountNumber: c.accountNumber!,
        subtitle: s.dashChallengeDay(c.currentDay, c.durationDays, c.profitTarget.toStringAsFixed(0)),
        isActive: isActive,
      ));
    }

    if (activeAccounts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.dashMyAccounts,
            style: GoogleFonts.manrope(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          ...activeAccounts,
        ],
      ),
    );
  }

  Widget _accountCard({
    required AppStrings s,
    required IconData icon,
    required String label,
    required String accountNumber,
    required String subtitle,
    required bool isActive,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: isActive ? AppColors.accent.withValues(alpha: 0.5) : AppColors.border,
          width: isActive ? 1 : 0.5,
        ),
        boxShadow: isActive ? [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ] : null,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.accent.withValues(alpha: 0.15)
                  : AppColors.cardBg2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isActive ? AppColors.accent : AppColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '#$accountNumber',
                  style: GoogleFonts.manrope(
                    color: isActive ? AppColors.accent : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                s.dashAccountActive,
                style: GoogleFonts.manrope(
                  color: AppColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Dev Tools ─────────────────────────────────────────────────────────────
  Widget _buildDevToggle() {
    return GestureDetector(
      onTap: () => setState(() => _showDevTools = !_showDevTools),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _showDevTools
                  ? Icons.bug_report
                  : Icons.bug_report_outlined,
              color: AppColors.textTertiary,
              size: 15,
            ),
            const SizedBox(width: 7),
            Text(
              ref.watch(appStringsProvider).dashDevTools,
              style: GoogleFonts.manrope(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevSection() {
    final s = ref.watch(appStringsProvider);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.danger.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.dashDevBanner,
            style: GoogleFonts.manrope(
              color: AppColors.danger,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              ref.read(killswitchProvider.notifier).activateAndSave(
                    'daily_loss',
                    360,
                    ref.read(currentUserIdProvider),
                    'personal',
                  );
              AccessibilityService.showKillswitchOverlay(
                durationMinutes: 360,
                reason: 'daily_loss',
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(
                  color: AppColors.danger, width: 0.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 9),
            ),
            child: Text(s.dashTestKillswitch,
                style: GoogleFonts.manrope(fontSize: 13)),
          ),
          const SizedBox(height: 7),
          OutlinedButton(
            onPressed: () =>
                setState(() => _showGatekeeper = true),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.fomo,
              side: const BorderSide(
                  color: AppColors.fomo, width: 0.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 9),
            ),
            child: Text(s.dashTestGatekeeper,
                style: GoogleFonts.manrope(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── Killswitch Banner ─────────────────────────────────────────────────────────
/// Banner non bloccante in cima alla dashboard.
/// Mostra info killswitch senza impedire l'uso di PipLock.
class _KillswitchBanner extends ConsumerStatefulWidget {
  const _KillswitchBanner();

  @override
  ConsumerState<_KillswitchBanner> createState() => _KillswitchBannerState();
}

class _KillswitchBannerState extends ConsumerState<_KillswitchBanner> {
  @override
  Widget build(BuildContext context) {
    final ks = ref.watch(killswitchProvider);
    if (!ks.isActive) return const SizedBox.shrink();
    return _BannerContent(ks: ks);
  }
}

class _BannerContent extends ConsumerStatefulWidget {
  final KillswitchState ks;
  const _BannerContent({required this.ks});

  @override
  ConsumerState<_BannerContent> createState() => _BannerContentState();
}

class _BannerContentState extends ConsumerState<_BannerContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  Duration _remaining = Duration.zero;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.ks.remainingTime;
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Aggiorna il countdown ogni secondo
    _tick();
  }

  void _tick() {
    if (!mounted) return;
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _remaining = widget.ks.remainingTime);
      _tick();
    });
  }

  @override
  void didUpdateWidget(_BannerContent old) {
    super.didUpdateWidget(old);
    _remaining = widget.ks.remainingTime;
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d <= Duration.zero) return '0:00';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    if (_dismissed) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context2, _) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFF3B30).withValues(alpha: 0.95),
              const Color(0xFFD62828).withValues(alpha: 0.95),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF3B30).withValues(alpha: _pulseAnim.value * 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Lock icon pulsante
            Opacity(
              opacity: _pulseAnim.value,
              child: const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            // Testo + countdown
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.dashKillswitchActive,
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    _formatDuration(_remaining),
                    style: GoogleFonts.manrope(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            // Dismiss banner
            GestureDetector(
              onTap: () => setState(() => _dismissed = true),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
