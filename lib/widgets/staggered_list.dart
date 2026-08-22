import 'package:flutter/material.dart';

/// Wrappa una lista di widget animandoli in entrata con delay progressivo
class StaggeredList extends StatefulWidget {
  final List<Widget> children;
  final Duration itemDelay;
  final Duration itemDuration;
  final Offset slideBegin;

  const StaggeredList({
    super.key,
    required this.children,
    this.itemDelay = const Duration(milliseconds: 22),
    this.itemDuration = const Duration(milliseconds: 250),
    this.slideBegin = const Offset(0, 0.05),
  });

  @override
  State<StaggeredList> createState() => _StaggeredListState();
}

class _StaggeredListState extends State<StaggeredList>
    with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;
  late final List<Animation<double>> _fades;
  late final List<Animation<Offset>> _slides;

  @override
  void initState() {
    super.initState();
    _initControllers(widget.children.length);
    _startAnimations();
  }

  void _initControllers(int count) {
    _ctrls = List.generate(
      count,
      (i) => AnimationController(vsync: this, duration: widget.itemDuration),
    );
    _fades = _ctrls
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut))
        .toList();
    _slides = _ctrls.map((c) {
      return Tween<Offset>(begin: widget.slideBegin, end: Offset.zero).animate(
        CurvedAnimation(parent: c, curve: Curves.easeOutCubic),
      );
    }).toList();
  }

  @override
  void didUpdateWidget(StaggeredList old) {
    super.didUpdateWidget(old);
    if (old.children.length != widget.children.length) {
      // Children count changed (e.g. broker card added/removed): recreate controllers.
      for (final c in _ctrls) c.dispose();
      _initControllers(widget.children.length);
      // Forward all controllers immediately — the list was already visible.
      for (final c in _ctrls) c.forward();
    }
  }

  Future<void> _startAnimations() async {
    for (int i = 0; i < _ctrls.length; i++) {
      await Future.delayed(widget.itemDelay * i);
      if (mounted) _ctrls[i].forward();
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(widget.children.length, (i) {
        return FadeTransition(
          opacity: _fades[i],
          child: SlideTransition(
            position: _slides[i],
            child: widget.children[i],
          ),
        );
      }),
    );
  }
}
