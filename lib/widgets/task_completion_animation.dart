import 'dart:math' as math;
import 'package:flutter/material.dart';

class TaskCompletionExit extends StatefulWidget {
  final Widget child;
  final VoidCallback onFinished;
  const TaskCompletionExit(
      {super.key, required this.child, required this.onFinished});
  @override
  State<TaskCompletionExit> createState() => _TaskCompletionExitState();
}

class _TaskCompletionExitState extends State<TaskCompletionExit>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 380))
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onFinished();
    })
    ..forward();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
      child: ExcludeSemantics(
          child: SizeTransition(
              sizeFactor: Tween<double>(begin: 1, end: 0).animate(
                  CurvedAnimation(
                      parent: _controller,
                      curve: const Interval(.18, 1,
                          curve: Curves.easeInOutCubic))),
              alignment: Alignment.topCenter,
              child: FadeTransition(
                  opacity: Tween<double>(begin: 1, end: 0).animate(
                      CurvedAnimation(
                          parent: _controller,
                          curve:
                              const Interval(0, .75, curve: Curves.easeOut))),
                  child: widget.child))));
}

class CompletionWaterFlight extends StatefulWidget {
  final Offset start, end;
  final VoidCallback onFinished;
  final bool Function() isVisible;
  const CompletionWaterFlight(
      {super.key,
      required this.start,
      required this.end,
      required this.onFinished,
      required this.isVisible});
  @override
  State<CompletionWaterFlight> createState() => _CompletionWaterFlightState();
}

class _CompletionWaterFlightState extends State<CompletionWaterFlight>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 760))
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onFinished();
    })
    ..forward();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _point(double t) {
    final start = widget.start, end = widget.end;
    final bend = Offset(start.dx + (end.dx >= start.dx ? 75 : -75),
        math.min(start.dy, end.dy) - 70);
    return start * ((1 - t) * (1 - t)) +
        bend * (2 * (1 - t) * t) +
        end * (t * t);
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
      child: ExcludeSemantics(
          child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                if (!widget.isVisible()) return const SizedBox.shrink();
                final t = Curves.easeInOutCubic.transform(_controller.value);
                final point = _point(t);
                final scale = t < .8 ? 1.0 : 1 - (t - .8) * 2.5;
                return Stack(children: [
                  for (var i = 3; i > 0; i--)
                    if (t > i * .025 && t < .95)
                      Positioned(
                          left: _point((t - i * .025).clamp(0.0, 1.0)).dx - 3,
                          top: _point((t - i * .025).clamp(0.0, 1.0)).dy - 3,
                          child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF47B9DE).withValues(
                                      alpha: .12 + (3 - i) * .08)))),
                  Positioned(
                      left: point.dx - 18,
                      top: point.dy - 18,
                      child: Transform.scale(
                          scale: scale,
                          child: Transform.rotate(
                              angle: math.sin(t * math.pi) * .22,
                              child: const Icon(Icons.water_drop_rounded,
                                  size: 36,
                                  color: Color(0xFF38A9D1),
                                  shadows: [
                                    Shadow(
                                        color: Color(0x4438A9D1),
                                        blurRadius: 10,
                                        offset: Offset(0, 3))
                                  ])))),
                ]);
              })));
}
