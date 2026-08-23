class PlannerSessionStatus {
  const PlannerSessionStatus._();

  static const String done = 'done';
  static const String partial = 'partial';
  static const String notDone = 'not_done';

  static String normalize(Object? value, {required bool isDone}) {
    final text = value is String ? value.trim() : '';
    return switch (text) {
      done || partial || notDone => text,
      _ => isDone ? done : notDone,
    };
  }
}

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
    String? status,
  }) : status = status ??
            (isDone ? PlannerSessionStatus.done : PlannerSessionStatus.notDone);

  final String id;
  final String userId;
  final String date;
  final String sessionId;
  final int startMinutes;
  final int endMinutes;
  final String title;
  final bool isDone;
  final String status;

  bool get isPartiallyDone => status == PlannerSessionStatus.partial;
  bool get isExplicitlyNotDone => status == PlannerSessionStatus.notDone;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'user_id': userId,
        'date': date,
        'session_id': sessionId,
        'start_minutes': startMinutes,
        'end_minutes': endMinutes,
        'title': title,
        'is_done': isDone ? 1 : 0,
        'status': status,
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
      status: PlannerSessionStatus.normalize(
        map['status'],
        isDone: (map['is_done'] as int) == 1,
      ),
    );
  }
}
