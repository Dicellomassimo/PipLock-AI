import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../widgets/ambient_blobs.dart';

class TradingHoursBlockScreen extends StatefulWidget {
  final TimeOfDay tradingStart;
  final TimeOfDay tradingEnd;

  const TradingHoursBlockScreen({
    super.key,
    required this.tradingStart,
    required this.tradingEnd,
  });

  @override
  State<TradingHoursBlockScreen> createState() =>
      _TradingHoursBlockScreenState();
}

class _TradingHoursBlockScreenState extends State<TradingHoursBlockScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateCountdown();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateCountdown();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _updateCountdown();
    }
  }

  void _updateCountdown() {
    setState(() => _remaining = _calcRemaining());
  }

  Duration _calcRemaining() {
    final now = DateTime.now();
    final startToday = DateTime(
      now.year, now.month, now.day,
      widget.tradingStart.hour, widget.tradingStart.minute,
    );
    DateTime nextOpen;
    if (now.isBefore(startToday)) {
      nextOpen = startToday;
    } else {
      nextOpen = startToday.add(const Duration(days: 1));
    }
    final diff = nextOpen.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  String _formatDuration(Duration d) {
    if (d <= Duration.zero) return '00:00:00';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _localNow() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final startStr = _formatTime(widget.tradingStart);
    final endStr   = _formatTime(widget.tradingEnd);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // Ambient silver blobs
            const Positioned.fill(child: IgnorePointer(child: AmbientBlobs())),
            // Radial silver blob center
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    width: 340,
                    height: 340,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.accent.withValues(alpha: 0.07),
                          Colors.transparent,
                        ],
                        radius: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Clock icon with silver glow
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent.withValues(alpha: 0.08),
                          boxShadow: AppColors.glowSilver(intensity: 1.2),
                        ),
                        child: const Icon(
                          Icons.schedule_rounded,
                          color: AppColors.accent,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Title
                      Text(
                        'Trading Chiuso\nTrading Closed',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          color: AppColors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Subtitle — configured hours
                      Text(
                        'Sei fuori orario · $startStr – $endStr',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 36),
                      // Countdown card
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 20),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.18),
                            width: 1,
                          ),
                          boxShadow: AppColors.glowSilver(),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'RIAPRE IN',
                              style: GoogleFonts.manrope(
                                color: AppColors.textTertiary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatDuration(_remaining),
                              style: GoogleFonts.robotoMono(
                                color: AppColors.accent,
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Current time row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Ora attuale: ',
                            style: GoogleFonts.manrope(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            _localNow(),
                            style: GoogleFonts.manrope(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '   ·   Riapertura: ',
                            style: GoogleFonts.manrope(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            startStr,
                            style: GoogleFonts.manrope(
                              color: AppColors.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),
                      // Bottom hint
                      Text(
                        'PipLock sta proteggendo la tua disciplina',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
