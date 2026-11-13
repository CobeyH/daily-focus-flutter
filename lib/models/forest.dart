import 'dart:math' as math;

enum TreeSpecies {
  pine('Pine', 1, 3),
  birch('Birch', 2, 4),
  oak('Oak', 3, 5),
  maple('Maple', 5, 6),
  willow('Willow', 8, 7),
  cedar('Cedar', 12, 9),
  redwood('Redwood', 16, 12);

  final String label;
  final int unlockLevel, seedCost;
  const TreeSpecies(this.label, this.unlockLevel, this.seedCost);
}

/// Append-only actions. Completion IDs are stable across devices and undo.
class ForestEvent {
  final String id;
  final String kind;
  final String? treeId;
  final TreeSpecies? species;
  final int? plot;
  const ForestEvent(
      {required this.id,
      required this.kind,
      this.treeId,
      this.species,
      this.plot});
  static String rewardId(String taskId, String dateKey) =>
      'reward_${taskId}_$dateKey';
  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        if (treeId != null) 'treeId': treeId,
        if (species != null) 'species': species!.name,
        if (plot != null) 'plot': plot
      };
  factory ForestEvent.fromJson(Map<String, dynamic> json) => ForestEvent(
      id: json['id'] as String,
      kind: json['kind'] as String,
      treeId: json['treeId'] as String?,
      plot: (json['plot'] as num?)?.toInt(),
      species: TreeSpecies.values
          .where((s) => s.name == json['species'])
          .firstOrNull);
}

class ForestTree {
  final String id;
  final TreeSpecies species;
  final int growth;
  final int plot;
  const ForestTree(this.id, this.species, this.growth, [this.plot = 0]);
  String get stage => switch (growth) {
        0 => 'Seedling',
        1 => 'Young tree',
        _ => 'Fully grown'
      };
}

class ForestState {
  final List<ForestEvent> events;
  late final Map<String, ForestEvent> byId = {
    for (final event in events) event.id: event
  };
  ForestState(Iterable<ForestEvent> events)
      : events = List.unmodifiable(events);
  int get completions => byId.values.where((e) => e.kind == 'reward').length;
  static int xpForLevel(int level) => (level - 1) * (level + 3) * 10;
  int get xp => completions * 10;
  int get level => math.sqrt(completions + 4).floor() - 1;
  int get levelXp => xp - xpForLevel(level);
  int get xpToNextLevel => xpForLevel(level + 1) - xpForLevel(level);
  double get levelProgress => levelXp / xpToNextLevel;
  TreeSpecies? get nextUnlock =>
      TreeSpecies.values.where((s) => s.unlockLevel > level).firstOrNull;
  bool unlocked(TreeSpecies species) => level >= species.unlockLevel;

  late final List<ForestTree> trees = _placeTrees();
  List<ForestTree> _placeTrees() {
    final used = <int>{0};
    final result = <ForestTree>[_tree('starter', TreeSpecies.pine, 0)];
    final plants = byId.values
        .where((e) => e.kind == 'plant' && e.species != null)
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    // Reserve explicit plots first, so adding a new tree cannot shift legacy ones.
    final reserved = plants
        .where((e) => e.plot != null && e.plot! > 0)
        .map((e) => e.plot!)
        .toSet();
    for (final event in plants) {
      var plot = event.plot ?? 0;
      if (plot < 1 || plot > 1000000 || used.contains(plot)) {
        plot = 1;
        while (used.contains(plot) || reserved.contains(plot)) {
          plot++;
        }
      }
      used.add(plot);
      result.add(_tree(event.id, event.species!, plot));
    }
    return List.unmodifiable(result);
  }

  int get nextPlot {
    final used = trees.map((t) => t.plot).toSet();
    var plot = 1;
    while (used.contains(plot)) {
      plot++;
    }
    return plot;
  }

  ForestTree _tree(String id, TreeSpecies species, int plot) => ForestTree(
      id,
      species,
      math.min(2,
          byId.values.where((e) => e.kind == 'water' && e.treeId == id).length),
      plot);

  // A stable spiral gives a natural layout without moving previously planted trees.
  static math.Point<double> positionForPlot(int plot) {
    final radius = 94 * math.sqrt(plot);
    final angle = plot * 2.399963229728653;
    return math.Point(math.cos(angle) * radius, math.sin(angle) * radius * .8);
  }

  double get clearingRadius => math.max(240 + (level - 1) * 28.0,
      trees.map((t) => 94 * math.sqrt(t.plot) + 125).fold(0.0, math.max));
  int get seeds => math.max(
      0,
      completions -
          trees
              .where((t) => t.id != 'starter')
              .fold(0, (sum, t) => sum + t.species.seedCost));
  int get water =>
      math.max(0, completions - trees.fold(0, (sum, t) => sum + t.growth));
}
