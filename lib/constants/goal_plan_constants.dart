class GoalPlanConstants {
  const GoalPlanConstants._();

  static const String allTag = 'all';
  static const String defaultTag = 'balance';

  static const List<String> tags = <String>[
    'exam',
    'focus',
    'fitness',
    'nicotine',
    'language',
    'balance',
    'morning',
    'night',
    'student',
    'work',
    'health',
    'habit',
    'recovery',
    'discipline',
    'learning',
    'productivity',
    'calm',
    'sleep',
    'diet',
    'social',
  ];

  static String normalizeTag(String value) {
    final normalized = value.trim().toLowerCase();
    return tags.contains(normalized) ? normalized : defaultTag;
  }

  static String labelFor(String tag) {
    if (tag == allTag) return 'All';
    final normalized = normalizeTag(tag);
    return normalized[0].toUpperCase() + normalized.substring(1);
  }
}
