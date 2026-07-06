class EnergyCheckIn {
  const EnergyCheckIn({
    required this.age,
    required this.sleepHours,
    required this.sleepQuality,
    required this.activityId,
    required this.durationMinutes,
    required this.stressLevel,
    required this.illnessOrPain,
    required this.heatExposure,
    required this.fitnessLevel,
    this.notes = '',
  });

  final int age;
  final double sleepHours;
  final double sleepQuality;
  final String activityId;
  final int durationMinutes;
  final double stressLevel;
  final double illnessOrPain;
  final double heatExposure;
  final double fitnessLevel;
  final String notes;
}
