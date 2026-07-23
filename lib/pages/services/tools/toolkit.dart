import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../constants/app_colors.dart';

// ═══════════════════════════════════════════════════════════════════════
//  SERVICES TOOLKIT — shared storage + UI bits every mini-app uses.
//
//  Storage model: each service persists JSON under its own prefs keys,
//  namespaced `svc.<serviceId>.<what>`. Lists hold Map<String,dynamic>
//  entries; single settings go in a map. Everything is on-device only.
// ═══════════════════════════════════════════════════════════════════════

class ServiceStore {
  static Future<List<Map<String, dynamic>>> loadList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Future<void> saveList(
      String key, List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(items));
  }

  static Future<Map<String, dynamic>> loadMap(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Future<void> saveMap(String key, Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }
}

/// YYYY-MM-DD key for a day.
String svcDay(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Pretty label for a YYYY-MM-DD key: Today / Yesterday / "Mon 14 Jul".
String svcDayLabel(String key) {
  final now = DateTime.now();
  if (key == svcDay(now)) return 'Today';
  if (key == svcDay(now.subtract(const Duration(days: 1)))) return 'Yesterday';
  final parts = key.split('-').map(int.parse).toList();
  final d = DateTime(parts[0], parts[1], parts[2]);
  const wd = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const mo = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${wd[d.weekday - 1]} ${d.day} ${mo[d.month - 1]}';
}

/// "7:05 PM" from a DateTime.
String svcClock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

// ── Shared widgets ───────────────────────────────────────────────────────

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 6, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class WhiteCard extends StatelessWidget {
  const WhiteCard({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline.withOpacity(0.8)),
      ),
      child: child,
    );
  }
}

class EmptyHint extends StatelessWidget {
  const EmptyHint(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            fontStyle: FontStyle.italic,
            color: AppColors.textMuted.withOpacity(0.8),
          ),
        ),
      ),
    );
  }
}

class SvcChip extends StatelessWidget {
  const SvcChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.outline.withOpacity(0.9),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF2A2E3B),
          ),
        ),
      ),
    );
  }
}

/// Thin app bar used by every service page.
PreferredSizeWidget svcAppBar(String title) {
  return AppBar(
    toolbarHeight: 44,
    scrolledUnderElevation: 0,
    title: Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
  );
}
