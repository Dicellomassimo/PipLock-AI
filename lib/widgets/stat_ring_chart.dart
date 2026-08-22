import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class StatRingChart extends StatefulWidget {
  final double value; // 0.0 – 1.0
  final Color color;
  final double size;
  final double strokeWidth;
  final Widget? center;
  final bool animate;

  const StatRingChart({
    super.key,
    required this.value,
    required this.color,
    this.size = 64,
    this.strokeWidth = 5,
    this.center,
    this.animate = true,
  });

  @override
  State<StatRingChart> createState() => _StatRingChartState();
}

class _StatRingChartState extends State<StatRingChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  double get _safeValue {
    final v = widget.value;
    return (v.isNaN || v.isInfinite) ? 0.0 : v.clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = Tween<double>(begin: 0, end: _safeValue).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    if (widget.animate) _controller.forward();
  }

  @override
  void didUpdateWidget(StatRingChart old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _anim = Tween<double>(begin: _anim.value, end: _safeValue).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, child) => CustomPaint(
          painter: _RingPainter(
            value: _anim.value,
            color: widget.color,
            strokeWidth: widget.strokeWidth,
            trackColor: AppColors.divider,
          ),
          child: child,
        ),
        child: widget.center != null
            ? Center(child: widget.center)
            : null,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _RingPainter({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth / 2;
    const startAngle = -90 * (3.14159 / 180.0); // top

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );

    // Guard: NaN or non-positive value → nothing to draw
    if (value.isNaN || value.isInfinite || value <= 0) return;

    // Glow layer
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      value * 2 * 3.14159,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..strokeWidth = strokeWidth + 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Fill arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      value * 2 * 3.14159,
      false,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color;
}
