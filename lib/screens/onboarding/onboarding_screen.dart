import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_colors.dart';
import '../../config/app_theme.dart';
import '../../widgets/premium_button.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _current = 0;
  double _pageOffset = 0.0; // for parallax
  late AnimationController _particleCtrl;
  String? _selectedPlatform;

  static const int _totalSlides = 12;

  static const _accentColors = [
    Color(0xFFFF4455),   // 0 - hook (danger red)
    Color(0xFFFF6B35),   // 1 - cost (orange)
    Color(0xFFC4D0DC),   // 2 - brand reveal (silver chrome)
    Color(0xFFFF4455),   // 3 - killswitch mockup (danger red)
    Color(0xFF00C896),   // 4 - AI planner (teal-mint)
    Color(0xFF4A90E2),   // 5 - social proof (steel blue)
    Color(0xFFFF6B35),   // 6 - why traders fail (orange)
    Color(0xFF00C896),   // 7 - discipline edge (teal)
    Color(0xFF00C896),   // 8 - benefits (teal)
    Color(0xFFFFBD2E),   // 9 - savings (amber)
    Color(0xFF8B98AA),   // 10 - platform (silver dim)
    Color(0xFFC4D0DC),   // 11 - paywall (silver chrome)
  ];

  @override
  void initState() {
    super.initState();
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _pageCtrl.addListener(() {
      if (mounted) setState(() => _pageOffset = _pageCtrl.page ?? 0.0);
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_current < _totalSlides - 1) {
      _pageCtrl.nextPage(duration: AppTheme.dSlow, curve: AppTheme.cSpring);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (_selectedPlatform != null) {
      await prefs.setString('trading_platform', _selectedPlatform!);
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/paywall');
  }

  Color get _currentAccent =>
      _accentColors[_current.clamp(0, _accentColors.length - 1)];

  String _ctaLabel() {
    switch (_current) {
      case 10:
        return _selectedPlatform != null ? 'Continue →' : 'Select platform';
      case 11:
        return 'Start free trial →';
      default:
        return 'Continue';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final accent = _currentAccent;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ambient blob — top right with parallax
          Positioned(
            top: -100,
            right: -80 + _pageOffset * 18,
            child: AnimatedContainer(
              duration: AppTheme.dSlow, curve: AppTheme.cSpring,
              width: 360, height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  accent.withValues(alpha: 0.12), Colors.transparent,
                ]),
              ),
            ),
          ),
          // Ambient blob — bottom left with parallax (counter-direction)
          Positioned(
            bottom: 200,
            left: -100 - _pageOffset * 14,
            child: AnimatedContainer(
              duration: AppTheme.dSlow, curve: AppTheme.cSpring,
              width: 280, height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  accent.withValues(alpha: 0.05), Colors.transparent,
                ]),
              ),
            ),
          ),
          // Particles
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, child) => CustomPaint(
              size: size,
              painter: _ParticlePainter(progress: _particleCtrl.value, color: accent),
            ),
          ),
          // Main content
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppTheme.pagePadding, 16, AppTheme.pagePadding, 0),
                  child: _ProgressBar(current: _current, total: _totalSlides, color: accent),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedOpacity(
                    opacity: _current < _totalSlides - 2 ? 1.0 : 0.0,
                    duration: AppTheme.dMedium,
                    child: TextButton(
                      onPressed: _current < _totalSlides - 2 ? _finish : null,
                      child: Text('Skip',
                        style: GoogleFonts.manrope(
                          color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    onPageChanged: (i) => setState(() => _current = i),
                    itemCount: _totalSlides,
                    itemBuilder: (_, i) {
                      final active = _current == i;
                      switch (i) {
                        case 0: return _EmotionalHookSlide(isActive: active);
                        case 1: return _CostSlide(isActive: active);
                        case 2: return _BrandRevealSlide(isActive: active);
                        case 3: return _KillswitchMockupSlide(isActive: active);
                        case 4: return _AiPlannerSlide(isActive: active);
                        case 5: return _SocialProofSlide(isActive: active);
                        case 6: return _WhyTradersFail(isActive: active);
                        case 7: return _DisciplineEdge(isActive: active);
                        case 8: return _BenefitsSlide(isActive: active);
                        case 9: return _SavingsSlide(isActive: active);
                        case 10: return _PlatformSlide(
                          isActive: active,
                          selected: _selectedPlatform,
                          onSelected: (p) => setState(() => _selectedPlatform = p),
                        );
                        case 11: return _PaywallSlide(isActive: active, onSkip: _finish);
                        default: return const SizedBox.shrink();
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppTheme.pagePadding, 0, AppTheme.pagePadding, 32),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_totalSlides, (i) {
                          final active = i == _current;
                          return AnimatedContainer(
                            duration: AppTheme.dMedium, curve: AppTheme.cSpring,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: active ? 20 : 6, height: 6,
                            decoration: BoxDecoration(
                              color: active ? accent : AppColors.textTertiary.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: active
                                  ? [BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 6)]
                                  : null,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                      PremiumButton(
                        label: _ctaLabel(),
                        onTap: _nextPage,
                        icon: _current == _totalSlides - 1
                            ? Icons.rocket_launch_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN 1 — Emotional hook (candle vortex → explode → FAIL)
// ══════════════════════════════════════════════════════════════════════════════
class _EmotionalHookSlide extends StatefulWidget {
  final bool isActive;
  const _EmotionalHookSlide({required this.isActive});
  @override State<_EmotionalHookSlide> createState() => _EmotionalHookSlideState();
}

class _EmotionalHookSlideState extends State<_EmotionalHookSlide>
    with TickerProviderStateMixin {
  late AnimationController _loopCtrl;
  late AnimationController _explodeCtrl;
  late AnimationController _contentCtrl;
  late Animation<double> _contentAnim;

  @override
  void initState() {
    super.initState();
    _loopCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _explodeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _contentCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _contentAnim = CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut);
    if (widget.isActive) _startAnimations();
  }

  void _startAnimations() {
    _explodeCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _contentCtrl.forward(from: 0);
    });
  }

  @override
  void didUpdateWidget(_EmotionalHookSlide old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _explodeCtrl.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _contentCtrl.forward(from: 0);
      });
    }
  }

  @override
  void dispose() {
    _loopCtrl.dispose();
    _explodeCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visual zone: candle vortex + FAIL text
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge([_loopCtrl, _explodeCtrl]),
                  builder: (_, __) => CustomPaint(
                    size: const Size(double.infinity, 180),
                    painter: _CandleVortexPainter(
                      loopValue: _loopCtrl.value,
                      explodeValue: _explodeCtrl.value,
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _explodeCtrl,
                  builder: (_, __) {
                    final showFail = _explodeCtrl.value > 0.7;
                    final failOpacity = showFail
                        ? ((_explodeCtrl.value - 0.7) / 0.3).clamp(0.0, 1.0)
                        : 0.0;
                    return Opacity(
                      opacity: failOpacity,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Glitch shadow behind
                          Transform.translate(
                            offset: const Offset(4, 2),
                            child: Text('FAIL',
                              style: GoogleFonts.manrope(
                                color: AppColors.danger.withValues(alpha: 0.5),
                                fontSize: 80, fontWeight: FontWeight.w900, letterSpacing: -3)),
                          ),
                          Transform.translate(
                            offset: const Offset(-3, -1),
                            child: Text('FAIL',
                              style: GoogleFonts.manrope(
                                color: AppColors.danger.withValues(alpha: 0.3),
                                fontSize: 80, fontWeight: FontWeight.w900, letterSpacing: -3)),
                          ),
                          Text('FAIL',
                            style: GoogleFonts.manrope(
                              color: AppColors.danger,
                              fontSize: 80, fontWeight: FontWeight.w900, letterSpacing: -3)),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FadeTransition(
            opacity: _contentAnim,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
                  .animate(_contentAnim),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('90% of traders don\'t fail\ndue to strategy.',
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary, fontSize: 36,
                      fontWeight: FontWeight.w900, letterSpacing: -1.8, height: 1.05)),
                  const SizedBox(height: 16),
                  Text('They fail in 1 hour of tilt.',
                    style: GoogleFonts.manrope(
                      color: AppColors.danger, fontSize: 22,
                      fontWeight: FontWeight.w800, letterSpacing: -0.8)),
                  const SizedBox(height: 20),
                  Text('Overtrading, revenge trading, and bad position sizing destroy months of gains in minutes.',
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary, fontSize: 15, height: 1.55)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN 2 — The cost (coin stack + green drop)
// ══════════════════════════════════════════════════════════════════════════════
class _CostSlide extends StatefulWidget {
  final bool isActive;
  const _CostSlide({required this.isActive});
  @override State<_CostSlide> createState() => _CostSlideState();
}

class _CostSlideState extends State<_CostSlide> with TickerProviderStateMixin {
  late AnimationController _coinsCtrl;
  late AnimationController _floatCtrl;
  late AnimationController _contentCtrl;
  late Animation<double> _contentAnim;

  @override
  void initState() {
    super.initState();
    _coinsCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _contentCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _contentAnim = CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut);
    if (widget.isActive) _start();
  }

  void _start() {
    _contentCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _coinsCtrl.forward(from: 0);
    });
  }

  @override
  void didUpdateWidget(_CostSlide old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _start();
  }

  @override
  void dispose() { _coinsCtrl.dispose(); _floatCtrl.dispose(); _contentCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
      child: FadeTransition(
        opacity: _contentAnim,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
              .animate(_contentAnim),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: _CoinStack(ctrl: _coinsCtrl)),
                  const SizedBox(width: 24),
                  _GreenDrop(ctrl: _floatCtrl),
                ],
              ),
              const SizedBox(height: 28),
              Text('One emotional mistake\ncosts an average of \$1,500.',
                style: GoogleFonts.manrope(
                  color: AppColors.textPrimary, fontSize: 34,
                  fontWeight: FontWeight.w900, letterSpacing: -1.5, height: 1.05)),
              const SizedBox(height: AppTheme.sp16),
              Text(
                'Most traders buy \$100k prop challenges only to blow them during their first week from a lack of strict risk controls.',
                style: GoogleFonts.manrope(
                  color: AppColors.textSecondary, fontSize: 15,
                  fontWeight: FontWeight.w400, height: 1.55)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoinStack extends StatelessWidget {
  final AnimationController ctrl;
  const _CoinStack({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = ctrl.value;
        final coinCount = (t * 8).floor().clamp(0, 8);
        final showCounter = t > 0.7;
        final counterVal = showCounter ? ((t - 0.7) / 0.3 * 1500).toInt() : 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showCounter)
              Text('\$$counterVal',
                style: GoogleFonts.manrope(
                  color: AppColors.danger,
                  fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -1)),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: List.generate(coinCount, (i) {
                  return Positioned(
                    bottom: i * 9.0,
                    child: Container(
                      width: 56, height: 12,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: LinearGradient(
                          colors: i % 3 == 0
                              ? [AppColors.danger.withValues(alpha: 0.9), AppColors.danger.withValues(alpha: 0.5)]
                              : [AppColors.silverDim, AppColors.silver],
                        ),
                        boxShadow: [BoxShadow(
                          color: AppColors.danger.withValues(alpha: 0.3),
                          blurRadius: 8, offset: const Offset(0, 2),
                        )],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 4),
            Text('Losses pile up', style: GoogleFonts.manrope(
              color: AppColors.textTertiary, fontSize: 11)),
          ],
        );
      },
    );
  }
}

class _GreenDrop extends StatelessWidget {
  final AnimationController ctrl;
  const _GreenDrop({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final floatAnim = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: ctrl, curve: Curves.easeInOut));
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, floatAnim.value),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success.withValues(alpha: 0.15),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.4), width: 1.5),
                boxShadow: [BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.3),
                  blurRadius: 20, spreadRadius: 2,
                )],
              ),
              child: const Icon(Icons.trending_up_rounded, color: AppColors.success, size: 28),
            ),
            const SizedBox(height: 8),
            Text('\$0.60/day', style: GoogleFonts.manrope(
              color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w700)),
            Text('PipLock', style: GoogleFonts.manrope(
              color: AppColors.textTertiary, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN 3 — Brand reveal (liquid reveal + shockwave rings)
// ══════════════════════════════════════════════════════════════════════════════
class _BrandRevealSlide extends StatefulWidget {
  final bool isActive;
  const _BrandRevealSlide({required this.isActive});
  @override State<_BrandRevealSlide> createState() => _BrandRevealSlideState();
}

class _BrandRevealSlideState extends State<_BrandRevealSlide>
    with TickerProviderStateMixin {
  late AnimationController _revealCtrl;
  late AnimationController _waveCtrl;
  late AnimationController _contentCtrl;
  late Animation<double> _revealAnim;
  late Animation<double> _contentAnim;

  @override
  void initState() {
    super.initState();
    _revealCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _waveCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _contentCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _revealAnim = CurvedAnimation(parent: _revealCtrl, curve: Curves.easeOutCubic);
    _contentAnim = CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut);
    if (widget.isActive) _start();
  }

  void _start() {
    _revealCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _contentCtrl.forward(from: 0);
    });
  }

  @override
  void didUpdateWidget(_BrandRevealSlide old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _start();
  }

  @override
  void dispose() {
    _revealCtrl.dispose(); _waveCtrl.dispose(); _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: SizedBox(
              width: 180, height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Shockwave rings
                  AnimatedBuilder(
                    animation: _waveCtrl,
                    builder: (_, __) => CustomPaint(
                      size: const Size(180, 140),
                      painter: _ShockwavePainter(progress: _waveCtrl.value),
                    ),
                  ),
                  // Glow ring
                  Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                        color: AppColors.silverBright.withValues(alpha: 0.25),
                        blurRadius: 40, spreadRadius: 8,
                      )],
                    ),
                  ),
                  // Logo reveal from bottom
                  AnimatedBuilder(
                    animation: _revealAnim,
                    builder: (_, child) => ClipRect(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        heightFactor: _revealAnim.value,
                        child: child,
                      ),
                    ),
                    child: Image.asset('assets/images/Icona PipLock.png',
                      width: 90, height: 90, fit: BoxFit.contain),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          FadeTransition(
            opacity: _contentAnim,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
                  .animate(_contentAnim),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Meet PipLock AI.',
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary, fontSize: 40,
                      fontWeight: FontWeight.w900, letterSpacing: -2, height: 1.0)),
                  Text('Forced discipline.\nBetter trading.',
                    style: GoogleFonts.manrope(
                      color: AppColors.accent, fontSize: 28,
                      fontWeight: FontWeight.w800, letterSpacing: -1.2, height: 1.1)),
                  const SizedBox(height: 16),
                  Text(
                    'Active risk infrastructure that monitors your accounts in real-time and intervenes before disaster hits.',
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary, fontSize: 15, height: 1.55)),
                  const SizedBox(height: 20),
                  _StaggerChip(delay: 0, ctrl: _contentCtrl, icon: Icons.lock_rounded,
                    label: 'Hard Killswitch', color: AppColors.danger),
                  const SizedBox(height: 10),
                  _StaggerChip(delay: 120, ctrl: _contentCtrl, icon: Icons.auto_awesome_rounded,
                    label: 'AI Challenge Planner', color: AppColors.accent),
                  const SizedBox(height: 10),
                  _StaggerChip(delay: 240, ctrl: _contentCtrl, icon: Icons.shield_rounded,
                    label: 'Real-time Monitoring', color: AppColors.silverBright),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaggerChip extends StatelessWidget {
  final int delay;
  final AnimationController ctrl;
  final IconData icon;
  final String label;
  final Color color;
  const _StaggerChip({required this.delay, required this.ctrl,
    required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final interval = Interval(
      (delay / 600).clamp(0.0, 1.0),
      ((delay + 300) / 600).clamp(0.0, 1.0),
      curve: Curves.easeOut,
    );
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, child) {
        final t = interval.transform(ctrl.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.manrope(
            color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  final double progress;
  const _BurstPainter({required this.progress});
  static const int _count = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < _count; i++) {
      final angle = (i / _count) * 2 * math.pi;
      final dist = progress * 55.0;
      final opacity = (1 - progress) * 0.7;
      final pos = center + Offset(math.cos(angle) * dist, math.sin(angle) * dist);
      canvas.drawCircle(pos, 2.5 * (1 - progress * 0.5),
        Paint()..color = AppColors.accent.withValues(alpha: opacity));
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.progress != progress;
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN 4 — Killswitch mockup (UI shatter → killswitch card)
// ══════════════════════════════════════════════════════════════════════════════
class _KillswitchMockupSlide extends StatefulWidget {
  final bool isActive;
  const _KillswitchMockupSlide({required this.isActive});
  @override State<_KillswitchMockupSlide> createState() => _KillswitchMockupSlideState();
}

class _KillswitchMockupSlideState extends State<_KillswitchMockupSlide>
    with TickerProviderStateMixin {
  late AnimationController _shatterCtrl;
  late AnimationController _killCtrl;
  late AnimationController _counterCtrl;
  late AnimationController _contentCtrl;
  late Animation<double> _contentAnim;

  @override
  void initState() {
    super.initState();
    _shatterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _killCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _counterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _contentCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _contentAnim = CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut);
    if (widget.isActive) _start();
  }

  void _start() {
    _shatterCtrl.forward(from: 0).then((_) {
      if (mounted) _killCtrl.forward(from: 0);
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _counterCtrl.forward(from: 0);
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _contentCtrl.forward(from: 0);
    });
  }

  @override
  void didUpdateWidget(_KillswitchMockupSlide old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _start();
  }

  @override
  void dispose() {
    _shatterCtrl.dispose(); _killCtrl.dispose();
    _counterCtrl.dispose(); _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visual: shatter then killswitch card
          SizedBox(
            height: 200,
            child: Stack(
              children: [
                // Shatter pieces (3 grey UI blocks that disperse)
                AnimatedBuilder(
                  animation: _shatterCtrl,
                  builder: (_, __) {
                    final t = CurvedAnimation(parent: _shatterCtrl, curve: Curves.easeIn).value;
                    return Stack(
                      children: [
                        _ShatterBlock(t: t, dx: -60, dy: -40, rot: -0.3, color: AppColors.cardBg2,
                          child: _FakeTradingRow(label: 'EUR/USD', value: '1.0842', isGreen: true)),
                        _ShatterBlock(t: t, dx: 50, dy: -20, rot: 0.25, color: AppColors.cardBg2,
                          child: _FakeTradingRow(label: 'GBP/USD', value: '1.2671', isGreen: false)),
                        _ShatterBlock(t: t, dx: -30, dy: 60, rot: 0.15, color: AppColors.cardBg2,
                          child: _FakeTradingRow(label: 'XAU/USD', value: '2,340', isGreen: true)),
                      ],
                    );
                  },
                ),
                // Killswitch card
                AnimatedBuilder(
                  animation: _killCtrl,
                  builder: (_, child) {
                    final t = CurvedAnimation(parent: _killCtrl, curve: Curves.easeOut).value;
                    return Opacity(
                      opacity: t,
                      child: Transform.scale(scale: 0.8 + 0.2 * t, child: child),
                    );
                  },
                  child: AnimatedBuilder(
                    animation: _counterCtrl,
                    builder: (_, __) {
                      final counterVal = (_counterCtrl.value * 1850).toInt();
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.danger.withValues(alpha: 0.4), width: 1.5),
                          boxShadow: [BoxShadow(
                            color: AppColors.danger.withValues(alpha: 0.2),
                            blurRadius: 24, offset: const Offset(0, 8),
                          )],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.lock_rounded, color: AppColors.danger, size: 18),
                              const SizedBox(width: 8),
                              Text('KILLSWITCH ACTIVATED',
                                style: GoogleFonts.manrope(
                                  color: AppColors.danger, fontSize: 13,
                                  fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                            ]),
                            const SizedBox(height: 6),
                            Text('Daily loss threshold reached (\$400 limit).',
                              style: GoogleFonts.manrope(
                                color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
                            const SizedBox(height: 10),
                            Text('Capital Protected Today: +\$$counterVal',
                              style: GoogleFonts.manrope(
                                color: AppColors.success, fontSize: 14,
                                fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Text('05:47:22 remaining',
                              style: GoogleFonts.robotoMono(
                                color: AppColors.textTertiary, fontSize: 12,
                                letterSpacing: 1)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.sp24),
          FadeTransition(
            opacity: _contentAnim,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
                  .animate(_contentAnim),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hit your loss limit?\nThe KillSwitch locks you out instantly.',
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary, fontSize: 28,
                      fontWeight: FontWeight.w900, letterSpacing: -1.2, height: 1.1)),
                  const SizedBox(height: AppTheme.sp16),
                  Text(
                    'PipLock AI restricts trading app access during your cooling-off period.',
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary, fontSize: 15,
                      fontWeight: FontWeight.w400, height: 1.55)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShatterBlock extends StatelessWidget {
  final double t, dx, dy, rot;
  final Color color;
  final Widget child;
  const _ShatterBlock({required this.t, required this.dx, required this.dy,
    required this.rot, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(dx * t, dy * t),
      child: Transform.rotate(
        angle: rot * t,
        child: Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _FakeTradingRow extends StatelessWidget {
  final String label, value;
  final bool isGreen;
  const _FakeTradingRow({required this.label, required this.value, required this.isGreen});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: GoogleFonts.manrope(
          color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Text(value, style: GoogleFonts.manrope(
          color: isGreen ? AppColors.success : AppColors.danger,
          fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN 5 — AI Planner (neural map + chat bubbles)
// ══════════════════════════════════════════════════════════════════════════════
class _AiPlannerSlide extends StatefulWidget {
  final bool isActive;
  const _AiPlannerSlide({required this.isActive});
  @override State<_AiPlannerSlide> createState() => _AiPlannerSlideState();
}

class _AiPlannerSlideState extends State<_AiPlannerSlide>
    with TickerProviderStateMixin {
  late AnimationController _neuralCtrl;
  late List<AnimationController> _msgCtrls;
  late AnimationController _contentCtrl;
  late Animation<double> _contentAnim;

  static const _delays = [0, 700, 1400];

  @override
  void initState() {
    super.initState();
    _neuralCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _msgCtrls = List.generate(2, (_) => AnimationController(
      vsync: this, duration: const Duration(milliseconds: 350)));
    _contentCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _contentAnim = CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut);
    if (widget.isActive) _start();
  }

  void _start() {
    _neuralCtrl.forward(from: 0);
    _contentCtrl.forward(from: 0);
    for (var i = 0; i < 2; i++) {
      Future.delayed(Duration(milliseconds: _delays[i + 1]), () {
        if (mounted) _msgCtrls[i].forward(from: 0);
      });
    }
  }

  @override
  void didUpdateWidget(_AiPlannerSlide old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      for (final c in _msgCtrls) c.value = 0;
      _neuralCtrl.value = 0;
      _start();
    }
  }

  @override
  void dispose() {
    _neuralCtrl.dispose();
    for (final c in _msgCtrls) c.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Widget _msg(int idx, bool isAI, String text, Color color) {
    return AnimatedBuilder(
      animation: _msgCtrls[idx],
      builder: (_, child) {
        final t = CurvedAnimation(parent: _msgCtrls[idx], curve: Curves.easeOut).value;
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
        );
      },
      child: _ChatBubble(isAI: isAI, text: text, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Neural map
          SizedBox(
            height: 130,
            child: AnimatedBuilder(
              animation: _neuralCtrl,
              builder: (_, __) => CustomPaint(
                size: const Size(double.infinity, 130),
                painter: _NeuralMapPainter(progress: _neuralCtrl.value),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Chat bubbles
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _msg(0, false,
                  'Lock my MT5 account if I lose more than \$300 today.',
                  AppColors.accent),
                const SizedBox(height: 10),
                _msg(1, true,
                  'Rule set. If equity drops below \$9,700, the KillSwitch triggers immediately.',
                  AppColors.accent),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.sp20),
          FadeTransition(
            opacity: _contentAnim,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
                  .animate(_contentAnim),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Set your risk rules\nby simply chatting with AI.',
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary, fontSize: 30,
                      fontWeight: FontWeight.w900, letterSpacing: -1.5, height: 1.1)),
                  const SizedBox(height: AppTheme.sp16),
                  Text(
                    'No complex menus. Tell PipLock AI your guidelines and it converts them into hard execution rules.',
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary, fontSize: 15,
                      fontWeight: FontWeight.w400, height: 1.55)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN 6 — Social proof (constellation network + counter)
// ══════════════════════════════════════════════════════════════════════════════
class _SocialProofSlide extends StatefulWidget {
  final bool isActive;
  const _SocialProofSlide({required this.isActive});
  @override State<_SocialProofSlide> createState() => _SocialProofSlideState();
}

class _SocialProofSlideState extends State<_SocialProofSlide>
    with TickerProviderStateMixin {
  late AnimationController _constellCtrl;
  late AnimationController _counterCtrl;
  late AnimationController _statsCtrl;
  late AnimationController _contentCtrl;
  late Animation<double> _contentAnim;

  @override
  void initState() {
    super.initState();
    _constellCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _counterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _statsCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _contentCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _contentAnim = CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut);
    if (widget.isActive) _start();
  }

  void _start() {
    _contentCtrl.forward(from: 0);
    _counterCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _statsCtrl.forward(from: 0);
    });
  }

  @override
  void didUpdateWidget(_SocialProofSlide old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _start();
  }

  @override
  void dispose() {
    _constellCtrl.dispose(); _counterCtrl.dispose();
    _statsCtrl.dispose(); _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shield painter
          SizedBox(
            height: 160,
            child: AnimatedBuilder(
              animation: _constellCtrl,
              builder: (_, __) => CustomPaint(
                size: const Size(double.infinity, 160),
                painter: _ShieldPainter(progress: _constellCtrl.value),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Counter
          AnimatedBuilder(
            animation: _counterCtrl,
            builder: (_, __) {
              final val = (_counterCtrl.value * 1200000).toInt();
              final formatted = '\$${(val / 1000).toStringAsFixed(0)}K+';
              return Text(formatted,
                style: GoogleFonts.manrope(
                  color: AppColors.silverBright, fontSize: 40,
                  fontWeight: FontWeight.w900, letterSpacing: -2));
            },
          ),
          FadeTransition(
            opacity: _contentAnim,
            child: Text('in trading capital protected this month.',
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary, fontSize: 16, height: 1.4)),
          ),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _statsCtrl,
            builder: (_, child) {
              final t = CurvedAnimation(parent: _statsCtrl, curve: Curves.easeOut).value;
              return Opacity(opacity: t,
                child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child));
            },
            child: Column(
              children: [
                Row(children: [
                  const Icon(Icons.verified_rounded, color: AppColors.accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Join funded traders who stay in the game longer.',
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary, fontSize: 13, height: 1.4))),
                ]),
                const SizedBox(height: 16),
                _StatRow(icon: Icons.shield_rounded, color: AppColors.accent,
                  text: 'Trading accounts protected: 2,847+'),
                const SizedBox(height: 10),
                _StatRow(icon: Icons.trending_up_rounded, color: AppColors.success,
                  text: 'Avg challenge pass rate with PipLock: 3.2x higher'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SLIDE 6 — Why traders fail (animated failure bars)
// ══════════════════════════════════════════════════════════════════════════════
class _WhyTradersFail extends StatefulWidget {
  final bool isActive;
  const _WhyTradersFail({required this.isActive});
  @override State<_WhyTradersFail> createState() => _WhyTradersFailState();
}

class _WhyTradersFailState extends State<_WhyTradersFail>
    with TickerProviderStateMixin {
  late AnimationController _headerCtrl;
  late List<AnimationController> _barCtrls;
  late Animation<double> _headerAnim;

  static const _failures = [
    (Icons.repeat_rounded, 'Overtrading', '68% of failed challenges', 0.68, Color(0xFFFF3B30)),
    (Icons.psychology_rounded, 'Revenge Trading', '61% of blown accounts', 0.61, Color(0xFFFF6B35)),
    (Icons.trending_up_rounded, 'FOMO Entries', '74% of avoidable losses', 0.74, Color(0xFFFFBD2E)),
    (Icons.schedule_rounded, 'Wrong trading hours', '45% of overtraders', 0.45, Color(0xFF4A90E2)),
  ];

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _headerAnim = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _barCtrls = List.generate(_failures.length, (_) =>
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900)));
    if (widget.isActive) _start();
  }

  void _start() {
    _headerCtrl.forward(from: 0);
    for (var i = 0; i < _failures.length; i++) {
      Future.delayed(Duration(milliseconds: 300 + i * 180), () {
        if (mounted) _barCtrls[i].forward(from: 0);
      });
    }
  }

  @override
  void didUpdateWidget(_WhyTradersFail old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _start();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    for (final c in _barCtrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          FadeTransition(
            opacity: _headerAnim,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
                  .animate(_headerAnim),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFF3B30).withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.bar_chart_rounded, color: Color(0xFFFF6B35), size: 28),
                  ),
                  const SizedBox(height: 20),
                  Text('Why 90% of traders\nfail their challenge.',
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary, fontSize: 32,
                      fontWeight: FontWeight.w900, letterSpacing: -1.5, height: 1.1)),
                  const SizedBox(height: 8),
                  Text('The patterns are always the same. And they\'re all preventable.',
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary, fontSize: 14, height: 1.45)),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          ...List.generate(_failures.length, (i) {
            final f = _failures[i];
            return AnimatedBuilder(
              animation: _barCtrls[i],
              builder: (_, __) {
                final t = CurvedAnimation(parent: _barCtrls[i], curve: Curves.easeOutCubic).value;
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, 14 * (1 - t)),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(f.$1, color: f.$5, size: 16),
                            const SizedBox(width: 8),
                            Text(f.$2,
                              style: GoogleFonts.manrope(
                                color: AppColors.textPrimary, fontSize: 14,
                                fontWeight: FontWeight.w700)),
                            const Spacer(),
                            Text(f.$3,
                              style: GoogleFonts.manrope(
                                color: f.$5, fontSize: 12, fontWeight: FontWeight.w600)),
                          ]),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Stack(children: [
                              Container(height: 6, color: AppColors.border),
                              FractionallySizedBox(
                                widthFactor: f.$4 * t,
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: f.$5,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _barCtrls.last,
            builder: (_, __) {
              final t = CurvedAnimation(parent: _barCtrls.last, curve: Curves.easeOut).value;
              return Opacity(
                opacity: t,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D4AA).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00D4AA).withValues(alpha: 0.25)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.lock_rounded, color: Color(0xFF00D4AA), size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text('PipLock detects and blocks all four before they cost you.',
                      style: GoogleFonts.manrope(
                        color: AppColors.textPrimary, fontSize: 13, height: 1.4))),
                  ]),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SLIDE 7 — Discipline Edge (before vs after)
// ══════════════════════════════════════════════════════════════════════════════
class _DisciplineEdge extends StatefulWidget {
  final bool isActive;
  const _DisciplineEdge({required this.isActive});
  @override State<_DisciplineEdge> createState() => _DisciplineEdgeState();
}

class _DisciplineEdgeState extends State<_DisciplineEdge>
    with TickerProviderStateMixin {
  late AnimationController _headerCtrl;
  late AnimationController _beforeCtrl;
  late AnimationController _afterCtrl;
  late AnimationController _arrowCtrl;
  late Animation<double> _headerAnim;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _headerAnim = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _beforeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _arrowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _afterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    if (widget.isActive) _start();
  }

  void _start() {
    _headerCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _beforeCtrl.forward(from: 0);
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _arrowCtrl.forward(from: 0);
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _afterCtrl.forward(from: 0);
    });
  }

  @override
  void didUpdateWidget(_DisciplineEdge old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _start();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _beforeCtrl.dispose();
    _arrowCtrl.dispose();
    _afterCtrl.dispose();
    super.dispose();
  }

  Widget _scenario({
    required String label,
    required Color labelColor,
    required Color borderColor,
    required Color bgColor,
    required List<(IconData, String, Color)> steps,
    required AnimationController ctrl,
  }) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = CurvedAnimation(parent: ctrl, curve: Curves.easeOut).value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - t)),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: labelColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(label,
                      style: GoogleFonts.manrope(
                        color: labelColor, fontSize: 11, fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
                  ),
                  const SizedBox(height: 10),
                  ...steps.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Icon(s.$1, color: s.$3, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(s.$2,
                        style: GoogleFonts.manrope(
                          color: AppColors.textPrimary, fontSize: 13, height: 1.35))),
                    ]),
                  )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          FadeTransition(
            opacity: _headerAnim,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
                  .animate(_headerAnim),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D4AA).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF00D4AA).withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.compare_arrows_rounded,
                        color: Color(0xFF00D4AA), size: 28),
                  ),
                  const SizedBox(height: 20),
                  Text('Your edge isn\'t the setup.\nIt\'s the discipline.',
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary, fontSize: 30,
                      fontWeight: FontWeight.w900, letterSpacing: -1.2, height: 1.1)),
                  const SizedBox(height: 8),
                  Text('See exactly what changes when PipLock is in your corner.',
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary, fontSize: 14, height: 1.45)),
                  const SizedBox(height: 22),
                ],
              ),
            ),
          ),
          _scenario(
            label: 'WITHOUT PIPLOCK',
            labelColor: const Color(0xFFFF3B30),
            borderColor: const Color(0xFFFF3B30).withValues(alpha: 0.25),
            bgColor: const Color(0xFFFF3B30).withValues(alpha: 0.05),
            steps: [
              (Icons.sentiment_dissatisfied_rounded, 'Bad day → impulse revenge trade', const Color(0xFFFF3B30)),
              (Icons.trending_down_rounded, 'Exceeded daily loss limit', const Color(0xFFFF6B35)),
              (Icons.cancel_rounded, 'Challenge failed. Start over.', const Color(0xFFFF3B30)),
            ],
            ctrl: _beforeCtrl,
          ),
          AnimatedBuilder(
            animation: _arrowCtrl,
            builder: (_, __) {
              final t = CurvedAnimation(parent: _arrowCtrl, curve: Curves.easeOut).value;
              return Opacity(
                opacity: t,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D4AA).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF00D4AA).withValues(alpha: 0.3)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.lock_rounded, color: Color(0xFF00D4AA), size: 14),
                            const SizedBox(width: 6),
                            Text('PipLock activates',
                              style: GoogleFonts.manrope(
                                color: const Color(0xFF00D4AA), fontSize: 12,
                                fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          _scenario(
            label: 'WITH PIPLOCK',
            labelColor: const Color(0xFF00D4AA),
            borderColor: const Color(0xFF00D4AA).withValues(alpha: 0.3),
            bgColor: const Color(0xFF00D4AA).withValues(alpha: 0.05),
            steps: [
              (Icons.sentiment_dissatisfied_rounded, 'Bad day → limit reached', const Color(0xFFFFBD2E)),
              (Icons.lock_rounded, 'Killswitch activates. Breathing exercise.', const Color(0xFF00D4AA)),
              (Icons.emoji_events_rounded, 'Capital protected. Challenge on track.', const Color(0xFF00D4AA)),
            ],
            ctrl: _afterCtrl,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN 7 — Platform selection (cards stagger in, 5 options)
// ══════════════════════════════════════════════════════════════════════════════
class _PlatformSlide extends StatefulWidget {
  final bool isActive;
  final String? selected;
  final ValueChanged<String> onSelected;
  const _PlatformSlide({required this.isActive, required this.selected, required this.onSelected});
  @override State<_PlatformSlide> createState() => _PlatformSlideState();
}

class _PlatformSlideState extends State<_PlatformSlide>
    with TickerProviderStateMixin {
  late List<AnimationController> _cardCtrls;
  late AnimationController _headerCtrl;
  late Animation<double> _headerAnim;

  @override
  void initState() {
    super.initState();
    _cardCtrls = List.generate(5, (_) => AnimationController(
      vsync: this, duration: const Duration(milliseconds: 350)));
    _headerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _headerAnim = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    if (widget.isActive) _start();
  }

  void _start() {
    _headerCtrl.forward(from: 0);
    for (var i = 0; i < 5; i++) {
      Future.delayed(Duration(milliseconds: 150 + i * 100), () {
        if (mounted) _cardCtrls[i].forward(from: 0);
      });
    }
  }

  @override
  void didUpdateWidget(_PlatformSlide old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _start();
  }

  @override
  void dispose() {
    for (final c in _cardCtrls) c.dispose();
    _headerCtrl.dispose();
    super.dispose();
  }

  Widget _card(int idx, IconData icon, String title, String desc,
      String value, Color color) {
    final isSelected = widget.selected == value;
    return AnimatedBuilder(
      animation: _cardCtrls[idx],
      builder: (_, child) {
        final t = CurvedAnimation(parent: _cardCtrls[idx], curve: Curves.easeOut).value;
        return Opacity(opacity: t,
          child: Transform.translate(offset: Offset(0, 20 * (1 - t)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              transform: Matrix4.identity()..scale(isSelected ? 1.02 : 1.0),
              child: child,
            )));
      },
      child: _PlatformCard(
        icon: icon, title: title, description: desc,
        value: value, selected: widget.selected,
        color: color, onTap: widget.onSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          FadeTransition(
            opacity: _headerAnim,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
                  .animate(_headerAnim),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: AppTheme.bXl,
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(Icons.devices_rounded, color: AppColors.accent, size: 28),
                  ),
                  const SizedBox(height: AppTheme.sp20),
                  Text('Which platforms do\nyou trade on?',
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary, fontSize: 36,
                      fontWeight: FontWeight.w900, letterSpacing: -2, height: 1.05)),
                  const SizedBox(height: 8),
                  Text('Tailor your active risk shield to your current broker setup.',
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary, fontSize: 15, height: 1.4)),
                  const SizedBox(height: AppTheme.sp20),
                ],
              ),
            ),
          ),
          _card(0, Icons.computer_rounded, 'MT5 / MT4 — Desktop or VPS',
            'Best: EA integration reads live account data directly.',
            'mt5_desktop', AppColors.accent),
          const SizedBox(height: 10),
          _card(1, Icons.smartphone_rounded, 'MT5 / MT4 — Mobile',
            'Accessibility Service monitors the broker app on your phone.',
            'mt5_mobile', AppColors.accent),
          const SizedBox(height: 10),
          _card(2, Icons.military_tech_rounded, 'FTMO / FundedNext',
            'Prop firm challenge accounts — EA + killswitch integration.',
            'ftmo', AppColors.warning),
          const SizedBox(height: 10),
          _card(3, Icons.candlestick_chart_outlined, 'IC Markets / cTrader',
            'Mobile monitoring via Accessibility Service.',
            'ctrader', AppColors.accent),
          const SizedBox(height: 10),
          _card(4, Icons.help_outline_rounded, 'Other / Multiple',
            'Manual tracking — set limits and log trades in the app.',
            'other', AppColors.textSecondary),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SLIDE 7 — Benefits (everything you get with Pro)
// ══════════════════════════════════════════════════════════════════════════════
class _BenefitsSlide extends StatefulWidget {
  final bool isActive;
  const _BenefitsSlide({required this.isActive});
  @override State<_BenefitsSlide> createState() => _BenefitsSlideState();
}

class _BenefitsSlideState extends State<_BenefitsSlide>
    with TickerProviderStateMixin {
  late AnimationController _headerCtrl;
  late List<AnimationController> _itemCtrls;
  late Animation<double> _headerAnim;

  static const _items = [
    (Icons.lock_rounded, 'Hard Killswitch', 'Full-screen lock when you break your rules. No way around it.', Color(0xFFFF3B30)),
    (Icons.auto_awesome_rounded, 'AI Challenge Planner', 'Personalized day-by-day plan with estimated success %.', Color(0xFF00C896)),
    (Icons.warning_amber_rounded, 'FOMO Gatekeeper', 'Real-time alert before you chase a move you already missed.', Color(0xFFFFBD2E)),
    (Icons.notifications_active_rounded, 'News & Session Alerts', 'NFP, CPI, Fed decisions — notified before they hit.', Color(0xFF4A90E2)),
    (Icons.bar_chart_rounded, 'MT5 Live Integration', 'EA reads your real equity and drawdown — no guessing.', Color(0xFF00D4AA)),
    (Icons.self_improvement_rounded, '4-7-8 Breathing', 'Built-in cooldown exercise during your locked period.', Color(0xFF8B98AA)),
  ];

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _itemCtrls = List.generate(_items.length, (_) => AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300)));
    _headerAnim = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    if (widget.isActive) _start();
  }

  void _start() {
    _headerCtrl.forward(from: 0);
    for (var i = 0; i < _items.length; i++) {
      Future.delayed(Duration(milliseconds: 250 + i * 90), () {
        if (mounted) _itemCtrls[i].forward(from: 0);
      });
    }
  }

  @override
  void didUpdateWidget(_BenefitsSlide old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _start();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    for (final c in _itemCtrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          FadeTransition(
            opacity: _headerAnim,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
                  .animate(_headerAnim),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D4AA).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('PRO PLAN',
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF00D4AA), fontSize: 11,
                        fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                  ),
                  const SizedBox(height: 12),
                  Text('Everything you need\nto stay disciplined.',
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary, fontSize: 30,
                      fontWeight: FontWeight.w900, letterSpacing: -1.2, height: 1.1)),
                  const SizedBox(height: 6),
                  Text('Six tools, one goal: protect your capital.',
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(_items.length, (i) {
            final (icon, title, desc, color) = _items[i];
            return Padding(
              padding: EdgeInsets.only(bottom: i < _items.length - 1 ? 10 : 0),
              child: AnimatedBuilder(
                animation: _itemCtrls[i],
                builder: (_, child) {
                  final t = CurvedAnimation(parent: _itemCtrls[i], curve: Curves.easeOut).value;
                  return Opacity(
                    opacity: t,
                    child: Transform.translate(offset: Offset(20 * (1 - t), 0), child: child),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10)),
                        child: Icon(icon, color: color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: GoogleFonts.manrope(
                              color: AppColors.textPrimary, fontSize: 13,
                              fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(desc, style: GoogleFonts.manrope(
                              color: AppColors.textSecondary, fontSize: 11,
                              height: 1.4)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.check_circle_rounded,
                        color: color.withValues(alpha: 0.7), size: 18),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SLIDE 8 — Savings Calculator
// ══════════════════════════════════════════════════════════════════════════════
class _SavingsSlide extends StatefulWidget {
  final bool isActive;
  const _SavingsSlide({required this.isActive});
  @override State<_SavingsSlide> createState() => _SavingsSlideState();
}

class _SavingsSlideState extends State<_SavingsSlide>
    with TickerProviderStateMixin {
  late AnimationController _headerCtrl;
  late AnimationController _counterCtrl;
  late AnimationController _cardsCtrl;
  late Animation<double> _headerAnim;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _counterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _cardsCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _headerAnim = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    if (widget.isActive) _start();
  }

  void _start() {
    _headerCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _counterCtrl.forward(from: 0);
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _cardsCtrl.forward(from: 0);
    });
  }

  @override
  void didUpdateWidget(_SavingsSlide old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _start();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _counterCtrl.dispose();
    _cardsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          FadeTransition(
            opacity: _headerAnim,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
                  .animate(_headerAnim),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1 emotional mistake\ncosts \$1,500.',
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary, fontSize: 30,
                      fontWeight: FontWeight.w900, letterSpacing: -1.2, height: 1.1)),
                  const SizedBox(height: 8),
                  Text('PipLock Pro prevents it for less than you think.',
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _counterCtrl,
            builder: (_, __) {
              final t = CurvedAnimation(parent: _counterCtrl, curve: Curves.easeOut).value;
              final savedVal = (t * 1500).toInt();
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.success.withValues(alpha: 0.12),
                      AppColors.success.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Average loss prevented per mistake',
                      style: GoogleFonts.manrope(
                        color: AppColors.textTertiary, fontSize: 11,
                        fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Text('\$$savedVal',
                      style: GoogleFonts.manrope(
                        color: AppColors.success, fontSize: 40,
                        fontWeight: FontWeight.w900, letterSpacing: -1.5)),
                    const SizedBox(height: 4),
                    Text('PipLock stops you before it happens.',
                      style: GoogleFonts.manrope(
                        color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _cardsCtrl,
            builder: (_, child) {
              final t = CurvedAnimation(parent: _cardsCtrl, curve: Curves.easeOut).value;
              return Opacity(opacity: t,
                child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child));
            },
            child: Row(
              children: [
                Expanded(child: _CostCard(
                  label: 'Per day',
                  value: '€0.66',
                  sub: 'Less than a coffee',
                  color: const Color(0xFF4A90E2),
                )),
                const SizedBox(width: 10),
                Expanded(child: _CostCard(
                  label: 'Per month',
                  value: '€19.99',
                  sub: 'Cancel anytime',
                  color: const Color(0xFFFFBD2E),
                )),
                const SizedBox(width: 10),
                Expanded(child: _CostCard(
                  label: 'Per year',
                  value: '€199',
                  sub: 'Best value',
                  color: const Color(0xFF00D4AA),
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded, color: AppColors.accent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '7-day free trial · No charge today · Cancel anytime from Google Play',
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _CostCard extends StatelessWidget {
  final String label, value, sub;
  final Color color;
  const _CostCard({required this.label, required this.value,
    required this.sub, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.manrope(
            color: AppColors.textTertiary, fontSize: 10,
            fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.manrope(
            color: color, fontSize: 16,
            fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(sub, style: GoogleFonts.manrope(
            color: AppColors.textTertiary, fontSize: 9, height: 1.3)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SLIDE 10 — Paywall (energy fusion display + features stagger)
// ══════════════════════════════════════════════════════════════════════════════
class _PaywallSlide extends StatefulWidget {
  final bool isActive;
  final VoidCallback onSkip;
  const _PaywallSlide({required this.isActive, required this.onSkip});
  @override State<_PaywallSlide> createState() => _PaywallSlideState();
}

class _PaywallSlideState extends State<_PaywallSlide>
    with TickerProviderStateMixin {
  late AnimationController _arcCtrl;
  late AnimationController _headerCtrl;
  late List<AnimationController> _featureCtrls;
  late Animation<double> _headerAnim;

  static const _features = [
    (Icons.lock_rounded, 'Hard Killswitch + Overlay on broker app', AppColors.danger),
    (Icons.auto_awesome_rounded, 'AI Challenge Planner — unlimited', AppColors.accent),
    (Icons.warning_amber_rounded, 'FOMO Gatekeeper real-time alerts', AppColors.warning),
    (Icons.notifications_active_rounded, 'News & session notifications', AppColors.silverBright),
    (Icons.bar_chart_rounded, 'MT5 EA Integration', AppColors.success),
  ];

  @override
  void initState() {
    super.initState();
    _arcCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _headerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _featureCtrls = List.generate(5, (_) => AnimationController(
      vsync: this, duration: const Duration(milliseconds: 350)));
    _headerAnim = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    if (widget.isActive) _start();
  }

  void _start() {
    _headerCtrl.forward(from: 0);
    for (var i = 0; i < 5; i++) {
      Future.delayed(Duration(milliseconds: 300 + i * 120), () {
        if (mounted) _featureCtrls[i].forward(from: 0);
      });
    }
  }

  @override
  void didUpdateWidget(_PaywallSlide old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _start();
  }

  @override
  void dispose() {
    _arcCtrl.dispose(); _headerCtrl.dispose();
    for (final c in _featureCtrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Energy fusion display
          AnimatedBuilder(
            animation: _arcCtrl,
            builder: (_, __) => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A1F6E), Color(0xFF1C2038)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Stack(
                children: [
                  // Arcs
                  SizedBox(
                    height: 80,
                    child: CustomPaint(
                      size: const Size(double.infinity, 80),
                      painter: _EnergyArcPainter(progress: _arcCtrl.value),
                    ),
                  ),
                  // Text overlay
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.success,
                            boxShadow: [BoxShadow(
                              color: AppColors.success.withValues(alpha: 0.6),
                              blurRadius: 8, spreadRadius: 1)],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('7-Day Free Trial Enabled',
                          style: GoogleFonts.manrope(
                            color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Today', style: GoogleFonts.manrope(
                                  color: AppColors.textTertiary, fontSize: 11)),
                                Text('\$0.00', style: GoogleFonts.manrope(
                                  color: AppColors.textPrimary, fontSize: 22,
                                  fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_rounded,
                            color: AppColors.textTertiary, size: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('In 7 Days', style: GoogleFonts.manrope(
                                  color: AppColors.textTertiary, fontSize: 11)),
                                Text('\$19.99/mo', style: GoogleFonts.manrope(
                                  color: AppColors.silverBright, fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.sp20),
          FadeTransition(
            opacity: _headerAnim,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
                  .animate(_headerAnim),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Protect your account\nfor less than a single Stop Loss.',
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary, fontSize: 30,
                      fontWeight: FontWeight.w900, letterSpacing: -1.5, height: 1.1)),
                  const SizedBox(height: 8),
                  Text('Start your 7-day free trial. No charge today.',
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
                  const SizedBox(height: 4),
                  Text('€9.99/month after trial — cancel anytime',
                    style: GoogleFonts.manrope(
                      color: AppColors.textTertiary, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.sp20),
          ...List.generate(_features.length, (i) {
            final (icon, label, color) = _features[i];
            return Padding(
              padding: EdgeInsets.only(bottom: i < _features.length - 1 ? 10 : 0),
              child: AnimatedBuilder(
                animation: _featureCtrls[i],
                builder: (_, child) {
                  final t = CurvedAnimation(parent: _featureCtrls[i], curve: Curves.easeOut).value;
                  return Opacity(opacity: t,
                    child: Transform.translate(offset: Offset(16 * (1 - t), 0), child: child));
                },
                child: _ProFeature(icon: icon, text: label, color: color),
              ),
            );
          }),
          const SizedBox(height: AppTheme.sp20),
          GestureDetector(
            onTap: widget.onSkip,
            child: Center(child: Text('Continue with free plan →',
              style: GoogleFonts.manrope(
                color: AppColors.textTertiary, fontSize: 13, fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.textTertiary))),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _ChatBubble extends StatelessWidget {
  final bool isAI;
  final String text;
  final Color color;
  const _ChatBubble({required this.isAI, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isAI ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.70),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: isAI ? const Radius.circular(4) : const Radius.circular(14),
            bottomRight: isAI ? const Radius.circular(14) : const Radius.circular(4),
          ),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Text(text,
          style: GoogleFonts.manrope(color: AppColors.textPrimary, fontSize: 12, height: 1.5)),
      ),
    );
  }
}

class _PlatformCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String value;
  final String? selected;
  final Color color;
  final ValueChanged<String> onTap;

  const _PlatformCard({required this.icon, required this.title,
    required this.description, required this.value,
    required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: AppTheme.dMedium, curve: AppTheme.cSpring,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.10) : AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isSelected ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.manrope(
                    color: isSelected ? color : AppColors.textPrimary,
                    fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(description, style: GoogleFonts.manrope(
                    color: AppColors.textTertiary, fontSize: 11, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: AppTheme.dFast,
              child: isSelected
                  ? Icon(Icons.check_circle_rounded, color: color, size: 20, key: const ValueKey(true))
                  : Icon(Icons.radio_button_unchecked, color: AppColors.textTertiary, size: 20, key: const ValueKey(false)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  final String quote, name, tag;
  final Color color;
  const _TestimonialCard({required this.quote, required this.name,
    required this.tag, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(quote, style: GoogleFonts.manrope(
            color: AppColors.textSecondary, fontSize: 13,
            fontStyle: FontStyle.italic, height: 1.5)),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6)),
                child: Text(tag, style: GoogleFonts.manrope(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Text(name, style: GoogleFonts.manrope(
                color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProFeature extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _ProFeature({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: GoogleFonts.manrope(
          color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500))),
        const SizedBox(width: 8),
        const Icon(Icons.check_rounded, color: AppColors.accent, size: 16),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _StatRow({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: GoogleFonts.manrope(
          color: AppColors.textSecondary, fontSize: 13, height: 1.4))),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int current, total;
  final Color color;
  const _ProgressBar({required this.current, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: (current + 1) / total,
        backgroundColor: AppColors.divider,
        valueColor: AlwaysStoppedAnimation(color),
        minHeight: 2,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PARTICLE PAINTER
// ══════════════════════════════════════════════════════════════════════════════
class _ParticlePainter extends CustomPainter {
  final double progress;
  final Color color;
  static final List<_Particle> _particles = List.generate(28, (i) => _Particle(
    x: i * 37.3 % 1.0, y: i * 61.7 % 1.0,
    radius: 1.0 + (i % 3) * 0.8,
    speed: 0.015 + (i % 5) * 0.004,
    phase: i * 0.45,
  ));

  const _ParticlePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final t = (progress * p.speed * 10 + p.phase) % 1.0;
      final opacity = (math.sin(t * math.pi * 2) * 0.5 + 0.5) * 0.18;
      final y = (p.y + progress * p.speed) % 1.0;
      canvas.drawCircle(Offset(p.x * size.width, y * size.height), p.radius,
        Paint()..color = color.withValues(alpha: opacity));
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress || old.color != color;
}

class _Particle {
  final double x, y, radius, speed, phase;
  const _Particle({required this.x, required this.y,
    required this.radius, required this.speed, required this.phase});
}

// ══════════════════════════════════════════════════════════════════════════════
// CUSTOM PAINTERS — new slides
// ══════════════════════════════════════════════════════════════════════════════

/// Screen 1: Candle vortex that explodes into particles
class _CandleVortexPainter extends CustomPainter {
  final double loopValue;
  final double explodeValue;
  const _CandleVortexPainter({required this.loopValue, required this.explodeValue});

  static const int _count = 8;
  static const double _radius = 60.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final isExploding = explodeValue > 0.0;
    final preBurst = explodeValue < 0.6;

    for (var i = 0; i < _count; i++) {
      final baseAngle = (i / _count) * 2 * math.pi;
      final angle = baseAngle + loopValue * 2 * math.pi;
      final isGreen = i % 2 == 0;
      final bodyColor = isGreen
          ? AppColors.success.withValues(alpha: isExploding ? (1 - explodeValue).clamp(0, 1) * 0.9 : 0.9)
          : AppColors.danger.withValues(alpha: isExploding ? (1 - explodeValue).clamp(0, 1) * 0.9 : 0.9);

      double dist = _radius;
      double scl = 1.0;
      if (isExploding && !preBurst) {
        final burst = ((explodeValue - 0.6) / 0.4).clamp(0.0, 1.0);
        dist = _radius + burst * 80;
        scl = 1.0 - burst * 0.8;
      }

      final pos = center + Offset(math.cos(angle) * dist, math.sin(angle) * dist);

      // Body
      final bodyWidth = 8.0 * scl;
      final bodyHeight = 20.0 * scl;
      final bodyRect = Rect.fromCenter(center: pos, width: bodyWidth, height: bodyHeight);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle + math.pi / 2);
      canvas.translate(-pos.dx, -pos.dy);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bodyRect, Radius.circular(2 * scl)),
        Paint()..color = bodyColor,
      );
      // Wick
      final wickPaint = Paint()
        ..color = AppColors.silver.withValues(alpha: isExploding ? (1 - explodeValue) * 0.6 : 0.6)
        ..strokeWidth = 1.5 * scl
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(pos.dx, pos.dy - bodyHeight / 2),
        Offset(pos.dx, pos.dy - bodyHeight / 2 - 8 * scl),
        wickPaint,
      );
      canvas.drawLine(
        Offset(pos.dx, pos.dy + bodyHeight / 2),
        Offset(pos.dx, pos.dy + bodyHeight / 2 + 5 * scl),
        wickPaint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CandleVortexPainter old) =>
      old.loopValue != loopValue || old.explodeValue != explodeValue;
}

/// Screen 3: Shockwave expanding rings
class _ShockwavePainter extends CustomPainter {
  final double progress;
  const _ShockwavePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 3; i++) {
      final delay = i * 0.25;
      final t = ((progress - delay) * (1 / 0.75)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final ringRadius = 60.0 + t * 100.0;
      final opacity = (1 - t) * 0.5;
      canvas.drawCircle(
        center, ringRadius,
        Paint()
          ..color = AppColors.silverBright.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_ShockwavePainter old) => old.progress != progress;
}

/// Screen 5: Neural map with nodes and progressive connection lines
class _NeuralMapPainter extends CustomPainter {
  final double progress;
  const _NeuralMapPainter({required this.progress});

  static const _nodeLabels = ['daily loss', 'MT5', 'equity', 'killswitch', 'rule', 'account'];
  static const _positions = [
    Offset(0.12, 0.5),
    Offset(0.30, 0.15),
    Offset(0.30, 0.85),
    Offset(0.88, 0.5),
    Offset(0.70, 0.15),
    Offset(0.70, 0.85),
  ];
  static const _centralIdx = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);

    // Draw connections
    for (var i = 0; i < _positions.length; i++) {
      if (i == _centralIdx) continue;
      final connProgress = (progress * _positions.length - i).clamp(0.0, 1.0);
      if (connProgress <= 0) continue;
      final from = Offset(_positions[i].dx * size.width, _positions[i].dy * size.height);
      final linePaint = Paint()
        ..color = AppColors.accent.withValues(alpha: 0.3 * connProgress)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      final dx = center.dx - from.dx;
      final dy = center.dy - from.dy;
      canvas.drawLine(from, Offset(from.dx + dx * connProgress, from.dy + dy * connProgress), linePaint);
    }

    // Draw satellite nodes
    for (var i = 0; i < _positions.length; i++) {
      if (i == _centralIdx) continue;
      final nodeProgress = ((progress * _positions.length) - i).clamp(0.0, 1.0);
      if (nodeProgress <= 0) continue;
      final pos = Offset(_positions[i].dx * size.width, _positions[i].dy * size.height);
      final glowColor = nodeProgress > 0.8 ? AppColors.success : AppColors.accent;
      canvas.drawCircle(pos, 6, Paint()
        ..color = glowColor.withValues(alpha: nodeProgress * 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawCircle(pos, 5, Paint()
        ..color = AppColors.cardBg);
      canvas.drawCircle(pos, 5, Paint()
        ..color = glowColor.withValues(alpha: nodeProgress * 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);

      final tp = TextPainter(
        text: TextSpan(
          text: _nodeLabels[i],
          style: GoogleFonts.manrope(
            color: AppColors.textTertiary.withValues(alpha: nodeProgress),
            fontSize: 9, fontWeight: FontWeight.w500),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy + 8));
    }

    // Central AI node (accent, larger, glow)
    final centralProgress = progress.clamp(0.0, 1.0);
    canvas.drawCircle(center, 18, Paint()
      ..color = AppColors.accent.withValues(alpha: 0.25 * centralProgress)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    canvas.drawCircle(center, 14, Paint()..color = AppColors.cardBg);
    canvas.drawCircle(center, 14, Paint()
      ..color = AppColors.accent.withValues(alpha: centralProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    final lock = TextPainter(
      text: TextSpan(text: '🔒', style: const TextStyle(fontSize: 12)),
      textDirection: TextDirection.ltr,
    )..layout();
    lock.paint(canvas, Offset(center.dx - lock.width / 2, center.dy - lock.height / 2));
  }

  @override
  bool shouldRepaint(_NeuralMapPainter old) => old.progress != progress;
}

/// Screen 6: Constellation of dots connected by lines, pulsing
class _ConstellationPainter extends CustomPainter {
  final double progress;
  const _ConstellationPainter({required this.progress});

  static final List<Offset> _nodes = List.generate(12, (i) => Offset(
    (i * 73.1 + 10) % 100 / 100,
    (i * 47.3 + 15) % 100 / 100,
  ));

  static final List<(int, int)> _edges = [
    (0, 3), (1, 4), (2, 5), (3, 6), (4, 7), (5, 8),
    (6, 9), (7, 10), (8, 11), (0, 6), (1, 7), (2, 8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Draw edges
    for (final (a, b) in _edges) {
      final pa = Offset(_nodes[a].dx * size.width, _nodes[a].dy * size.height);
      final pb = Offset(_nodes[b].dx * size.width, _nodes[b].dy * size.height);
      final pulsed = (math.sin(progress * 2 * math.pi + a) * 0.5 + 0.5) * 0.2;
      canvas.drawLine(pa, pb, Paint()
        ..color = AppColors.silverBright.withValues(alpha: 0.08 + pulsed)
        ..strokeWidth = 0.8);
    }

    // Draw nodes
    for (var i = 0; i < _nodes.length; i++) {
      final pos = Offset(_nodes[i].dx * size.width, _nodes[i].dy * size.height);
      final pulsed = (math.sin(progress * 2 * math.pi + i * 0.5) * 0.5 + 0.5);
      final r = 2.0 + pulsed * 1.5;
      canvas.drawCircle(pos, r + 4, Paint()
        ..color = AppColors.silverBright.withValues(alpha: pulsed * 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawCircle(pos, r, Paint()
        ..color = AppColors.silverBright.withValues(alpha: 0.5 + pulsed * 0.5));
    }
  }

  @override
  bool shouldRepaint(_ConstellationPainter old) => old.progress != progress;
}

/// Shield painter for Slide 5 (social proof) — animated protective shield visual
class _ShieldPainter extends CustomPainter {
  final double progress;
  const _ShieldPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final shieldH = size.height * 0.62;
    final shieldW = shieldH * 0.72;

    // Pulsing protective rings
    for (var i = 0; i < 3; i++) {
      final phase = i / 3;
      final t = ((progress * 1.2 + phase) % 1.0);
      final radius = shieldW * (0.8 + i * 0.35) + math.sin(t * 2 * math.pi) * 4;
      final alpha = (1.0 - t) * 0.22;
      canvas.drawCircle(
        Offset(cx, cy * 0.9),
        radius,
        Paint()
          ..color = const Color(0xFF00D4AA).withValues(alpha: alpha)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // Shield path
    final path = Path();
    final top = cy * 0.9 - shieldH * 0.48;
    final bottom = cy * 0.9 + shieldH * 0.52;
    final left = cx - shieldW / 2;
    final right = cx + shieldW / 2;
    path.moveTo(cx, top);
    path.cubicTo(right + shieldW * 0.08, top + shieldH * 0.08,
        right + shieldW * 0.06, top + shieldH * 0.5,
        cx, bottom);
    path.cubicTo(left - shieldW * 0.06, top + shieldH * 0.5,
        left - shieldW * 0.08, top + shieldH * 0.08,
        cx, top);
    path.close();

    // Shield glow
    canvas.drawPath(path, Paint()
      ..color = const Color(0xFF00D4AA).withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16));

    // Shield border
    final pulse = math.sin(progress * 2 * math.pi) * 0.5 + 0.5;
    canvas.drawPath(path, Paint()
      ..color = const Color(0xFF00D4AA).withValues(alpha: 0.55 + pulse * 0.25)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke);

    // Lock icon in center (simple: circle + rectangle)
    final lockCx = cx;
    final lockCy = cy * 0.9 + shieldH * 0.04;
    // Shackle arc
    canvas.drawArc(
      Rect.fromCenter(center: Offset(lockCx, lockCy - 8), width: 16, height: 16),
      math.pi, math.pi,
      false,
      Paint()
        ..color = const Color(0xFF00D4AA).withValues(alpha: 0.9)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(lockCx, lockCy + 5), width: 18, height: 14),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF00D4AA).withValues(alpha: 0.85),
    );

    // Blocked threat dots (4 positions)
    final threats = [
      Offset(left - 22, top + shieldH * 0.15),
      Offset(right + 20, top + shieldH * 0.25),
      Offset(left - 18, bottom - shieldH * 0.28),
      Offset(right + 16, bottom - shieldH * 0.38),
    ];
    for (var i = 0; i < threats.length; i++) {
      final blink = (math.sin(progress * 2 * math.pi + i * 1.5) * 0.5 + 0.5);
      canvas.drawCircle(threats[i], 6, Paint()
        ..color = const Color(0xFFFF3B30).withValues(alpha: 0.15 + blink * 0.1));
      final xPaint = Paint()
        ..color = const Color(0xFFFF3B30).withValues(alpha: 0.5 + blink * 0.4)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(threats[i] + const Offset(-3.5, -3.5),
          threats[i] + const Offset(3.5, 3.5), xPaint);
      canvas.drawLine(threats[i] + const Offset(3.5, -3.5),
          threats[i] + const Offset(-3.5, 3.5), xPaint);
    }
  }

  @override
  bool shouldRepaint(_ShieldPainter old) => old.progress != progress;
}

/// Screen 8: Energy arcs rotating around a center
class _EnergyArcPainter extends CustomPainter {
  final double progress;
  const _EnergyArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.82, size.height * 0.5);
    for (var i = 0; i < 3; i++) {
      final phase = i / 3;
      final t = (progress + phase) % 1.0;
      final radius = 18.0 + i * 12.0 + math.sin(t * 2 * math.pi) * 4;
      final opacity = (math.sin(t * math.pi) * 0.5 + 0.15).clamp(0.05, 0.55);
      final ringColor = i == 0
          ? AppColors.accent.withValues(alpha: opacity)
          : AppColors.silverBright.withValues(alpha: opacity * 0.6);
      canvas.drawCircle(
        center, radius,
        Paint()
          ..color = ringColor
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  @override
  bool shouldRepaint(_EnergyArcPainter old) => old.progress != progress;
}
