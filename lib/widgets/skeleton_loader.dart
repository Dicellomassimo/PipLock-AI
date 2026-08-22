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
