import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'persistence_contract.dart';

Future<AppPersistence> createPersistence() async {
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;
  final databasePath = path.join(
    await databaseFactory.getDatabasesPath(),
    'rental_facility_manager.sqlite',
  );
  final database = await databaseFactory.openDatabase(
    databasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE app_state (
            state_key TEXT PRIMARY KEY,
            schema_version INTEGER NOT NULL,
            payload TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    ),
  );
  return SqlitePersistence(database, databasePath);
}

class SqlitePersistence implements AppPersistence {
  SqlitePersistence(this._database, this.databasePath);

  static const _stateKey = 'rental_store';
  final Database _database;
  final String databasePath;

  @override
  String get storageDescription => databasePath;

  @override
  Future<String?> readSnapshot() async {
    final rows = await _database.query(
      'app_state',
      columns: ['payload'],
      where: 'state_key = ?',
      whereArgs: [_stateKey],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['payload'] as String?;
  }

  @override
  Future<void> writeSnapshot(String snapshot) async {
    await _database.insert(
      'app_state',
      {
        'state_key': _stateKey,
        'schema_version': 1,
        'payload': snapshot,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> clear() async {
    await _database.delete(
      'app_state',
      where: 'state_key = ?',
      whereArgs: [_stateKey],
    );
  }

  @override
  Future<void> close() => _database.close();
}
