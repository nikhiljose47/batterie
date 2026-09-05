import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/goal_plan_constants.dart';
import '../models/community_plan.dart';

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
    this.tag = GoalPlanConstants.defaultTag,
    this.shortName,
    this.longName,
    this.description = '',
    this.imageUrl,
    this.authorId = '',
    this.status = 'draft',
    this.visibility = 'private',
    this.createdAt,
    this.updatedAt,
    this.cards = const <PlanCard>[],
  });

  final String id;
  final String name;
  final List<CustomSlot> slots;
  final String tag;
  final String? shortName;
  final String? longName;
  final String description;
  final String? imageUrl;
  final String authorId;
  final String status;
  final String visibility;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<PlanCard> cards;

  List<PlanCard> get planCards =>
      cards.isEmpty ? CustomModeStore.cardsFromSlots(slots) : cards;

  CustomPlan copyWith({
    String? name,
    List<CustomSlot>? slots,
    String? tag,
    String? shortName,
    String? longName,
    String? description,
    String? imageUrl,
    String? authorId,
    String? status,
    String? visibility,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<PlanCard>? cards,
  }) {
    final nextSlots = slots ?? this.slots;
    return CustomPlan(
      id: id,
      name: name ?? this.name,
      slots: nextSlots,
      tag: GoalPlanConstants.normalizeTag(tag ?? this.tag),
      shortName: shortName ?? this.shortName,
      longName: longName ?? this.longName,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      authorId: authorId ?? this.authorId,
      status: status ?? this.status,
      visibility: visibility ?? this.visibility,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cards: cards ??
          (slots == null
              ? this.cards
              : CustomModeStore.cardsFromSlots(nextSlots)),
    );
  }

  Plan toPlan({String? authorIdOverride}) {
    final now = DateTime.now();
    return Plan(
      id: id,
      shortName: shortName ?? name,
      longName: longName ?? name,
      description: description,
      imageUrl: imageUrl,
      authorId: authorIdOverride ?? authorId,
      status: status,
      visibility: visibility,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      cards: List<PlanCard>.unmodifiable(planCards),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'shortName': shortName ?? name,
        'longName': longName ?? name,
        'description': description,
        if (imageUrl != null && imageUrl!.trim().isNotEmpty)
          'imageUrl': imageUrl,
        'authorId': authorId,
        'status': status,
        'visibility': visibility,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        'tag': tag,
        'slots': slots.map((slot) => slot.toJson()).toList(),
        'cards': planCards.map((card) => card.toJson()).toList(),
      };

  factory CustomPlan.fromJson(Map<String, dynamic> j) {
    final cards = CustomModeStore.normalizeCards(
      ((j['cards'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(PlanCard.fromJson)
          .toList(),
    );
    final rawSlots = ((j['slots'] as List<dynamic>?) ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(CustomSlot.fromJson)
        .toList();
    final slots = rawSlots.isEmpty
        ? CustomModeStore.slotsFromCards(cards)
        : CustomModeStore.normalizeSlots(rawSlots);
    final now = DateTime.now();
    return CustomPlan(
      id: (j['id'] as String?) ?? '',
      name: (j['name'] as String?) ??
          (j['shortName'] as String?) ??
          'Custom plan',
      shortName: j['shortName'] as String?,
      longName: j['longName'] as String?,
      description: (j['description'] as String?) ?? '',
      imageUrl: j['imageUrl'] as String?,
      authorId: (j['authorId'] as String?) ?? '',
      status: (j['status'] as String?) ?? 'draft',
      visibility: (j['visibility'] as String?) ?? 'private',
      createdAt: DateTime.tryParse((j['createdAt'] as String?) ?? '') ?? now,
      updatedAt: DateTime.tryParse((j['updatedAt'] as String?) ?? '') ?? now,
      tag: GoalPlanConstants.normalizeTag(
        (j['tag'] as String?) ?? GoalPlanConstants.defaultTag,
      ),
      slots: slots,
      cards: cards.isEmpty ? CustomModeStore.cardsFromSlots(slots) : cards,
    );
  }
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

  static List<PlanCard> normalizeCards(List<PlanCard> input) {
    final cards = input
        .where((card) => card.id.isNotEmpty && card.title.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return List<PlanCard>.unmodifiable(cards.take(slotCount));
  }

  static List<PlanCard> cardsFromSlots(List<CustomSlot> slots) {
    const offsets = <int>[0, 90, 210, 330, 450, 570, 690, 960];
    final normalized = normalizeSlots(slots);
    return List<PlanCard>.generate(slotCount, (index) {
      final slot = normalized[index];
      final title = slot.recommendation.trim().isNotEmpty
          ? slot.recommendation.trim()
          : slot.tip.trim();
      return PlanCard(
        id: 'card_${(index + 1).toString().padLeft(3, '0')}',
        title: title.isEmpty ? 'Plan card ${index + 1}' : title,
        description: slot.descriptions.join('\n'),
        startOffsetMinutes: offsets[index],
        endOffsetMinutes: offsets[index + 1],
        position: index + 1,
      );
    });
  }

  static List<CustomSlot> slotsFromCards(List<PlanCard> cards) {
    final sorted = normalizeCards(cards);
    return normalizeSlots(<CustomSlot>[
      for (final card in sorted)
        CustomSlot(
          recommendation: card.title,
          tip: card.title,
          descriptions: ((card.description ?? '').trim().isEmpty)
              ? const <String>[]
              : (card.description ?? '')
                  .split('\n')
                  .map((line) => line.trim())
                  .where((line) => line.isNotEmpty)
                  .take(3)
                  .toList(),
        ),
    ]);
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

  bool hasPlanNamed(String name, {String? exceptId}) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return plans.value.any(
      (plan) =>
          plan.id != exceptId && plan.name.trim().toLowerCase() == normalized,
    );
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

  Future<CustomPlan?> addPlanFrom({
    required String name,
    required List<CustomSlot> slots,
    String tag = GoalPlanConstants.defaultTag,
    List<PlanCard> cards = const <PlanCard>[],
    String description = '',
    String? imageUrl,
    String authorId = '',
    String status = 'draft',
    String visibility = 'private',
  }) async {
    if (hasPlanNamed(name)) return null;
    final plan = await addPlan();
    if (plan == null) return null;
    final imported = plan.copyWith(
      name: name.trim().isEmpty ? plan.name : name.trim(),
      slots: normalizeSlots(slots),
      tag: tag,
      shortName: name.trim().isEmpty ? plan.name : name.trim(),
      longName: name.trim().isEmpty ? plan.name : name.trim(),
      description: description,
      imageUrl: imageUrl,
      authorId: authorId,
      status: status,
      visibility: visibility,
      cards: cards.isEmpty ? cardsFromSlots(slots) : normalizeCards(cards),
    );
    await savePlan(imported);
    return imported;
  }

  Future<void> savePlan(CustomPlan plan) async {
    final now = DateTime.now();
    final next = <CustomPlan>[
      for (final existing in plans.value)
        existing.id == plan.id
            ? plan.copyWith(slots: normalizeSlots(plan.slots)).copyWith(
                  createdAt: plan.createdAt ?? existing.createdAt ?? now,
                  updatedAt: now,
                  cards: plan.cards.isEmpty
                      ? cardsFromSlots(plan.slots)
                      : normalizeCards(plan.cards),
                )
            : existing,
    ];
    _setPlans(next);
    activePlanId.value = plan.id;
    _syncSlots();
    await _save();
  }

  Future<void> deletePlan(String id) async {
    final next = plans.value.where((plan) => plan.id != id).toList();
    _setPlans(next);
    activePlanId.value = next.isEmpty ? defaultPlanId : next.first.id;
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
