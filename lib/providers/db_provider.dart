import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DBProvider {
  DBProvider._internal() {
    if (_database == null) database;
  }
  static final DBProvider instance = DBProvider._internal();

  /// sqflite datbase instance
  static Database? _database;

  /// gets database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  /// initialize the database
  Future<Database> _initDB() async {
    print('creating databse');
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'dailyfocus.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks(
        uuid TEXT PRIMARY KEY,
        name TEXT,
        goal INTEGER,
        progress REAL,
        incremental INTEGER
      )
    ''');
  }
}
