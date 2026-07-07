/// A single activity placed on the day timeline rail.
class LoggedActivity {
  const LoggedActivity({
    required this.id,
    required this.activityId,
    required this.startMinutes,
    required this.durationMinutes,
  });

  final String id;
  final String activityId;

  /// Minutes from midnight (0–1439).
  final int startMinutes;
  final int durationMinutes;

  int get endMinutes => startMinutes + durationMinutes;

  LoggedActivity copyWith({int? startMinutes, int? durationMinutes}) {
    return LoggedActivity(
      id: id,
      activityId: activityId,
      startMinutes: startMinutes ?? this.startMinutes,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }
}

const Map<String, String> activityEmojis = <String, String>{
  'focused_coding': '💻',
  'email_and_message_backlog': '📧',
  'video_meeting_for_work': '🎥',
  'social_media_scrolling': '📱',
  'easy_walking': '🚶',
  'brisk_walking': '🥾',
  'running_easy_pace': '🏃',
  'hiit_workout': '🏋️',
  'cooking_light_meal': '🍳',
  'deep_house_cleaning': '🧹',
  'slow_breathing_exercise': '🌬️',
  'mindfulness_meditation': '🧘',
  'power_nap_10_20_min': '😴',
  'meal_break_away_from_desk': '🍽️',
};

String formatMinutes(int minutes) {
  final h = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  final period = h >= 12 ? 'PM' : 'AM';
  final hour12 = h % 12 == 0 ? 12 : h % 12;
  return '$hour12:${m.toString().padLeft(2, '0')} $period';
}
