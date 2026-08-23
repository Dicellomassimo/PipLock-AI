import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Divisore ultra-premium con fade ai bordi.
/// Firma Opal: non è una linea solida — sfuma dal centro.
class PremiumDivider extends StatelessWidget {
  final double height;
  final EdgeInsets? margin;
  final Color? color;

  const PremiumDivider({
    super.key,
    this.height = 0.5,
    this.margin,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              (color ?? AppColors.border).withValues(alpha: 0.8),
              (color ?? AppColors.border).withValues(alpha: 0.8),
              Colors.transparent,
            ],
            stops: const [0.0, 0.25, 0.75, 1.0],
          ),
        ),
      ),
    );
  }
}

/// Label badge con bordo shimmer — usata per badge "LIVE", "PRO", ecc.
class ShimmerBadge extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;

  const ShimmerBadge({
    super.key,
    required this.label,
    required this.color,
    this.fontSize = 9,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.30),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          height: 1.2,
        ),
      ),
    );
  }
}
