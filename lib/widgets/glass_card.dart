import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_theme.dart';

/// Card glassmorphism con BackdropFilter reale (blur 12px).
/// Usa [useBlur]=false su device low-end o quando non è sopra a un gradiente.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;
  final bool useBlur;
  final double blurSigma;
  final double glassOpacity;
  final Color? glowColor;
  final Border? customBorder;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.useBlur = true,
    this.blurSigma = 12,
    this.glassOpacity = 0.06,
    this.glowColor,
    this.customBorder,
    this.boxShadow,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? AppTheme.bLg;

    final border = customBorder ??
        Border.all(
          color: glowColor != null
              ? glowColor!.withValues(alpha: 0.18)
              : AppColors.glassBorder,
          width: 1,
        );

    final shadows = boxShadow ??
        (glowColor != null
            ? [
                BoxShadow(
                  color: glowColor!.withValues(alpha: 0.12),
                  blurRadius: 20,
                  spreadRadius: -4,
                ),
                ...AppTheme.shadowMd,
              ]
            : AppTheme.shadowMd);

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: glassOpacity),
        borderRadius: br,
        border: border,
        boxShadow: shadows,
      ),
      child: child,
    );

    if (useBlur) {
      content = ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: content,
        ),
      );
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }

    return content;
  }
}

/// Solid card with premium shadow and subtle border — no blur needed.
class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? glowColor;
  final VoidCallback? onTap;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.backgroundColor,
    this.borderColor,
    this.glowColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.cardBg;
    final bc = borderColor ?? AppColors.border;
    final glow = glowColor;

    Widget card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: borderRadius,
        border: Border.all(color: bc, width: 1),
        boxShadow: [
          if (glow != null)
            BoxShadow(
              color: glow.withValues(alpha: 0.16),
              blurRadius: 24,
              spreadRadius: -4,
              offset: const Offset(0, 6),
            ),
          const BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}
