import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Background premium minimal — sostituisce i blob animati.
/// Effetto: vignetta argento negli angoli + sottile glow silver top-right.
/// Nessuna animazione: look fintech premium, non cheap.
class AmbientBlobs extends StatelessWidget {
  final bool showViolet; // mantenuto per compatibilità — ignorato
  final bool showSilver;
  final bool showDanger;

  const AmbientBlobs({
    super.key,
    this.showViolet = true,
    this.showSilver = true,
    this.showDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _PremiumBgPainter(showDanger: showDanger),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _PremiumBgPainter extends CustomPainter {
  final bool showDanger;
  const _PremiumBgPainter({this.showDanger = false});

  @override
  void paint(Canvas canvas, Size size) {
    // ── Glow silver in alto a destra ────────────────────────────────────────
    final topRightGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.accent.withValues(alpha: 0.055),
          Colors.transparent,
        ],
        radius: 0.7,
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 1.05, size.height * -0.05),
        radius: size.width * 0.7,
      ));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), topRightGlow);

    // ── Vignetta silver in basso a sinistra ──────────────────────────────────
    final bottomLeftGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.silver.withValues(alpha: 0.03),
          Colors.transparent,
        ],
        radius: 0.8,
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * -0.1, size.height * 1.1),
        radius: size.width * 0.65,
      ));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bottomLeftGlow);

    // ── Linee griglia orizzontali (stile trading terminal) ───────────────────
    final gridPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.022)
      ..strokeWidth = 0.5;

    const lines = 8;
    final step = size.height / lines;
    for (int i = 1; i < lines; i++) {
      final y = step * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // ── Glow danger (solo killswitch screen) ─────────────────────────────────
    if (showDanger) {
      final dangerGlow = Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.danger.withValues(alpha: 0.07),
            Colors.transparent,
          ],
          radius: 0.8,
        ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.5, 0),
          radius: size.width * 0.7,
        ));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), dangerGlow);
    }
  }

  @override
  bool shouldRepaint(_PremiumBgPainter old) => old.showDanger != showDanger;
}
