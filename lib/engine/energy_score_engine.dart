import 'dart:math' as math;

import '../models/energy_check_in.dart';
import 'models/energy_state.dart';
import 'models/score_context.dart';

class EnergyScoreEngine {
  const EnergyScoreEngine();

  static const List<EnergyActivity> activities = <EnergyActivity>[
    EnergyActivity(
      id: 'focused_coding',
      name: 'Focused work or coding',
      referenceMinutes: 60,
      physicalDelta: -1,
      brainDelta: -22,
      intensity: ActivityIntensity.light,
      confidence: ActivityConfidence.medium,
      tags: <String>['deep_work', 'sitting', 'work'],
    ),
    EnergyActivity(
      id: 'email_and_message_backlog',
      name: 'Messages or admin backlog',
      referenceMinutes: 60,
      physicalDelta: -2,
      brainDelta: -19,
      intensity: ActivityIntensity.light,
      confidence: ActivityConfidence.medium,
      tags: <String>['sitting', 'work'],
    ),
    EnergyActivity(
      id: 'video_meeting_for_work',
      name: 'Video meeting',
      referenceMinutes: 60,
      physicalDelta: -2,
      brainDelta: -17,
      intensity: ActivityIntensity.light,
      confidence: ActivityConfidence.medium,
      tags: <String>['sitting', 'screen'],
    ),
    EnergyActivity(
      id: 'social_media_scrolling',
      name: 'Social media scrolling',
      referenceMinutes: 30,
      physicalDelta: -1,
      brainDelta: -14,
      intensity: ActivityIntensity.sedentary,
      confidence: ActivityConfidence.low,
      tags: <String>['screen', 'sitting'],
    ),
    EnergyActivity(
      id: 'easy_walking',
      name: 'Easy walking',
      referenceMinutes: 30,
      physicalDelta: -3,
      brainDelta: 3,
      intensity: ActivityIntensity.light,
      confidence: ActivityConfidence.high,
      tags: <String>['movement'],
    ),
    EnergyActivity(
      id: 'brisk_walking',
      name: 'Brisk walking',
      referenceMinutes: 30,
      physicalDelta: -7,
      brainDelta: 6,
      intensity: ActivityIntensity.moderate,
      confidence: ActivityConfidence.high,
      tags: <String>['movement'],
    ),
    EnergyActivity(
      id: 'running_easy_pace',
      name: 'Easy run',
      referenceMinutes: 30,
      physicalDelta: -16,
      brainDelta: 6,
      intensity: ActivityIntensity.vigorous,
      confidence: ActivityConfidence.high,
      tags: <String>['exercise'],
    ),
    EnergyActivity(
      id: 'hiit_workout',
      name: 'HIIT or hard workout',
      referenceMinutes: 20,
      physicalDelta: -17,
      brainDelta: -5,
      intensity: ActivityIntensity.veryVigorous,
      confidence: ActivityConfidence.high,
      tags: <String>['exercise'],
    ),
    EnergyActivity(
      id: 'cooking_light_meal',
      name: 'Cooking or light chores',
      referenceMinutes: 30,
      physicalDelta: -2,
      brainDelta: -4,
      intensity: ActivityIntensity.light,
      confidence: ActivityConfidence.medium,
      tags: <String>['home'],
    ),
    EnergyActivity(
      id: 'deep_house_cleaning',
      name: 'Deep cleaning or errands',
      referenceMinutes: 60,
      physicalDelta: -9,
      brainDelta: -6,
      intensity: ActivityIntensity.moderate,
      confidence: ActivityConfidence.medium,
      tags: <String>['home'],
    ),
    EnergyActivity(
      id: 'slow_breathing_exercise',
      name: 'Breathing exercise',
      referenceMinutes: 10,
      physicalDelta: 10,
      brainDelta: 11,
      intensity: ActivityIntensity.sedentary,
      confidence: ActivityConfidence.high,
      tags: <String>['recovery', 'gain'],
    ),
    EnergyActivity(
      id: 'mindfulness_meditation',
      name: 'Meditation',
      referenceMinutes: 15,
      physicalDelta: 10,
      brainDelta: 13,
      intensity: ActivityIntensity.sedentary,
      confidence: ActivityConfidence.high,
      tags: <String>['recovery', 'gain'],
    ),
    EnergyActivity(
      id: 'power_nap_10_20_min',
      name: 'Short power nap',
      referenceMinutes: 20,
      physicalDelta: 5,
      brainDelta: 9,
      intensity: ActivityIntensity.sedentary,
      confidence: ActivityConfidence.high,
      tags: <String>['nap', 'gain'],
    ),
    EnergyActivity(
      id: 'meal_break_away_from_desk',
      name: 'Meal break away from desk',
      referenceMinutes: 30,
      physicalDelta: 5,
      brainDelta: 8,
      intensity: ActivityIntensity.sedentary,
      confidence: ActivityConfidence.medium,
      tags: <String>['break', 'gain'],
    ),
  ];

