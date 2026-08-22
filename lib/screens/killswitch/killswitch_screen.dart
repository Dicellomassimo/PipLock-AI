import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/killswitch_provider.dart';
import '../../services/accessibility_service.dart';
import '../../services/face_auth_service.dart';

class KillswitchScreen extends ConsumerStatefulWidget {
  const KillswitchScreen({super.key});

  @override
  ConsumerState<KillswitchScreen> createState() => _KillswitchScreenState();
}

class _KillswitchScreenState extends ConsumerState<KillswitchScreen>
    with TickerProviderStateMixin {
  late AnimationController _breatheCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _entryCtrl;
  late AnimationController _holdCtrl;

  late Animation<double> _breathe;
  late Animation<double> _ring1;
  late Animation<double> _ring2;
  late Animation<double> _ring3;
  late Animation<double> _entryScale;
  late Animation<double> _entryFade;
  late Animation<double> _holdProgress;

  bool _holding = false;

  // Countdown state
  Duration _remaining = Duration.zero;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();

    // Breathing background
    _breatheCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _breathe = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut),
    );

    // Pulsing rings
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat();
    _ring1 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: const Interval(0.0, 0.8, curve: Curves.easeOut)),
    );
    _ring2 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: const Interval(0.15, 0.95, curve: Curves.easeOut)),
    );
    _ring3 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: const Interval(0.30, 1.0, curve: Curves.easeOut)),
    );

    // Entry animation
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _entryScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut),
    );
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);

    // Hold-to-unlock
    _holdCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    _holdProgress = CurvedAnimation(parent: _holdCtrl, curve: Curves.easeOut);
    _holdCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _tryUnlock();
    });

    _entryCtrl.forward();
    HapticFeedback.heavyImpact();

    // Initialize countdown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ks = ref.read(killswitchProvider);
      setState(() => _remaining = ks.remainingTime);
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final ks = ref.read(killswitchProvider);
      if (!ks.isActive) {
        _countdownTimer?.cancel();
        if (mounted) Navigator.of(context).maybePop();
        return;
      }
      final remaining = ks.remainingTime;
      if (mounted) {
        setState(() => _remaining = remaining);
        if (remaining == Duration.zero) {
          _countdownTimer?.cancel();
          ref.read(killswitchProvider.notifier).deactivate();
          if (mounted) Navigator.of(context).maybePop();
        }
      }
    });
  }

  @override
  void dispose() {
    _breatheCtrl.dispose();
    _pulseCtrl.dispose();
    _entryCtrl.dispose();
    _holdCtrl.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startHold() {
    if (_holding) return;
    setState(() => _holding = true);
    HapticFeedback.mediumImpact();
    _holdCtrl.forward(from: 0);
  }

  void _cancelHold() {
    if (!_holding) return;
    setState(() => _holding = false);
    _holdCtrl.reverse();
  }

  Future<void> _tryUnlock() async {
    // Face ID: optional attempt, does not block flow if unavailable.
    try {
      await FaceAuthService.authenticate(
        reason: 'Confirm your identity to unlock the Killswitch early',
      );
    } catch (_) {}

    final s = ref.read(appStringsProvider);
    final success = await ref.read(killswitchProvider.notifier).useToken();
    if (!success && mounted) {
      _cancelHold();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.ksTokensExhausted),
          backgroundColor: AppColors.danger,
        ),
      );
    } else if (mounted) {
      // Set flag so personal_rules_screen skips the lock for this session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('killswitch_token_used', true);
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/personal_rules');
      }
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$sec';
  }

  String _reasonText(String? reason, AppStrings s) {
    switch (reason) {
      case 'daily_loss':
        return s.ksDailyLoss;
      case 'max_trades':
        return s.ksMaxTrades;
      case 'revenge_pattern':
        return s.ksRevengePattern;
      case 'overleveraging':
        return s.ksOverleveraging;
      case 'fomo_pattern':
        return s.ksFomoPattern;
      default:
        return s.t('Limit reached', 'Limite raggiunto');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ks = ref.watch(killswitchProvider);
    final s = ref.watch(appStringsProvider);
    final tokens = ref.watch(authProvider).profile?.tokensAvailable ?? 0;

    if (!ks.isActive && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: AnimatedBuilder(
          animation: Listenable.merge([_breathe, _pulseCtrl, _entryCtrl]),
          builder: (_, child) {
            final breatheVal = _breathe.value;
            return Stack(
              children: [
                // Background gradient that breathes
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.lerp(const Color(0xFF0A0000), const Color(0xFF1A0000), breatheVal)!,
                        Color.lerp(const Color(0xFF1A0000), const Color(0xFF2D0000), breatheVal)!,
                        Color.lerp(const Color(0xFF0A0000), const Color(0xFF120000), breatheVal)!,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),

                // Vignette bottom
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 200,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x990D0000)],
                      ),
                    ),
                  ),
                ),

                // Pulsing rings behind icon
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _PulseRing(progress: _ring1.value, baseRadius: 120, color: AppColors.danger),
                      _PulseRing(progress: _ring2.value, baseRadius: 100, color: AppColors.danger),
                      _PulseRing(progress: _ring3.value, baseRadius: 80, color: AppColors.danger),
                    ],
                  ),
                ),

                // Main content
                SafeArea(
                  child: FadeTransition(
                    opacity: _entryFade,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
                      child: Column(
                        children: [
                          const SizedBox(height: 36),

                          // Title label
                          Text(
                            s.ksTitle.toUpperCase(),
                            style: GoogleFonts.manrope(
                              color: Colors.white.withValues(alpha: 0.40),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4.0,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Lock icon with entry scale + 3 static rings
                          ScaleTransition(
                            scale: _entryScale,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outermost ring
                                Container(
                                  width: 160,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.red.withValues(alpha: 0.08),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                // Middle ring
                                Container(
                                  width: 130,
                                  height: 130,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.red.withValues(alpha: 0.15),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                // Inner filled circle with glow
                                Container(
                                  width: 104,
                                  height: 104,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.danger.withValues(alpha: 0.15),
                                    border: Border.all(
                                      color: AppColors.danger.withValues(alpha: 0.4),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.danger.withValues(alpha: 0.35),
                                        blurRadius: 40,
                                        spreadRadius: -4,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.lock_rounded,
                                    color: Colors.white,
                                    size: 44,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Reason headline
                          Text(
                            _reasonText(ks.reason, s),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            s.t('Stay calm. The lock will end automatically.', 'Mantieni la calma. Il blocco terminerà automaticamente.'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: AppTheme.sp32),

                          // Countdown
                          _CountdownBlock(
                            remaining: _remaining,
                            formatter: _formatDuration,
                            willUnlockLabel: s.ksWillUnlock,
                          ),

                          const SizedBox(height: 20),

                          // Open positions info
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: AppTheme.bMd,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.10),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.info_outline_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    s.ksOpenPositions,
                                    style: GoogleFonts.manrope(
                                      color: Colors.white.withValues(alpha: 0.75),
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Token info badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.sp16, vertical: AppTheme.sp12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: AppTheme.bMd,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.toll_rounded, color: AppColors.accent, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  tokens > 0 ? s.ksTokensAvailable(tokens) : s.ksNoTokens,
                                  style: GoogleFonts.manrope(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: AppTheme.sp24),

                          // Hold-to-unlock button
                          _HoldToUnlockButton(
                            holdProgress: _holdProgress,
                            holding: _holding,
                            onHoldStart: tokens > 0 ? _startHold : null,
                            onHoldEnd: tokens > 0 ? _cancelHold : null,
                            label: tokens > 0 ? s.ksHoldToUnlock : s.ksNoTokens,
                            enabled: tokens > 0,
                          ),

                          const SizedBox(height: 12),

                          // Exit MT5 button
                          GestureDetector(
                            onTap: () => AccessibilityService.goHome(),
                            child: Container(
                              width: double.infinity,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: AppTheme.bMd,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.exit_to_app_rounded,
                                      color: Colors.white70, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    s.t('Exit MT5', 'Esci da MT5'),
                                    style: GoogleFonts.manrope(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 36),

                          // Divider
                          Row(
                            children: [
                              Expanded(child: Container(height: 0.5, color: Colors.white.withValues(alpha: 0.12))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                child: Text(
                                  s.t('STAY CALM', 'MANTIENI LA CALMA'),
                                  style: GoogleFonts.manrope(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2.5,
                                  ),
                                ),
                              ),
                              Expanded(child: Container(height: 0.5, color: Colors.white.withValues(alpha: 0.12))),
                            ],
                          ),
                          const SizedBox(height: 28),
                          const _BreathingWidget(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Pulse Ring ───────────────────────────────────────────────────────────────
class _PulseRing extends StatelessWidget {
  final double progress;
  final double baseRadius;
  final Color color;
  const _PulseRing({required this.progress, required this.baseRadius, required this.color});

  @override
  Widget build(BuildContext context) {
    final radius = baseRadius + progress * 60;
    final opacity = (1.0 - progress) * 0.25;
    if (opacity <= 0) return const SizedBox.shrink();
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: opacity),
          width: 1.5,
        ),
      ),
    );
  }
}

// ── Countdown Block ──────────────────────────────────────────────────────────
class _CountdownBlock extends StatelessWidget {
  final Duration remaining;
  final String Function(Duration) formatter;
  final String willUnlockLabel;
  const _CountdownBlock({
    required this.remaining,
    required this.formatter,
    required this.willUnlockLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isUrgent = remaining.inMinutes < 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Text(
            formatter(remaining),
            style: GoogleFonts.manrope(
              color: isUrgent ? AppColors.warning : AppColors.silverBright,
              fontSize: 64,
              fontWeight: FontWeight.w900,
              letterSpacing: -2,
              height: 1.0,
              fontFeatures: [const FontFeature.tabularFigures()],
              shadows: [
                Shadow(
                  color: isUrgent
                      ? AppColors.warning.withValues(alpha: 0.50)
                      : AppColors.silverBright.withValues(alpha: 0.40),
                  blurRadius: 24,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            willUnlockLabel,
            style: GoogleFonts.manrope(
              color: Colors.white.withValues(alpha: 0.40),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hold To Unlock Button ────────────────────────────────────────────────────
class _HoldToUnlockButton extends StatelessWidget {
  final Animation<double> holdProgress;
  final bool holding;
  final VoidCallback? onHoldStart;
  final VoidCallback? onHoldEnd;
  final String label;
  final bool enabled;

  const _HoldToUnlockButton({
    required this.holdProgress,
    required this.holding,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.label,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: onHoldStart != null ? (_) => onHoldStart!() : null,
      onLongPressEnd: onHoldEnd != null ? (_) => onHoldEnd!() : null,
      onLongPressCancel: onHoldEnd,
      child: AnimatedBuilder(
        animation: holdProgress,
        builder: (_, _) {
          final progress = holdProgress.value;
          return Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: enabled
                  ? Colors.white.withValues(alpha: holding ? 0.18 : 0.09)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: AppTheme.bMd,
              border: Border.all(
                color: enabled
                    ? Colors.white.withValues(alpha: 0.25 + progress * 0.5)
                    : Colors.white.withValues(alpha: 0.08),
                width: 1 + progress,
              ),
              boxShadow: progress > 0.1
                  ? [
                      BoxShadow(
                        color: AppColors.danger.withValues(alpha: progress * 0.3),
                        blurRadius: 20,
                        spreadRadius: -4,
                      )
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                // Progress fill
                if (progress > 0)
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.12),
                            Colors.white.withValues(alpha: 0.06),
                          ],
                        ),
                        borderRadius: AppTheme.bMd,
                      ),
                    ),
                  ),
                // Label
                SizedBox(
                  height: 56,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.toll_rounded,
                              color: enabled
                                  ? Colors.white.withValues(alpha: 0.7 + progress * 0.3)
                                  : Colors.white.withValues(alpha: 0.25),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              label,
                              style: GoogleFonts.manrope(
                                color: enabled
                                    ? Colors.white.withValues(alpha: 0.7 + progress * 0.3)
                                    : Colors.white.withValues(alpha: 0.30),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Breathing Exercise Widget ─────────────────────────────────────────────────

class _BreathingWidget extends StatefulWidget {
  const _BreathingWidget();

  @override
  State<_BreathingWidget> createState() => _BreathingWidgetState();
}

class _BreathingWidgetState extends State<_BreathingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // 4s inhale + 7s hold + 8s exhale = 19s total
  static const _totalMs = 19000;
  static const _inhaleEnd = 4 / 19;
  static const _holdEnd = 11 / 19;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalMs),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;

        final String phaseLabel;
        final Color circleColor;
        final double size;

        if (t < _inhaleEnd) {
          final progress = t / _inhaleEnd;
          phaseLabel = 'Inhale';
          circleColor = const Color(0xFF7B61FF);
          size = 80 + 80 * progress;
        } else if (t < _holdEnd) {
          phaseLabel = 'Hold';
          circleColor = const Color(0xFFFFC947);
          size = 160;
        } else {
          final progress = (t - _holdEnd) / (1.0 - _holdEnd);
          phaseLabel = 'Exhale';
          circleColor = const Color(0xFF4CAF50);
          size = 160 - 80 * progress;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '4-7-8 Exercise',
              style: GoogleFonts.manrope(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 180,
              height: 180,
              child: Center(
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: circleColor.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(color: circleColor, width: 2.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              phaseLabel,
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      },
    );
  }
}
