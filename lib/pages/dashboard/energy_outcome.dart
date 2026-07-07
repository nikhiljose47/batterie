import 'dart:math' as math;

import '../../engine/energy_score_engine.dart';
import '../../models/logged_activity.dart';
import '../../models/timeline_point.dart';

enum EnergyOutcomeTone { great, ok, low, empty }

class EnergyOutcome {
  const EnergyOutcome({required this.headline, required this.tone});

  final String headline;
  final EnergyOutcomeTone tone;
}

/// Reads the whole day's planned/logged activities (past and future) and
/// summarizes where energy is predicted to be strong or thin.
EnergyOutcome computeEnergyOutcome(
  List<TimelinePoint> points,
  EnergyScoreEngine engine,
) {
  if (points.isEmpty) {
    return const EnergyOutcome(
      headline: 'Plan your day to see today\'s energy outlook.',
      tone: EnergyOutcomeTone.empty,
    );
  }

  var minPhysical = 100;
  var minBrain = 100;
  TimelinePoint? worstPoint;
  var worstMetricIsPhysical = true;

  for (final point in points) {
    if (point.physical < minPhysical) {
      minPhysical = point.physical;
    }
    if (point.brain < minBrain) {
      minBrain = point.brain;
    }
    final pointWorst = math.min(point.physical, point.brain);
    final currentWorst =
        worstPoint == null ? 101 : math.min(worstPoint.physical, worstPoint.brain);
    if (pointWorst < currentWorst) {
      worstPoint = point;
      worstMetricIsPhysical = point.physical <= point.brain;
    }
  }

  final overallMin = math.min(minPhysical, minBrain);

  if (overallMin >= 80) {
    return const EnergyOutcome(
      headline: 'All green — 80%+ energy through the day! 🔋',
      tone: EnergyOutcomeTone.great,
    );
  }

  if (worstPoint == null) {
    return EnergyOutcome(
      headline: 'Energy dips to $overallMin% today.',
      tone: overallMin < 40 ? EnergyOutcomeTone.low : EnergyOutcomeTone.ok,
    );
  }

  final activityName = engine.activityById(worstPoint.activityId).name;
  final time = formatMinutes(worstPoint.startMinutes);
  final metricLabel = worstMetricIsPhysical ? 'physical' : 'brain';

  if (overallMin < 40) {
    return EnergyOutcome(
      headline: 'Low $metricLabel energy after $activityName ($time).',
      tone: EnergyOutcomeTone.low,
    );
  }

  return EnergyOutcome(
    headline: 'Dips to $overallMin% $metricLabel after $activityName ($time).',
    tone: EnergyOutcomeTone.ok,
  );
}
