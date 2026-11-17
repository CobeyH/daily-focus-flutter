import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/forest.dart';
import 'app_controller.dart';
import 'forest_reward_provider.dart';

final forestProvider =
    NotifierProvider<ForestController, ForestState>(ForestController.new);

class ForestController extends Notifier<ForestState> {
  final bool isSandbox;
  final bool _restorationGoals;
  final List<ForestEvent> _initial;
  ForestController()
      : isSandbox = false,
        _restorationGoals = false,
        _initial = const [];
  ForestController.sandbox(Iterable<ForestEvent> initial,
      {bool restorationGoals = false})
      : isSandbox = true,
        _restorationGoals = restorationGoals,
        _initial = List.of(initial);
  Future<void> _pending = Future.value();

  // Serialize spends and saves so fast taps cannot overdraw or lose a rollback.
  Future<T> _run<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  @override
  ForestState build() {
    if (isSandbox) {
      if (!kDebugMode) {
        throw StateError('Sandbox is available in debug builds only.');
      }
      return ForestState(_initial, restorationGoals: _restorationGoals);
    }
    return ForestState(ref.watch(storageProvider).loadForest());
  }

  Future<ForestState?> _append(ForestEvent event) => _appendAll([event]);

  Future<ForestState?> _appendAll(Iterable<ForestEvent> events) async {
    final added = events.where((e) => !state.byId.containsKey(e.id)).toList();
    if (added.isEmpty) return null;
    final before = state;
    final next = ForestState([...state.events, ...added],
        restorationGoals: state.restorationGoals);
    state = next;
    try {
      if (!isSandbox) await ref.read(storageProvider).saveForest(next.events);
      return next;
    } catch (_) {
      if (ref.mounted && identical(state, next)) state = before;
      rethrow;
    }
  }

  /// Called only after a new full task completion is recorded locally.
  Future<void> awardCompletion(String taskId, String dateKey) => _run(() async {
        final before = state;
        final event = ForestEvent(
            id: ForestEvent.rewardId(taskId, dateKey), kind: 'reward');
        final after = await _appendAll(_rewardEvents(state, event));
        if (after != null && ref.mounted) {
          ref
              .read(forestRewardProvider.notifier)
              .emit(ForestReward(before, after));
        }
      });

  List<ForestEvent> _rewardEvents(ForestState forest, ForestEvent reward) {
    if (forest.byId.containsKey(reward.id)) return [];
    return [reward];
  }

  Future<void> _sync() async {
    if (isSandbox) return;
    try {
      await ref.read(syncCoordinatorProvider)?.pushLocal();
    } catch (_) {}
  }

  Future<String> plant(TreeSpecies species) => _run(() async {
        if (!state.canPlant(species)) {
          throw StateError(
              'Not enough planting resources or this tree is still locked.');
        }
        final id =
            'plant_${DateTime.now().toUtc().microsecondsSinceEpoch}_${const Uuid().v4()}';
        await _append(ForestEvent(
            id: id, kind: 'plant', species: species, plot: state.nextPlot));
        _sync().ignore();
        return id;
      });

  Future<void> waterTree(String id) => _run(() async {
        final tree = state.trees.where((t) => t.id == id).firstOrNull;
        if (tree == null || tree.growth >= 2 || state.water < 1) {
          throw StateError('This tree cannot be watered right now.');
        }
        await _append(ForestEvent(
            id: 'water_${const Uuid().v4()}', kind: 'water', treeId: id));
        _sync().ignore();
      });

  Future<void> chooseProject(ForestProject project) => _run(() async {
        if (state.hasProject(project)) return;
        await _append(ForestEvent(
            id: 'goal_${DateTime.now().toUtc().microsecondsSinceEpoch}_${const Uuid().v4()}',
            kind: 'goal',
            project: project));
        _sync().ignore();
      });

  Future<void> buildProject(ForestProject project) => _run(() async {
        if (state.restorationGoals) {
          throw StateError(
              'Habitat achievements unlock automatically when their trees mature.');
        }
        if (!state.canBuild(project)) {
          throw StateError('This project still has requirements to complete.');
        }
        await _append(ForestEvent(
            id: 'project_${project.name}', kind: 'project', project: project));
        _sync().ignore();
      });

  void _requireSandbox() {
    if (!kDebugMode || !isSandbox) {
      throw StateError('Cheats require the debug sandbox.');
    }
  }

  Future<void> debugResources() => _run(() async {
        _requireSandbox();
        await _append(ForestEvent(
            id: 'debug_${const Uuid().v4()}', kind: 'debugResources'));
      });

