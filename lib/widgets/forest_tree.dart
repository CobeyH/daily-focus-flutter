import 'package:flutter/material.dart';
import '../models/forest.dart';

class ForestTreeArt extends StatelessWidget {
  final TreeSpecies species;
  final int growth;
  const ForestTreeArt({super.key, required this.species, required this.growth});
  @override
  Widget build(BuildContext context) => CustomPaint(
      painter: _TreePainter(species, growth), size: const Size(100, 120));
}

class _TreePainter extends CustomPainter {
  final TreeSpecies species;
  final int growth;
  const _TreePainter(this.species, this.growth);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 120);
    final paint = Paint()..isAntiAlias = true;
    canvas.drawOval(const Rect.fromLTWH(14, 103, 72, 12),
        paint..color = const Color(0x24244435));
    if (growth == 0) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(48, 77, 5, 30), const Radius.circular(2)),
          paint..color = const Color(0xFF806342));
      canvas.drawOval(const Rect.fromLTWH(27, 70, 24, 13),
          paint..color = const Color(0xFF42966C));
      canvas.drawOval(const Rect.fromLTWH(50, 61, 24, 16),
          paint..color = const Color(0xFF6DA876));
    } else {
      if (growth == 1) {
        canvas.translate(14, 31);
        canvas.scale(.72);
      }
      final trunk = species == TreeSpecies.birch
          ? const Color(0xFFF1EAD5)
          : const Color(0xFF806342);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(46, 48, 9, 60), const Radius.circular(3)),
          paint..color = trunk);
      if (species == TreeSpecies.pine ||
          species == TreeSpecies.cedar ||
          species == TreeSpecies.redwood) {
        for (var level = 0;
            level < (species == TreeSpecies.redwood ? 4 : 3);
            level++) {
          final y = (species == TreeSpecies.redwood ? 2.0 : 12.0) +
              level * (species == TreeSpecies.redwood ? 20 : 22);
          final width = species == TreeSpecies.redwood
              ? 14.0 + level * 5
              : species == TreeSpecies.cedar
                  ? 27.0 + level * 8
                  : 22.0 + level * 9;
          final path = Path()
            ..moveTo(50, y)
            ..quadraticBezierTo(46, y + 12, 50 - width, y + 32)
            ..quadraticBezierTo(50, y + 40, 50 + width, y + 32)
            ..quadraticBezierTo(54, y + 12, 50, y)
            ..close();
          canvas.drawPath(
              path,
              paint
                ..color = [
                  const Color(0xFF43896F),
                  const Color(0xFF32745D),
                  const Color(0xFF245B4B)
                ][level % 3]);
        }
      } else if (species == TreeSpecies.birch) {
        canvas.drawOval(const Rect.fromLTWH(22, 9, 58, 75),
            paint..color = const Color(0xFF91B973));
        canvas.drawOval(const Rect.fromLTWH(24, 9, 40, 59),
            paint..color = const Color(0xFFB2CE87));
        for (var y = 82.0; y < 106; y += 9) {
          canvas.drawRect(Rect.fromLTWH(47, y, 5, 2),
              paint..color = const Color(0xFF897F66));
        }
      } else if (species == TreeSpecies.willow) {
        canvas.drawOval(const Rect.fromLTWH(12, 22, 76, 46),
            paint..color = const Color(0xFF6BA989));
        for (var i = 0; i < 5; i++) {
          final x = 14.0 + i * 14;
          final leaves = Path()
            ..moveTo(x, 45)
            ..quadraticBezierTo(x - 9, 72, x + 2, 92 - (i % 2) * 12)
            ..quadraticBezierTo(x + 14, 73, x + 12, 44)
            ..close();
          canvas.drawPath(
              leaves,
              paint
                ..color = i.isEven
                    ? const Color(0xFF55977A)
                    : const Color(0xFF83B99B));
        }
      } else {
        for (final circle in [
          const Offset(27, 56),
          const Offset(69, 53),
          const Offset(48, 33)
        ]) {
          canvas.drawCircle(
              circle,
              25,
              paint
                ..color = species == TreeSpecies.maple
                    ? const Color(0xFFC76840)
                    : const Color(0xFF608C50));
        }
        canvas.drawCircle(
            const Offset(38, 36),
            22,
            paint
              ..color = species == TreeSpecies.maple
                  ? const Color(0xFFE5A34D)
                  : const Color(0xFF82A966));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TreePainter old) =>
      old.species != species || old.growth != growth;
}
