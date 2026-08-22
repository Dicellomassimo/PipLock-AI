import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_theme.dart';

/// Progress bar con entry animation e glow gradient.
class GlowProgressBar extends StatefulWidget {
  final double value; // 0.0 – 1.0
  final Color fillColor;
  final Color trackColor;
  final double height;
  final bool showGlow;
  final bool animate;
  final BorderRadius? borderRadius;

  const GlowProgressBar({
    super.key,
    required this.value,
    required this.fillColor,
    required this.trackColor,
    this.height = 6,
    this.showGlow = true,
    this.animate = true,
    this.borderRadius,
  });

  @override
  State<GlowProgressBar> createState() => _GlowProgressBarState();
}

class _GlowProgressBarState extends State<GlowProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = Tween<double>(begin: 0, end: widget.value.clamp(0.0, 1.0)).animate(
      CurvedAnimation(parent: _controller, curve: AppTheme.cSpring),
    );
    if (widget.animate) _controller.forward();
  }

  @override
  void didUpdateWidget(GlowProgressBar old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _anim = Tween<double>(
        begin: _anim.value,
        end: widget.value.clamp(0.0, 1.0),
      ).animate(CurvedAnimation(parent: _controller, curve: AppTheme.cSpring));
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
    final br = widget.borderRadius ?? BorderRadius.circular(widget.height);
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => LayoutBuilder(
        builder: (layoutContext, constraints) {
          final maxW = constraints.maxWidth;
          final fillW = (maxW * _anim.value).clamp(0.0, maxW);
          return Stack(
            children: [
              // Track
              Container(
                height: widget.height,
                decoration: BoxDecoration(
                  color: widget.trackColor,
                  borderRadius: br,
                ),
              ),
              // Fill
              if (fillW > 0)
                Container(
                  width: fillW,
                  height: widget.height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.fillColor.withValues(alpha: 0.8),
                        widget.fillColor,
                      ],
                    ),
                    borderRadius: br,
                    boxShadow: widget.showGlow
                        ? [
                            BoxShadow(
                              color: widget.fillColor.withValues(alpha: 0.50),
                              blurRadius: 8,
                              spreadRadius: -1,
                            ),
                          ]
                        : null,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Segmented progress bar — shows discrete steps with glow.
class SegmentedProgressBar extends StatelessWidget {
  final int total;
  final int filled;
  final Color fillColor;
  final Color trackColor;
  final double height;
  final double gap;

  const SegmentedProgressBar({
    super.key,
    required this.total,
    required this.filled,
    required this.fillColor,
    this.trackColor = AppColors.divider,
    this.height = 5,
    this.gap = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i < filled;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? gap : 0),
            height: height,
            decoration: BoxDecoration(
              color: active ? fillColor : trackColor,
              borderRadius: BorderRadius.circular(height / 2),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: fillColor.withValues(alpha: 0.45),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}
