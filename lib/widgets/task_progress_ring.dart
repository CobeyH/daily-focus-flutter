import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A vector ring with enough space for smooth edges at desktop display scales.
class TaskProgressRing extends StatelessWidget {
  final double progress;
  final Color color;
  final IconData icon;
  final String label;

  const TaskProgressRing({
    super.key,
    required this.progress,
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0);
    return Semantics(
      label: label,
      value: '${(value * 100).round()} percent complete',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: 48,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: value, end: value),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (context, animated, child) => CustomPaint(
              painter: _RingPainter(animated, color),
              child: child,
            ),
            child: Center(child: Icon(icon, color: color, size: 24)),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _RingPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.5;
    final center = size.center(Offset.zero);
    // Inset both edges; neither the stroke nor its antialiasing gets clipped.
    final outer =
        Rect.fromCircle(center: center, radius: size.shortestSide / 2 - 1.5);
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(outer)
      ..addOval(outer.deflate(stroke));
    final paint = Paint()..isAntiAlias = true;
    if (progress < 1) {
      canvas.drawPath(ring, paint..color = color.withValues(alpha: 0.14));
    }
    if (progress >= 1) {
      // A closed filled ring avoids a visible join at twelve o'clock.
      canvas.drawPath(ring, paint..color = color);
    } else if (progress > 0) {
      canvas.drawArc(
          outer.deflate(stroke / 2),
          -math.pi / 2,
          2 * math.pi * progress,
          false,
          paint
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
