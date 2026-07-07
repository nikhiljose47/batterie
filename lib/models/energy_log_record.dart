/// One persisted timeline entry plus the energy it resulted in.
/// Shaped like a DB row (toMap/fromMap) so it maps 1:1 onto SQLite today
/// and any server DB later.
class EnergyLogRecord {
  const EnergyLogRecord({
    required this.id,
    required this.date,
    required this.startMinutes,
    required this.durationMinutes,
    required this.activityId,
    required this.physicalAfter,
    required this.brainAfter,
  });

  final String id;

  /// Day key in YYYY-MM-DD.
  final String date;
  final int startMinutes;
  final int durationMinutes;
  final String activityId;

  /// Energy scores (0–100) right after this activity was applied.
  final int physicalAfter;
  final int brainAfter;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'date': date,
        'start_minutes': startMinutes,
        'duration_minutes': durationMinutes,
        'activity_id': activityId,
        'physical_after': physicalAfter,
        'brain_after': brainAfter,
      };

  factory EnergyLogRecord.fromMap(Map<String, Object?> map) {
    return EnergyLogRecord(
      id: map['id'] as String,
      date: map['date'] as String,
      startMinutes: map['start_minutes'] as int,
      durationMinutes: map['duration_minutes'] as int,
      activityId: map['activity_id'] as String,
      physicalAfter: map['physical_after'] as int,
      brainAfter: map['brain_after'] as int,
    );
  }
}

/// YYYY-MM-DD key for a given day.
String dateKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