  Future<void> debugLevelUp({int? targetLevel}) => _run(() async {
        _requireSandbox();
        final before = state;
        final target = targetLevel ?? before.level + 1;
        if (target <= before.level || target > 25) return;
        final count = (ForestState.xpForLevel(target) - before.xp) ~/ 10;
        var next = state;
        for (var i = 0; i < count; i++) {
          next = ForestState([
            ...next.events,
            ..._rewardEvents(
                next,
                ForestEvent(
                    id: 'debug_reward_${const Uuid().v4()}', kind: 'reward'))
          ], restorationGoals: next.restorationGoals);
        }
        state = next;
        ref
            .read(forestRewardProvider.notifier)
            .emit(ForestReward(before, state));
      });

  Future<void> debugGrowTrees() => _run(() async {
        _requireSandbox();
        await _append(ForestEvent(
            id: 'debug_${const Uuid().v4()}', kind: 'debugResources'));
        for (var i = state.trees.length; i < 4; i++) {
          await _append(ForestEvent(
              id: 'debug_plant_${const Uuid().v4()}',
              kind: 'plant',
              species: TreeSpecies.pine,
              plot: state.nextPlot));
        }
        for (final tree in state.trees.take(4)) {
          for (var stage = tree.growth; stage < 2; stage++) {
            await _append(ForestEvent(
                id: 'debug_water_${const Uuid().v4()}',
                kind: 'water',
                treeId: tree.id));
          }
        }
      });

  Future<void> chooseRestoration(ForestRestoration milestone) => _run(() async {
        _requireSandbox();
        if (!state.restorationGoals || state.restorations.contains(milestone)) {
          return;
        }
        await _append(ForestEvent(
            id: 'goal_${DateTime.now().toUtc().microsecondsSinceEpoch}_${const Uuid().v4()}',
            kind: 'restorationGoal',
            restoration: milestone));
      });

  Future<void> debugRestorationStart() => _run(() async {
        _requireSandbox();
        ref.read(forestRewardProvider.notifier).clear();
        state = ForestState([
          for (var i = 0; i < 32; i++)
            ForestEvent(id: 'restoration_reward_$i', kind: 'reward'),
          const ForestEvent(
              id: 'starter_water_1', kind: 'water', treeId: 'starter'),
          const ForestEvent(
              id: 'starter_water_2', kind: 'water', treeId: 'starter'),
        ], restorationGoals: true);
      });

  Future<void> debugCompleteGoal() => _run(() async {
        _requireSandbox();
        if (!state.restorationGoals) return;
        final project = state.activeProject,
            milestone = state.activeRestoration;
        if (project == null && milestone == null) return;
        await _append(ForestEvent(
            id: 'debug_${const Uuid().v4()}', kind: 'debugResources'));
        final species = project == null
            ? TreeSpecies.pine
            : state.planFor(project).species!;
        final target = project == null
            ? milestone!.target
            : state.planFor(project).matureTrees;
        while (project != null
            ? state.matureCount(species) < target
            : state.restorationCount(milestone!) < target) {
          final wanted = milestone?.diversity == true
              ? TreeSpecies.values
                  .firstWhere((s) => !state.matureSpecies.contains(s))
              : species;
          var tree = state.trees
              .where((t) => t.species == wanted && t.growth < 2)
              .firstOrNull;
          if (tree == null) {
            final id = 'debug_plant_${const Uuid().v4()}';
            await _append(ForestEvent(
                id: id, kind: 'plant', species: wanted, plot: state.nextPlot));
            tree = state.trees.firstWhere((t) => t.id == id);
          }
          for (var growth = tree.growth; growth < 2; growth++) {
            await _append(ForestEvent(
                id: 'debug_water_${const Uuid().v4()}',
                kind: 'water',
                treeId: tree.id));
          }
        }
      });

  Future<void> debugRestoredForest() => _run(() async {
        _requireSandbox();
        ref.read(forestRewardProvider.notifier).clear();
        final species = [
          TreeSpecies.pine,
          TreeSpecies.pine,
          for (var i = 0; i < 5; i++) TreeSpecies.maple,
          for (var i = 0; i < 3; i++) TreeSpecies.willow,
          TreeSpecies.birch
        ];
        state = ForestState([
          for (var i = 0; i < 77; i++)
            ForestEvent(id: 'restored_reward_$i', kind: 'reward'),
          for (var i = 0; i < species.length; i++)
            ForestEvent(
                id: 'restored_tree_$i',
                kind: 'plant',
                species: species[i],
                plot: i + 1),
          for (final id in [
            'starter',
            for (var i = 0; i < species.length; i++) 'restored_tree_$i'
          ])
            for (var i = 0; i < 2; i++)
              ForestEvent(
                  id: 'restored_water_${id}_$i', kind: 'water', treeId: id),
        ], restorationGoals: true);
      });

  Future<void> debugReset() => _run(() async {
        _requireSandbox();
        ref.read(forestRewardProvider.notifier).clear();
        state = ForestState([], restorationGoals: state.restorationGoals);
      });
}
