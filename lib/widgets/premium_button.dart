import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../config/app_theme.dart';

enum PremiumButtonVariant { primary, danger, ghost, secondary }

class PremiumButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final PremiumButtonVariant variant;
  final bool loading;
  final bool fullWidth;
  final IconData? icon;
  final double? height;
  final double fontSize;
  final LinearGradient? gradient;

  const PremiumButton({
    super.key,
    required this.label,
    this.onTap,
    this.variant = PremiumButtonVariant.primary,
    this.loading = false,
    this.fullWidth = true,
    this.icon,
    this.height,
    this.fontSize = 15,
    this.gradient,
  });

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _glowAnim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _glowAnim = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  LinearGradient get _gradient {
    if (widget.gradient != null) return widget.gradient!;
    switch (widget.variant) {
      case PremiumButtonVariant.primary:
        return AppColors.accentGradient;
      case PremiumButtonVariant.danger:
        return const LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case PremiumButtonVariant.ghost:
      case PremiumButtonVariant.secondary:
        return const LinearGradient(
          colors: [AppColors.cardBg2, AppColors.cardBg2],
        );
    }
  }

  Color get _foreground {
    switch (widget.variant) {
      case PremiumButtonVariant.primary:
        return Colors.white;
      case PremiumButtonVariant.danger:
        return Colors.white;
      case PremiumButtonVariant.ghost:
        return AppColors.accent;
      case PremiumButtonVariant.secondary:
        return AppColors.textPrimary;
    }
  }

  List<BoxShadow> _buildShadow() {
    if (widget.variant == PremiumButtonVariant.ghost ||
        widget.variant == PremiumButtonVariant.secondary) {
      return [];
    }
    final color = widget.variant == PremiumButtonVariant.danger
        ? AppColors.danger
        : AppColors.accent;
    return [
      BoxShadow(
        color: color.withValues(alpha: (_pressed ? 0.15 : 0.30) * _glowAnim.value),
        blurRadius: _pressed ? 12 : 24,
        spreadRadius: -4,
        offset: const Offset(0, 6),
      ),
    ];
  }

  void _onTapDown(_) {
    if (widget.onTap == null || widget.loading) return;
    setState(() => _pressed = true);
    _controller.forward();
    HapticFeedback.lightImpact();
  }

  void _onTapUp(_) {
    _controller.reverse();
    setState(() => _pressed = false);
    widget.onTap?.call();
  }

  void _onTapCancel() {
    _controller.reverse();
    setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null && !widget.loading;

    return GestureDetector(
      onTapDown: enabled ? _onTapDown : null,
      onTapUp: enabled ? _onTapUp : null,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: AnimatedOpacity(
            duration: AppTheme.dFast,
            opacity: enabled ? 1.0 : 0.5,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: widget.height ?? 52,
              width: widget.fullWidth ? double.infinity : null,
              padding: widget.fullWidth
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                gradient: _gradient,
                borderRadius: AppTheme.bMd,
                border: widget.variant == PremiumButtonVariant.ghost
                    ? Border.all(color: AppColors.accent.withValues(alpha: 0.4))
                    : null,
                boxShadow: _buildShadow(),
              ),
              child: Center(
                child: widget.loading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: _foreground,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, color: _foreground, size: 18),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            widget.label,
                            style: GoogleFonts.manrope(
                              color: _foreground,
                              fontSize: widget.fontSize,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
