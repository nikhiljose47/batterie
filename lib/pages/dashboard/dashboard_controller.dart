import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../engine/energy_score_engine.dart';
import '../../models/battery_status.dart';
import '../../models/body_status.dart';
import '../../models/day_template.dart';
import '../../models/energy_check_in.dart';
import '../../models/energy_log_record.dart';
import '../../models/logged_activity.dart';
import '../../models/timeline_point.dart';
import '../../repositories/energy_health_repository.dart';
import '../../services/energy_log_store.dart';
import '../../services/open_router_service.dart';
import '../../services/settings_service.dart';
import '../../state/async_view_state.dart';
import 'dashboard_state.dart';

class DashboardController extends ChangeNotifier {
  DashboardController({
    EnergyHealthRepository? repository,
    EnergyScoreEngine? energyScoreEngine,
    EnergyLogStore? logStore,
  })  : repository = repository ?? const EnergyHealthRepository(),
        _energyScoreEngine = energyScoreEngine ?? const EnergyScoreEngine(),
        _logStore = logStore ?? SqliteEnergyLogStore.instance;

  final EnergyHealthRepository repository;
  final EnergyScoreEngine _energyScoreEngine;
  final EnergyLogStore _logStore;

  DashboardState _state = const DashboardState();

  DashboardState get state => _state;

  Future<void> load() async {
    _state = _state.copyWith(status: AsyncStatus.loading);
    notifyListeners();

    try {
      final bodyStatusFuture = repository.getBodyStatus();
      final batteriesFuture = repository.getBatteryStatuses();
      final bodyStatus = await bodyStatusFuture;
      final batteries = await batteriesFuture;

      _state = _state.copyWith(
        status: batteries.isEmpty ? AsyncStatus.empty : AsyncStatus.success,
        bodyStatus: bodyStatus,
        batteries: batteries,
        hasCheckInEstimate: false,
      );

      // Restore anything already logged today so the rail and batteries
      // survive app restarts. Storage failure must not break the dashboard.
      List<EnergyLogRecord> saved = const <EnergyLogRecord>[];
      try {
        saved = await _logStore.recordsForDate(dateKey(DateTime.now()));
      } catch (_) {}
      if (saved.isNotEmpty) {
        _state = _state.copyWith(
          loggedActivities: saved
              .map((r) => LoggedActivity(
                    id: r.id,
                    activityId: r.activityId,
                    startMinutes: r.startMinutes,
                    durationMinutes: r.durationMinutes,
                  ))
              .toList(),
          hasCheckInEstimate: true,
        );
        _recomputeFromTimeline();
      }
    } catch (_) {
      _state = _state.copyWith(
        status: AsyncStatus.error,
        errorMessage: AppStrings.genericError,
      );
    }

    notifyListeners();
  }

  Future<void> analyzeCheckIn(EnergyCheckIn checkIn) async {
    if (_state.isAnalyzing) return;

    _state = _state.copyWith(isAnalyzing: true, analysisError: null);
    notifyListeners();

    try {
      final result = _energyScoreEngine.estimate(checkIn);

      final updatedBatteries = <BatteryStatus>[
        BatteryStatus(
          title: AppStrings.physicalEnergy,
          percent: result.state.physical / 100,
          subtitle: _percentLabel(result.state.physical / 100),
          color: AppColors.bodyEnergy,
        ),
        BatteryStatus(
          title: AppStrings.brainEnergy,
          percent: result.state.brain / 100,
          subtitle: _percentLabel(result.state.brain / 100),
          color: AppColors.brainEnergy,
        ),
      ];

      final updatedBodyStatus = BodyStatus(
        status: result.status,
        potential: result.potential,
        previousActivity:
            '${result.activity.name} for ${checkIn.durationMinutes} min.',
        supportNote: result.supportNote,
        recommendedActions: result.recommendations,
      );

      _state = _state.copyWith(
        bodyStatus: updatedBodyStatus,
        batteries: updatedBatteries,
        isAnalyzing: false,
        hasCheckInEstimate: true,
      );
    } catch (e) {
      _state = _state.copyWith(
        isAnalyzing: false,
        analysisError: e.toString().replaceFirst('Exception: ', ''),
      );
    }

    notifyListeners();
  }

