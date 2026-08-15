class PlannerSessionLog {
  const PlannerSessionLog({
    required this.id,
    required this.userId,
    required this.date,
    required this.sessionId,
    required this.startMinutes,
    required this.endMinutes,
    required this.title,
    required this.isDone,
  });

  final String id;
  final String userId;
  final String date;
  final String sessionId;
  final int startMinutes;
  final int endMinutes;
  final String title;
  final bool isDone;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'user_id': userId,
        'date': date,
        'session_id': sessionId,
        'start_minutes': startMinutes,
        'end_minutes': endMinutes,
        'title': title,
        'is_done': isDone ? 1 : 0,
      };

  factory PlannerSessionLog.fromMap(Map<String, Object?> map) {
    return PlannerSessionLog(
      id: map['id'] as String,
      userId: (map['user_id'] as String?) ?? 'local_legacy_user',
      date: map['date'] as String,
      sessionId: map['session_id'] as String,
      startMinutes: map['start_minutes'] as int,
      endMinutes: map['end_minutes'] as int,
      title: map['title'] as String,
      isDone: (map['is_done'] as int) == 1,
    );
  }
}
