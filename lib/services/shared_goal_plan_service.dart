import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/goal_plan_constants.dart';
import '../models/community_plan.dart';
import '../pages/profile/profile_store.dart';
import 'custom_mode_store.dart';

class SharedGoalPlan {
  const SharedGoalPlan({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.likesCount,
    required this.usedCount,
    required this.usedByNames,
    required this.rating,
    required this.slots,
    required this.likedByMe,
    required this.tag,
    required this.cards,
    this.shortName,
    this.longName,
    this.description = '',
    this.imageUrl,
    this.authorId = '',
    this.status = 'published',
    this.visibility = 'public',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String ownerName;
  final int likesCount;
  final int usedCount;
  final List<String> usedByNames;
  final double rating;
  final List<CustomSlot> slots;
  final bool likedByMe;
  final String tag;
  final List<PlanCard> cards;
  final String? shortName;
  final String? longName;
  final String description;
  final String? imageUrl;
  final String authorId;
  final String status;
  final String visibility;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get displayUsedCount => usedCount < 2 ? 2 : usedCount;

  SharedGoalPlan copyWith({
    int? likesCount,
    int? usedCount,
    List<String>? usedByNames,
    bool? likedByMe,
  }) {
    return SharedGoalPlan(
      id: id,
      name: name,
      ownerName: ownerName,
      likesCount: likesCount ?? this.likesCount,
      usedCount: usedCount ?? this.usedCount,
      usedByNames: usedByNames ?? this.usedByNames,
      rating: rating,
      slots: slots,
      likedByMe: likedByMe ?? this.likedByMe,
      tag: tag,
      cards: cards,
      shortName: shortName,
      longName: longName,
      description: description,
      imageUrl: imageUrl,
      authorId: authorId,
      status: status,
      visibility: visibility,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory SharedGoalPlan.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String? uid,
  ) {
    final data = doc.data();
    final likedBy = ((data['liked_by'] as List<dynamic>?) ?? const <dynamic>[])
        .whereType<String>()
        .toSet();
    final usedByNames =
        ((data['used_by_names'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<String>()
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty)
            .toList(growable: false);
    final cards = CustomModeStore.normalizeCards(
      ((data['cards'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(PlanCard.fromJson)
          .toList(),
    );
    final rawSlots = ((data['slots'] as List<dynamic>?) ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(CustomSlot.fromJson)
        .toList();
    final slots = rawSlots.isEmpty
        ? CustomModeStore.slotsFromCards(cards)
        : CustomModeStore.normalizeSlots(rawSlots);
    return SharedGoalPlan(
      id: doc.id,
      name: (data['shortName'] as String?) ??
          (data['name'] as String?) ??
          'Shared plan',
      shortName: data['shortName'] as String?,
      longName: data['longName'] as String?,
      description: (data['description'] as String?) ?? '',
      imageUrl: data['imageUrl'] as String?,
      authorId:
          (data['authorId'] as String?) ?? (data['owner_id'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'published',
      visibility: (data['visibility'] as String?) ?? 'public',
      createdAt: _readDate(data['createdAt'] ?? data['created_at']),
      updatedAt: _readDate(data['updatedAt'] ?? data['updated_at']),
      ownerName: (data['owner_name'] as String?) ?? 'Someone',
      likesCount: (data['likes_count'] as num?)?.round() ?? likedBy.length,
      usedCount: (data['used_count'] as num?)?.round() ?? 0,
      usedByNames: usedByNames,
      rating: (data['rating'] as num?)?.toDouble() ?? 4.5,
      likedByMe: uid != null && likedBy.contains(uid),
      tag: GoalPlanConstants.normalizeTag(
        (data['tag'] as String?) ?? GoalPlanConstants.defaultTag,
      ),
      slots: slots,
      cards: cards.isEmpty ? CustomModeStore.cardsFromSlots(slots) : cards,
    );
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class SharedGoalPlanService {
  SharedGoalPlanService._();
  static final SharedGoalPlanService instance = SharedGoalPlanService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _plans =>
      _firestore.collection('shared_goal_plans');

  String? get uid => _auth.currentUser?.uid;

  Future<List<SharedGoalPlan>> trendingPlans({int limit = 20}) async {
    final currentUid = uid;
    final byId = <String, SharedGoalPlan>{};

    Future<void> addPlans(
      Query<Map<String, dynamic>> query,
    ) async {
      try {
        final snapshot = await query.get();
        for (final doc in snapshot.docs) {
          final plan = SharedGoalPlan.fromDoc(doc, currentUid);
          if (plan.status != 'published' || plan.visibility != 'public') {
            continue;
          }
          byId[plan.id] = plan;
        }
      } catch (_) {
        // Older installs may not have every indexed field yet; keep the feed usable.
      }
    }

    await addPlans(_plans.orderBy('used_count', descending: true).limit(limit));
    await addPlans(_plans.orderBy('updated_at', descending: true).limit(limit));

    final plans = byId.values.toList(growable: false);
    plans.sort((a, b) {
      final used = b.usedCount.compareTo(a.usedCount);
      if (used != 0) return used;
      final likes = b.likesCount.compareTo(a.likesCount);
      if (likes != 0) return likes;
      final bUpdated = b.updatedAt ?? b.createdAt ?? DateTime(1970);
      final aUpdated = a.updatedAt ?? a.createdAt ?? DateTime(1970);
      return bUpdated.compareTo(aUpdated);
    });
    return plans;
  }

  Future<void> publishLocalPlans() async {
    if (uid == null) return;
    for (final plan in CustomModeStore.instance.plans.value) {
      if (plan.planCards.isEmpty && plan.slots.every((slot) => slot.isEmpty)) {
        continue;
      }
      await publishPlan(plan);
    }
  }

  Future<void> publishCurrentPlan() async {
    final currentUid = uid;
    if (currentUid == null) return;
    final current = CustomModeStore.instance.planForModeId(
      CustomModeStore.instance.activePlanId.value,
    );
    await publishPlan(current);
  }

  Future<void> publishPlan(CustomPlan plan) async {
    final currentUid = uid;
    if (currentUid == null) return;
    final current = plan;
    final docRef = _plans.doc('${currentUid}_${current.id}');
    final existing = await docRef.get();
    final planData = current
        .copyWith(
          shortName: current.shortName ?? current.name,
          longName: current.longName ?? current.name,
          authorId: currentUid,
          status: 'published',
          visibility: 'public',
          cards: current.planCards,
        )
        .toPlan(authorIdOverride: currentUid)
        .toJson();
    final displayName = _auth.currentUser?.displayName?.trim();
    final profileName = ProfileStore.instance.name.value.trim();
    await docRef.set(
      <String, Object?>{
        ...planData,
        'name': current.name,
        'owner_id': currentUid,
        'owner_name': displayName != null && displayName.isNotEmpty
            ? displayName
            : profileName.isNotEmpty
                ? profileName
                : 'Someone',
        'tag': current.tag,
        'slots': current.slots.map((slot) => slot.toJson()).toList(),
        'cards': current.planCards.map((card) => card.toJson()).toList(),
        if (!existing.exists) ...<String, Object?>{
          'likes_count': 0,
          'used_count': 0,
          'rating': 4.5,
          'liked_by': <String>[],
          'created_at': FieldValue.serverTimestamp(),
        },
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> toggleLike(SharedGoalPlan plan) async {
    final currentUid = uid;
    if (currentUid == null) return;
    await _plans.doc(plan.id).update(<String, Object?>{
      'liked_by': plan.likedByMe
          ? FieldValue.arrayRemove(<String>[currentUid])
          : FieldValue.arrayUnion(<String>[currentUid]),
      'likes_count': FieldValue.increment(plan.likedByMe ? -1 : 1),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<CustomPlan?> usePlan(SharedGoalPlan plan) async {
    final imported = await CustomModeStore.instance.addPlanFrom(
      name: plan.name,
      slots: plan.slots,
      tag: plan.tag,
      cards: plan.cards,
      description: plan.description,
      imageUrl: plan.imageUrl,
      authorId: plan.authorId,
      status: 'draft',
      visibility: 'private',
    );
    if (imported == null) return null;
    final displayName = _auth.currentUser?.displayName?.trim();
    final profileName = ProfileStore.instance.name.value.trim();
    final userName = displayName != null && displayName.isNotEmpty
        ? displayName
        : profileName.isNotEmpty
            ? profileName
            : null;
    await _plans.doc(plan.id).update(<String, Object?>{
      'used_count': FieldValue.increment(1),
      if (userName != null)
        'used_by_names': FieldValue.arrayUnion(<String>[userName]),
      'updated_at': FieldValue.serverTimestamp(),
    });
    return imported;
  }
}
