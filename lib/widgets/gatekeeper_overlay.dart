import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../config/app_strings.dart';

class GatekeeperOverlay extends ConsumerStatefulWidget {
  final String? message;
  final VoidCallback? onStop;
  final VoidCallback? onProceed;

  const GatekeeperOverlay({
    super.key,
    this.message,
    this.onStop,
    this.onProceed,
  });

  static OverlayEntry show(
    BuildContext context, {
    String? message,
    VoidCallback? onStop,
    VoidCallback? onProceed,
  }) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => GatekeeperOverlay(
        message: message,
        onStop: () {
          entry.remove();
          onStop?.call();
        },
        onProceed: () {
          entry.remove();
          onProceed?.call();
        },
      ),
    );
    Overlay.of(context).insert(entry);
    return entry;
  }

  @override
  ConsumerState<GatekeeperOverlay> createState() => _GatekeeperOverlayState();
}

class _GatekeeperOverlayState extends ConsumerState<GatekeeperOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final displayMessage = widget.message ?? s.gatekeeperDefaultMessage;
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.black.withValues(alpha: 0.75),
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1030),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.fomo.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.fomo.withValues(alpha: 0.2),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.fomo.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.remove_red_eye_outlined,
                      color: AppColors.fomo,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    s.gatekeeperLabel,
                    style: GoogleFonts.manrope(
                      color: AppColors.fomo,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    displayMessage,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.gatekeeperQuestion,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onStop,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.fomo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        s.gatekeeperStop,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: widget.onProceed,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        s.gatekeeperProceed,
                        style: GoogleFonts.manrope(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
