import 'dart:convert';

/// One activity placed at a fixed time inside a [DayTemplate].
class TemplateActivity {
  const TemplateActivity({
    required this.activityId,
    required this.startMinutes,
    required this.durationMinutes,
  });

  final String activityId;
  final int startMinutes;
  final int durationMinutes;

  TemplateActivity copyWith({int? startMinutes, int? durationMinutes}) {
    return TemplateActivity(
      activityId: activityId,
      startMinutes: startMinutes ?? this.startMinutes,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'activityId': activityId,
        'startMinutes': startMinutes,
        'durationMinutes': durationMinutes,
      };

  factory TemplateActivity.fromMap(Map<String, Object?> map) {
    return TemplateActivity(
      activityId: map['activityId'] as String,
      startMinutes: map['startMinutes'] as int,
      durationMinutes: map['durationMinutes'] as int,
    );
  }
}

/// A reusable "shape" for a day — a set of activities at fixed times that can
/// be applied to today's rail in one tap, then customized and saved again.
class DayTemplate {
  const DayTemplate({
    required this.id,
    required this.name,
    required this.emoji,
    required this.items,
    this.isCustom = false,
  });

  final String id;
  final String name;
  final String emoji;
  final List<TemplateActivity> items;
  final bool isCustom;

  DayTemplate copyWith({
    String? id,
    String? name,
    String? emoji,
    List<TemplateActivity>? items,
    bool? isCustom,
  }) {
    return DayTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      items: items ?? this.items,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  String encodeItems() =>
      jsonEncode(items.map((item) => item.toMap()).toList());

  static List<TemplateActivity> decodeItems(String json) {
    final decoded = jsonDecode(json) as List<dynamic>;
    return decoded
        .map((e) => TemplateActivity.fromMap(e as Map<String, Object?>))
        .toList();
  }
}

/// Curated starting points shown at the top of the day planner sheet.
const List<DayTemplate> prefilledDayTemplates = <DayTemplate>[
  DayTemplate(
    id: 'tpl_balanced',
    name: 'Balanced work day',
    emoji: '🧭',
    items: <TemplateActivity>[
      TemplateActivity(
          activityId: 'brisk_walking', startMinutes: 7 * 60, durationMinutes: 20),
      TemplateActivity(
          activityId: 'focused_coding', startMinutes: 9 * 60, durationMinutes: 90),
      TemplateActivity(
          activityId: 'meal_break_away_from_desk',
          startMinutes: 12 * 60 + 30,
          durationMinutes: 30),
      TemplateActivity(
          activityId: 'video_meeting_for_work',
          startMinutes: 14 * 60,
          durationMinutes: 60),
      TemplateActivity(
          activityId: 'mindfulness_meditation',
          startMinutes: 17 * 60,
          durationMinutes: 15),
    ],
  ),
  DayTemplate(
    id: 'tpl_gym',
    name: 'Gym focus day',
    emoji: '🏋️',
    items: <TemplateActivity>[
      TemplateActivity(
          activityId: 'hiit_workout',
          startMinutes: 6 * 60 + 30,
          durationMinutes: 30),
      TemplateActivity(
          activityId: 'cooking_light_meal',
          startMinutes: 7 * 60 + 30,
          durationMinutes: 20),
      TemplateActivity(
          activityId: 'focused_coding', startMinutes: 9 * 60, durationMinutes: 120),
      TemplateActivity(
          activityId: 'easy_walking', startMinutes: 13 * 60, durationMinutes: 15),
      TemplateActivity(
          activityId: 'slow_breathing_exercise',
          startMinutes: 20 * 60,
          durationMinutes: 10),
    ],
  ),
  DayTemplate(
    id: 'tpl_recovery',
    name: 'Recovery day',
    emoji: '🌿',
    items: <TemplateActivity>[
      TemplateActivity(
          activityId: 'mindfulness_meditation',
          startMinutes: 8 * 60,
          durationMinutes: 20),
      TemplateActivity(
          activityId: 'easy_walking', startMinutes: 10 * 60, durationMinutes: 25),
      TemplateActivity(
          activityId: 'cooking_light_meal',
          startMinutes: 12 * 60,
          durationMinutes: 30),
      TemplateActivity(
          activityId: 'power_nap_10_20_min',
          startMinutes: 14 * 60,
          durationMinutes: 20),
      TemplateActivity(
          activityId: 'deep_house_cleaning',
          startMinutes: 16 * 60,
          durationMinutes: 45),
    ],
  ),
  DayTemplate(
    id: 'tpl_deepwork',
    name: 'Deep work sprint',
    emoji: '💻',
    items: <TemplateActivity>[
      TemplateActivity(
          activityId: 'focused_coding', startMinutes: 8 * 60, durationMinutes: 120),
      TemplateActivity(
          activityId: 'meal_break_away_from_desk',
          startMinutes: 11 * 60,
          durationMinutes: 30),
      TemplateActivity(
          activityId: 'focused_coding', startMinutes: 13 * 60, durationMinutes: 120),
      TemplateActivity(
          activityId: 'brisk_walking', startMinutes: 16 * 60, durationMinutes: 20),
      TemplateActivity(
          activityId: 'email_and_message_backlog',
          startMinutes: 17 * 60,
          durationMinutes: 45),
    ],
  ),
];