  // ── Timeline rail ───────────────────────────────────────────────────

  int _entryCounter = 0;

  /// Adds an activity to the day timeline (from a chip tap, drag-drop, or
  /// text input) and recomputes energy from the whole day's sequence.
  void logActivity(String activityId,
      {int? startMinutes, int? durationMinutes}) {
    final now = DateTime.now();
    final entry = LoggedActivity(
      id: 'log_${_entryCounter++}_${now.microsecondsSinceEpoch}',
      activityId: activityId,
      startMinutes: (startMinutes ?? now.hour * 60 + now.minute).clamp(0, 1439),
      durationMinutes: durationMinutes ?? _defaultDurations[activityId] ?? 30,
    );

    _state = _state.copyWith(
      loggedActivities: <LoggedActivity>[..._state.loggedActivities, entry],
      hasCheckInEstimate: true,
      analysisError: null,
    );
    _recomputeFromTimeline();
    notifyListeners();
  }

  void updateLoggedActivity(String id,
      {int? startMinutes, int? durationMinutes}) {
    _state = _state.copyWith(
      loggedActivities: _state.loggedActivities
          .map((a) => a.id == id
              ? a.copyWith(
                  startMinutes: startMinutes,
                  durationMinutes: durationMinutes,
                )
              : a)
          .toList(),
    );
    _recomputeFromTimeline();
    notifyListeners();
  }

  void removeLoggedActivity(String id) {
    _state = _state.copyWith(
      loggedActivities:
          _state.loggedActivities.where((a) => a.id != id).toList(),
    );
    _recomputeFromTimeline();
    notifyListeners();
  }

  /// Replaces today's whole rail with [template]'s items — used by the day
  /// planner sheet to lay out a full day in one action.
  void applyTemplate(DayTemplate template) {
    final now = DateTime.now();
    final entries = template.items
        .map((item) => LoggedActivity(
              id: 'log_${_entryCounter++}_${now.microsecondsSinceEpoch}',
              activityId: item.activityId,
              startMinutes: item.startMinutes.clamp(0, 1439),
              durationMinutes: item.durationMinutes,
            ))
        .toList();

    _state = _state.copyWith(
      loggedActivities: entries,
      hasCheckInEstimate: true,
      analysisError: null,
    );
    _recomputeFromTimeline();
    notifyListeners();
  }

  Future<List<DayTemplate>> loadCustomTemplates() =>
      _logStore.customTemplates();

  Future<void> saveCustomTemplate(DayTemplate template) =>
      _logStore.saveTemplate(template);

  Future<void> deleteCustomTemplate(String id) => _logStore.deleteTemplate(id);

