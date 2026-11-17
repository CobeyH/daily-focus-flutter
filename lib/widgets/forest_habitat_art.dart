import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/forest.dart';
import 'forest_scene_geometry.dart';

Offset habitatGround(ForestProject project) => switch (project) {
      ForestProject.nursery => const Offset(115, 70),
      ForestProject.birdhouse => const Offset(15, -165),
      ForestProject.pond => const Offset(-135, 35),
    };

// Habitat art shares the scene's isometric projection and depth ordering.
void paintForestHabitat(Canvas canvas, ForestProject project,
    {required bool built, required double progress, double arrival = 1}) {
  final ground = habitatGround(project);
  final base = projectForestPoint(ground.dx, ground.dy);
  canvas.save();
  canvas.translate(base.dx, base.dy);
  if (built) canvas.scale(.9 + arrival * .1);
  final paint = Paint()..isAntiAlias = true;
  Offset p(double x, double y, [double z = 0]) => projectForestPoint(x, y, z);
  void poly(List<Offset> points, Color color) =>
      canvas.drawPath(Path()..addPolygon(points, true), paint..color = color);
  void line(Offset a, Offset b, Color color, [double width = 3]) =>
      canvas.drawLine(
          a,
          b,
          paint
            ..color = color
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round);
  const wood = Color(0xFF9A7049),
      lightWood = Color(0xFFCBAC77),
      roof = Color(0xFF638C6A);
  canvas.drawOval(const Rect.fromLTWH(-48, -12, 96, 30),
      paint..color = const Color(0x22314327));
  if (!built) {
    poly([p(-30, -24), p(30, -24), p(30, 24), p(-30, 24)],
        const Color(0xFFB9AD80));
    for (final x in [-30.0, 30.0]) {
      for (final y in [-24.0, 24.0]) {
        line(p(x, y), p(x, y, 18), wood);
      }
    }
    for (var i = 0; i < (progress * 6).floor(); i++) {
      line(p(-25, -20 + i * 8), p(25, -20 + i * 8), lightWood, 5);
    }
    canvas.restore();
    return;
  }
  switch (project) {
    case ForestProject.nursery:
      poly([p(-35, -27), p(35, -27), p(35, 27), p(-35, 27)],
          const Color(0xFFB6AC7C));
      for (final x in [-31.0, 31.0]) {
        for (final y in [-23.0, 23.0]) {
          line(p(x, y), p(x, y, 48), wood, 4);
        }
      }
      poly(
          [p(-38, -30, 48), p(0, -30, 67), p(0, 32, 67), p(-38, 32, 48)], roof);
      poly([p(0, -30, 67), p(38, -30, 48), p(38, 32, 48), p(0, 32, 67)],
          const Color(0xFF97B393));
      line(p(-31, 23, 22), p(31, 23, 22), lightWood, 9);
      for (var i = 0; i < 4; i++) {
        final pot = p(-23 + i * 15, 23, 25);
        poly([
          pot + const Offset(-5, -3),
          pot + const Offset(5, -3),
          pot + const Offset(3, 5),
          pot + const Offset(-3, 5)
        ], const Color(0xFFB97852));
        line(pot + const Offset(0, -3), pot + const Offset(0, -13), roof, 2);
        canvas.drawOval(
            Rect.fromCenter(
                center: pot + const Offset(-3, -10), width: 8, height: 4),
            paint..color = roof);
      }
    case ForestProject.birdhouse:
      line(p(0, 0), p(0, 0, 60), wood, 7);
      poly([p(-13, -12, 60), p(13, -12, 60), p(13, 12, 60), p(-13, 12, 60)],
          lightWood);
      poly([p(-13, 12, 60), p(13, 12, 60), p(13, 12, 85), p(-13, 12, 85)],
          const Color(0xFFD1B97E));
      poly(
          [p(13, -12, 60), p(13, 12, 60), p(13, 12, 85), p(13, -12, 85)], wood);
      poly([p(-18, 15, 85), p(0, 15, 102), p(0, -16, 102), p(-18, -16, 85)],
          roof);
      poly([p(0, 15, 102), p(18, 15, 85), p(18, -16, 85), p(0, -16, 102)],
          const Color(0xFF8AA779));
      final hole = p(0, 12, 74);
      canvas.drawCircle(hole, 4, paint..color = const Color(0xFF584936));
      line(p(0, 12, 65), p(0, 24, 65), wood, 3);
      for (var i = 0; i < 2; i++) {
        final bird =
            p(i == 0 ? -27 : 30, i == 0 ? 10 : -6, 35 + (1 - arrival) * 20);
        canvas.drawOval(Rect.fromCenter(center: bird, width: 12, height: 8),
            paint..color = const Color(0xFFD3A44D));
        canvas.drawCircle(bird + const Offset(5, -4), 4, paint);
        poly([
          bird + const Offset(8, -5),
          bird + const Offset(13, -3),
          bird + const Offset(8, -2)
        ], wood);
        line(bird + const Offset(-3, 0), bird + const Offset(2, 2),
            const Color(0xFF755F43), 2);
        canvas.drawCircle(bird + const Offset(6, -5), .8,
            paint..color = const Color(0xFF303D2D));
      }
    case ForestProject.pond:
      void disk(double radius, Color color) => poly([
            for (var i = 0; i < 24; i++)
              p(math.cos(i * math.pi / 12) * radius,
                  math.sin(i * math.pi / 12) * radius * .8)
          ], color);
      disk(57, const Color(0xFFC6C4A0));
      disk(49, const Color(0xFF548F8A));
      disk(39, const Color(0xFF88C2B4));
      for (var i = 0; i < 3; i++) {
        final ripple = p(-25 + i * 13, -10 + i * 12);
        line(ripple, ripple + const Offset(18, 0), const Color(0xFFBFDED0), 2);
      }
      for (var i = 0; i < 4; i++) {
        final reed = p(34 + i * 3, -14 + i * 8);
        line(reed, reed + Offset(-3 - i * 1.0, -23), roof, 2);
        line(reed + Offset(-3 - i * 1.0, -23), reed + Offset(-3 - i * 1.0, -29),
            wood, 4);
      }
      for (var i = 0; i < 2; i++) {
        final frog = p(-25 + i * 30, 20 + i * 7);
        canvas.drawOval(Rect.fromCenter(center: frog, width: 13, height: 9),
            paint..color = const Color(0xFF638642));
        for (final x in [-3.0, 3.0]) {
          canvas.drawCircle(frog + Offset(x, -4), 2.5, paint);
          canvas.drawCircle(
              frog + Offset(x, -5), .9, paint..color = const Color(0xFF263F29));
          paint.color = const Color(0xFF638642);
        }
      }
  }
  canvas.restore();
}
