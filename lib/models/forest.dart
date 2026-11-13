import 'dart:math' as math;

enum TreeSpecies {
  pine('Pine', 0, 3),
  birch('Birch', 5, 4),
  oak('Oak', 12, 5);

  final String label;
  final int unlockAt, seedCost;
  const TreeSpecies(this.label, this.unlockAt, this.seedCost);
}

/// Append-only actions. Completion IDs are stable across devices and undo.
class ForestEvent {
  final String id;
  final String kind;
  final String? treeId;
  final TreeSpecies? species;
  const ForestEvent(
      {required this.id, required this.kind, this.treeId, this.species});
  static String rewardId(String taskId, String dateKey) =>
      'reward_${taskId}_$dateKey';
  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        if (treeId != null) 'treeId': treeId,
        if (species != null) 'species': species!.name
      };
  factory ForestEvent.fromJson(Map<String, dynamic> json) => ForestEvent(
      id: json['id'] as String,
      kind: json['kind'] as String,
      treeId: json['treeId'] as String?,
      species: TreeSpecies.values
          .where((s) => s.name == json['species'])
          .firstOrNull);
}

class ForestTree {
  final String id;
  final TreeSpecies species;
  final int growth;
  const ForestTree(this.id, this.species, this.growth);
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
  bool unlocked(TreeSpecies species) => completions >= species.unlockAt;
  late final List<ForestTree> trees = [
    _tree('starter', TreeSpecies.pine),
    for (final event
        in byId.values.toList()..sort((a, b) => a.id.compareTo(b.id)))
      if (event.kind == 'plant' && event.species != null)
        _tree(event.id, event.species!),
  ];
  ForestTree _tree(String id, TreeSpecies species) => ForestTree(
      id,
      species,
      math.min(
          2,
          byId.values
              .where((e) => e.kind == 'water' && e.treeId == id)
              .length));
  int get seeds => math.max(
      0,
      completions -
          trees
              .where((t) => t.id != 'starter')
              .fold(0, (sum, t) => sum + t.species.seedCost));
  int get water =>
      math.max(0, completions - trees.fold(0, (sum, t) => sum + t.growth));
}