  /// Replays every timeline activity in chronological order on top of the
  /// daily baseline, so the batteries always reflect the whole day.
  /// Each intermediate state is persisted so the stats tab can chart the day.
  void _recomputeFromTimeline() {
    var energy = _energyScoreEngine.createDailyBaseline(28, 8.0, 0.7);
    final sorted = <LoggedActivity>[..._state.loggedActivities]
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    final today = dateKey(DateTime.now());
    final records = <EnergyLogRecord>[];
    final points = <TimelinePoint>[];
    for (final item in sorted) {
      energy = _energyScoreEngine.applyActivity(
        energy,
        item.activityId,
        item.durationMinutes,
        28,
      );
      records.add(EnergyLogRecord(
        id: item.id,
        date: today,
        startMinutes: item.startMinutes,
        durationMinutes: item.durationMinutes,
        activityId: item.activityId,
        physicalAfter: energy.physical,
        brainAfter: energy.brain,
      ));
      points.add(TimelinePoint(
        startMinutes: item.startMinutes,
        activityId: item.activityId,
        physical: energy.physical,
        brain: energy.brain,
      ));
    }
    unawaited(
      _logStore.saveDay(today, records).catchError((Object _) {}),
    );

    final lastActivity = sorted.isEmpty
        ? null
        : _energyScoreEngine.activityById(sorted.last.activityId);

    // Find lowest physical and brain across today's predicted timeline.
    double lowestPhysical = points.isEmpty
        ? energy.physical.toDouble()
        : points.first.physical.toDouble();
    int lowestPhysicalAt = points.isEmpty ? -1 : points.first.startMinutes;
    double lowestBrain = points.isEmpty
        ? energy.brain.toDouble()
        : points.first.brain.toDouble();
    int lowestBrainAt = points.isEmpty ? -1 : points.first.startMinutes;
    for (final p in points) {
      if (p.physical < lowestPhysical) {
        lowestPhysical = p.physical.toDouble();
        lowestPhysicalAt = p.startMinutes;
      }
      if (p.brain < lowestBrain) {
        lowestBrain = p.brain.toDouble();
        lowestBrainAt = p.startMinutes;
      }
    }

    _state = _state.copyWith(
      batteries: <BatteryStatus>[
        BatteryStatus(
          title: AppStrings.physicalEnergy,
          percent: energy.physical / 100,
          subtitle: _percentLabel(energy.physical / 100),
          color: AppColors.bodyEnergy,
        ),
        BatteryStatus(
          title: AppStrings.brainEnergy,
          percent: energy.brain / 100,
          subtitle: _percentLabel(energy.brain / 100),
          color: AppColors.brainEnergy,
        ),
      ],
      timelinePoints: points,
      lowestPhysical: lowestPhysical,
      lowestPhysicalAt: lowestPhysicalAt,
      lowestBrain: lowestBrain,
      lowestBrainAt: lowestBrainAt,
      bodyStatus: _state.bodyStatus == null || lastActivity == null
          ? _state.bodyStatus
          : BodyStatus(
              status:
                  'Physical ${energy.physical}% and brain ${energy.brain}% after ${sorted.length} logged ${sorted.length == 1 ? 'activity' : 'activities'} today.',
              potential: _state.bodyStatus!.potential,
              previousActivity:
                  '${lastActivity.name} for ${sorted.last.durationMinutes} min.',
              supportNote: _state.bodyStatus!.supportNote,
              recommendedActions: _state.bodyStatus!.recommendedActions,
            ),
    );
  }

