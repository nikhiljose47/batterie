import '../models/day_template.dart';
import '../models/energy_log_record.dart';
import '../models/planner_session_log.dart';

class DailyProgressRecord {
  const DailyProgressRecord({
    required this.userId,
    required this.dateKey,
    required this.displayName,
    required this.plannerMode,
    required this.serviceActionCount,
    required this.appUseMinutes,
    required this.focusMinutes,
    required this.goalDoneCount,
    required this.goalPartialCount,
    required this.goalTotalCount,
    required this.completionPercent,
    required this.scorePercent,
  });

  final String userId;
  final String dateKey;
  final String displayName;
  final String plannerMode;
  final int serviceActionCount;
  final int appUseMinutes;
  final int focusMinutes;
  final int goalDoneCount;
  final int goalPartialCount;
  final int goalTotalCount;
  final int completionPercent;
  final int scorePercent;

  Map<String, Object?> toMap() => <String, Object?>{
        'user_id': userId,
        'date_key': dateKey,
        'display_name': displayName,
        'planner_mode': plannerMode,
        'service_action_count': serviceActionCount,
        'app_use_minutes': appUseMinutes,
        'focus_minutes': focusMinutes,
        'goal_done_count': goalDoneCount,
        'goal_partial_count': goalPartialCount,
        'goal_total_count': goalTotalCount,
        'completion_percent': completionPercent,
        'score_percent': scorePercent,
      };

