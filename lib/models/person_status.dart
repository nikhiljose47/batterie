class PersonStatus {
  const PersonStatus({
    required this.name,
    required this.role,
    required this.energyPercent,
    required this.brainPercent,
    required this.note,
    this.scorePercent,
    this.goalDoneCount,
    this.goalTotalCount,
    this.appUseMinutes,
    this.focusMinutes,
  });

  final String name;
  final String role;
  final double energyPercent;
  final double brainPercent;
  final String note;
  final int? scorePercent;
  final int? goalDoneCount;
  final int? goalTotalCount;
  final int? appUseMinutes;
  final int? focusMinutes;
}
