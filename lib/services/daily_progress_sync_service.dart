import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/daily_score_rules.dart';
import '../models/energy_log_record.dart';
import '../models/person_status.dart';
import '../models/planner_session_log.dart';
import '../pages/home_tab/data/mode_advice.dart';
import '../pages/profile/profile_store.dart';
import '../pages/services/tools/toolkit.dart';
import 'energy_log_store.dart';
import 'remote_sync.dart';

class DailyProgressSyncService {
  const DailyProgressSyncService._();

  static const DailyProgressSyncService instance = DailyProgressSyncService._();
  static final Map<String, String> _lastRemotePayloadByDate =
      <String, String>{};
  static Timer? _remoteFetchTimer;
  static int _remoteFetchDelayMinutes = 1;
  static const String _focusSessionsKey = 'svc.focus.sessions';
  static const String _progressCacheKey = 'status.daily_progress.v1';
  static const String _appUsageCacheKey = 'status.app_usage_minutes.v1';

  Future<void> syncToday() => syncForDate(DateTime.now());

  Future<DailyProgressRecord?> todayRecord() => recordForDate(DateTime.now());

  Future<int> appUseMinutesForDay(DateTime day) => _appUseMinutesForDay(day);

  void startBackgroundTopScoreRefresh() {
    _remoteFetchTimer?.cancel();
    _remoteFetchDelayMinutes = 1;
    _scheduleRemoteFetch(Duration.zero);
  }

