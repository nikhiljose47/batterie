class BodyStatus {
  const BodyStatus({
    required this.status,
    required this.potential,
    required this.previousActivity,
    required this.supportNote,
    required this.recommendedActions,
  });

  final String status;
  final String potential;
  final String previousActivity;
  final String supportNote;
  final List<String> recommendedActions;
}
