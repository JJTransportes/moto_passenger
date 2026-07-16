import 'package:sqflite/sqflite.dart';

class Schema {
  static const currentVersion = 2;

  static final createStatements = [
    '''
    CREATE TABLE IF NOT EXISTS metadata (
      key   TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS auth (
      id             INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id        TEXT    NOT NULL,
      access_token   TEXT    NOT NULL,
      refresh_token  TEXT    DEFAULT '',
      roles          TEXT    NOT NULL,
      expires_at     TEXT,
      created_at     TEXT    NOT NULL DEFAULT (datetime('now'))
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS user_profile (
      user_id    TEXT PRIMARY KEY,
      full_name  TEXT NOT NULL,
      email      TEXT NOT NULL,
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS travels (
      travel_id           TEXT PRIMARY KEY,
      status              TEXT NOT NULL,
      driver_name         TEXT,
      passenger_name      TEXT,
      departure_address   TEXT,
      destination_address TEXT,
      created_at          TEXT NOT NULL,
      started_at          TEXT,
      finished_at         TEXT,
      cached_at           TEXT NOT NULL DEFAULT (datetime('now'))
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS active_travel (
      id          INTEGER PRIMARY KEY CHECK (id = 1),
      travel_id   TEXT NOT NULL UNIQUE,
      status      TEXT NOT NULL,
      driver_name TEXT,
      created_at  TEXT NOT NULL,
      cached_at   TEXT NOT NULL DEFAULT (datetime('now'))
    )
    ''',
  ];

  static Future<void> onCreate(Database db, int version) async {
    for (final stmt in createStatements) {
      await db.execute(stmt);
    }
    await db.insert('metadata', {
      'key': 'db_version',
      'value': version.toString(),
    });
  }

  static Future<void> onUpgrade(Database db, int oldVersion,
      int newVersion) async {
    // Migration 1→2: add refresh_token column to auth table
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE auth ADD COLUMN refresh_token TEXT DEFAULT \'\'');
      } catch (_) {
        // Column may already exist — ignore
      }
    }
    await db.update(
      'metadata',
      {'value': newVersion.toString()},
      where: 'key = ?',
      whereArgs: ['db_version'],
    );
  }
}
