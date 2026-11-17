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
  ForestResources get maturityYield => switch (this) {
        pine => const ForestResources(materials: 4),
        birch => const ForestResources(seeds: 6),
        oak => const ForestResources(materials: 6),
        maple => const ForestResources(seeds: 10),
        willow => const ForestResources(water: 6),
        cedar => const ForestResources(materials: 8),
        redwood => const ForestResources(materials: 12),
      };
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

class ForestResources {
  final int seeds, water, materials;
  const ForestResources({this.seeds = 0, this.water = 0, this.materials = 0});
  ForestResources operator +(ForestResources other) => ForestResources(
      seeds: seeds + other.seeds,
      water: water + other.water,
      materials: materials + other.materials);
  ForestResources operator -(ForestResources other) => ForestResources(
      seeds: seeds - other.seeds,
      water: water - other.water,
      materials: materials - other.materials);
  ForestResources get nonnegative => ForestResources(
      seeds: math.max(0, seeds),
      water: math.max(0, water),
      materials: math.max(0, materials));
  String get balance =>
      '$seeds ${seeds == 1 ? 'seed' : 'seeds'} · $water water · $materials ${materials == 1 ? 'material' : 'materials'}';
  String get yieldLabel => [
        if (seeds > 0) '$seeds ${seeds == 1 ? 'seed' : 'seeds'}',
        if (water > 0) '$water water',
        if (materials > 0)
          '$materials ${materials == 1 ? 'material' : 'materials'}'
      ].join(' · ');
}

class ForestProjectPlan {
  final ForestResources cost, bonus;
  final int matureTrees;
  final ForestProject? prerequisite;
  final String benefit;
  const ForestProjectPlan(
      {required this.cost,
      required this.matureTrees,
      required this.benefit,
      this.prerequisite,
      this.bonus = const ForestResources()});
}

