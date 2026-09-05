import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/remote_sync.dart';

// ─── Storage contract ────────────────────────────────────────────────────────
// All user profile fields are persisted to SharedPreferences under the
// 'profile.*' namespace.  When migrating to an online backend, replace each
// prefs.get/set call with a single API call that reads/writes the same field
// names as JSON keys — the ValueNotifiers stay as local cache and the rest
// of the app is unaffected.
//
// Current keys:
//   profile.user.id    — stable local user id (String, generated once)
//   profile.name       — display name (String, default 'You')
//   profile.age        — user age in years (int?)
//   profile.photo.path — absolute path to local profile photo (String?)
//   profile.onboarded  — first-run onboarding completed (bool)
//   user.planner.mode  — selected day mode id (String, default 'healthy')
// ─────────────────────────────────────────────────────────────────────────────

/// Singleton that holds the user's profile data in memory (ValueNotifiers)
/// and persists it to SharedPreferences across restarts.
///
/// Call [init] once at startup (main.dart). Then listen to individual fields
/// from any widget with ValueListenableBuilder.
class ProfileStore {
  ProfileStore._();
  static final ProfileStore instance = ProfileStore._();

  static const _nameKey = 'profile.name';
  static const _ageKey = 'profile.age';
  static const _photoKey = 'profile.photo.path';
  static const _modeKey = 'user.planner.mode';
  static const _userIdKey = 'profile.user.id';
  static const _onboardingCompleteKey = 'profile.onboarded';

  final ValueNotifier<String> userId = ValueNotifier<String>('');
  final ValueNotifier<String> name = ValueNotifier<String>('You');
  final ValueNotifier<int?> age = ValueNotifier<int?>(null);
  final ValueNotifier<String?> photoPath = ValueNotifier<String?>(null);
  final ValueNotifier<String> plannerMode = ValueNotifier<String>('healthy');
  final ValueNotifier<bool> onboardingComplete = ValueNotifier<bool>(false);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final storedUserId = prefs.getString(_userIdKey);
    if (storedUserId != null && storedUserId.isNotEmpty) {
      userId.value = storedUserId;
    } else {
      final generated = _generateLocalUserId();
      await prefs.setString(_userIdKey, generated);
      userId.value = generated;
    }

    final storedName = prefs.getString(_nameKey);
    if (storedName != null && storedName.isNotEmpty) name.value = storedName;

    final storedAge = prefs.getInt(_ageKey);
    if (storedAge != null && storedAge > 0) age.value = storedAge;

    final storedMode = prefs.getString(_modeKey);
    if (storedMode != null && storedMode.isNotEmpty) {
      plannerMode.value = _normalizePlannerMode(storedMode);
    }

    final stored = prefs.getString(_photoKey);
    if (stored != null && File(stored).existsSync()) photoPath.value = stored;

    final storedOnboarded = prefs.getBool(_onboardingCompleteKey);
    onboardingComplete.value = storedOnboarded ??
        (storedName != null && storedName.isNotEmpty && storedName != 'You');
  }

  Future<void> setName(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, trimmed);
    name.value = trimmed;
    _syncProfile();
  }

  Future<void> setAge(int value) async {
    if (value <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_ageKey, value);
    age.value = value;
  }

  Future<void> setPlannerMode(String modeId) async {
    final normalized = _normalizePlannerMode(modeId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, normalized);
    plannerMode.value = normalized;
    _syncProfile();
  }

  Future<void> completeOnboarding({
    required String displayName,
    required int userAge,
    required String modeId,
  }) async {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty || userAge <= 0) return;
    final normalized = _normalizePlannerMode(modeId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, trimmed);
    await prefs.setInt(_ageKey, userAge);
    await prefs.setString(_modeKey, normalized);
    await prefs.setBool(_onboardingCompleteKey, true);
    name.value = trimmed;
    age.value = userAge;
    plannerMode.value = normalized;
    onboardingComplete.value = true;
    _syncProfile();
  }

  void _syncProfile() {
    unawaited(
      RemoteSync.instance.upsertProfile(
        userId: userId.value,
        name: name.value,
        plannerMode: plannerMode.value,
        photoUrl: null,
      ),
    );
  }

  String _normalizePlannerMode(String modeId) {
    return switch (modeId) {
      'normal' => 'healthy',
      'normal_pro' || 'healthy_pro' => 'healthy',
      'coder_pro' || 'coder_super_plus' || 'office_pro' => 'office',
      'athletic' || 'athletic_pro' => 'healthy',
      'gym_pro' => 'gym',
      'nicotine_free_pro' => 'nicotine_free',
      _ => modeId,
    };
  }

  Future<void> setPhoto(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_photoKey, path);
    photoPath.value = path;
  }

  Future<void> clearPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_photoKey);
    photoPath.value = null;
  }

  String _generateLocalUserId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'local_$hex';
  }
}