  Future<void> saveTodayAppUseMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = await _cachedAppUsageMinutes();
    cached[dateKey(DateTime.now())] = minutes.clamp(0, 1440).toInt();
    await prefs.setString(_appUsageCacheKey, jsonEncode(cached));
  }

  Future<DailyProgressRecord?> recordForDate(DateTime day) async {
    final userId = ProfileStore.instance.userId.value;
    if (userId.isEmpty) return null;

    final key = dateKey(day);
    final store = SqliteEnergyLogStore.instance;
    await store.claimEnergyLogsForUser(userId);
    await store.claimPlannerSessionLogsForUser(userId);

    final records = await store.recordsForDate(key, userId: userId);
    final plannerLogs = await store.plannerSessionLogsForDate(
      key,
      userId: userId,
    );
    final total = plannerSlots.length;
    final done = plannerLogs
        .where((log) => log.status == PlannerSessionStatus.done)
        .length;
    final partial = plannerLogs
        .where((log) => log.status == PlannerSessionStatus.partial)
        .length;
    final logged = plannerLogs.length;
    final goalPercent =
        total == 0 ? 0 : (((done + partial * 0.5) / total) * 100);
    final appUseMinutes = await _appUseMinutesForDay(day);
    final focusMinutes = await _focusMinutesForDay(day);
    final score = DailyScoreRules.appUsePoints(appUseMinutes) +
        DailyScoreRules.serviceLogPoints(records.length) +
        DailyScoreRules.dayTrackPoints(
          loggedCount: logged,
          totalCount: total,
        );

    return DailyProgressRecord(
      userId: userId,
      dateKey: key,
      displayName: ProfileStore.instance.name.value,
      plannerMode: ProfileStore.instance.plannerMode.value,
      serviceActionCount: records.length,
      appUseMinutes: appUseMinutes,
      focusMinutes: focusMinutes,
      goalDoneCount: done,
      goalPartialCount: partial,
      goalTotalCount: total,
      completionPercent: goalPercent.round().clamp(0, 100),
      scorePercent: score,
    );
  }

  Future<void> syncForDate(DateTime day) async {
    final progress = await recordForDate(day);
    if (progress == null) return;

    await _cacheProgress(progress);
    final payload = jsonEncode(progress.toMap());
    if (_lastRemotePayloadByDate[progress.dateKey] == payload) return;
    try {
      await RemoteSync.instance.upsertDailyProgress(
        progress,
        userId: progress.userId,
      );
      _lastRemotePayloadByDate[progress.dateKey] = payload;
    } catch (_) {}
  }

  Future<PersonStatus?> currentUserStatus() async {
    final progress = await todayRecord();
    if (progress == null) return null;
    return PersonStatus(
      name: progress.displayName,
      role: 'Today',
      energyPercent: progress.scorePercent / 100,
      brainPercent: progress.completionPercent / 100,
      note:
          'Goal ${progress.goalDoneCount}/${progress.goalTotalCount} done. App use ${progress.appUseMinutes}m, focus ${progress.focusMinutes}m.',
      scorePercent: progress.scorePercent,
      goalDoneCount: progress.goalDoneCount,
      goalTotalCount: progress.goalTotalCount,
      appUseMinutes: progress.appUseMinutes,
      focusMinutes: progress.focusMinutes,
    );
  }

  Future<List<PersonStatus>> cachedTopStatuses() async {
    final today = dateKey(DateTime.now());
    final currentUserId = ProfileStore.instance.userId.value;
    final cached = await cachedProgress();
    final records = cached
        .where((record) =>
            record.dateKey == today && record.userId != currentUserId)
        .toList(growable: false)
      ..sort((a, b) => b.scorePercent.compareTo(a.scorePercent));
    return records.take(7).map(_statusFromProgress).toList(growable: false);
  }

  void _scheduleRemoteFetch(Duration delay) {
    _remoteFetchTimer?.cancel();
    _remoteFetchTimer = Timer(delay, () {
      unawaited(_fetchRemoteTopScores());
    });
  }

  Future<void> _fetchRemoteTopScores() async {
    try {
      final records = await RemoteSync.instance.fetchDailyProgress(
        dateKey: dateKey(DateTime.now()),
        limit: 7,
      );
      await _cacheProgressList(records);
    } catch (_) {}

    final nextDelay = Duration(minutes: _remoteFetchDelayMinutes);
    _remoteFetchDelayMinutes =
        (_remoteFetchDelayMinutes * 2).clamp(1, 60).toInt();
    _scheduleRemoteFetch(nextDelay);
  }

  PersonStatus _statusFromProgress(DailyProgressRecord progress) {
    return PersonStatus(
      name: progress.displayName,
      role: 'Today',
      energyPercent: progress.scorePercent / 100,
      brainPercent: progress.completionPercent / 100,
      note:
          'Goal ${progress.goalDoneCount}/${progress.goalTotalCount} done. App use ${progress.appUseMinutes}m, focus ${progress.focusMinutes}m.',
      scorePercent: progress.scorePercent,
      goalDoneCount: progress.goalDoneCount,
      goalTotalCount: progress.goalTotalCount,
      appUseMinutes: progress.appUseMinutes,
      focusMinutes: progress.focusMinutes,
    );
  }

  Future<int> _focusMinutesForDay(DateTime day) async {
    final sessions = await ServiceStore.loadList(_focusSessionsKey);
    final key = dateKey(day);
    return sessions.fold<int>(0, (sum, session) {
      final when = DateTime.tryParse((session['t'] as String?) ?? '');
      if (when == null || dateKey(when) != key) return sum;
      return sum + ((session['minutes'] as num?)?.round() ?? 0);
    });
  }

  Future<void> _cacheProgress(DailyProgressRecord progress) async {
    await _cacheProgressList(<DailyProgressRecord>[progress]);
  }

  Future<void> _cacheProgressList(List<DailyProgressRecord> progress) async {
    if (progress.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final cached = await cachedProgress();
    final next = <DailyProgressRecord>[
      ...progress,
      for (final item in cached)
        if (!progress.any((progressItem) =>
            progressItem.userId == item.userId &&
            progressItem.dateKey == item.dateKey))
          item,
    ].take(60).map((item) => item.toMap()).toList(growable: false);
    await prefs.setString(_progressCacheKey, jsonEncode(next));
  }

  Future<List<DailyProgressRecord>> cachedProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_progressCacheKey);
    if (raw == null || raw.isEmpty) return const <DailyProgressRecord>[];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(DailyProgressRecord.fromMap)
          .where((item) => item.userId.isNotEmpty && item.dateKey.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <DailyProgressRecord>[];
    }
  }

  Future<int> _appUseMinutesForDay(DateTime day) async {
    final cached = await _cachedAppUsageMinutes();
    return cached[dateKey(day)] ?? 0;
  }

  Future<Map<String, int>> _cachedAppUsageMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_appUsageCacheKey);
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map<String, int>((key, value) {
        return MapEntry(key, (value as num?)?.round() ?? 0);
      });
    } catch (_) {
      return <String, int>{};
    }
  }
}
