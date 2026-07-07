import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/day_template.dart';
import '../models/energy_log_record.dart';

/// Storage contract for daily energy data.
///
/// The app only ever talks to this interface, so swapping SQLite for a
/// remote DB later means writing one new implementation — no UI changes.
abstract class EnergyLogStore {
  /// Replaces all records for [date] with [records] (wipe-and-write keeps
  /// edits/removals trivially consistent).
  Future<void> saveDay(String date, List<EnergyLogRecord> records);

  Future<List<EnergyLogRecord>> recordsForDate(String date);

  Future<void> saveRemark(String date, String remark);

  Future<String?> remarkForDate(String date);

  /// Creates or updates (by id) a user-saved day template.
  Future<void> saveTemplate(DayTemplate template);

  Future<List<DayTemplate>> customTemplates();

  Future<void> deleteTemplate(String id);
}

/// SQLite implementation. Works on Android/iOS out of the box; on Windows
/// and Linux `main.dart` switches sqflite to its FFI factory first.
class SqliteEnergyLogStore implements EnergyLogStore {
  SqliteEnergyLogStore._();

  static final SqliteEnergyLogStore instance = SqliteEnergyLogStore._();

  Database? _db;

  Future<Database> get _database async {
    final existing = _db;
    if (existing != null) return existing;

    final String dir;
    if (Platform.isWindows || Platform.isLinux) {
      dir = (await getApplicationSupportDirectory()).path;
    } else {
      dir = await getDatabasesPath();
    }

    final db = await openDatabase(
      p.join(dir, 'energy_logs.db'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE energy_logs(
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL,
            start_minutes INTEGER NOT NULL,
            duration_minutes INTEGER NOT NULL,
            activity_id TEXT NOT NULL,
            physical_after INTEGER NOT NULL,
            brain_after INTEGER NOT NULL
          )
        ''');
        await db
            .execute('CREATE INDEX idx_energy_logs_date ON energy_logs(date)');
        await db.execute('''
          CREATE TABLE daily_remarks(
            date TEXT PRIMARY KEY,
            remark TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE day_templates(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            emoji TEXT NOT NULL,
            items TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS day_templates(
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              emoji TEXT NOT NULL,
              items TEXT NOT NULL
            )
          ''');
        }
      },
    );
    _db = db;
    return db;
  }

  @override
  Future<void> saveDay(String date, List<EnergyLogRecord> records) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('energy_logs', where: 'date = ?', whereArgs: [date]);
      final batch = txn.batch();
      for (final record in records) {
        batch.insert('energy_logs', record.toMap());
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<List<EnergyLogRecord>> recordsForDate(String date) async {
    final db = await _database;
    final rows = await db.query(
      'energy_logs',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'start_minutes ASC',
    );
    return rows.map(EnergyLogRecord.fromMap).toList();
  }

  @override
  Future<void> saveRemark(String date, String remark) async {
    final db = await _database;
    await db.insert(
      'daily_remarks',
      <String, Object?>{'date': date, 'remark': remark},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<String?> remarkForDate(String date) async {
    final db = await _database;
    final rows = await db.query(
      'daily_remarks',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['remark'] as String?;
  }

  @override
  Future<void> saveTemplate(DayTemplate template) async {
    final db = await _database;
    await db.insert(
      'day_templates',
      <String, Object?>{
        'id': template.id,
        'name': template.name,
        'emoji': template.emoji,
        'items': template.encodeItems(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<DayTemplate>> customTemplates() async {
    final db = await _database;
    final rows = await db.query('day_templates', orderBy: 'name ASC');
    return rows
        .map((row) => DayTemplate(
              id: row['id'] as String,
              name: row['name'] as String,
              emoji: row['emoji'] as String,
              items: DayTemplate.decodeItems(row['items'] as String),
              isCustom: true,
            ))
        .toList();
  }

  @override
  Future<void> deleteTemplate(String id) async {
    final db = await _database;
    await db.delete('day_templates', where: 'id = ?', whereArgs: [id]);
  }
}
