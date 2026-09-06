import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_theme.dart';

class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  const SkeletonLoader.text({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.borderRadius,
  });

  const SkeletonLoader.circle({
    super.key,
    required double size,
    this.borderRadius,
  })  : width = size,
        height = size;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius ?? AppTheme.bXs,
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value, 0),
            colors: const [
              AppColors.cardBg,
              AppColors.cardBg2,
              AppColors.border,
              AppColors.cardBg2,
              AppColors.cardBg,
            ],
            stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
          ),
        ),
      ),
    );
  }
}

/// A single pulsing grey box used to build skeleton loading states.
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = 8,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.25, end: 0.55).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _anim.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// A skeleton card that mimics a killswitch event row (for History screen).
class SkeletonEventCard extends StatelessWidget {
  const SkeletonEventCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111118),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          const SkeletonBox(width: 36, height: 36, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(height: 13, radius: 6),
                const SizedBox(height: 8),
                SkeletonBox(
                  width: MediaQuery.of(context).size.width * 0.35,
                  height: 10,
                  radius: 5,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const SkeletonBox(width: 48, height: 10, radius: 5),
        ],
      ),
    );
  }
}

/// A skeleton card that mimics a dashboard challenge/plan card.
class SkeletonDashCard extends StatelessWidget {
  const SkeletonDashCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111118),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonBox(width: 28, height: 28, radius: 8),
              const SizedBox(width: 10),
              const Expanded(child: SkeletonBox(height: 14, radius: 6)),
              const SizedBox(width: 40),
              const SkeletonBox(width: 50, height: 20, radius: 10),
            ],
          ),
          const SizedBox(height: 16),
          const SkeletonBox(height: 8, radius: 4),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(child: SkeletonBox(height: 48, radius: 10)),
              const SizedBox(width: 10),
              const Expanded(child: SkeletonBox(height: 48, radius: 10)),
              const SizedBox(width: 10),
              const Expanded(child: SkeletonBox(height: 48, radius: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card skeleton — usato mentre i dati caricano
class SkeletonCard extends StatelessWidget {
  final double height;
  const SkeletonCard({super.key, this.height = 120});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(AppTheme.sp16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: AppTheme.bLg,
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoader(width: 80, height: 10),
          SizedBox(height: AppTheme.sp12),
          SkeletonLoader(width: 140, height: 20),
          SizedBox(height: AppTheme.sp8),
          SkeletonLoader.text(),
          SizedBox(height: AppTheme.sp6),
          SkeletonLoader(width: 200, height: 10),
        ],
      ),
    );
  }
}
