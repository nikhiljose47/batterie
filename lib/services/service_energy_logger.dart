import '../engine/energy_score_engine.dart';
import '../models/energy_log_record.dart';
import '../pages/profile/profile_store.dart';
import 'energy_log_store.dart';
import 'remote_sync.dart';

class ServiceEnergyLogger {
  const ServiceEnergyLogger._();

  static const ServiceEnergyLogger instance = ServiceEnergyLogger._();
  static const EnergyScoreEngine _engine = EnergyScoreEngine();

  Future<void> addServiceLog({
    required String sourceId,
    required String activityId,
    required DateTime at,
    int durationMinutes = 5,
  }) async {
    final userId = ProfileStore.instance.userId.value;
    final dayKey = dateKey(at);
    final store = SqliteEnergyLogStore.instance;
    await store.claimEnergyLogsForUser(userId);

    final records = await store.recordsForDate(dayKey, userId: userId);
    records.add(
      EnergyLogRecord(
        id: _idFor(sourceId, at),
        userId: userId,
        date: dayKey,
        startMinutes: at.hour * 60 + at.minute,
        durationMinutes: durationMinutes.clamp(1, 1440).toInt(),
        activityId: activityId,
        physicalAfter: 0,
        brainAfter: 0,
      ),
    );

    final recomputed = _recompute(records, userId);
    await store.saveDay(dayKey, recomputed, userId: userId);
    for (final record in recomputed) {
      await RemoteSync.instance.upsertEnergyLog(record, userId: userId);
    }
  }

  List<EnergyLogRecord> _recompute(
    List<EnergyLogRecord> records,
    String userId,
  ) {
    var energy = _engine.createDailyBaseline(28, 8.0, 0.7);
    final sorted = <EnergyLogRecord>[...records]
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return <EnergyLogRecord>[
      for (final record in sorted)
        () {
          energy = _engine.applyActivity(
            energy,
            record.activityId,
            record.durationMinutes,
            28,
          );
          return EnergyLogRecord(
            id: record.id,
            userId: userId,
            date: record.date,
            startMinutes: record.startMinutes,
            durationMinutes: record.durationMinutes,
            activityId: record.activityId,
            physicalAfter: energy.physical,
            brainAfter: energy.brain,
          );
        }(),
    ];
  }

  String _idFor(String sourceId, DateTime at) =>
      'svc_${sourceId}_${at.microsecondsSinceEpoch}';
}
