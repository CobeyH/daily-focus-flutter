import 'dart:io';
import 'package:daily_focus/database/saves_database.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

const int _version = 2;

class DBProvider {
// make this a singleton class
  DBProvider._privateConstructor();
  static final DBProvider instance = DBProvider._privateConstructor();

// only have a single app-wide reference to the database
  static Database? _database;
  Future<Database> get database async => _database ??= await _initDB();

  /// initialize the database
  Future<Database> _initDB() async {
    print('creating database');
    return await _createDatabase();
  }

  // Future<void> _createDatabase(Database db, int version) async {}
  Future<Database> _createDatabase() async {
    //get location of database
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'dailyfocus.db');
    // deleteDatabase(path);

    //open database
    return await openDatabase(path, version: _version, onOpen: (db) {},
        onCreate: (Database db, int version) async {
      await db.execute('''
      CREATE TABLE tasks(
        uuid TEXT PRIMARY KEY,
        name TEXT,
        goal INTEGER,
        progress INTEGER,
        incremental INTEGER,
        iconPoint INTEGER
      )
    ''');

      await db.execute('''
      CREATE TABLE $savesDbName(
        uuid TEXT PRIMARY KEY,
        name TEXT,
        goal INTEGER,
        progress INTEGER,
        incremental INTEGER,
        iconPoint INTEGER,
        date TEXT
      )
    ''');
    });
  }
}
