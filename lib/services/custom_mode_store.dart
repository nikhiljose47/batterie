import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomSlot {
  const CustomSlot({
    this.recommendation = '',
    this.tip = '',
    this.descriptions = const <String>[],
  });

  final String recommendation;
  final String tip;
  final List<String> descriptions;

  bool get isEmpty =>
      recommendation.isEmpty && tip.isEmpty && descriptions.isEmpty;

  CustomSlot copyWith({
    String? recommendation,
    String? tip,
    List<String>? descriptions,
  }) {
    return CustomSlot(
      recommendation: recommendation ?? this.recommendation,
      tip: tip ?? this.tip,
      descriptions: descriptions ?? this.descriptions,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'rec': recommendation,
        'tip': tip,
        'descriptions': descriptions,
      };

  factory CustomSlot.fromJson(Map<String, dynamic> j) => CustomSlot(
        recommendation: (j['rec'] as String?) ?? '',
        tip: (j['tip'] as String?) ?? '',
        descriptions: ((j['descriptions'] as List<dynamic>?) ??
                (j['desc'] as List<dynamic>?) ??
                const <dynamic>[])
            .whereType<String>()
            .where((text) => text.trim().isNotEmpty)
            .map((text) => text.trim())
            .take(3)
            .toList(),
      );
}

class CustomPlan {
  const CustomPlan({
    required this.id,
    required this.name,
    required this.slots,
  });

  final String id;
  final String name;
  final List<CustomSlot> slots;

  CustomPlan copyWith({String? name, List<CustomSlot>? slots}) {
    return CustomPlan(
      id: id,
      name: name ?? this.name,
      slots: slots ?? this.slots,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'slots': slots.map((slot) => slot.toJson()).toList(),
      };

  factory CustomPlan.fromJson(Map<String, dynamic> j) => CustomPlan(
        id: (j['id'] as String?) ?? '',
        name: (j['name'] as String?) ?? 'Custom plan',
        slots: CustomModeStore.normalizeSlots(
          ((j['slots'] as List<dynamic>?) ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(CustomSlot.fromJson)
              .toList(),
        ),
      );
}

class CustomModeStore {
  CustomModeStore._();
  static final CustomModeStore instance = CustomModeStore._();

  static const int maxPlans = 4;
  static const int slotCount = 7;
  static const String defaultPlanId = 'custom_1';

  static const _legacySlotsKey = 'mode.custom.slots.v1';
  static const _plansKey = 'mode.custom.plans.v1';
  static const _activePlanKey = 'mode.custom.active_plan.v1';

  final ValueNotifier<List<CustomPlan>> plans =
      ValueNotifier<List<CustomPlan>>(<CustomPlan>[
    CustomPlan(
      id: defaultPlanId,
      name: 'My Plan',
      slots: List<CustomSlot>.filled(slotCount, const CustomSlot()),
    ),
  ]);

  final ValueNotifier<String> activePlanId =
      ValueNotifier<String>(defaultPlanId);

  /// Backwards-compatible alias for older listeners that expect one plan.
  final ValueNotifier<List<CustomSlot>> slots = ValueNotifier<List<CustomSlot>>(
    List<CustomSlot>.filled(slotCount, const CustomSlot()),
  );

  static bool isCustomModeId(String modeId) =>
      modeId == 'custom' || modeId.startsWith('custom_');

  static List<CustomSlot> normalizeSlots(List<CustomSlot> input) {
    final list = List<CustomSlot>.of(input);
    while (list.length < slotCount) {
      list.add(const CustomSlot());
    }
    return List<CustomSlot>.unmodifiable(list.take(slotCount));
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final storedPlans = prefs.getString(_plansKey);
    if (storedPlans != null) {
      try {
        final decoded = jsonDecode(storedPlans) as List<dynamic>;
        final loaded = decoded
            .whereType<Map<String, dynamic>>()
            .map(CustomPlan.fromJson)
            .where((plan) => plan.id.isNotEmpty)
            .take(maxPlans)
            .toList();
        if (loaded.isNotEmpty) {
          _setPlans(loaded);
          final active = prefs.getString(_activePlanKey);
          activePlanId.value = loaded.any((plan) => plan.id == active)
              ? active!
              : loaded.first.id;
          _syncSlots();
          return;
        }
      } catch (_) {}
    }

    final legacyRaw = prefs.getString(_legacySlotsKey);
    if (legacyRaw != null) {
      try {
        final legacySlots = (jsonDecode(legacyRaw) as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(CustomSlot.fromJson)
            .toList();
        _setPlans(<CustomPlan>[
          CustomPlan(
            id: defaultPlanId,
            name: 'My Plan',
            slots: normalizeSlots(legacySlots),
          ),
        ]);
        await _save();
        return;
      } catch (_) {}
    }

    _syncSlots();
  }

  CustomPlan planForModeId(String modeId) {
    final list = plans.value;
    if (list.isEmpty) return _emptyPlan(defaultPlanId, 'My Plan');
    if (modeId == 'custom') {
      return list.firstWhere(
        (plan) => plan.id == activePlanId.value,
        orElse: () => list.first,
      );
    }
    return list.firstWhere((plan) => plan.id == modeId,
        orElse: () => list.first);
  }

  Future<CustomPlan?> addPlan() async {
    if (plans.value.length >= maxPlans) return null;
    final used = plans.value.map((plan) => plan.id).toSet();
    var index = 1;
    while (used.contains('custom_$index')) {
      index++;
    }
    final plan = _emptyPlan('custom_$index', 'Plan $index');
    _setPlans(<CustomPlan>[...plans.value, plan]);
    activePlanId.value = plan.id;
    _syncSlots();
    await _save();
    return plan;
  }

  Future<void> savePlan(CustomPlan plan) async {
    final next = <CustomPlan>[
      for (final existing in plans.value)
        existing.id == plan.id
            ? plan.copyWith(slots: normalizeSlots(plan.slots))
            : existing,
    ];
    _setPlans(next);
    activePlanId.value = plan.id;
    _syncSlots();
    await _save();
  }

  Future<void> deletePlan(String id) async {
    if (plans.value.length <= 1) return;
    final next = plans.value.where((plan) => plan.id != id).toList();
    if (next.isEmpty) return;
    _setPlans(next);
    activePlanId.value = next.first.id;
    _syncSlots();
    await _save();
  }

  Future<void> setActivePlan(String id) async {
    if (!plans.value.any((plan) => plan.id == id)) return;
    activePlanId.value = id;
    _syncSlots();
    await _save();
  }

  Future<void> replaceAll(List<CustomSlot> values) async {
    final current = planForModeId(activePlanId.value);
    await savePlan(current.copyWith(slots: normalizeSlots(values)));
  }

  void _setPlans(List<CustomPlan> value) {
    plans.value = List<CustomPlan>.unmodifiable(value.take(maxPlans));
  }

  void _syncSlots() {
    slots.value = planForModeId(activePlanId.value).slots;
  }

  CustomPlan _emptyPlan(String id, String name) {
    return CustomPlan(
      id: id,
      name: name,
      slots: List<CustomSlot>.filled(slotCount, const CustomSlot()),
    );
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _plansKey,
      jsonEncode(plans.value.map((plan) => plan.toJson()).toList()),
    );
    await prefs.setString(_activePlanKey, activePlanId.value);
  }
}
