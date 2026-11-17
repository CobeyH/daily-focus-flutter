import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/forest.dart';
import 'forest_scene_geometry.dart';
import 'forest_tree.dart';
import 'forest_habitat_art.dart';

typedef _Camera = ({Offset origin, double scale});

class ForestLandscape extends StatefulWidget {
  final ForestState forest;
  final String selectedId;
  final ValueChanged<String> onSelect;
  const ForestLandscape(
      {super.key,
      required this.forest,
      required this.selectedId,
      required this.onSelect});
  @override
  State<ForestLandscape> createState() => _ForestLandscapeState();
}

class _ForestLandscapeState extends State<ForestLandscape> {
  bool _closeUp = false;
  @override
  void reassemble() {
    clearForestTreePictures();
    super.reassemble();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.forest.trees
            .where((t) => t.id == widget.selectedId)
            .firstOrNull ??
        widget.forest.trees.first;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      final layout = ForestSceneLayout(widget.forest, size,
          focusedTree: _closeUp ? selected : null);
      final camera = (origin: layout.origin, scale: layout.scale);
      return ClipRect(
          child: Stack(children: [
        Positioned.fill(
            child: TweenAnimationBuilder<_Camera>(
          duration: reduced ? Duration.zero : const Duration(milliseconds: 550),
          curve: Curves.easeInOutCubic,
          tween: _CameraTween(begin: camera, end: camera),
          builder: (context, camera, child) {
            final trees = widget.forest.trees.toList()
              ..sort((a, b) {
                final pa = forestGroundPosition(a),
                    pb = forestGroundPosition(b);
                return (pa.dx + pa.dy).compareTo(pb.dx + pb.dy);
              });
            return Stack(children: [
              Positioned.fill(
                  child: RepaintBoundary(
                      child: TweenAnimationBuilder<double>(
                key: ValueKey(
                    '${selected.id}-${selected.growth}-${trees.length}-${widget.forest.projects.length}'),
                tween: Tween(begin: reduced ? 1 : 0, end: 1),
                duration:
                    reduced ? Duration.zero : const Duration(milliseconds: 850),
                curve: Curves.easeOutCubic,
                builder: (context, pulse, child) => CustomPaint(
                  key: const ValueKey('isometric-forest'),
                  painter: _ForestPainter(
                      widget.forest, selected.id, camera, dark, pulse),
                ),
              ))),
              for (final tree in trees) _treeTarget(tree, camera),
            ]);
          },
        )),
        Positioned(
            top: 8,
            right: 12,
            child: Material(
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: .92),
              borderRadius: BorderRadius.circular(18),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                    tooltip: 'View whole forest',
                    isSelected: !_closeUp,
                    onPressed: () => setState(() => _closeUp = false),
                    icon: const Icon(Icons.landscape_outlined)),
                IconButton(
                    tooltip: 'Closer look at selected tree',
                    isSelected: _closeUp,
                    onPressed: () => setState(() => _closeUp = true),
                    icon: const Icon(Icons.center_focus_strong_outlined)),
              ]),
            )),
        Positioned(
            left: 16,
            bottom: 10,
            child: IgnorePointer(
                child: Text(
              'Tap a tree to tend it',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      dark ? const Color(0xFFB9C8BE) : const Color(0xFF526956)),
            ))),
      ]));
    });
  }

  Widget _treeTarget(ForestTree tree, _Camera camera) {
    final p = forestGroundPosition(tree);
    final base = camera.origin + projectForestPoint(p.dx, p.dy) * camera.scale;
    final width = math.max(44.0, 92 * camera.scale);
    final height = math.max(44.0, (tree.growth == 0 ? 55 : 145) * camera.scale);
    return Positioned(
      left: base.dx - width / 2,
      top: base.dy - height + 8 * camera.scale,
      width: width,
      height: height,
      child: Semantics(
        button: true,
        selected: tree.id == widget.selectedId,
        label: '${tree.species.label}, ${tree.stage}, tree ${tree.plot + 1}',
        child: Tooltip(
          message: '${tree.species.label} · ${tree.stage}',
          child: GestureDetector(
              key: ValueKey('forest-tree-${tree.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onSelect(tree.id),
              child: const SizedBox.expand()),
        ),
      ),
    );
  }
}

