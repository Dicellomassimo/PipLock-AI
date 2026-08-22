import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Blob animati in background che si muovono lentamente (drift)
class AmbientBlobs extends StatefulWidget {
  final bool showViolet;
  final bool showSilver;
  final bool showDanger;

  const AmbientBlobs({
    super.key,
    this.showViolet = true,
    this.showSilver = true,
    this.showDanger = false,
  });

  @override
  State<AmbientBlobs> createState() => _AmbientBlobsState();
}

class _AmbientBlobsState extends State<AmbientBlobs>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        final sin1 = math.sin(t * 2 * math.pi);
        final cos1 = math.cos(t * 2 * math.pi);
        final sin2 = math.sin(t * 2 * math.pi + 2.1);
        return Stack(
          children: [
            if (widget.showViolet)
              Positioned(
                top: -80 + 30 * sin1,
                right: -80 + 20 * cos1,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.blobAccent(opacity: 0.09),
                  ),
                ),
              ),
            if (widget.showSilver)
              Positioned(
                bottom: -60 + 25 * sin2,
                left: -60 + 15 * cos1,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.blobSilver(opacity: 0.06),
                  ),
                ),
              ),
            if (widget.showDanger)
              Positioned(
                top: 100 + 20 * cos1,
                left: -40 + 10 * sin1,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.blobDanger(opacity: 0.07),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
