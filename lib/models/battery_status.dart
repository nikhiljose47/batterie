import 'package:flutter/material.dart';

class BatteryStatus {
  const BatteryStatus({
    required this.title,
    required this.percent,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final double percent;
  final String subtitle;
  final Color color;
}
