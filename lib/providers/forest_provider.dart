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
  final List<ForestEvent> _initial;
  ForestController()
      : isSandbox = false,
        _initial = const [];
  ForestController.sandbox(Iterable<ForestEvent> initial)
      : isSandbox = true,
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
      return ForestState(_initial);
    }
    return ForestState(ref.watch(storageProvider).loadForest());
  }

  Future<ForestState?> _append(ForestEvent event) async {
    if (state.byId.containsKey(event.id)) return null;
    final before = state;
    final next = ForestState([...state.events, event]);
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
        final after = await _append(ForestEvent(
            id: ForestEvent.rewardId(taskId, dateKey), kind: 'reward'));
        if (after != null && ref.mounted) {
          ref
              .read(forestRewardProvider.notifier)
              .emit(ForestReward(before, after));
        }
      });

  Future<void> _sync() async {
    if (isSandbox) return;
    try {
      await ref.read(syncCoordinatorProvider)?.pushLocal();
    } catch (_) {}
  }

  Future<String> plant(TreeSpecies species) => _run(() async {
        if (!state.unlocked(species) || state.seeds < species.seedCost) {
          throw StateError('Not enough seeds or this tree is still locked.');
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
        state = ForestState([
          ...state.events,
          for (var i = 0; i < count; i++)
            ForestEvent(id: 'debug_reward_${const Uuid().v4()}', kind: 'reward')
        ]);
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

  Future<void> debugReset() => _run(() async {
        _requireSandbox();
        ref.read(forestRewardProvider.notifier).clear();
        state = ForestState([]);
      });
}
