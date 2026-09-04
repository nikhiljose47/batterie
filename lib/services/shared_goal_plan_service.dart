import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/goal_plan_constants.dart';
import 'custom_mode_store.dart';

class SharedGoalPlan {
  const SharedGoalPlan({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.likesCount,
    required this.usedCount,
    required this.rating,
    required this.slots,
    required this.likedByMe,
    required this.tag,
  });

  final String id;
  final String name;
  final String ownerName;
  final int likesCount;
  final int usedCount;
  final double rating;
  final List<CustomSlot> slots;
  final bool likedByMe;
  final String tag;

  int get displayUsedCount => usedCount < 2 ? 2 : usedCount;

  SharedGoalPlan copyWith({
    int? likesCount,
    int? usedCount,
    bool? likedByMe,
  }) {
    return SharedGoalPlan(
      id: id,
      name: name,
      ownerName: ownerName,
      likesCount: likesCount ?? this.likesCount,
      usedCount: usedCount ?? this.usedCount,
      rating: rating,
      slots: slots,
      likedByMe: likedByMe ?? this.likedByMe,
      tag: tag,
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
    return SharedGoalPlan(
      id: doc.id,
      name: (data['name'] as String?) ?? 'Shared plan',
      ownerName: (data['owner_name'] as String?) ?? 'Someone',
      likesCount: (data['likes_count'] as num?)?.round() ?? likedBy.length,
      usedCount: (data['used_count'] as num?)?.round() ?? 0,
      rating: (data['rating'] as num?)?.toDouble() ?? 4.5,
      likedByMe: uid != null && likedBy.contains(uid),
      tag: GoalPlanConstants.normalizeTag(
        (data['tag'] as String?) ?? GoalPlanConstants.defaultTag,
      ),
      slots: CustomModeStore.normalizeSlots(
        ((data['slots'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(CustomSlot.fromJson)
            .toList(),
      ),
    );
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
    try {
      final snapshot = await _plans
          .orderBy('used_count', descending: true)
          .limit(limit)
          .get();
      final plans = snapshot.docs
          .map((doc) => SharedGoalPlan.fromDoc(doc, currentUid))
          .toList(growable: false);
      plans.sort((a, b) {
        final used = b.usedCount.compareTo(a.usedCount);
        return used == 0 ? b.likesCount.compareTo(a.likesCount) : used;
      });
      return plans;
    } catch (_) {
      return const <SharedGoalPlan>[];
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
    await _plans.doc('${currentUid}_${current.id}').set(
      <String, Object?>{
        'name': current.name,
        'owner_id': currentUid,
        'owner_name': _auth.currentUser?.displayName ?? 'Someone',
        'tag': current.tag,
        'slots': current.slots.map((slot) => slot.toJson()).toList(),
        'likes_count': 0,
        'used_count': 0,
        'rating': 4.5,
        'liked_by': <String>[],
        'updated_at': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
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
    );
    if (imported == null) return null;
    await _plans.doc(plan.id).update(<String, Object?>{
      'used_count': FieldValue.increment(1),
      'updated_at': FieldValue.serverTimestamp(),
    });
    return imported;
  }
}
