import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../database/saves_database.dart';
import '../models/save.dart';
import '../models/task.dart';

part 'saves_provider.g.dart';

@Riverpod(keepAlive: true)
class Saves extends _$Saves {
  @override
  Future<List<Save>> build() async {
    final db = SavesDatabase.dbProvider;
    return await db.getAllSaves();
  }

  void convertToSaves(List<Task> tasks) {
    // Convert saves to tasks
    List<Save> newSaves = tasks.map((t) => Save.fromTask(t)).toList();
    // Add new saves to the saves provider
    for (Save s in newSaves) {
      ref.read(savesProvider.notifier).createNew(s);
    }
  }

  Future<void> createNew(Save task) async {
    task.uuid = const Uuid().v4().toString();
    state = AsyncData([...state.value ?? [], task]);
    await SavesDatabase.dbProvider.insertSave(task);
  }

  List<Save> lastWeek() {
    List<Save> allSaves = state.value ?? [];
    DateTime oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
    allSaves = allSaves.where((Save s) => s.date.isAfter(oneWeekAgo)).toList();
    return allSaves;
  }

  void delete(Save task) {
    state = AsyncData((state.value ?? [])
        .where((element) => element.uuid != task.uuid)
        .toList());
    SavesDatabase.dbProvider.deleteSave(task.uuid);
  }
}
