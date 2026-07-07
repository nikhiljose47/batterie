/// A single point on the day's predicted energy curve, captured right after
/// [activityId] finishes. Used to drive the outcome summary card.
class TimelinePoint {
  const TimelinePoint({
    required this.startMinutes,
    required this.activityId,
    required this.physical,
    required this.brain,
  });

  final int startMinutes;
  final String activityId;
  final int physical;
  final int brain;
}
