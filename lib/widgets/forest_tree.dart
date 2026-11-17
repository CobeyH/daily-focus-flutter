import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/forest.dart';
import 'forest_scene_geometry.dart';

final _pictures = <(TreeSpecies, int), ui.Picture>{};

class ForestSpeciesPreview extends StatelessWidget {
  final ForestState forest;
  final TreeSpecies species;
  const ForestSpeciesPreview(
      {super.key, required this.forest, required this.species});
  @override
  Widget build(BuildContext context) => forest.unlocked(species)
      ? ForestTreeArt(species: species, growth: forest.highestGrowth(species))
      : Semantics(
          label: '${species.label}, unlocks at level ${species.unlockLevel}',
          child: Center(
              child: Icon(Icons.lock_outline_rounded,
                  size: 28,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)));
}

void clearForestTreePictures() {
  for (final picture in _pictures.values) {
    picture.dispose();
  }
  _pictures.clear();
}

void paintForestTree(
    Canvas canvas, Offset base, TreeSpecies species, int growth,
    {double scale = 1}) {
  final picture = _pictures.putIfAbsent((species, growth), () {
    final recorder = ui.PictureRecorder();
    _TreeMesh(Canvas(recorder)).paint(species, growth);
    return recorder.endRecording();
  });
  canvas.save();
  canvas.translate(base.dx, base.dy);
  canvas.scale(scale);
  canvas.drawPicture(picture);
  canvas.restore();
}

class ForestTreeArt extends StatelessWidget {
  final TreeSpecies species;
  final int growth;
  const ForestTreeArt({super.key, required this.species, required this.growth});
  @override
  Widget build(BuildContext context) => CustomPaint(
      painter: _TreePainter(species, growth), size: const Size(110, 150));
}

class _TreePainter extends CustomPainter {
  final TreeSpecies species;
  final int growth;
  const _TreePainter(this.species, this.growth);
  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 110, size.height / 180);
    paintForestTree(
        canvas, Offset(size.width / 2, size.height * .91), species, growth,
        scale: scale);
  }

  @override
  bool shouldRepaint(_TreePainter old) =>
      old.species != species || old.growth != growth;
}

class _Vertex {
  final double x, y, z;
  const _Vertex(this.x, this.y, this.z);
  Offset get point => projectForestPoint(x, y, z);
}

class _Face {
  final List<_Vertex> vertices;
  final Color color;
  const _Face(this.vertices, this.color);
  double get depth =>
      vertices.fold(0.0, (sum, p) => sum + p.x + p.y + p.z) / vertices.length;
}

class _TreeMesh {
  final Canvas canvas;
  final _paint = Paint()..isAntiAlias = true;
  _TreeMesh(this.canvas);

  void polygon(List<Offset> points, Color color) {
    final path = Path()..addPolygon(points, true);
    canvas.drawPath(
        path,
        _paint
          ..style = PaintingStyle.fill
          ..color = color);
    canvas.drawPath(
        path,
        _paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = .45
          ..color = color);
    _paint.style = PaintingStyle.fill;
  }

  Color shade(Color color, double value) => Color.lerp(
      value < 0 ? const Color(0xFF142F2E) : const Color(0xFFFFF2C4),
      color,
      1 - value.abs().clamp(0, .7))!;

  void solid(List<_Face> faces) {
    faces.sort((a, b) => a.depth.compareTo(b.depth));
    for (final face in faces) {
      polygon(face.vertices.map((p) => p.point).toList(), face.color);
    }
  }

