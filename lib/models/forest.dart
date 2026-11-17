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

enum ForestProject {
  nursery('Woodland nursery', 6, 2, 0),
  birdhouse('Songbird haven', 12, 3, 0),
  pond('Woodland pond', 20, 4, 8);

  final String label;
  final int materialCost, matureTrees, waterCost;
  const ForestProject(
      this.label, this.materialCost, this.matureTrees, this.waterCost);
  ForestProject? get prerequisite => switch (this) {
        nursery => null,
        birdhouse => nursery,
        pond => birdhouse
      };
  String get benefit => switch (this) {
        nursery => '8 bonus seeds · opens the songbird project',
        birdhouse => 'Resident songbirds · opens pond restoration',
        pond => 'Resident frogs · early access to willow trees'
      };
  String get description => switch (this) {
        nursery => 'A sheltered growing space built from fallen branches.',
        birdhouse => 'Give your first woodland residents a place to settle.',
        pond => 'Restore a quiet pool and bring the waterside to life.'
      };
}

/// Append-only actions. Completion IDs are stable across devices and undo.
class ForestEvent {
  final String id;
  final String kind;
  final String? treeId;
  final TreeSpecies? species;
  final int? plot;
  final ForestProject? project;
  const ForestEvent(
      {required this.id,
      required this.kind,
      this.treeId,
      this.species,
      this.plot,
      this.project});
  static String rewardId(String taskId, String dateKey) =>
      'reward_${taskId}_$dateKey';
  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        if (treeId != null) 'treeId': treeId,
        if (species != null) 'species': species!.name,
        if (plot != null) 'plot': plot,
        if (project != null) 'project': project!.name
      };
  factory ForestEvent.fromJson(Map<String, dynamic> json) => ForestEvent(
      id: json['id'] as String,
      kind: json['kind'] as String,
      treeId: json['treeId'] as String?,
      plot: (json['plot'] as num?)?.toInt(),
      project: ForestProject.values
          .where((p) => p.name == json['project'])
          .firstOrNull,
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
      TreeSpecies.values.where((s) => !unlocked(s)).firstOrNull;
  bool unlocked(TreeSpecies species) =>
      level >= species.unlockLevel ||
      (species == TreeSpecies.willow && hasProject(ForestProject.pond));

  late final Set<ForestProject> projects = byId.values
      .where((e) => e.kind == 'project' && e.project != null)
      .map((e) => e.project!)
      .toSet();
  bool hasProject(ForestProject project) => projects.contains(project);
  int get matureTrees => trees.where((t) => t.growth == 2).length;
  // Sandbox packs are never written to disk or accepted by Firestore rules.
  int get _debugResources =>
      byId.values.where((e) => e.kind == 'debugResources').length * 50;
  int get materials => math.max(
      0,
      completions +
          matureTrees * 3 +
          _debugResources -
          projects.fold<int>(0, (sum, p) => sum + p.materialCost));
  bool canBuild(ForestProject project) =>
      !hasProject(project) &&
      (project.prerequisite == null || hasProject(project.prerequisite!)) &&
      matureTrees >= project.matureTrees &&
      materials >= project.materialCost &&
      water >= project.waterCost;
  ForestProject? get activeProject {
    final goals = byId.values
        .where((e) => e.kind == 'goal' && e.project != null)
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    if (goals.isNotEmpty && !hasProject(goals.last.project!)) {
      return goals.last.project;
    }
    return ForestProject.values.where((p) => !hasProject(p)).firstOrNull;
  }

  double projectProgress(ForestProject project) {
    if (hasProject(project)) return 1;
    final parts = <double>[
      math.min(1, materials / project.materialCost),
      math.min(1, matureTrees / project.matureTrees),
      if (project.waterCost > 0) math.min(1, water / project.waterCost),
      if (project.prerequisite != null)
        hasProject(project.prerequisite!) ? 1 : 0,
    ];
    return parts.reduce((a, b) => a + b) / parts.length;
  }

  int highestGrowth(TreeSpecies species) => trees
      .where((tree) => tree.species == species)
      .fold(0, (best, tree) => math.max(best, tree.growth));

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
      completions +
          _debugResources +
          (hasProject(ForestProject.nursery) ? 8 : 0) -
          trees
              .where((t) => t.id != 'starter')
              .fold(0, (sum, t) => sum + t.species.seedCost));
  int get water => math.max(
      0,
      completions +
          _debugResources -
          trees.fold<int>(0, (sum, t) => sum + t.growth) -
          projects.fold<int>(0, (sum, p) => sum + p.waterCost));
}
