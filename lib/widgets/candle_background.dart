import 'dart:math';
import 'package:flutter/material.dart';

/// Decorative candlestick chart background.
/// Paints faint silver/white candles as ambient decoration.
/// [accentColor] tints the bullish candles — default is silver.
/// [opacity] controls overall transparency — keep between 0.04 and 0.10.
class CandleBackground extends StatelessWidget {
  final Color accentColor;
  final double opacity;

  const CandleBackground({
    super.key,
    this.accentColor = const Color(0xFFC4D0DC),
    this.opacity = 0.07,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _CandlePainter(accentColor: accentColor, opacity: opacity),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _CandlePainter extends CustomPainter {
  final Color accentColor;
  final double opacity;

  const _CandlePainter({required this.accentColor, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    // Fixed pseudo-random candle data — deterministic, no state needed
    final candles = _generateCandles(size);

    final bullPaint = Paint()
      ..color = accentColor.withValues(alpha: opacity)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.fill;

    final bearPaint = Paint()
      ..color = const Color(0xFF6B7A88).withValues(alpha: opacity * 0.7)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.fill;

    final wickPaint = Paint()
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (final c in candles) {
      final isBull = c.close >= c.open;
      final bodyPaint = isBull ? bullPaint : bearPaint;
      wickPaint.color = (isBull ? accentColor : const Color(0xFF6B7A88))
          .withValues(alpha: opacity * 0.6);

      final bodyTop = isBull ? c.close : c.open;
      final bodyBot = isBull ? c.open : c.close;
      final bodyH = (bodyTop - bodyBot).abs().clamp(2.0, double.infinity);

      // Body
      canvas.drawRect(
        Rect.fromLTWH(c.x - c.width / 2, bodyTop, c.width, bodyH),
        bodyPaint,
      );

      // Wick
      canvas.drawLine(
        Offset(c.x, c.high),
        Offset(c.x, bodyTop),
        wickPaint,
      );
      canvas.drawLine(
        Offset(c.x, bodyBot),
        Offset(c.x, c.low),
        wickPaint,
      );
    }
  }

  List<_Candle> _generateCandles(Size size) {
    // Place candles in the bottom-right quadrant, fading out to the left
    // like a real chart viewport
    const count = 24;
    final spacing = size.width / (count + 2);
    final candleWidth = (spacing * 0.55).clamp(4.0, 14.0);
    final baseY = size.height * 0.62; // chart "baseline" at 62% down
    final chartH = size.height * 0.38; // chart occupies bottom 38%

    // Pseudo-random heights using a simple deterministic sequence
    final List<_Candle> result = [];
    double price = 0.5; // normalized 0..1
    final deltas = [
      0.04, -0.02, 0.06, -0.03, 0.02, 0.08, -0.05, 0.03,
      -0.06, 0.05, 0.01, -0.04, 0.07, -0.02, 0.04, -0.01,
      0.06, -0.03, 0.08, -0.04, 0.03, 0.05, -0.02, 0.04,
    ];

    for (int i = 0; i < count; i++) {
      final x = spacing * (i + 1.5);
      final open = price;
      price = (price + deltas[i % deltas.length]).clamp(0.1, 0.9);
      final close = price;
      final hi = max(open, close) + 0.03 + (i % 3 == 0 ? 0.04 : 0.01);
      final lo = min(open, close) - 0.02 - (i % 4 == 0 ? 0.03 : 0.01);

      result.add(_Candle(
        x: x,
        width: candleWidth,
        open: baseY - open * chartH,
        close: baseY - close * chartH,
        high: baseY - hi.clamp(0.0, 1.0) * chartH,
        low: baseY - lo.clamp(0.0, 1.0) * chartH,
      ));
    }
    return result;
  }

  @override
  bool shouldRepaint(_CandlePainter old) =>
      old.accentColor != accentColor || old.opacity != opacity;
}

class _Candle {
  final double x, width, open, close, high, low;
  const _Candle({
    required this.x,
    required this.width,
    required this.open,
    required this.close,
    required this.high,
    required this.low,
  });
}
