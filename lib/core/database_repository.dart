import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class DatabaseRepository {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    String dbPath = join(await getDatabasesPath(), 'tracking_session.db');

    return await openDatabase(
      dbPath,
      version: 1,
      onOpen: (db) async {
        // ENFORCEMENT: Execute schema validation on every connection instance.
        // This mitigates the ghost-file caching issue by ensuring the table
        // is verified or created every single time Dart touches the database.
        await db.execute('''
          CREATE TABLE IF NOT EXISTS locations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            latitude REAL,
            longitude REAL,
            timestamp INTEGER,
            accuracy REAL
          )
        ''');
        if (kDebugMode) {
          print("SYSTEM METRIC: SQLite schema enforced via onOpen lifecycle.");
        }
      },
    );
  }

  static Future<List<Map<String, dynamic>>> fetchTelemetryLog() async {
    try {
      final db = await database;
      return await db.query('locations', orderBy: 'timestamp DESC');
    } catch (e) {
      if (kDebugMode) {
        print("SYSTEM METRIC: Disk Read Failure - $e");
      }
      return [];
    }
  }
}
