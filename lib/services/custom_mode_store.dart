import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One editable planner slot for the user's "Custom" mode.
/// Order matches `plannerSlots` in `mode_advice.dart` — 7 entries total.
class CustomSlot {
  const CustomSlot({
    this.recommendation = '',
    this.tip = '',
    this.crowd = '',
  });

  final String recommendation;
  final String tip;
  final String crowd;

  bool get isEmpty =>
      recommendation.isEmpty && tip.isEmpty && crowd.isEmpty;

  CustomSlot copyWith({String? recommendation, String? tip, String? crowd}) {
    return CustomSlot(
      recommendation: recommendation ?? this.recommendation,
      tip: tip ?? this.tip,
      crowd: crowd ?? this.crowd,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'rec': recommendation,
        'tip': tip,
        'crowd': crowd,
      };

  factory CustomSlot.fromJson(Map<String, dynamic> j) => CustomSlot(
        recommendation: (j['rec'] as String?) ?? '',
        tip: (j['tip'] as String?) ?? '',
        crowd: (j['crowd'] as String?) ?? '',
      );
}

/// Persists the user's "Custom" mode: a per-slot list of recommendation +
/// tip + crowd, edited via the Daily Planner service and read by the home
/// tab's planner cards when [ProfileStore.plannerMode] is `custom`.
class CustomModeStore {
  CustomModeStore._();
  static final CustomModeStore instance = CustomModeStore._();

  static const _key = 'mode.custom.slots.v1';

  /// Number of slots — must match `plannerSlots.length`. Kept as a constant
  /// so the store doesn't need to import the UI layer.
  static const int slotCount = 7;

  final ValueNotifier<List<CustomSlot>> slots = ValueNotifier<List<CustomSlot>>(
    List<CustomSlot>.filled(slotCount, const CustomSlot()),
  );

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => CustomSlot.fromJson(e as Map<String, dynamic>))
          .toList();
      // Pad or truncate to the current slot count so an older cache still
      // works after we change `plannerSlots`.
      while (list.length < slotCount) {
        list.add(const CustomSlot());
      }
      slots.value = list.sublist(0, slotCount);
    } catch (_) {
      // Corrupt payload — keep defaults.
    }
  }

  Future<void> setSlot(int index, CustomSlot value) async {
    if (index < 0 || index >= slotCount) return;
    final next = List<CustomSlot>.of(slots.value);
    next[index] = value;
    slots.value = next;
    await _save();
  }

  Future<void> replaceAll(List<CustomSlot> values) async {
    if (values.length != slotCount) return;
    slots.value = List<CustomSlot>.unmodifiable(values);
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(slots.value.map((s) => s.toJson()).toList()),
    );
  }
}