  EnergyScoreResult estimate(EnergyCheckIn checkIn) {
    final baseline = createDailyBaseline(
      checkIn.age,
      checkIn.sleepHours,
      checkIn.sleepQuality,
    );
    final activity = activityById(checkIn.activityId);
    final state = applyActivity(
      baseline,
      activity.id,
      checkIn.durationMinutes,
      checkIn.age,
      context: ScoreContext(
        sleepQuality: checkIn.sleepQuality,
        stressLevel: checkIn.stressLevel,
        illnessOrPain: checkIn.illnessOrPain,
        heatExposure: checkIn.heatExposure,
        fitnessLevel: checkIn.fitnessLevel,
        consecutiveMentalMinutes:
            activity.tags.contains('deep_work') ? checkIn.durationMinutes : 0,
        consecutiveSittingMinutes:
            activity.tags.contains('sitting') ? checkIn.durationMinutes : 0,
      ),
    );

    return EnergyScoreResult(
      state: state,
      activity: activity,
      status: _statusFor(state, checkIn),
      potential: _potentialFor(state),
      supportNote: _supportNoteFor(state, checkIn),
      recommendations: _recommendationsFor(state, checkIn, activity),
    );
  }

  EnergyState createDailyBaseline(
    int age,
    double sleepHours, [
    double sleepQuality = 0.7,
  ]) {
    final band = _ageBand(age);
    final targetMid = (band.sleepMinHours + band.sleepMaxHours) / 2;
    final deficit = math.max(0, targetMid - sleepHours);
    final excess = math.max(0, sleepHours - band.sleepMaxHours - 1);
    final quality = _clamp(sleepQuality, 0, 1);

    final physical =
        _clamp(72 + (quality - 0.7) * 20 - deficit * 8 - excess * 2);
    final brain = _clamp(74 + (quality - 0.7) * 24 - deficit * 10 - excess * 3);

    return EnergyState(
      physical: physical.round(),
      brain: brain.round(),
      confidence: 0.55,
    );
  }

  EnergyState applyActivity(
    EnergyState state,
    String activityId,
    int durationMinutes,
    int age, {
    ScoreContext context = const ScoreContext(),
  }) {
    final activity = activityById(activityId);
    if (durationMinutes <= 0) {
      throw ArgumentError.value(durationMinutes, 'durationMinutes');
    }

    final band = _ageBand(age);
    final ratio = math.min(durationMinutes / activity.referenceMinutes, 4.0);
    final positiveScale = math.pow(ratio, 0.65).toDouble();
    final negativeScale = math.pow(ratio, 0.85).toDouble();

    double scale(int delta) => delta >= 0 ? positiveScale : negativeScale;

    final physicalAge = activity.physicalDelta < 0
        ? band.physicalDrainMultiplier
        : band.recoveryMultiplier;
    final brainAge = activity.brainDelta < 0
        ? band.mentalDrainMultiplier
        : band.recoveryMultiplier;

    var physicalDelta =
        activity.physicalDelta * scale(activity.physicalDelta) * physicalAge;
    var brainDelta =
        activity.brainDelta * scale(activity.brainDelta) * brainAge;

    if (activity.isVigorous) {
      physicalDelta *= 1.15 - 0.30 * _clamp(context.fitnessLevel, 0, 1);
    }

    final illness = _clamp(context.illnessOrPain, 0, 1);
    final heat = _clamp(context.heatExposure, 0, 1);
    final stress = _clamp(context.stressLevel, 0, 1);

    physicalDelta -= 5 * illness + 4 * heat;
    brainDelta -= 4 * illness + 5 * stress;

    if (activity.tags.contains('deep_work') &&
        context.consecutiveMentalMinutes > 90) {
      brainDelta *= 1.15;
    }
    if (activity.tags.contains('deep_work') &&
        context.consecutiveMentalMinutes > 180) {
      brainDelta *= 1.20;
    }
    if (activity.tags.contains('sitting') &&
        context.consecutiveSittingMinutes > 120) {
      physicalDelta -= 2;
    }

    return EnergyState(
      physical: _clamp(state.physical + physicalDelta).round(),
      brain: _clamp(state.brain + brainDelta).round(),
      confidence: math.min(state.confidence, activity.confidence.value),
    );
  }