  factory DailyProgressRecord.fromMap(Map<String, dynamic> map) {
    return DailyProgressRecord(
      userId: (map['user_id'] as String?) ?? '',
      dateKey: (map['date_key'] as String?) ?? '',
      displayName: (map['display_name'] as String?) ?? 'You',
      plannerMode: (map['planner_mode'] as String?) ?? 'healthy',
      serviceActionCount: (map['service_action_count'] as num?)?.round() ?? 0,
      appUseMinutes: (map['app_use_minutes'] as num?)?.round() ?? 0,
      focusMinutes: (map['focus_minutes'] as num?)?.round() ?? 0,
      goalDoneCount: (map['goal_done_count'] as num?)?.round() ?? 0,
      goalPartialCount: (map['goal_partial_count'] as num?)?.round() ?? 0,
      goalTotalCount: (map['goal_total_count'] as num?)?.round() ?? 0,
      completionPercent: (map['completion_percent'] as num?)?.round() ?? 0,
      scorePercent: (map['score_percent'] as num?)?.round() ?? 0,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Remote Sync — Supabase migration layer
// ═════════════════════════════════════════════════════════════════════════════
//
// HOW TO MIGRATE TO SUPABASE
// ─────────────────────────────────────────────────────────────────────────────
// 1. Add dependency to pubspec.yaml:
//      supabase_flutter: ^2.x.x
//
// 2. Create the tables below in your Supabase SQL editor (copy-paste each block).
//
// 3. In main.dart, before runApp():
//      await Supabase.initialize(url: 'YOUR_URL', anonKey: 'YOUR_ANON_KEY');
//      RemoteSync.use(SupabaseRemoteSync());
//
// 4. Implement sign-in (email magic link / OAuth) and set a real userId.
//    Until a user signs in, _userId returns null and all sync calls are skipped.
//
// Everything else in the app — stores, widgets, models — stays unchanged.
// ─────────────────────────────────────────────────────────────────────────────
//
// ── Supabase SQL schemas ────────────────────────────────────────────────────
//
// -- Enable Row Level Security on every table after creation.
//
// create table if not exists profiles (
//   id          uuid primary key references auth.users on delete cascade,
//   name        text    not null default 'You',
//   planner_mode text   not null default 'healthy',
//   photo_url   text,            -- Supabase Storage URL, not a local path
//   updated_at  timestamptz not null default now()
// );
// alter table profiles enable row level security;
// create policy "owner" on profiles for all using (auth.uid() = id);
//
// create table if not exists energy_logs (
//   id                  text primary key,   -- same id as local SQLite row
//   user_id             uuid not null references auth.users on delete cascade,
//   date_key            text not null,       -- 'YYYY-MM-DD'
//   start_minutes       int  not null,
//   duration_minutes    int  not null,
//   activity_id         text not null,
//   physical_after      int  not null,
//   brain_after         int  not null,
//   synced_at           timestamptz not null default now()
// );
// alter table energy_logs enable row level security;
// create policy "owner" on energy_logs for all using (auth.uid() = user_id);
// create index on energy_logs (user_id, date_key);
//
// create table if not exists daily_remarks (
//   user_id     uuid not null references auth.users on delete cascade,
//   date_key    text not null,
//   remark      text not null,
//   updated_at  timestamptz not null default now(),
//   primary key (user_id, date_key)
// );
// alter table daily_remarks enable row level security;
// create policy "owner" on daily_remarks for all using (auth.uid() = user_id);
//
// create table if not exists day_templates (
//   id         text primary key,
//   user_id    uuid not null references auth.users on delete cascade,
//   name       text not null,
//   emoji      text not null,
//   items      jsonb not null,   -- same JSON as DayTemplate.encodeItems()
//   created_at timestamptz not null default now()
// );
// alter table day_templates enable row level security;
// create policy "owner" on day_templates for all using (auth.uid() = user_id);
//
// create table if not exists planner_session_logs (
//   id              text primary key,
//   user_id         uuid not null references auth.users on delete cascade,
//   date_key        text not null,
//   session_id      text not null,
//   start_minutes   int  not null,
//   end_minutes     int  not null,
//   title           text not null,
//   is_done         bool not null,
//   status          text not null default 'done',
//   updated_at      timestamptz not null default now(),
//   unique (user_id, date_key, session_id)
// );
// alter table planner_session_logs enable row level security;
// create policy "owner" on planner_session_logs for all using (auth.uid() = user_id);
// create index on planner_session_logs (user_id, date_key);
//
// create table if not exists daily_progress (
//   user_id              uuid not null references auth.users on delete cascade,
//   date_key             text not null,
//   display_name         text not null,
//   planner_mode         text not null,
//   service_action_count int not null default 0,
//   app_use_minutes      int not null default 0,
//   focus_minutes        int not null default 0,
//   goal_done_count      int not null default 0,
//   goal_partial_count   int not null default 0,
//   goal_total_count     int not null default 0,
//   completion_percent   int not null default 0,
//   score_percent        int not null default 0,
//   updated_at           timestamptz not null default now(),
//   primary key (user_id, date_key)
// );
// alter table daily_progress enable row level security;
// create policy "owner-write" on daily_progress for all using (auth.uid() = user_id);
// create policy "signed-in-read" on daily_progress for select using (auth.uid() is not null);
//
// ─────────────────────────────────────────────────────────────────────────────

/// Contract for every remote write the app performs.
///
/// The default implementation ([NoOpRemoteSync]) does nothing — all data stays
/// local.  Swap it for [SupabaseRemoteSync] (below) to get cloud persistence.
abstract class RemoteSync {
  static RemoteSync _instance = const NoOpRemoteSync();

  /// The active sync implementation — NoOp by default.
  static RemoteSync get instance => _instance;

  /// Call once at startup (after Supabase.initialize) to switch backends.
  ///   RemoteSync.use(SupabaseRemoteSync());
  static void use(RemoteSync impl) => _instance = impl;

  // ── Profile ───────────────────────────────────────────────────────────────

  /// Called whenever the user's display name or planner mode changes.
  Future<void> upsertProfile({
    required String userId,
    required String name,
    required String plannerMode,
    String? photoUrl,
  });

  // ── Energy log ────────────────────────────────────────────────────────────

  /// Called after every energy log insert.
  Future<void> upsertEnergyLog(EnergyLogRecord record,
      {required String userId});

  /// Called after an energy log entry is deleted locally.
  Future<void> deleteEnergyLog(String id, {required String userId});

  // ── Planner session logs ─────────────────────────────────────────────────

  /// Called when a Today Plan card is marked done/not done.
  Future<void> upsertPlannerSessionLog(
    PlannerSessionLog log, {
    required String userId,
  });

  Future<void> upsertDailyProgress(
    DailyProgressRecord progress, {
    required String userId,
  });

  Future<List<DailyProgressRecord>> fetchDailyProgress({
    required String dateKey,
    int limit = 7,
  });

  // ── Daily remarks ─────────────────────────────────────────────────────────

  Future<void> upsertRemark({
    required String userId,
    required String dateKey,
    required String remark,
  });

  // ── Day templates ─────────────────────────────────────────────────────────

  /// Called after a custom template is saved.
  Future<void> upsertTemplate(DayTemplate template, {required String userId});

  /// Called after a custom template is deleted.
  Future<void> deleteTemplate(String id, {required String userId});
}

// ─────────────────────────────────────────────────────────────────────────────
//  Default: no-op — zero dependencies, zero network calls
// ─────────────────────────────────────────────────────────────────────────────

class NoOpRemoteSync implements RemoteSync {
  const NoOpRemoteSync();

  @override
  Future<void> upsertProfile({
    required String userId,
    required String name,
    required String plannerMode,
    String? photoUrl,
  }) async {}

  @override
  Future<void> upsertEnergyLog(
    EnergyLogRecord record, {
    required String userId,
  }) async {}

  @override
  Future<void> deleteEnergyLog(String id, {required String userId}) async {}

  @override
  Future<void> upsertPlannerSessionLog(
    PlannerSessionLog log, {
    required String userId,
  }) async {}

  @override
  Future<void> upsertDailyProgress(
    DailyProgressRecord progress, {
    required String userId,
  }) async {}

  @override
  Future<List<DailyProgressRecord>> fetchDailyProgress({
    required String dateKey,
    int limit = 7,
  }) async {
    return const <DailyProgressRecord>[];
  }

  @override
  Future<void> upsertRemark({
    required String userId,
    required String dateKey,
    required String remark,
  }) async {}

  @override
  Future<void> upsertTemplate(
    DayTemplate template, {
    required String userId,
  }) async {}

  @override
  Future<void> deleteTemplate(String id, {required String userId}) async {}
}

// ─────────────────────────────────────────────────────────────────────────────
//  Supabase implementation (uncomment when ready)
// ─────────────────────────────────────────────────────────────────────────────
//
// import 'package:supabase_flutter/supabase_flutter.dart';
//
// class SupabaseRemoteSync implements RemoteSync {
//   SupabaseClient get _db => Supabase.instance.client;
//
//   /// Returns the signed-in user's UUID, or null if not authenticated.
//   /// Sync calls are silently skipped when null — local-only mode.
//   String? get _userId => _db.auth.currentUser?.id;
//
//   @override
//   Future<void> upsertProfile({
//     required String userId,
//     required String name,
//     required String plannerMode,
//     String? photoUrl,
//   }) async {
//     final id = _userId;
//     if (id == null) return;
//     await _db.from('profiles').upsert({
//       'id': id,
//       'name': name,
//       'planner_mode': plannerMode,
//       if (photoUrl != null) 'photo_url': photoUrl,
//       'updated_at': DateTime.now().toIso8601String(),
//     });
//   }
//
//   @override
//   Future<void> upsertEnergyLog(
//     EnergyLogRecord record, {
//     required String userId,
//   }) async {
//     final id = _userId;
//     if (id == null) return;
//     await _db.from('energy_logs').upsert({
//       'id': record.id,
//       'user_id': id,
//       'date_key': record.date,
//       'start_minutes': record.startMinutes,
//       'duration_minutes': record.durationMinutes,
//       'activity_id': record.activityId,
//       'physical_after': record.physicalAfter,
//       'brain_after': record.brainAfter,
//       'synced_at': DateTime.now().toIso8601String(),
//     });
//   }
//
//   @override
//   Future<void> deleteEnergyLog(String id, {required String userId}) async {
//     final uid = _userId;
//     if (uid == null) return;
//     await _db.from('energy_logs').delete()
//         .eq('id', id).eq('user_id', uid);
//   }
//
//   @override
//   Future<void> upsertPlannerSessionLog(
//     PlannerSessionLog log, {
//     required String userId,
//   }) async {
//     final id = _userId;
//     if (id == null) return;
//     await _db.from('planner_session_logs').upsert({
//       'id': log.id,
//       'user_id': id,
//       'date_key': log.date,
//       'session_id': log.sessionId,
//       'start_minutes': log.startMinutes,
//       'end_minutes': log.endMinutes,
//       'title': log.title,
//       'is_done': log.isDone,
//       'status': log.status,
//       'updated_at': DateTime.now().toIso8601String(),
//     });
//   }
//
//   @override
//   Future<void> upsertRemark({
//     required String userId,
//     required String dateKey,
//     required String remark,
//   }) async {
//     final id = _userId;
//     if (id == null) return;
//     await _db.from('daily_remarks').upsert({
//       'user_id': id,
//       'date_key': dateKey,
//       'remark': remark,
//       'updated_at': DateTime.now().toIso8601String(),
//     });
//   }
//
//   @override
//   Future<void> upsertTemplate(
//     DayTemplate template, {
//     required String userId,
//   }) async {
//     final id = _userId;
//     if (id == null) return;
//     await _db.from('day_templates').upsert({
//       'id': template.id,
//       'user_id': id,
//       'name': template.name,
//       'emoji': template.emoji,
//       'items': template.encodeItems(),
//     });
//   }
//
//   @override
//   Future<void> deleteTemplate(String id, {required String userId}) async {
//     final uid = _userId;
//     if (uid == null) return;
//     await _db.from('day_templates').delete()
//         .eq('id', id).eq('user_id', uid);
//   }
// }
