import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/day_template.dart';
import '../models/energy_log_record.dart';
import '../models/planner_session_log.dart';

/// Storage contract for daily energy data.
///
/// The app only ever talks to this interface, so swapping SQLite for a
/// remote DB later means writing one new implementation — no UI changes.
abstract class EnergyLogStore {
  /// Replaces all records for [date] with [records] (wipe-and-write keeps
  /// edits/removals trivially consistent).
  Future<void> saveDay(
    String date,
    List<EnergyLogRecord> records, {
    String? userId,
  });

  Future<List<EnergyLogRecord>> recordsForDate(String date, {String? userId});

  Future<List<String>> activityDates({String? userId});

  Future<void> claimEnergyLogsForUser(String userId);

  Future<void> savePlannerSessionLog(PlannerSessionLog log);

  Future<List<PlannerSessionLog>> plannerSessionLogsForDate(
    String date, {
    String? userId,
  });

  Future<void> claimPlannerSessionLogsForUser(String userId);

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
      version: 6,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE energy_logs(
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            date TEXT NOT NULL,
            start_minutes INTEGER NOT NULL,
            duration_minutes INTEGER NOT NULL,
            activity_id TEXT NOT NULL,
            physical_after INTEGER NOT NULL,
            brain_after INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_energy_logs_user_date ON energy_logs(user_id, date)',
        );
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
        await db.execute('''
          CREATE TABLE planner_session_logs(
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            date TEXT NOT NULL,
            session_id TEXT NOT NULL,
            start_minutes INTEGER NOT NULL,
            end_minutes INTEGER NOT NULL,
            title TEXT NOT NULL,
            is_done INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'done'
          )
        ''');
        await db.execute('''
          CREATE UNIQUE INDEX idx_planner_session_logs_user_day_session
          ON planner_session_logs(user_id, date, session_id)
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
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS planner_session_logs(
              id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL DEFAULT 'local_legacy_user',
              date TEXT NOT NULL,
              session_id TEXT NOT NULL,
              start_minutes INTEGER NOT NULL,
              end_minutes INTEGER NOT NULL,
              title TEXT NOT NULL,
              is_done INTEGER NOT NULL,
              status TEXT NOT NULL DEFAULT 'done'
            )
          ''');
          await db.execute('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_planner_session_logs_day_session
            ON planner_session_logs(date, session_id)
          ''');
        }
        if (oldVersion < 4) {
          final columns = await db.rawQuery(
            'PRAGMA table_info(planner_session_logs)',
          );
          final hasUserId =
              columns.any((column) => column['name'] == 'user_id');
          if (!hasUserId) {
            await db.execute('''
              ALTER TABLE planner_session_logs
              ADD COLUMN user_id TEXT NOT NULL DEFAULT 'local_legacy_user'
            ''');
          }
          await db.execute(
              'DROP INDEX IF EXISTS idx_planner_session_logs_day_session');
          await db.execute('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_planner_session_logs_user_day_session
            ON planner_session_logs(user_id, date, session_id)
          ''');
        }
        if (oldVersion < 5) {
          final columns = await db.rawQuery('PRAGMA table_info(energy_logs)');
          final hasUserId =
              columns.any((column) => column['name'] == 'user_id');
          if (!hasUserId) {
            await db.execute('''
              ALTER TABLE energy_logs
              ADD COLUMN user_id TEXT NOT NULL DEFAULT 'local_legacy_user'
            ''');
          }
          await db.execute('DROP INDEX IF EXISTS idx_energy_logs_date');
          await db.execute('''
            CREATE INDEX IF NOT EXISTS idx_energy_logs_user_date
            ON energy_logs(user_id, date)
          ''');
        }
        if (oldVersion < 6) {
          final columns = await db.rawQuery(
            'PRAGMA table_info(planner_session_logs)',
          );
          final hasStatus = columns.any((column) => column['name'] == 'status');
          if (!hasStatus) {
            await db.execute('''
              ALTER TABLE planner_session_logs
              ADD COLUMN status TEXT NOT NULL DEFAULT 'done'
            ''');
            await db.execute('''
              UPDATE planner_session_logs
              SET status = CASE WHEN is_done = 1 THEN 'done' ELSE 'not_done' END
            ''');
          }
        }
      },
    );
    _db = db;
    return db;
  }

  @override
  Future<void> saveDay(
    String date,
    List<EnergyLogRecord> records, {
    String? userId,
  }) async {
    final db = await _database;
    final ownerId = userId ?? (records.isEmpty ? null : records.first.userId);
    await db.transaction((txn) async {
      await txn.delete(
        'energy_logs',
        where: ownerId == null ? 'date = ?' : 'date = ? AND user_id = ?',
        whereArgs: ownerId == null ? <Object?>[date] : <Object?>[date, ownerId],
      );
      final batch = txn.batch();
      for (final record in records) {
        batch.insert('energy_logs', record.toMap());
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<List<EnergyLogRecord>> recordsForDate(
    String date, {
    String? userId,
  }) async {
    final db = await _database;
    final where = userId == null ? 'date = ?' : 'date = ? AND user_id = ?';
    final whereArgs =
        userId == null ? <Object?>[date] : <Object?>[date, userId];
    final rows = await db.query(
      'energy_logs',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'start_minutes ASC',
    );
    return rows.map(EnergyLogRecord.fromMap).toList();
  }

  @override
  Future<List<String>> activityDates({String? userId}) async {
    final db = await _database;
    final where = userId == null ? null : 'user_id = ?';
    final whereArgs = userId == null ? null : <Object?>[userId];
    final dates = <String>{};

    final energyRows = await db.query(
      'energy_logs',
      distinct: true,
      columns: <String>['date'],
      where: where,
      whereArgs: whereArgs,
    );
    final plannerRows = await db.query(
      'planner_session_logs',
      distinct: true,
      columns: <String>['date'],
      where: where,
      whereArgs: whereArgs,
    );

    for (final row in <Map<String, Object?>>[
      ...energyRows,
      ...plannerRows,
    ]) {
      final date = row['date'] as String?;
      if (date != null && date.isNotEmpty) dates.add(date);
    }

    return dates.toList()..sort();
  }

  @override
  Future<void> claimEnergyLogsForUser(String userId) async {
    final db = await _database;
    await db.update(
      'energy_logs',
      <String, Object?>{'user_id': userId},
      where: 'user_id = ?',
      whereArgs: ['local_legacy_user'],
    );
  }

  @override
  Future<void> savePlannerSessionLog(PlannerSessionLog log) async {
    final db = await _database;
    await db.insert(
      'planner_session_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> claimPlannerSessionLogsForUser(String userId) async {
    final db = await _database;
    await db.update(
      'planner_session_logs',
      <String, Object?>{'user_id': userId},
      where: 'user_id = ?',
      whereArgs: ['local_legacy_user'],
    );
  }

  @override
  Future<List<PlannerSessionLog>> plannerSessionLogsForDate(
    String date, {
    String? userId,
  }) async {
    final db = await _database;
    final where = userId == null ? 'date = ?' : 'date = ? AND user_id = ?';
    final whereArgs =
        userId == null ? <Object?>[date] : <Object?>[date, userId];
    final rows = await db.query(
      'planner_session_logs',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'start_minutes ASC',
    );
    return rows.map(PlannerSessionLog.fromMap).toList();
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
