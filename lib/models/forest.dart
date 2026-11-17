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

enum ForestRestoration {
  grass('Living forest floor', 3, false, 'Grass spreads across the clearing'),
  lichen('A diverse woodland', 3, true, 'Lichen appears on mature tree trunks'),
  wildflowers(
      'A flourishing grove', 8, false, 'Wildflowers bloom among the grass');

  final String label, reward;
  final int target;
  final bool diversity;
  const ForestRestoration(this.label, this.target, this.diversity, this.reward);
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
  final ForestResources cost;
  final int matureTrees;
  final TreeSpecies? species;
  final ForestProject? prerequisite;
  final String benefit;
  const ForestProjectPlan({
    required this.cost,
    required this.matureTrees,
    required this.benefit,
    this.prerequisite,
    this.species,
  });
}

/// Append-only actions. Completion IDs are stable across devices and undo.
class ForestEvent {
  final String id;
  final String kind;
  final String? treeId;
  final TreeSpecies? species;
  final int? plot;
  final ForestProject? project;
  final ForestRestoration? restoration;
  const ForestEvent(
      {required this.id,
      required this.kind,
      this.treeId,
      this.species,
      this.plot,
      this.project,
      this.restoration});
  static String rewardId(String taskId, String dateKey) =>
      'reward_${taskId}_$dateKey';
  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        if (treeId != null) 'treeId': treeId,
        if (species != null) 'species': species!.name,
        if (plot != null) 'plot': plot,
        if (project != null) 'project': project!.name,
        if (restoration != null) 'restoration': restoration!.name
      };
  factory ForestEvent.fromJson(Map<String, dynamic> json) => ForestEvent(
      id: json['id'] as String,
      kind: json['kind'] as String,
      treeId: json['treeId'] as String?,
      plot: (json['plot'] as num?)?.toInt(),
      restoration: ForestRestoration.values
          .where((r) => r.name == json['restoration'])
          .firstOrNull,
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
  // Restoration achievements are a local sandbox experiment only.
  final bool restorationGoals;
  late final Map<String, ForestEvent> byId = {
    for (final event in events) event.id: event
  };
  ForestState(Iterable<ForestEvent> events, {this.restorationGoals = false})
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
      (!restorationGoals &&
          species == TreeSpecies.willow &&
          hasProject(ForestProject.pond));

  late final Set<ForestProject> projects = Set.unmodifiable(restorationGoals
      ? ForestProject.values.where(
          (p) => matureCount(planFor(p).species!) >= planFor(p).matureTrees)
      : byId.values
          .where((e) => e.kind == 'project' && e.project != null)
          .map((e) => e.project!));
  int matureCount(TreeSpecies species) =>
      trees.where((t) => t.species == species && t.growth == 2).length;
  int growingCount(TreeSpecies species) =>
      trees.where((t) => t.species == species && t.growth < 2).length;
  Set<TreeSpecies> get matureSpecies =>
      trees.where((t) => t.growth == 2).map((t) => t.species).toSet();
  int restorationCount(ForestRestoration milestone) =>
      milestone.diversity ? matureSpecies.length : matureTrees;
  late final Set<ForestRestoration> restorations = Set.unmodifiable(
      restorationGoals
          ? ForestRestoration.values
              .where((r) => restorationCount(r) >= r.target)
          : <ForestRestoration>[]);
  double restorationProgress(ForestRestoration milestone) =>
      math.min(1, restorationCount(milestone) / milestone.target);
  bool hasProject(ForestProject project) => projects.contains(project);
  int get matureTrees => trees.where((t) => t.growth == 2).length;
  // Sandbox packs are never written to disk or accepted by Firestore rules.
  int get _debugResources =>
      byId.values.where((e) => e.kind == 'debugResources').length * 50;
  ForestProjectPlan planFor(ForestProject project) {
    if (!restorationGoals) {
      return ForestProjectPlan(
          cost: ForestResources(
              materials: project.materialCost, water: project.waterCost),
          matureTrees: project.matureTrees,
          prerequisite: project.prerequisite,
          benefit: project.benefit);
    }
    return switch (project) {
      ForestProject.nursery => const ForestProjectPlan(
          cost: ForestResources(),
          matureTrees: 3,
          species: TreeSpecies.pine,
          benefit: 'A woodland nursery appears in your forest'),
      ForestProject.birdhouse => const ForestProjectPlan(
          cost: ForestResources(),
          matureTrees: 5,
          species: TreeSpecies.maple,
          benefit: 'A birdhouse appears and songbirds move in'),
      ForestProject.pond => const ForestProjectPlan(
          cost: ForestResources(),
          matureTrees: 3,
          species: TreeSpecies.willow,
          benefit: 'A pond appears and frogs settle by the water'),
    };
  }

  ForestResources plantingCost(TreeSpecies species) => restorationGoals
      ? ForestResources(materials: species.seedCost)
      : ForestResources(seeds: species.seedCost);
  bool canPlant(TreeSpecies species) =>
      unlocked(species) &&
      (restorationGoals ? materials : seeds) >= species.seedCost;
  String balanceFor(ForestResources value) => restorationGoals
      ? '${value.materials} materials · ${value.water} water'
      : value.balance;
  String get resourceBalance => balanceFor(resources);

  late final ForestResources resources = _resources();
  ForestResources _resources() {
    final stock = _debugResources;
    var total = ForestResources(
        seeds: completions + stock,
        water: completions + stock,
        materials: completions + stock);
    for (final tree in trees) {
      if (tree.id != 'starter') total -= plantingCost(tree.species);
      total -= ForestResources(water: tree.growth);
      if (!restorationGoals && tree.growth == 2) {
        total += const ForestResources(materials: 3);
      }
    }
    if (!restorationGoals) {
      for (final project in projects) {
        total -= planFor(project).cost;
        if (project == ForestProject.nursery) {
          total += const ForestResources(seeds: 8);
        }
      }
    }
    return total.nonnegative;
  }

  int get materials => resources.materials;
  bool canBuild(ForestProject project) {
    final plan = planFor(project);
    return !restorationGoals &&
        !hasProject(project) &&
        (plan.prerequisite == null || hasProject(plan.prerequisite!)) &&
        matureTrees >= plan.matureTrees &&
        materials >= plan.cost.materials &&
        water >= plan.cost.water;
  }

  String speciesProgress(ForestProject project) {
    final plan = planFor(project), species = plan.species!;
    return '${matureCount(species)} / ${plan.matureTrees} mature ${species.label.toLowerCase()} trees';
  }

  bool helpsGoal(TreeSpecies species) {
    if (!unlocked(species)) return false;
    if (activeProject != null) {
      return planFor(activeProject!).species == species;
    }
    final milestone = activeRestoration;
    if (milestone == null) return false;
    return !milestone.diversity || !matureSpecies.contains(species);
  }

  String? get activeGoalTitle =>
      activeProject?.label ?? activeRestoration?.label;
  List<ForestEvent> get _goals => byId.values
      .where((e) =>
          e.kind == 'goal' || (restorationGoals && e.kind == 'restorationGoal'))
      .toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  ForestRestoration? get activeRestoration {
    final goal = _goals.lastOrNull?.restoration;
    return goal != null && !restorations.contains(goal) ? goal : null;
  }

  String? get goalAdvice {
    if (activeProject case final goal?) {
      final plan = planFor(goal);
      if (plan.species case final species?) {
        if (!unlocked(species)) {
          return '${species.label} unlocks at level ${species.unlockLevel}.';
        }
        final needed = math.max(
            0, plan.matureTrees - matureCount(species) - growingCount(species));
        return needed > 0
            ? 'Plant $needed more ${species.label.toLowerCase()} trees; grow your ${growingCount(species)} seedlings.'
            : 'You have enough planted. Grow your ${growingCount(species)} remaining ${species.label.toLowerCase()} trees.';
      }
    }
    if (activeRestoration case final milestone?) {
      if (milestone.diversity) {
        final available = TreeSpecies.values
            .where((s) => unlocked(s) && !matureSpecies.contains(s));
        final next = TreeSpecies.values
            .where((s) => !matureSpecies.contains(s))
            .firstOrNull;
        if (available.isEmpty && next != null) {
          return '${next.label} unlocks at level ${next.unlockLevel}, opening a new mature variety.';
        }
        return 'Grow a variety you do not yet have at maturity.';
      }
      return 'Every variety counts. Grow your seedlings to maturity.';
    }
    return null;
  }

  ForestResources afterWatering(ForestTree tree) =>
      resources - const ForestResources(water: 1);

  ForestProject? get activeProject {
    final goals = _goals;
    if (goals.isNotEmpty) {
      final goal = goals.last.project;
      if (goal != null && !hasProject(goal)) return goal;
      if (restorationGoals) return null;
    }
    return restorationGoals
        ? null
        : ForestProject.values.where((p) => !hasProject(p)).firstOrNull;
  }

  double projectProgress(ForestProject project) {
    if (hasProject(project)) return 1;
    final plan = planFor(project);
    final parts = <double>[
      if (plan.cost.materials > 0) math.min(1, materials / plan.cost.materials),
      math.min(
          1,
          (plan.species == null ? matureTrees : matureCount(plan.species!)) /
              plan.matureTrees),
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
