import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/day_template.dart';
import '../models/energy_log_record.dart';
import '../models/planner_session_log.dart';
import 'remote_sync.dart';

class FirestoreRemoteSync implements RemoteSync {
  FirestoreRemoteSync({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  Object get _serverTime => FieldValue.serverTimestamp();

  Future<void> _tryWrite(Future<void> Function() write) async {
    try {
      await write();
    } catch (_) {}
  }

  @override
  Future<void> upsertProfile({
    required String userId,
    required String name,
    required String plannerMode,
    String? photoUrl,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _tryWrite(() {
      return _firestore.collection('users').doc(uid).set(
        <String, Object?>{
          'user_id': uid,
          'name': name,
          'planner_mode': plannerMode,
          if (photoUrl != null) 'photo_url': photoUrl,
          'updated_at': _serverTime,
        },
        SetOptions(merge: true),
      );
    });
  }

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
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _tryWrite(() {
      return _firestore
          .collection('daily_progress')
          .doc('${uid}_${progress.dateKey}')
          .set(
        <String, Object?>{
          ...progress.toMap(),
          'user_id': uid,
          'cloud_write_count': FieldValue.increment(1),
          'updated_at': _serverTime,
        },
        SetOptions(merge: true),
      );
    });
  }

  @override
  Future<List<DailyProgressRecord>> fetchDailyProgress({
    required String dateKey,
    int limit = 7,
  }) async {
    final uid = _uid;
    if (uid == null) return const <DailyProgressRecord>[];
    try {
      final snapshot = await _firestore
          .collection('daily_progress')
          .where('date_key', isEqualTo: dateKey)
          .orderBy('score_percent', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs
          .map((doc) => DailyProgressRecord.fromMap(doc.data()))
          .toList(growable: false);
    } catch (_) {
      return const <DailyProgressRecord>[];
    }
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