  // Accepts free-text like "walked 30 min" or "gym 1h".
  // First attempts a local keyword → activity match; falls back to OpenRouter.
  Future<void> processActivityText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _state.isAnalyzing) return;

    final match = _matchActivity(trimmed);
    if (match != null) {
      logActivity(match.activityId, durationMinutes: match.durationMinutes);
      return;
    }

    // No local match — try OpenRouter
    _state = _state.copyWith(isAnalyzing: true, analysisError: null);
    notifyListeners();

    try {
      final apiKey = SettingsService().getApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        _state = _state.copyWith(
          isAnalyzing: false,
          analysisError:
              'Activity not recognised locally. Add an OpenRouter API key to .env for AI fallback.',
        );
        notifyListeners();
        return;
      }

      final analysis = await const OpenRouterService().analyzeEnergyLevels(
        apiKey: apiKey,
        userInput: trimmed,
      );

      _state = _state.copyWith(
        batteries: <BatteryStatus>[
          BatteryStatus(
            title: AppStrings.physicalEnergy,
            percent: analysis.physicalPercent,
            subtitle: _percentLabel(analysis.physicalPercent),
            color: AppColors.bodyEnergy,
          ),
          BatteryStatus(
            title: AppStrings.brainEnergy,
            percent: analysis.brainPercent,
            subtitle: _percentLabel(analysis.brainPercent),
            color: AppColors.brainEnergy,
          ),
        ],
        isAnalyzing: false,
        hasCheckInEstimate: true,
      );
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(
        isAnalyzing: false,
        analysisError: e.toString().replaceFirst('Exception: ', ''),
      );
      notifyListeners();
    }
  }

  // --- private helpers ---

  String _percentLabel(double percent) {
    if (percent >= 0.8) return 'High energy';
    if (percent >= 0.6) return 'Good level';
    if (percent >= 0.4) return 'Moderate — pace yourself';
    if (percent >= 0.2) return 'Low — prioritise rest';
    return 'Very low — rest now';
  }

  static const Map<String, List<String>> _keywordMap = <String, List<String>>{
    'focused_coding': <String>[
      'cod',
      'program',
      'dev',
      'develop',
      'work',
      'study',
      'focus',
      'task',
    ],
    'email_and_message_backlog': <String>[
      'email',
      'message',
      'slack',
      'admin',
      'inbox',
      'reply',
    ],
    'video_meeting_for_work': <String>[
      'meeting',
      'call',
      'zoom',
      'teams',
      'conference',
    ],
    'social_media_scrolling': <String>[
      'social',
      'scroll',
      'instagram',
      'twitter',
      'tiktok',
      'reels',
      'facebook',
      'youtube',
    ],
    'easy_walking': <String>['easy walk', 'stroll', 'slow walk', 'leisurely'],
    'brisk_walking': <String>['walk', 'brisk'],
    'running_easy_pace': <String>['run', 'jog'],
    'hiit_workout': <String>[
      'hiit',
      'gym',
      'workout',
      'weight',
      'lift',
      'exercise',
      'training',
      'sports',
    ],
    'cooking_light_meal': <String>['cook', 'kitchen', 'meal prep', 'bake'],
    'deep_house_cleaning': <String>['clean', 'chore', 'errands', 'housework'],
    'slow_breathing_exercise': <String>['breath', 'breathe', 'breathing'],
    'mindfulness_meditation': <String>[
      'meditat',
      'mindful',
      'yoga',
      'zen',
      'stretching',
    ],
    'power_nap_10_20_min': <String>['nap'],
    'meal_break_away_from_desk': <String>[
      'break',
      'lunch',
      'dinner',
      'breakfast',
      'meal',
    ],
  };

  static const Map<String, int> _defaultDurations = <String, int>{
    'focused_coding': 60,
    'email_and_message_backlog': 60,
    'video_meeting_for_work': 60,
    'social_media_scrolling': 30,
    'easy_walking': 30,
    'brisk_walking': 30,
    'running_easy_pace': 30,
    'hiit_workout': 30,
    'cooking_light_meal': 30,
    'deep_house_cleaning': 60,
    'slow_breathing_exercise': 10,
    'mindfulness_meditation': 15,
    'power_nap_10_20_min': 20,
    'meal_break_away_from_desk': 30,
  };

  ({String activityId, int durationMinutes})? _matchActivity(String text) {
    final lower = text.toLowerCase();
    final mins = _parseDuration(lower);

    for (final entry in _keywordMap.entries) {
      for (final kw in entry.value) {
        if (lower.contains(kw)) {
          return (
            activityId: entry.key,
            durationMinutes: mins ?? _defaultDurations[entry.key]!,
          );
        }
      }
    }
    return null;
  }

  int? _parseDuration(String text) {
    final hourMatch = RegExp(r'(\d+)\s*h(?:ou?r)?s?\b').firstMatch(text);
    final minMatch = RegExp(r'(\d+)\s*min(?:ute)?s?\b').firstMatch(text);
    var total = 0;
    if (hourMatch != null) total += int.parse(hourMatch.group(1)!) * 60;
    if (minMatch != null) total += int.parse(minMatch.group(1)!);
    return total > 0 ? total : null;
  }
}
