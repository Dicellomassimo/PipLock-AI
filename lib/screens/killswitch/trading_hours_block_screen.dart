import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/ambient_blobs.dart';

class TradingHoursBlockScreen extends ConsumerStatefulWidget {
  final TimeOfDay tradingStart;
  final TimeOfDay tradingEnd;

  const TradingHoursBlockScreen({
    super.key,
    required this.tradingStart,
    required this.tradingEnd,
  });

  @override
  ConsumerState<TradingHoursBlockScreen> createState() =>
      _TradingHoursBlockScreenState();
}

class _TradingHoursBlockScreenState extends ConsumerState<TradingHoursBlockScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _isUnlocking = false;

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

  Future<void> _useToken() async {
    final s = ref.read(appStringsProvider);
    final userId = ref.read(currentUserIdProvider);
    if (userId.isEmpty || _isUnlocking) return;
    setState(() => _isUnlocking = true);
    try {
      final success = await SupabaseService.consumeToken(userId);
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(s.thBlockNoTokens,
                style: GoogleFonts.manrope(color: Colors.white)),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ));
        }
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('trading_hours_token_used', true);
      if (mounted) Navigator.of(context).pushReplacementNamed('/personal_rules');
    } catch (e) {
      debugPrint('[TradingHoursBlock] _useToken error: $e');
    } finally {
      if (mounted) setState(() => _isUnlocking = false);
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

  Widget _buildTokenSection(AppStrings s) {
    final tokens = ref.watch(authProvider).profile?.tokensAvailable ?? 0;

    if (tokens <= 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.key_off_rounded, color: AppColors.textTertiary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                s.thBlockNoTokens,
                style: GoogleFonts.manrope(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _isUnlocking ? null : _useToken,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: _isUnlocking
              ? AppColors.accent.withValues(alpha: 0.06)
              : AppColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: _isUnlocking ? 0.15 : 0.30),
            width: 1.5,
          ),
          boxShadow: _isUnlocking ? null : AppColors.glowSilver(intensity: 0.6),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _isUnlocking
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : const Icon(Icons.key_rounded, color: AppColors.accent, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.thBlockTokenUnlock,
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.thBlockTokenUnlockSub,
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.accent.withValues(alpha: 0.6),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
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
                        s.tradingHoursTitle,
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
                        s.tradingHoursSubtitle(startStr, endStr),
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
                              s.tradingHoursOpensIn,
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
                            '${s.tradingHoursCurrentTime} ',
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
                            '   ·   ${s.tradingHoursOpensAt} ',
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
                      const SizedBox(height: 36),
                      // ── Token unlock section ─────────────────────────────
                      _buildTokenSection(s),
                      const SizedBox(height: 32),
                      // Bottom hint
                      Text(
                        s.tradingHoursFooter,
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