class _CameraTween extends Tween<_Camera> {
  _CameraTween({required _Camera begin, required _Camera end})
      : super(begin: begin, end: end);
  @override
  _Camera lerp(double t) => (
        origin: Offset.lerp(begin!.origin, end!.origin, t)!,
        scale: begin!.scale + (end!.scale - begin!.scale) * t
      );
}

class _ForestPainter extends CustomPainter {
  final ForestState forest;
  final String selectedId;
  final _Camera camera;
  final bool dark;
  final double pulse;
  _ForestPainter(
      this.forest, this.selectedId, this.camera, this.dark, this.pulse);
  final _paint = Paint()..isAntiAlias = true;

  void _poly(Canvas canvas, List<Offset> points, Color color) {
    canvas.drawPath(
        Path()..addPolygon(points, true),
        _paint
          ..style = PaintingStyle.fill
          ..color = color);
  }

  Offset _p(double x, double y, [double z = 0]) => projectForestPoint(x, y, z);

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
        sky,
        _paint
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const [
                    Color(0xFF1B3434),
                    Color(0xFF152722),
                    Color(0xFF21382D)
                  ]
                : const [
                    Color(0xFFEBF2E9),
                    Color(0xFFDCE8D7),
                    Color(0xFFEBEBD8)
                  ],
          ).createShader(sky));
    _paint.shader = null;
    // Distant ridges belong to the scenery, not the player's planted collection.
    for (var layer = 0; layer < 3; layer++) {
      final path = Path()..moveTo(0, size.height);
      for (var i = 0; i <= 24; i++) {
        final x = size.width * i / 24;
        final y = size.height * (.50 + layer * .11) +
            math.sin(i * .42 + layer * 2.1) * size.height * .055;
        path.lineTo(x, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(
          path,
          _paint
            ..color = (dark
                    ? const [
                        Color(0xFF24413B),
                        Color(0xFF294B3B),
                        Color(0xFF314F3B)
                      ]
                    : const [
                        Color(0xFFD0DFCA),
                        Color(0xFFC3D6BD),
                        Color(0xFFB7CFAF)
                      ])[layer]
                .withValues(alpha: .65));
    }
    canvas.save();
    canvas.translate(camera.origin.dx, camera.origin.dy);
    canvas.scale(camera.scale);
    final r = forest.clearingRadius;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(0, r * .35), width: r * 2.4, height: r * .94),
        _paint
          ..color = const Color(0x19303B2B)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16));
    _paint.maskFilter = null;
    final rim = <Offset>[];
    for (var i = 0; i < 24; i++) {
      final angle = i * math.pi / 12;
      final radius = r * (.94 + math.sin(i * 1.9) * .025);
      rim.add(_p(math.cos(angle) * radius, math.sin(angle) * radius));
    }
    for (var i = 0; i < rim.length; i++) {
      final a = rim[i], b = rim[(i + 1) % rim.length];
      _poly(
          canvas,
          [a, b, b + const Offset(0, 34), a + const Offset(0, 34)],
          Color.lerp(const Color(0xFF725F42), const Color(0xFFA18B5B),
              (math.sin(i * .7) + 1) / 2)!);
      _poly(canvas, [a, b, b + const Offset(0, 8), a + const Offset(0, 8)],
          dark ? const Color(0xFF4D6C41) : const Color(0xFF799954));
    }
    final top = Path()..addPolygon(rim, true);
    canvas.drawPath(
        top,
        _paint
          ..color = dark ? const Color(0xFF537544) : const Color(0xFFB1C986));
    canvas.save();
    canvas.clipPath(top);
    for (var x = -r; x < r; x += 60) {
      for (var y = -r; y < r; y += 60) {
        final index = ((x + r) / 60 + (y + r) / 60).round();
        _poly(
            canvas,
            [_p(x, y), _p(x + 60, y), _p(x + 60, y + 60), _p(x, y + 60)],
            (index.isEven ? Colors.white : const Color(0xFF2E6439))
                .withValues(alpha: .035));
      }
    }
    final trail = Path()
      ..moveTo(_p(-r, r * .15).dx, _p(-r, r * .15).dy)
      ..cubicTo(
          _p(-r * .4, r * .65).dx,
          _p(-r * .4, r * .65).dy,
          _p(r * .1, -r * .3).dx,
          _p(r * .1, -r * .3).dy,
          _p(r * .65, r * .75).dx,
          _p(r * .65, r * .75).dy);
    canvas.drawPath(
        trail,
        _paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 20
          ..strokeCap = StrokeCap.round
          ..color = dark ? const Color(0xFF9A9569) : const Color(0xFFD9CF9A));
    canvas.drawPath(
        trail,
        _paint
          ..strokeWidth = 12
          ..color = dark ? const Color(0xFFA8A077) : const Color(0xFFE8DCAC));
    _paint.style = PaintingStyle.fill;
    for (var i = 0; i < 65; i++) {
      final angle = i * 2.3999632;
      final radius = r * math.sqrt((i + 1) / 70);
      final p = _p(math.cos(angle) * radius, math.sin(angle) * radius);
      canvas.drawLine(
          p,
          p + const Offset(-2, -5),
          _paint
            ..color = const Color(0x775E873F)
            ..strokeWidth = 1.6);
      canvas.drawLine(p, p + const Offset(3, -4), _paint);
      if (i % 8 == 0) {
        canvas.drawCircle(p + const Offset(2, -4), 2.2,
            _paint..color = const Color(0xFFECE0B2));
      }
    }
    canvas.restore();
    final trees = forest.trees.toList()
      ..sort((a, b) {
        final pa = forestGroundPosition(a), pb = forestGroundPosition(b);
        return (pa.dx + pa.dy).compareTo(pb.dx + pb.dy);
      });
    final objects = <({double depth, VoidCallback paint})>[
      for (final project in ForestProject.values)
        if (forest.hasProject(project) || forest.activeProject == project)
          (
            depth: habitatGround(project).dx + habitatGround(project).dy,
            paint: () => paintForestHabitat(canvas, project,
                built: forest.hasProject(project),
                progress: forest.projectProgress(project),
                arrival: pulse)
          ),
      for (final tree in trees)
        (
          depth: forestGroundPosition(tree).dx + forestGroundPosition(tree).dy,
          paint: () => _paintTree(canvas, tree)
        ),
    ]..sort((a, b) => a.depth.compareTo(b.depth));
    for (final object in objects) {
      object.paint();
    }
    canvas.restore();
  }

  void _paintTree(Canvas canvas, ForestTree tree) {
    final ground = forestGroundPosition(tree);
    final base = _p(ground.dx, ground.dy);
    if (tree.id == selectedId) {
      canvas.drawOval(
          Rect.fromCenter(
              center: base + const Offset(0, 3), width: 65, height: 23),
          _paint
            ..color = const Color(0x99FFEDAA)
            ..style = PaintingStyle.fill);
      canvas.drawOval(
          Rect.fromCenter(
              center: base + const Offset(0, 3), width: 65, height: 23),
          _paint
            ..color = const Color(0xFFFFF2C1)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      _paint.style = PaintingStyle.fill;
    }
    paintForestTree(canvas, base, tree.species, tree.growth,
        scale: tree.id == selectedId ? .92 + pulse * .08 : 1);
    if (tree.id == selectedId &&
        pulse < .99 &&
        forest.events.isNotEmpty &&
        forest.events.last.kind == 'water' &&
        forest.events.last.treeId == tree.id) {
      for (var i = 0; i < 5; i++) {
        final t = (pulse + i * .15) % 1;
        final point = base + Offset(math.sin(i * 2) * 28, -130 + t * 85);
        canvas.drawOval(
            Rect.fromCenter(center: point, width: 5, height: 9),
            _paint
              ..color = const Color(0xFF9ED5E1).withValues(alpha: 1 - pulse));
      }
    }
  }

  @override
  bool shouldRepaint(_ForestPainter old) =>
      old.forest != forest ||
      old.selectedId != selectedId ||
      old.camera != camera ||
      old.dark != dark ||
      old.pulse != pulse;
}
