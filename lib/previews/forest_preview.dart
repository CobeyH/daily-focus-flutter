import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import '../models/forest.dart';
import '../theme/app_theme.dart';
import '../widgets/forest_landscape.dart';

@Preview(name: 'Forest · phone', group: 'Forest', size: Size(390, 580))
@Preview(name: 'Forest · wide', group: 'Forest', size: Size(900, 520))
Widget forestScenePreview() => MaterialApp(
    theme: focusTheme(Brightness.light),
    home: const Scaffold(body: _ForestPreview()));

class _ForestPreview extends StatefulWidget {
  const _ForestPreview();
  @override
  State<_ForestPreview> createState() => _ForestPreviewState();
}

class _ForestPreviewState extends State<_ForestPreview> {
  String selected = 'starter';
  final forest = ForestState([
    for (var i = 0; i < 90; i++) ForestEvent(id: 'reward-$i', kind: 'reward'),
    for (var i = 1; i <= 9; i++)
      ForestEvent(
          id: 'tree-$i',
          kind: 'plant',
          plot: i,
          species: TreeSpecies.values[(i - 1) % 5]),
    for (final id in ['starter', for (var i = 1; i <= 9; i++) 'tree-$i'])
      for (var water = 0; water < 2; water++)
        ForestEvent(id: 'water-$id-$water', kind: 'water', treeId: id),
  ]);
  @override
  Widget build(BuildContext context) => ForestLandscape(
      forest: forest,
      selectedId: selected,
      onSelect: (id) => setState(() => selected = id));
}