  void trunk(double height, double radius, Color color) {
    final faces = <_Face>[];
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3, b = (i + 1) * math.pi / 3;
      faces.add(_Face([
        _Vertex(math.cos(a) * radius, math.sin(a) * radius, 0),
        _Vertex(math.cos(b) * radius, math.sin(b) * radius, 0),
        _Vertex(math.cos(b) * radius * .65, math.sin(b) * radius * .65, height),
        _Vertex(math.cos(a) * radius * .65, math.sin(a) * radius * .65, height),
      ], shade(color, math.cos(a + 1) * .22)));
    }
    solid(faces);
  }

  void crown(
      double x, double y, double z, double radius, double tall, Color color,
      {int segments = 9}) {
    final faces = <_Face>[];
    _Vertex at(int ring, int segment) {
      final latitude = -math.pi / 2 + ring * math.pi / 5;
      final angle = segment * math.pi * 2 / segments + (ring.isOdd ? .12 : 0);
      return _Vertex(
          x + math.cos(angle) * math.cos(latitude) * radius,
          y + math.sin(angle) * math.cos(latitude) * radius,
          z + math.sin(latitude) * tall);
    }

    for (var ring = 0; ring < 5; ring++) {
      for (var segment = 0; segment < segments; segment++) {
        final a = at(ring, segment),
            b = at(ring, segment + 1),
            c = at(ring + 1, segment),
            d = at(ring + 1, segment + 1);
        for (final tri in [
          [a, b, c],
          [b, d, c]
        ]) {
          final mx = tri.fold(0.0, (sum, v) => sum + v.x - x) / 3 / radius;
          final my = tri.fold(0.0, (sum, v) => sum + v.y - y) / 3 / radius;
          final mz = tri.fold(0.0, (sum, v) => sum + v.z - z) / 3 / tall;
          final light = (-mx * .28 - my * .42 + mz * .48).clamp(-.45, .45);
          faces.add(_Face(tri, shade(color, light)));
        }
      }
    }
    solid(faces);
  }

  void evergreen(double z, double radius, double height, Color color) {
    final faces = <_Face>[];
    for (var i = 0; i < 9; i++) {
      final a = i * math.pi * 2 / 9, b = (i + 1) * math.pi * 2 / 9;
      faces.add(_Face([
        _Vertex(math.cos(a) * radius, math.sin(a) * radius, z),
        _Vertex(math.cos(b) * radius, math.sin(b) * radius, z),
        _Vertex(0, 0, z + height),
      ], shade(color, math.cos(a + .8) * .25)));
    }
    solid(faces);
  }

  void paint(TreeSpecies species, int growth) {
    canvas.drawOval(const Rect.fromLTWH(-27, -1, 72, 17),
        _paint..color = const Color(0x2231412E));
    canvas.drawOval(const Rect.fromLTWH(-19, -2, 42, 11),
        _paint..color = const Color(0x1853291D));
    if (growth == 0) {
      trunk(20, 2.5, const Color(0xFF816343));
      polygon([
        const Offset(0, -15),
        const Offset(-20, -28),
        const Offset(-18, -15),
        const Offset(0, -12)
      ], const Color(0xFF4D9570));
      polygon([
        const Offset(0, -21),
        const Offset(17, -38),
        const Offset(23, -24),
        const Offset(0, -15)
      ], const Color(0xFF84B879));
      polygon(
          [const Offset(0, -21), const Offset(17, -38), const Offset(13, -23)],
          const Color(0xFFADCA88));
      return;
    }
    canvas.save();
    final young = growth == 1;
    if (young) {
      canvas.scale(.8);
    }
    final birch = species == TreeSpecies.birch;
    trunk(
        young
            ? 58
            : species == TreeSpecies.redwood
                ? 105
                : 72,
        species == TreeSpecies.redwood ? 7 : 4.5,
        birch ? const Color(0xFFE5DFCA) : const Color(0xFF8D6542));
    switch (species) {
      case TreeSpecies.pine:
      case TreeSpecies.cedar:
      case TreeSpecies.redwood:
        final cedar = species == TreeSpecies.cedar;
        final redwood = species == TreeSpecies.redwood;
        final layers = young
            ? 2
            : redwood
                ? 5
                : 4;
        for (var i = 0; i < layers; i++) {
          evergreen(
              28.0 + i * (redwood ? 21 : 18),
              (young
                      ? 23
                      : cedar
                          ? 43
                          : redwood
                              ? 29
                              : 34) -
                  i * (redwood ? 4.0 : 6.0),
              cedar ? 39 : 43,
              [
                const Color(0xFF245E50),
                const Color(0xFF347B60),
                const Color(0xFF438E6D),
                const Color(0xFF5BA17A),
                const Color(0xFF74AD80)
              ][i]);
        }
      case TreeSpecies.birch:
        crown(0, 0, young ? 62 : 82, young ? 16 : 24, young ? 25 : 40,
            const Color(0xFFA4C97B));
        for (var z = 15.0; z < 51; z += 10) {
          polygon([
            Offset(-3, -z),
            Offset(2, -z + 1),
            Offset(2, -z + 3),
            Offset(-3, -z + 2)
          ], const Color(0xFF8B8872));
        }
      case TreeSpecies.oak:
      case TreeSpecies.maple:
        final maple = species == TreeSpecies.maple;
        if (young) {
          crown(0, 0, 62, 22, 24,
              maple ? const Color(0xFFD58C4D) : const Color(0xFF78A266));
        } else {
          crown(-17, -5, 73, 27, 27,
              maple ? const Color(0xFFC96F43) : const Color(0xFF5A8C53));
          crown(18, 5, 73, 27, 30,
              maple ? const Color(0xFFD88942) : const Color(0xFF6C9B5C));
          crown(-2, -1, 97, 27, 27,
              maple ? const Color(0xFFE7AD57) : const Color(0xFF88AE6C));
        }
      case TreeSpecies.willow:
        crown(0, 0, young ? 62 : 80, young ? 23 : 39, young ? 18 : 24,
            const Color(0xFF6CAA80));
        final branches = young ? 3 : 7;
        for (var i = 0; i < branches; i++) {
          final angle = i * math.pi * 2 / branches;
          crown(
              math.cos(angle) * (young ? 15 : 28),
              math.sin(angle) * (young ? 15 : 28),
              young ? 49 : 57,
              young ? 7 : 12,
              young ? 16 : 30,
              i.isEven ? const Color(0xFF73AD83) : const Color(0xFF4F926D),
              segments: 6);
        }
    }
    canvas.restore();
  }
}