  EnergyActivity activityById(String id) {
    return activities.firstWhere(
      (activity) => activity.id == id,
      orElse: () => activities.first,
    );
  }

  EnergyAgeBand _ageBand(int age) {
    return _ageBands.firstWhere(
      (band) => age >= band.minAge && age <= band.maxAge,
      orElse: () => _ageBands[2],
    );
  }

  String _statusFor(EnergyState state, EnergyCheckIn checkIn) {
    final physical = _levelName(state.physical);
    final brain = _levelName(state.brain);
    return 'Your physical readiness looks $physical and your brain readiness looks $brain after ${checkIn.sleepHours.toStringAsFixed(1)} hours of sleep.';
  }

  String _potentialFor(EnergyState state) {
    if (state.physical >= 75 && state.brain >= 75) {
      return 'Good window for demanding work, training, or social plans. Keep recovery breaks on the calendar.';
    }
    if (state.brain >= 70 && state.physical < 55) {
      return 'Better for thinking work than hard physical effort. Keep movement light and deliberate.';
    }
    if (state.physical >= 70 && state.brain < 55) {
      return 'Your body can move, but decision-heavy work may feel expensive. Use simple tasks and clear breaks.';
    }
    if (state.physical < 45 || state.brain < 45) {
      return 'Keep the next block small. Recovery, hydration, food, and one essential task are the better bet.';
    }
    return 'A steady day is possible if you single-task and avoid stacking too many high-effort blocks.';
  }

  String _supportNoteFor(EnergyState state, EnergyCheckIn checkIn) {
    final confidence = (state.confidence * 100).round();
    final notes = checkIn.notes.trim();
    if (notes.isEmpty) {
      return 'This is a sensor-free estimate with about $confidence% confidence. Treat it as a planning signal, not a medical reading.';
    }
    return 'Your note was included: "$notes". This is a sensor-free planning estimate with about $confidence% confidence.';
  }

  List<String> _recommendationsFor(
    EnergyState state,
    EnergyCheckIn checkIn,
    EnergyActivity activity,
  ) {
    final actions = <String>[];

    if (checkIn.sleepHours < 6.5 || checkIn.sleepQuality < 0.45) {
      actions.add('Protect an earlier wind-down tonight');
    }
    if (state.brain < 55 || checkIn.stressLevel > 0.65) {
      actions.add('Do one priority task before switching context');
    }
    if (state.physical < 55 || checkIn.illnessOrPain > 0.35) {
      actions.add('Keep movement gentle for the next block');
    }
    if (checkIn.heatExposure > 0.5) {
      actions.add('Cool down and hydrate before exertion');
    }
    if (activity.tags.contains('sitting') && checkIn.durationMinutes >= 60) {
      actions.add('Take a short standing or walking reset');
    }
    if (actions.length < 3) {
      actions.add('Drink water and eat something steady');
    }
    if (actions.length < 3) {
      actions.add('Schedule a short recovery break');
    }
    if (actions.length < 3) {
      actions.add('Match the next task to your lowest battery');
    }

    return actions.take(3).toList();
  }

  String _levelName(int score) {
    if (score >= 80) return 'high';
    if (score >= 65) return 'solid';
    if (score >= 45) return 'moderate';
    if (score >= 25) return 'low';
    return 'very low';
  }

