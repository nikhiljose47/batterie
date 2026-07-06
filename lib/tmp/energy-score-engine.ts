import energyData from './energy_activity_map.json';

export type EnergyState = {
  physical: number; // 0..100 estimated readiness
  brain: number;    // 0..100 estimated readiness
  confidence: number; // 0..1
};

export type ScoreContext = {
  sleepQuality?: number;        // 0..1, default 0.7
  stressLevel?: number;         // 0..1, default 0.3
  illnessOrPain?: number;       // 0..1, default 0
  heatExposure?: number;        // 0..1, default 0
  fitnessLevel?: number;        // 0..1, default 0.5
  consecutiveMentalMinutes?: number;
  consecutiveSittingMinutes?: number;
};

const clamp = (n: number, min = 0, max = 100) => Math.max(min, Math.min(max, n));

function ageBand(age: number) {
  return energyData.ageBands.find(b => age >= b.minAge && age <= b.maxAge)
    ?? energyData.ageBands[2];
}

function confidenceToNumber(value: string): number {
  if (value === 'high') return 0.72;
  if (value === 'medium') return 0.58;
  return 0.43;
}

/**
 * Apply one logged activity. This estimates readiness; it does not measure physiology.
 */
export function applyActivity(
  state: EnergyState,
  activityId: string,
  durationMinutes: number,
  age: number,
  context: ScoreContext = {}
): EnergyState & { delayed?: { physical: number; brain: number; applyAfterMinutes: number } } {
  const activity = energyData.activities.find(a => a.id === activityId);
  if (!activity) throw new Error(`Unknown activity: ${activityId}`);
  if (!Number.isFinite(durationMinutes) || durationMinutes <= 0) {
    throw new Error('durationMinutes must be greater than zero');
  }

  const band = ageBand(age);
  const ratio = Math.min(durationMinutes / activity.referenceMinutes, 4);
  const positiveScale = Math.pow(ratio, 0.65); // diminishing recovery return
  const negativeScale = Math.pow(ratio, 0.85); // prolonged load compounds more

  const scale = (delta: number) => delta >= 0 ? positiveScale : negativeScale;
  const physicalAge = activity.physicalDelta < 0
    ? band.physicalDrainMultiplier
    : band.recoveryMultiplier;
  const brainAge = activity.brainDelta < 0
    ? band.mentalDrainMultiplier
    : band.recoveryMultiplier;

  const sleepQuality = clamp(context.sleepQuality ?? 0.7, 0, 1);
  const stress = clamp(context.stressLevel ?? 0.3, 0, 1);
  const illness = clamp(context.illnessOrPain ?? 0, 0, 1);
  const heat = clamp(context.heatExposure ?? 0, 0, 1);
  const fitness = clamp(context.fitnessLevel ?? 0.5, 0, 1);

  let pDelta = activity.physicalDelta * scale(activity.physicalDelta) * physicalAge;
  let bDelta = activity.brainDelta * scale(activity.brainDelta) * brainAge;

  // Context penalties. These are conservative heuristics, not diagnoses.
  if (activity.tags.includes('sleep')) {
    pDelta *= 0.65 + 0.5 * sleepQuality;
    bDelta *= 0.60 + 0.6 * sleepQuality;
  }
  if (activity.intensity === 'vigorous' || activity.intensity === 'very_vigorous') {
    pDelta *= 1.15 - 0.30 * fitness;
  }
  pDelta -= 5 * illness + 4 * heat;
  bDelta -= 4 * illness + 5 * stress;

  const mentalRun = context.consecutiveMentalMinutes ?? 0;
  if (activity.tags.includes('deep_work') && mentalRun > 90) bDelta *= 1.15;
  if (activity.tags.includes('deep_work') && mentalRun > 180) bDelta *= 1.20;

  const sittingRun = context.consecutiveSittingMinutes ?? 0;
  if (activity.tags.includes('sitting') && sittingRun > 120) pDelta -= 2;

  const result: EnergyState & { delayed?: { physical: number; brain: number; applyAfterMinutes: number } } = {
    physical: Math.round(clamp(state.physical + pDelta)),
    brain: Math.round(clamp(state.brain + bDelta)),
    confidence: Math.min(state.confidence, confidenceToNumber(activity.confidence))
  };

  if (activity.delayedAfterMinutes > 0 &&
      (activity.delayedPhysicalDelta !== 0 || activity.delayedBrainDelta !== 0)) {
    result.delayed = {
      physical: activity.delayedPhysicalDelta,
      brain: activity.delayedBrainDelta,
      applyAfterMinutes: activity.delayedAfterMinutes
    };
  }
  return result;
}

/** Set a daily starting estimate mainly from sleep duration and self-reported quality. */
export function createDailyBaseline(age: number, sleepHours: number, sleepQuality = 0.7): EnergyState {
  const band = ageBand(age);
  const targetMid = (band.sleepTargetHours.min + band.sleepTargetHours.max) / 2;
  const deficit = Math.max(0, targetMid - sleepHours);
  const excess = Math.max(0, sleepHours - band.sleepTargetHours.max - 1);
  const quality = clamp(sleepQuality, 0, 1);

  const physical = clamp(72 + (quality - 0.7) * 20 - deficit * 8 - excess * 2);
  const brain = clamp(74 + (quality - 0.7) * 24 - deficit * 10 - excess * 3);
  return { physical: Math.round(physical), brain: Math.round(brain), confidence: 0.55 };
}

/** Optional calibration: update a per-activity multiplier from a 0..100 user check-in. */
export function calibrationMultiplier(predicted: number, reported: number, oldMultiplier = 1): number {
  const safePredicted = Math.max(10, predicted);
  const observed = clamp(reported) / safePredicted;
  return clamp(oldMultiplier * 0.8 + observed * 0.2, 0.6, 1.5);
}
