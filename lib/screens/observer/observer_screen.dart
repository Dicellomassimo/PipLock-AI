import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../config/app_theme.dart';
import '../../providers/observer_provider.dart';


class ObserverScreen extends ConsumerStatefulWidget {
  const ObserverScreen({super.key});

  @override
  ConsumerState<ObserverScreen> createState() => _ObserverScreenState();
}

class _ObserverScreenState extends ConsumerState<ObserverScreen> {
  Timer? _quoteTimer;
  Timer? _elapsedTimer;
  int _quoteIndex = 0;
  Duration _elapsed = Duration.zero;

  // Hold-to-exit
  bool _isHolding = false;
  double _holdProgress = 0.0;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _startQuoteRotation();
    _startElapsedTimer();
  }

  void _startQuoteRotation() {
    _quoteTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {
          _quoteIndex = _quoteIndex + 1;
        });
      }
    });
  }

  void _startElapsedTimer() {
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final startedAt = ref.read(observerProvider).startedAt;
      if (startedAt != null) {
        setState(() {
          _elapsed = DateTime.now().difference(startedAt);
        });
      }
    });

    // Inizializza subito
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final startedAt = ref.read(observerProvider).startedAt;
      if (startedAt != null && mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(startedAt);
        });
      }
    });
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    _elapsedTimer?.cancel();
    _holdTimer?.cancel();
    super.dispose();
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void _onHoldStart() {
    setState(() {
      _isHolding = true;
      _holdProgress = 0.0;
    });

    const steps = 20;
    int count = 0;
    _holdTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      count++;
      if (mounted) {
        setState(() => _holdProgress = count / steps);
      }
      if (count >= steps) {
        t.cancel();
        _exitObserverMode();
      }
    });
  }

  void _onHoldEnd() {
    _holdTimer?.cancel();
    if (mounted) {
      setState(() {
        _isHolding = false;
        _holdProgress = 0.0;
      });
    }
  }

  Future<void> _exitObserverMode() async {
    await ref.read(observerProvider.notifier).deactivate();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final observer = ref.watch(observerProvider);
    final quotes = s.observerQuotes;
    final quoteIndex = _quoteIndex % quotes.length;
    const blueColor = Color(0xFF4A90E2);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1628),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                // Header row with live dot
                Row(
                  children: [
                    // Live pulsing dot
                    _PulsingDot(color: blueColor),
                    const SizedBox(width: 8),
                    Text(
                      'LIVE · Observer Mode',
                      style: GoogleFonts.manrope(
                        color: blueColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    // Streak badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: blueColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: blueColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 5),
                          Text(
                            '${observer.consecutiveDays} days',
                            style: GoogleFonts.manrope(
                              color: blueColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Eye icon
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: blueColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: blueColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: blueColor.withValues(alpha: 0.2),
                        blurRadius: 32,
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.remove_red_eye_outlined,
                    color: blueColor,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  s.observerTitle,
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  s.observerSubtitle,
                  style: GoogleFonts.manrope(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Metrics grid 2x2
                Row(
                  children: [
                    Expanded(
                      child: _ObserverMetricCard(
                        icon: Icons.timer_outlined,
                        label: 'Elapsed',
                        value: _formatElapsed(_elapsed),
                        color: blueColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ObserverMetricCard(
                        icon: Icons.local_fire_department_rounded,
                        label: 'Clean days',
                        value: '${observer.consecutiveDays}',
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ObserverMetricCard(
                        icon: Icons.repeat_rounded,
                        label: 'Sessions today',
                        value: '${observer.sessionsToday}',
                        color: blueColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ObserverMetricCard(
                        icon: Icons.emoji_events_outlined,
                        label: 'Best streak',
                        value: '${observer.bestStreak}d',
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Motivational quote
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    key: ValueKey(_quoteIndex),
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: AppTheme.bLg,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '"',
                          style: GoogleFonts.manrope(
                            color: blueColor,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            height: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          quotes[quoteIndex],
                          style: GoogleFonts.manrope(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                            height: 1.6,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Exit button (hold-to-confirm)
                GestureDetector(
                  onLongPressStart: (_) => _onHoldStart(),
                  onLongPressEnd: (_) => _onHoldEnd(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: _isHolding ? 0.15 : 0.07),
                      borderRadius: AppTheme.bMd,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_isHolding)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: AppTheme.bMd,
                              child: LinearProgressIndicator(
                                value: _holdProgress,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                            ),
                          ),
                        Text(
                          _isHolding
                              ? s.observerReleaseToCancel
                              : s.observerHoldToExit,
                          style: GoogleFonts.manrope(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                Text(
                  s.observerHoldHint,
                  style: GoogleFonts.manrope(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Live pulsing dot ────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: _anim.value),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: _anim.value * 0.5),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Metric card ─────────────────────────────────────────────────────────────

class _ObserverMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ObserverMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: AppTheme.bMd,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.manrope(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
