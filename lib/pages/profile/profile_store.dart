import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Storage contract ────────────────────────────────────────────────────────
// All user profile fields are persisted to SharedPreferences under the
// 'profile.*' namespace.  When migrating to an online backend, replace each
// prefs.get/set call with a single API call that reads/writes the same field
// names as JSON keys — the ValueNotifiers stay as local cache and the rest
// of the app is unaffected.
//
// Current keys:
//   profile.name       — display name (String, default 'You')
//   profile.photo.path — absolute path to local profile photo (String?)
//   user.planner.mode  — selected day mode id (String, default 'normal')
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
  static const _photoKey = 'profile.photo.path';
  static const _modeKey = 'user.planner.mode';

  final ValueNotifier<String> name = ValueNotifier<String>('You');
  final ValueNotifier<String?> photoPath = ValueNotifier<String?>(null);
  final ValueNotifier<String> plannerMode = ValueNotifier<String>('normal');

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final storedName = prefs.getString(_nameKey);
    if (storedName != null && storedName.isNotEmpty) name.value = storedName;

    final storedMode = prefs.getString(_modeKey);
    if (storedMode != null && storedMode.isNotEmpty) plannerMode.value = storedMode;

    final stored = prefs.getString(_photoKey);
    if (stored != null && File(stored).existsSync()) photoPath.value = stored;
  }

  Future<void> setName(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, trimmed);
    name.value = trimmed;
  }

  Future<void> setPlannerMode(String modeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, modeId);
    plannerMode.value = modeId;
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
}
