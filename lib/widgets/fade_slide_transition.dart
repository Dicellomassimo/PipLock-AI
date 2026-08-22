import 'package:flutter/material.dart';

/// Transizione pagina premium: fade + slide-up
class FadeSlideRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Offset begin;

  FadeSlideRoute({
    required this.page,
    this.begin = const Offset(0, 0.06),
    RouteSettings? settings,
  }) : super(
          settings: settings,
          pageBuilder: (_, __, ___) => page,
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          transitionsBuilder: (_, animation, __, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(begin: begin, end: Offset.zero)
                    .animate(curved),
                child: child,
              ),
            );
          },
        );
}
