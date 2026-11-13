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
  final Rect sourceBounds;
  final VoidCallback onFinished;
  final bool Function() isVisible;
  const CompletionWaterFlight(
      {super.key,
      required this.start,
      required this.sourceBounds,
      required this.end,
      required this.onFinished,
      required this.isVisible});
  @override
  State<CompletionWaterFlight> createState() => _CompletionWaterFlightState();
}

class _CompletionWaterFlightState extends State<CompletionWaterFlight>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))
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
          child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                if (!widget.isVisible()) return const SizedBox.shrink();
                return SizedBox.expand(
                    child: CustomPaint(
                        key: const ValueKey('completion-droplets'),
                        painter: _DropletBurstPainter(widget.sourceBounds,
                            widget.end, _controller.value)));
              })));
}

class _DropletBurstPainter extends CustomPainter {
  final Rect source;
  final Offset destination;
  final double time;
  const _DropletBurstPainter(this.source, this.destination, this.time);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final area = source.deflate(math.min(20, source.shortestSide / 5));
    for (var i = 0; i < 18; i++) {
      // Spread origins over the whole card; use deterministic variation rather
      // than frame-by-frame randomness, so motion remains continuous.
      final start = Offset(area.left + area.width * ((i % 6 + .5) / 6),
          area.top + area.height * ((i ~/ 6 + .5) / 3));
      final radial = start - source.center;
      final angle = math.atan2(radial.dy, radial.dx);
      final burst =
          start + Offset(math.cos(angle), math.sin(angle)) * (22 + (i % 4) * 7);
      final flightStart = .18 + (i % 6) * .019;
      final flight =
          ((time - flightStart) / (.64 + (i % 3) * .02)).clamp(0.0, 1.0);
      if (flight >= 1) continue;
      final t = Curves.easeInOutCubic.transform(flight);
      final bend = Offset(burst.dx + (i.isEven ? 1 : -1) * (45 + i % 5 * 12),
          destination.dy - 26 - (i % 3) * 8);
      final point = time < flightStart
          ? Offset.lerp(start, burst,
              Curves.easeOutCubic.transform((time / .18).clamp(0.0, 1.0)))!
          : burst * ((1 - t) * (1 - t)) +
              bend * (2 * (1 - t) * t) +
              destination * (t * t);
      final opacity = ((time / .055).clamp(0.0, 1.0) *
          ((1 - flight) / .12).clamp(0.0, 1.0));
      final radius = (5.0 + i % 4) * (1 - .55 * t);
      final rotation = time < flightStart
          ? math.sin(angle) * .6
          : (1 - t) * math.sin(i.toDouble()) * .45;
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(rotation);
      final drop = Path()
        ..moveTo(0, -radius)
        ..cubicTo(radius * .32, -radius * .42, radius * .82, radius * .05,
            radius * .76, radius * .4)
        ..cubicTo(radius * .65, radius * 1.2, -radius * .65, radius * 1.2,
            -radius * .76, radius * .4)
        ..cubicTo(-radius * .82, radius * .05, -radius * .32, -radius * .42, 0,
            -radius)
        ..close();
      final color = const [
        Color(0xFF38A9D1),
        Color(0xFF53BDDD),
        Color(0xFF268FBF)
      ][i % 3];
      canvas.drawPath(drop, paint..color = color.withValues(alpha: opacity));
      canvas.drawCircle(Offset(-radius * .24, radius * .16), radius * .15,
          paint..color = Colors.white.withValues(alpha: opacity * .65));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_DropletBurstPainter old) =>
      time != old.time ||
      source != old.source ||
      destination != old.destination;
}
