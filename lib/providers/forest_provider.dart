import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/forest.dart';
import 'app_controller.dart';

final forestProvider =
    NotifierProvider<ForestController, ForestState>(ForestController.new);

class ForestController extends Notifier<ForestState> {
  @override
  ForestState build() => ForestState(ref.watch(storageProvider).loadForest());

  Future<void> _append(ForestEvent event) async {
    if (state.byId.containsKey(event.id)) return;
    final before = state;
    final next = ForestState([...state.events, event]);
    state = next;
    try {
      await ref.read(storageProvider).saveForest(next.events);
    } catch (_) {
      if (ref.mounted && identical(state, next)) state = before;
      rethrow;
    }
  }

  /// Called only after a new full task completion is recorded locally.
  Future<void> awardCompletion(String taskId, String dateKey) => _append(
      ForestEvent(id: ForestEvent.rewardId(taskId, dateKey), kind: 'reward'));

  Future<void> _sync() async {
    try {
      await ref.read(syncCoordinatorProvider)?.pushLocal();
    } catch (_) {}
  }

  Future<String> plant(TreeSpecies species) async {
    if (!state.unlocked(species) || state.seeds < species.seedCost) {
      throw StateError('Not enough seeds or this tree is still locked.');
    }
    final id =
        'plant_${DateTime.now().toUtc().microsecondsSinceEpoch}_${const Uuid().v4()}';
    await _append(ForestEvent(
        id: id, kind: 'plant', species: species, plot: state.nextPlot));
    _sync().ignore();
    return id;
  }

  Future<void> waterTree(String id) async {
    final tree = state.trees.where((t) => t.id == id).firstOrNull;
    if (tree == null || tree.growth >= 2 || state.water < 1) {
      throw StateError('This tree cannot be watered right now.');
    }
    await _append(ForestEvent(
        id: 'water_${const Uuid().v4()}', kind: 'water', treeId: id));
    _sync().ignore();
  }
}
