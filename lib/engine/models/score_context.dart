/// Optional context that modifies how an activity affects energy scores.
///
/// All fields are optional — supply only what you know.
/// Defaults represent a "typical healthy adult" baseline.
///
/// Usage:
///   const ctx = ScoreContext(sleepQuality: 0.5, stressLevel: 0.6);
///   final result = engine.applyActivity('focused_coding', 90, 28, context: ctx);
class ScoreContext {
  const ScoreContext({
    this.sleepQuality = 0.7,
    this.stressLevel = 0.3,
    this.illnessOrPain = 0.0,
    this.heatExposure = 0.0,
    this.fitnessLevel = 0.5,
    this.consecutiveMentalMinutes = 0,
    this.consecutiveSittingMinutes = 0,
  });

  /// Quality of last night's sleep. 0.0 = terrible, 1.0 = excellent. Default 0.7.
  final double sleepQuality;

  /// Current perceived stress. 0.0 = calm, 1.0 = extreme. Default 0.3.
  final double stressLevel;

  /// Illness or pain intensity. 0.0 = none, 1.0 = severe. Default 0.0.
  final double illnessOrPain;

  /// Ambient heat stress. 0.0 = comfortable, 1.0 = dangerous heat. Default 0.0.
  final double heatExposure;

  /// Fitness level. 0.0 = sedentary, 1.0 = highly trained. Default 0.5.
  /// Used to scale the drain of vigorous activities.
  final double fitnessLevel;

  /// How long the person has been doing cognitive work without a break.
  /// Activities tagged 'deep_work' compound brain drain after 90 and 180 min.
  final int consecutiveMentalMinutes;

  /// How long the person has been sitting without a break.
  /// Activities tagged 'sitting' add extra physical drain after 120 min.
  final int consecutiveSittingMinutes;
}
