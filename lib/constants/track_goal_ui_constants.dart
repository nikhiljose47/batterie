import 'package:flutter/material.dart';

import 'app_colors.dart';

class TrackGoalSectionInfo {
  const TrackGoalSectionInfo({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;
}

class TrackGoalUiConstants {
  const TrackGoalUiConstants._();

  static const List<TrackGoalSectionInfo> sections = <TrackGoalSectionInfo>[
    TrackGoalSectionInfo(
      title: 'Morning',
      icon: Icons.wb_sunny_rounded,
      color: Color(0xFFE0A224),
    ),
    TrackGoalSectionInfo(
      title: 'Daytime',
      icon: Icons.center_focus_strong_rounded,
      color: AppColors.info,
    ),
    TrackGoalSectionInfo(
      title: 'Evening',
      icon: Icons.fitness_center_rounded,
      color: AppColors.brainEnergy,
    ),
    TrackGoalSectionInfo(
      title: 'Night',
      icon: Icons.nights_stay_rounded,
      color: Color(0xFF4F46E5),
    ),
  ];

  static TrackGoalSectionInfo sectionForCardIndex(int index) {
    if (index == 0) return sections[0];
    if (index <= 3) return sections[1];
    if (index <= 5) return sections[2];
    return sections[3];
  }
}
