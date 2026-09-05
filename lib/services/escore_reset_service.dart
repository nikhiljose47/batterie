import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EscoreResetService {
  EscoreResetService._();
  static final EscoreResetService instance = EscoreResetService._();

  static const String configCollection = 'app_config';
  static const String configDoc = 'escore';
  static const String resetAfterField = 'reset_after';

  static const String _appliedResetKey = 'escore.reset.applied_after.v1';
  static const String _progressCacheKey = 'status.daily_progress.v1';
  static const String _appUsageCacheKey = 'status.app_usage_minutes.v1';

  Future<void> checkForRemoteReset() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(configCollection)
          .doc(configDoc)
          .get();
      final remoteReset = _parseReset(snapshot.data()?[resetAfterField]);
      if (remoteReset == null) return;

      final prefs = await SharedPreferences.getInstance();
      final localReset = DateTime.tryParse(
        prefs.getString(_appliedResetKey) ?? '',
      );
      if (localReset != null && !remoteReset.isAfter(localReset)) return;

      await prefs.remove(_progressCacheKey);
      await prefs.remove(_appUsageCacheKey);
      await prefs.setString(_appliedResetKey, remoteReset.toIso8601String());
    } catch (_) {}
  }

  Future<DateTime?> appliedResetAfter() async {
    final prefs = await SharedPreferences.getInstance();
    return DateTime.tryParse(prefs.getString(_appliedResetKey) ?? '');
  }

  bool isAfterAppliedReset({
    required String date,
    required int startMinutes,
    required DateTime? resetAfter,
  }) {
    if (resetAfter == null) return true;
    final parts = date.split('-').map(int.tryParse).toList(growable: false);
    if (parts.length != 3 || parts.any((part) => part == null)) return true;
    final at = DateTime(
      parts[0]!,
      parts[1]!,
      parts[2]!,
      startMinutes ~/ 60,
      startMinutes % 60,
    );
    return !at.isBefore(resetAfter);
  }

  DateTime? _parseReset(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.round());
    }
    return null;
  }
}
