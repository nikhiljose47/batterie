import 'package:flutter/foundation.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../engine/energy_score_engine.dart';
import '../../models/battery_status.dart';
import '../../models/body_status.dart';
import '../../models/energy_check_in.dart';
import '../../repositories/energy_health_repository.dart';
import '../../services/open_router_service.dart';
import '../../services/settings_service.dart';
import '../../state/async_view_state.dart';
import 'dashboard_state.dart';

class DashboardController extends ChangeNotifier {
  DashboardController({
    EnergyHealthRepository? repository,
    EnergyScoreEngine? energyScoreEngine,
  })  : repository = repository ?? const EnergyHealthRepository(),
        _energyScoreEngine = energyScoreEngine ?? const EnergyScoreEngine();

  final EnergyHealthRepository repository;
  final EnergyScoreEngine _energyScoreEngine;

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

  // Accepts free-text like "walked 30 min" or "gym 1h".
  // First attempts a local keyword → activity match; falls back to OpenRouter.
  Future<void> processActivityText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _state.isAnalyzing) return;

    final match = _matchActivity(trimmed);
    if (match != null) {
      await analyzeCheckIn(EnergyCheckIn(
        age: 28,
        sleepHours: 7.0,
        sleepQuality: 0.7,
        activityId: match.activityId,
        durationMinutes: match.durationMinutes,
        stressLevel: 0.3,
        illnessOrPain: 0.0,
        heatExposure: 0.0,
        fitnessLevel: 0.5,
        notes: trimmed,
      ));
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

  static const Map<String, List<String>> _keywordMap =
      <String, List<String>>{
    'focused_coding': <String>[
      'cod', 'program', 'dev', 'develop', 'work', 'study', 'focus', 'task',
    ],
    'email_and_message_backlog': <String>[
      'email', 'message', 'slack', 'admin', 'inbox', 'reply',
    ],
    'video_meeting_for_work': <String>[
      'meeting', 'call', 'zoom', 'teams', 'conference',
    ],
    'social_media_scrolling': <String>[
      'social', 'scroll', 'instagram', 'twitter', 'tiktok', 'reels',
      'facebook', 'youtube',
    ],
    'easy_walking': <String>['easy walk', 'stroll', 'slow walk', 'leisurely'],
    'brisk_walking': <String>['walk', 'brisk'],
    'running_easy_pace': <String>['run', 'jog'],
    'hiit_workout': <String>[
      'hiit', 'gym', 'workout', 'weight', 'lift', 'exercise', 'training',
      'sports',
    ],
    'cooking_light_meal': <String>['cook', 'kitchen', 'meal prep', 'bake'],
    'deep_house_cleaning': <String>['clean', 'chore', 'errands', 'housework'],
    'slow_breathing_exercise': <String>['breath', 'breathe', 'breathing'],
    'mindfulness_meditation': <String>[
      'meditat', 'mindful', 'yoga', 'zen', 'stretching',
    ],
    'power_nap_10_20_min': <String>['nap'],
    'meal_break_away_from_desk': <String>[
      'break', 'lunch', 'dinner', 'breakfast', 'meal',
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