  double _clamp(num value, [double min = 0, double max = 100]) {
    return math.max(min, math.min(max, value.toDouble()));
  }

  static const List<EnergyAgeBand> _ageBands = <EnergyAgeBand>[
    EnergyAgeBand(
      minAge: 6,
      maxAge: 12,
      sleepMinHours: 9,
      sleepMaxHours: 12,
      physicalDrainMultiplier: 0.9,
      mentalDrainMultiplier: 0.9,
      recoveryMultiplier: 1.08,
    ),
    EnergyAgeBand(
      minAge: 13,
      maxAge: 17,
      sleepMinHours: 8,
      sleepMaxHours: 10,
      physicalDrainMultiplier: 0.95,
      mentalDrainMultiplier: 0.95,
      recoveryMultiplier: 1.05,
    ),
    EnergyAgeBand(
      minAge: 18,
      maxAge: 29,
      sleepMinHours: 7,
      sleepMaxHours: 9,
      physicalDrainMultiplier: 1,
      mentalDrainMultiplier: 1,
      recoveryMultiplier: 1,
    ),
    EnergyAgeBand(
      minAge: 30,
      maxAge: 44,
      sleepMinHours: 7,
      sleepMaxHours: 9,
      physicalDrainMultiplier: 1.03,
      mentalDrainMultiplier: 1.02,
      recoveryMultiplier: 0.99,
    ),
    EnergyAgeBand(
      minAge: 45,
      maxAge: 59,
      sleepMinHours: 7,
      sleepMaxHours: 9,
      physicalDrainMultiplier: 1.08,
      mentalDrainMultiplier: 1.04,
      recoveryMultiplier: 0.96,
    ),
    EnergyAgeBand(
      minAge: 60,
      maxAge: 74,
      sleepMinHours: 7,
      sleepMaxHours: 9,
      physicalDrainMultiplier: 1.15,
      mentalDrainMultiplier: 1.05,
      recoveryMultiplier: 0.93,
    ),
    EnergyAgeBand(
      minAge: 75,
      maxAge: 120,
      sleepMinHours: 7,
      sleepMaxHours: 8,
      physicalDrainMultiplier: 1.25,
      mentalDrainMultiplier: 1.08,
      recoveryMultiplier: 0.9,
    ),
  ];
}

class EnergyScoreResult {
  const EnergyScoreResult({
    required this.state,
    required this.activity,
    required this.status,
    required this.potential,
    required this.supportNote,
    required this.recommendations,
  });

  final EnergyState state;
  final EnergyActivity activity;
  final String status;
  final String potential;
  final String supportNote;
  final List<String> recommendations;
}

class EnergyActivity {
  const EnergyActivity({
    required this.id,
    required this.name,
    required this.referenceMinutes,
    required this.physicalDelta,
    required this.brainDelta,
    required this.intensity,
    required this.confidence,
    required this.tags,
  });

  final String id;
  final String name;
  final int referenceMinutes;
  final int physicalDelta;
  final int brainDelta;
  final ActivityIntensity intensity;
  final ActivityConfidence confidence;
  final List<String> tags;

  bool get isVigorous =>
      intensity == ActivityIntensity.vigorous ||
      intensity == ActivityIntensity.veryVigorous;
}

class EnergyAgeBand {
  const EnergyAgeBand({
    required this.minAge,
    required this.maxAge,
    required this.sleepMinHours,
    required this.sleepMaxHours,
    required this.physicalDrainMultiplier,
    required this.mentalDrainMultiplier,
    required this.recoveryMultiplier,
  });

  final int minAge;
  final int maxAge;
  final double sleepMinHours;
  final double sleepMaxHours;
  final double physicalDrainMultiplier;
  final double mentalDrainMultiplier;
  final double recoveryMultiplier;
}

enum ActivityIntensity {
  sedentary,
  light,
  moderate,
  vigorous,
  veryVigorous,
}

enum ActivityConfidence {
  high(0.72),
  medium(0.58),
  low(0.43);

  const ActivityConfidence(this.value);

  final double value;
}
