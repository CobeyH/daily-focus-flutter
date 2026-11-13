import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/forest.dart';
import 'forest_tree.dart';

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
  final _camera = TransformationController();
  Size _viewport = Size.zero;
  bool _initialized = false;
  ForestTree get _selectedTree =>
      widget.forest.trees.where((t) => t.id == widget.selectedId).firstOrNull ??
      widget.forest.trees.first;
  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  Offset _point(ForestTree tree) {
    final p = ForestState.positionForPlot(tree.plot),
        r = widget.forest.clearingRadius;
    return Offset(r + p.x, r + p.y);
  }

  void _focus(ForestTree tree, [double? zoom]) {
    final scale = zoom ?? _camera.value.getMaxScaleOnAxis().clamp(.45, 1.5);
    final point = _point(tree);
    _camera.value = Matrix4.translationValues(
        _viewport.width / 2 - point.dx * scale,
        _viewport.height / 2 - (point.dy - 35) * scale,
        0)
      ..multiply(Matrix4.diagonal3Values(scale, scale, scale));
  }

  void _overview() {
    final extent = widget.forest.clearingRadius * 2;
    final scale = (math.min(_viewport.width, _viewport.height) / extent * .95)
        .clamp(.001, 1.0);
    _camera.value = Matrix4.translationValues(
        (_viewport.width - extent * scale) / 2,
        (_viewport.height - extent * scale) / 2,
        0)
      ..multiply(Matrix4.diagonal3Values(scale, scale, scale));
  }

  @override
  void didUpdateWidget(ForestLandscape old) {
    super.didUpdateWidget(old);
    final delta = old.forest.clearingRadius - widget.forest.clearingRadius;
    if (delta != 0 && _initialized) {
      _camera.value = _camera.value.clone()
        ..multiply(Matrix4.translationValues(delta, delta, 0));
    }
    if (old.selectedId != widget.selectedId && _initialized) {
      final selected = widget.forest.trees
          .where((t) => t.id == widget.selectedId)
          .firstOrNull;
      if (selected != null) _focus(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = widget.forest.clearingRadius;
    final trees = widget.forest.trees.toList()
      ..sort((a, b) => _point(a).dy.compareTo(_point(b).dy));
    return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
            height: 360,
            child: LayoutBuilder(builder: (context, constraints) {
              final viewport =
                  Size(constraints.maxWidth, constraints.maxHeight);
              if (!_initialized || _viewport != viewport) {
                _viewport = viewport;
                _focus(_selectedTree, .9);
                _initialized = true;
              }
              return Stack(children: [
                Positioned.fill(
                    child: ColoredBox(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF182D28)
                            : const Color(0xFFE4EEE0))),
                Positioned.fill(
                    child: InteractiveViewer(
                        key: const ValueKey('continuous-forest'),
                        transformationController: _camera,
                        constrained: false,
                        minScale: .001,
                        maxScale: 2.5,
                        boundaryMargin: const EdgeInsets.all(500),
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                            width: radius * 2,
                            height: radius * 2,
                            child: Stack(children: [
                              Positioned.fill(
                                  child: CustomPaint(
                                      painter: _GroundPainter(
                                          widget.forest.level,
                                          radius,
                                          Theme.of(context).brightness))),
                              for (final tree in trees)
                                Positioned(
                                    left: _point(tree).dx - 44,
                                    top: _point(tree).dy - 102,
                                    width: 88,
                                    height: 116,
                                    child: Semantics(
                                        button: true,
                                        selected: tree.id == widget.selectedId,
                                        label:
                                            '${tree.species.label}, ${tree.stage}',
                                        child: Tooltip(
                                          message:
                                              '${tree.species.label} · ${tree.stage}',
                                          child: InkWell(
                                              key: ValueKey(
                                                  'forest-tree-${tree.id}'),
                                              borderRadius:
                                                  BorderRadius.circular(40),
                                              onTap: () =>
                                                  widget.onSelect(tree.id),
                                              child: Stack(children: [
                                                if (tree.id ==
                                                    widget.selectedId)
                                                  Positioned(
                                                      left: 18,
                                                      right: 18,
                                                      bottom: 0,
                                                      height: 16,
                                                      child: DecoratedBox(
                                                          decoration: BoxDecoration(
                                                              color: colors
                                                                  .primary
                                                                  .withValues(
                                                                      alpha:
                                                                          .15),
                                                              border: Border.all(
                                                                  color: colors
                                                                      .primary,
                                                                  width: 1.5),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          30)))),
                                                Positioned.fill(
                                                    child: ForestTreeArt(
                                                        species: tree.species,
                                                        growth: tree.growth)),
                                              ])),
                                        ))),
                            ])))),
                Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                        color: colors.surface.withValues(alpha: .92),
                        borderRadius: BorderRadius.circular(16),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                              tooltip: 'Zoom out',
                              icon: const Icon(Icons.remove),
                              onPressed: () => _focus(
                                  _selectedTree,
                                  (_camera.value.getMaxScaleOnAxis() / 1.3)
                                      .clamp(.001, 2.5))),
                          IconButton(
                              tooltip: 'View whole forest',
                              icon: const Icon(Icons.fit_screen),
                              onPressed: _overview),
                          IconButton(
                              tooltip: 'Zoom in',
                              icon: const Icon(Icons.add),
                              onPressed: () => _focus(
                                  _selectedTree,
                                  (_camera.value.getMaxScaleOnAxis() * 1.3)
                                      .clamp(.001, 2.5))),
                        ]))),
                const Positioned(
                    left: 12,
                    bottom: 10,
                    child: IgnorePointer(
                        child: Text('Drag to explore · pinch to zoom',
                            style: TextStyle(fontSize: 12)))),
              ]);
            })));
  }
}

class _GroundPainter extends CustomPainter {
  final int level;
  final double radius;
  final Brightness brightness;
  const _GroundPainter(this.level, this.radius, this.brightness);
  @override
  void paint(Canvas canvas, Size size) {
    final dark = brightness == Brightness.dark;
    final center = size.center(Offset.zero);
    final paint = Paint()..isAntiAlias = true;
    canvas.drawCircle(
        center,
        radius - 8,
        paint
          ..color = dark ? const Color(0xFF243F32) : const Color(0xFFD2E4BE));
    canvas.drawCircle(
        center,
        math.max(100, radius - 54),
        paint
          ..color = dark ? const Color(0xFF2B4736) : const Color(0xFFDDEBCB));
    final trail = Path()
      ..moveTo(center.dx - radius, center.dy + 65)
      ..cubicTo(center.dx - 100, center.dy + 140, center.dx + 70,
          center.dy - 50, center.dx + radius, center.dy - 35);
    canvas.drawPath(
        trail,
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 22
          ..color = (dark ? const Color(0xFF53634A) : const Color(0xFFCCCEAC))
              .withValues(alpha: .6));
    paint.style = PaintingStyle.fill;
    for (var i = 0; i < 90; i++) {
      final angle = i * 2.399963229728653;
      final r = (radius - 40) * math.sqrt((i + .5) / 90);
      final point = center + Offset(math.cos(angle), math.sin(angle)) * r;
      canvas.drawOval(
          Rect.fromCenter(center: point, width: 4 + i % 3 * 2, height: 3),
          paint
            ..color = (dark ? const Color(0xFF72A06C) : const Color(0xFF8FB07B))
                .withValues(alpha: .35));
    }
  }

  @override
  bool shouldRepaint(_GroundPainter old) =>
      level != old.level ||
      radius != old.radius ||
      brightness != old.brightness;
}
