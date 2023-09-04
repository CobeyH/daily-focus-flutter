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

  void createNew(Save task) async {
    task.uuid = const Uuid().v4().toString();
    state = AsyncData([...state.value ?? [], task]);
    await SavesDatabase.dbProvider.insertSave(task);
  }

  void updateSave(Save task) async {
    state = AsyncData((state.value ?? [])
        .map((t) => t.uuid == task.uuid ? task : t)
        .toList());
    await SavesDatabase.dbProvider.updateSave(task);
  }

  void delete(Save task) {
    state = AsyncData((state.value ?? [])
        .where((element) => element.uuid != task.uuid)
        .toList());
    SavesDatabase.dbProvider.deleteSave(task.uuid);
  }
}