/// Append-only actions. Completion IDs are stable across devices and undo.
class ForestEvent {
  final String id;
  final String kind;
  final String? treeId;
  final TreeSpecies? species;
  final int? plot;
  final ForestProject? project;
  final int? atCompletion;
  const ForestEvent(
      {required this.id,
      required this.kind,
      this.treeId,
      this.species,
      this.plot,
      this.project,
      this.atCompletion});
  static String rewardId(String taskId, String dateKey) =>
      'reward_${taskId}_$dateKey';
  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        if (treeId != null) 'treeId': treeId,
        if (species != null) 'species': species!.name,
        if (plot != null) 'plot': plot,
        if (project != null) 'project': project!.name,
        if (atCompletion != null) 'atCompletion': atCompletion
      };
  factory ForestEvent.fromJson(Map<String, dynamic> json) => ForestEvent(
      id: json['id'] as String,
      kind: json['kind'] as String,
      treeId: json['treeId'] as String?,
      plot: (json['plot'] as num?)?.toInt(),
      atCompletion: (json['atCompletion'] as num?)?.toInt(),
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
  // The resource-choice economy is a local sandbox experiment only.
  final bool resourceChoices;
  late final Map<String, ForestEvent> byId = {
    for (final event in events) event.id: event
  };
  ForestState(Iterable<ForestEvent> events, {this.resourceChoices = false})
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
      .where((e) =>
          (e.kind == 'project' ||
              (resourceChoices && e.kind == 'choiceProject')) &&
          e.project != null)
      .map((e) => e.project!)
      .toSet();
  bool hasProject(ForestProject project) => projects.contains(project);
  int get matureTrees => trees.where((t) => t.growth == 2).length;
  // Sandbox packs are never written to disk or accepted by Firestore rules.
  int get _debugResources =>
      byId.values.where((e) => e.kind == 'debugResources').length * 50;
  ForestProjectPlan planFor(ForestProject project) {
    if (!resourceChoices) {
      return ForestProjectPlan(
          cost: ForestResources(
              materials: project.materialCost, water: project.waterCost),
          matureTrees: project.matureTrees,
          prerequisite: project.prerequisite,
          benefit: project.benefit);
    }
    return switch (project) {
      ForestProject.nursery => const ForestProjectPlan(
          cost: ForestResources(materials: 8, water: 2),
          matureTrees: 1,
          bonus: ForestResources(materials: 2),
          benefit: '+2 materials every 4 tasks · build habitats faster'),
      ForestProject.birdhouse => const ForestProjectPlan(
          cost: ForestResources(materials: 10),
          matureTrees: 1,
          bonus: ForestResources(seeds: 2),
          benefit:
              '+2 seeds every 4 tasks · plant more trees · resident songbirds'),
      ForestProject.pond => const ForestProjectPlan(
          cost: ForestResources(materials: 12, water: 6),
          matureTrees: 1,
          bonus: ForestResources(water: 2),
          benefit:
              '+2 water every 4 tasks · early willow planting · resident frogs'),
    };
  }

  ForestResources maturityYield(TreeSpecies species) => resourceChoices
      ? species.maturityYield
      : const ForestResources(materials: 3);

  late final ForestResources resources = _resources();
  ForestResources _resources() {
    final stock = _debugResources +
        (resourceChoices &&
                byId.values.any((e) => e.kind == 'debugChoiceBudget')
            ? 3
            : 0);
    var total = ForestResources(
        seeds: completions + stock,
        water: completions + stock,
        materials: completions + stock);
    for (final tree in trees) {
      if (tree.id != 'starter') {
        total -= ForestResources(seeds: tree.species.seedCost);
      }
      total -= ForestResources(water: tree.growth);
      if (tree.growth == 2) total += maturityYield(tree.species);
    }
    for (final project in projects) {
      total -= planFor(project).cost;
      if (!resourceChoices && project == ForestProject.nursery) {
        total += const ForestResources(seeds: 8);
      }
    }
    if (resourceChoices) {
      for (final event in byId.values
          .where((e) => e.kind == 'choiceBonus' && e.project != null)) {
        total += planFor(event.project!).bonus;
      }
    }
    return total.nonnegative;
  }

  int get materials => resources.materials;
  bool canBuild(ForestProject project) {
    final plan = planFor(project);
    return !hasProject(project) &&
        (plan.prerequisite == null || hasProject(plan.prerequisite!)) &&
        matureTrees >= plan.matureTrees &&
        materials >= plan.cost.materials &&
        water >= plan.cost.water;
  }

  int bonusIn(ForestProject project) {
    final event = byId.values
        .where((e) => e.kind == 'choiceProject' && e.project == project)
        .firstOrNull;
    return event == null
        ? 4
        : 4 - (completions - (event.atCompletion ?? completions)) % 4;
  }

  String? goalShortfall(ForestResources remaining, {ForestProject? building}) {
    final goal = activeProject;
    if (goal == null || goal == building) return null;
    final missing = (planFor(goal).cost - remaining).nonnegative;
    return missing.yieldLabel.isEmpty
        ? null
        : 'Goal: ${missing.yieldLabel} still needed for ${goal.label}.';
  }

  bool helpsGoal(TreeSpecies species) {
    final goal = activeProject;
    if (goal == null || !unlocked(species)) return false;
    final missing = (planFor(goal).cost - resources).nonnegative;
    final yield = maturityYield(species);
    return (missing.materials > 0 && yield.materials > 0) ||
        (missing.water > 0 && yield.water > 0);
  }

  String? get goalAdvice {
    final goal = activeProject;
    if (goal == null) return null;
    final plan = planFor(goal);
    if (matureTrees < plan.matureTrees) {
      return 'Grow a tree to maturity to support this habitat.';
    }
    if (water < plan.cost.water) {
      return unlocked(TreeSpecies.willow)
          ? 'Save water, or grow a willow to get water at maturity.'
          : 'Save water for this goal. Watering another tree spends it.';
    }
    if (materials < plan.cost.materials) {
      return 'Pines yield materials; a nursery earns extra materials as you complete tasks.';
    }
    return 'Ready to build · check what you will have left.';
  }

  ForestResources afterWatering(ForestTree tree) =>
      resources -
      const ForestResources(water: 1) +
      (tree.growth == 1
          ? maturityYield(tree.species)
          : const ForestResources());

  ForestProject? get activeProject {
    final goals = byId.values
        .where((e) => e.kind == 'goal' && e.project != null)
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    if (goals.isNotEmpty && !hasProject(goals.last.project!)) {
      return goals.last.project;
    }
    return resourceChoices
        ? null
        : ForestProject.values.where((p) => !hasProject(p)).firstOrNull;
  }

  double projectProgress(ForestProject project) {
    if (hasProject(project)) return 1;
    final plan = planFor(project);
    final parts = <double>[
      math.min(1, materials / plan.cost.materials),
      math.min(1, matureTrees / plan.matureTrees),
      if (plan.cost.water > 0) math.min(1, water / plan.cost.water),
      if (plan.prerequisite != null) hasProject(plan.prerequisite!) ? 1 : 0,
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
  int get seeds => resources.seeds;
  int get water => resources.water;
}
