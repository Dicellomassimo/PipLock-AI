import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Background premium per pagine con dati storici (History, AI Planner).
/// Sostituisce le candele giapponesi con un pattern fintech minimale:
/// linee prezzo orizzontali + sottile gradiente silver.
class CandleBackground extends StatelessWidget {
  final Color accentColor;
  final double opacity;

  const CandleBackground({
    super.key,
    this.accentColor = AppColors.accent,
    this.opacity = 0.06,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _PriceGridPainter(accentColor: accentColor, opacity: opacity),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _PriceGridPainter extends CustomPainter {
  final Color accentColor;
  final double opacity;

  const _PriceGridPainter({required this.accentColor, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    // ── Glow angolo in alto a destra ────────────────────────────────────────
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accentColor.withValues(alpha: opacity * 0.8),
          Colors.transparent,
        ],
        radius: 0.65,
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 1.1, size.height * -0.1),
        radius: size.width * 0.75,
      ));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);

    // ── Linee prezzo orizzontali (6 livelli) ─────────────────────────────────
    final linePaint = Paint()
      ..strokeWidth = 0.5;

    const levels = 6;
    final step = size.height / (levels + 1);

    for (int i = 1; i <= levels; i++) {
      final y = step * i;
      // Le linee si affievoliscono verso il basso
      final alpha = opacity * (1.0 - (i / (levels + 1)) * 0.5);
      linePaint.color = accentColor.withValues(alpha: alpha * 0.5);

      // Linea tratteggiata manuale
      const dashWidth = 12.0;
      const dashGap = 8.0;
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, y),
          Offset((x + dashWidth).clamp(0, size.width), y),
          linePaint,
        );
        x += dashWidth + dashGap;
      }
    }

    // ── Linee verticali sottilissime (colonne temporali) ─────────────────────
    final colPaint = Paint()
      ..color = accentColor.withValues(alpha: opacity * 0.18)
      ..strokeWidth = 0.4;

    const cols = 5;
    final colStep = size.width / (cols + 1);
    for (int i = 1; i <= cols; i++) {
      final x = colStep * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), colPaint);
    }
  }

  @override
  bool shouldRepaint(_PriceGridPainter old) =>
      old.accentColor != accentColor || old.opacity != opacity;
}
