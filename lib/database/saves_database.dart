import '../models/save.dart';
import 'db_provider.dart';

const String savesDbName = "saves";

class SavesDatabase {
  static final SavesDatabase dbProvider = SavesDatabase._();

  SavesDatabase._();

  Future<List<Save>> getAllSaves() async {
    final db = await DBProvider.instance.database;
    List<Map<String, dynamic>> jsonSaves = await db.query(savesDbName);
    return jsonSaves.map((t) => Save.fromJson(t)).toList();
  }

  Future<int> insertSave(Save save) async {
    final db = await DBProvider.instance.database;
    return await db.insert(savesDbName, save.toJson());
  }

  Future<int> updateSave(Save task) async {
    final db = await DBProvider.instance.database;
    return await db.update(
      savesDbName,
      task.toJson(),
      where: 'uuid = ?',
      whereArgs: [task.uuid],
    );
  }

  Future<int> deleteSave(String uuid) async {
    final db = await DBProvider.instance.database;
    return await db.delete(
      savesDbName,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }
}
