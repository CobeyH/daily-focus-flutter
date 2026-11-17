import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/forest.dart';
import 'forest_scene_geometry.dart';

void paintForestGroundcover(
    Canvas canvas, ForestState forest, double radius, bool dark) {
  final grass = forest.restorations.contains(ForestRestoration.grass);
  final flowers = forest.restorations.contains(ForestRestoration.wildflowers);
  final paint = Paint()..isAntiAlias = true;
  for (var i = 0; i < 90; i++) {
    final angle = i * 2.3999632, r = radius * math.sqrt((i + 1) / 96);
    final x = math.cos(angle) * r, y = math.sin(angle) * r;
    final p = projectForestPoint(x, y);
    if (grass) {
      if (i % 3 == 0) {
        final points = [
          for (var j = 0; j < 10; j++)
            projectForestPoint(x + math.cos(j * math.pi / 5) * (29 + i % 12),
                y + math.sin(j * math.pi / 5) * (25 + i % 9))
        ];
        canvas.drawPath(
            Path()..addPolygon(points, true),
            paint
              ..color =
                  (dark ? const Color(0xFF4D7144) : const Color(0xFF87B16D))
                      .withValues(alpha: .6));
      }
      canvas.drawLine(
          p,
          p + const Offset(-3, -7),
          paint
            ..color = (dark ? const Color(0xFF8FAF72) : const Color(0xFF527B3E))
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round);
      canvas.drawLine(p, p + const Offset(4, -6), paint);
      canvas.drawLine(p, p + const Offset(0, -9), paint);
    } else if (i % 2 == 0) {
      canvas.drawOval(Rect.fromCenter(center: p, width: 6, height: 2),
          paint..color = const Color(0x33806C4C));
    }
    if (flowers && i % 4 == 0) {
      final center = p + const Offset(0, -9);
      for (var petal = 0; petal < 5; petal++) {
        canvas.drawCircle(
            center +
                Offset(math.cos(petal * math.pi * 2 / 5) * 3,
                    math.sin(petal * math.pi * 2 / 5) * 3),
            2.4,
            paint
              ..color = i % 8 == 0
                  ? const Color(0xFFEAE0AC)
                  : const Color(0xFFDCAD9E));
      }
      canvas.drawCircle(center, 1.5, paint..color = const Color(0xFFCA9E49));
    }
  }
}

void paintForestLichen(Canvas canvas, Offset base, ForestTree tree) {
  if (tree.growth < 2) return;
  final paint = Paint()..isAntiAlias = true;
  final evergreen = [TreeSpecies.pine, TreeSpecies.cedar, TreeSpecies.redwood]
      .contains(tree.species);
  final height = evergreen ? 7.0 : 25.0;
  for (var i = 0; i < 4; i++) {
    final point = base + Offset(i.isEven ? -1.0 : 1.0, -2 - i * height / 4);
    canvas.drawOval(
        Rect.fromCenter(center: point, width: i.isEven ? 3 : 2.5, height: 2.5),
        paint
          ..color =
              i.isEven ? const Color(0xFFA6B886) : const Color(0xFFD0CB94));
    canvas.drawCircle(point + const Offset(2, -1), 1.6, paint);
  }
}
