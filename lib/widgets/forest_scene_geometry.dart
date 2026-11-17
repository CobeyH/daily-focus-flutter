import 'dart:math' as math;
import 'dart:ui';
import '../models/forest.dart';

Offset projectForestPoint(double x, double y, [double height = 0]) =>
    Offset((x - y) * .8660254, (x + y) * .5 - height);

Offset forestGroundPosition(ForestTree tree) {
  final p = ForestState.positionForPlot(tree.plot);
  return Offset(p.x, p.y / .8);
}

class ForestSceneLayout {
  final double scale;
  final Offset origin;
  final Rect bounds;
  ForestSceneLayout._(this.scale, this.origin, this.bounds);

  factory ForestSceneLayout(ForestState forest, Size viewport,
      {ForestTree? focusedTree}) {
    final radius = forest.clearingRadius;
    final bounds = focusedTree == null
        ? Rect.fromLTRB(-radius * 1.3 - 16, -radius * .72 - 165,
            radius * 1.3 + 16, radius * .72 + 60)
        : Rect.fromCenter(
            center: projectForestPoint(forestGroundPosition(focusedTree).dx,
                    forestGroundPosition(focusedTree).dy) +
                const Offset(0, -65),
            width: 230,
            height: 240);
    final scale = math.min(math.max(1, viewport.width - 24) / bounds.width,
        math.max(1, viewport.height - 32) / bounds.height);
    return ForestSceneLayout._(
        scale, viewport.center(Offset.zero) - bounds.center * scale, bounds);
  }

  Offset treeBase(ForestTree tree) {
    final p = forestGroundPosition(tree);
    return origin + projectForestPoint(p.dx, p.dy) * scale;
  }
}
