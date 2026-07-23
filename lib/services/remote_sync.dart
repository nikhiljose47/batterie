import '../models/day_template.dart';
import '../models/energy_log_record.dart';

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
//   planner_mode text   not null default 'normal',
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
  Future<void> upsertEnergyLog(EnergyLogRecord record, {required String userId});

  /// Called after an energy log entry is deleted locally.
  Future<void> deleteEnergyLog(String id, {required String userId});

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
//       ...record.toMap(),
//       'user_id': id,
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
