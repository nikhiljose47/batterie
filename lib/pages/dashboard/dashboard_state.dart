import '../../models/battery_status.dart';
import '../../models/body_status.dart';
import '../../models/logged_activity.dart';
import '../../models/timeline_point.dart';
import '../../state/async_view_state.dart';

class DashboardState {
  const DashboardState({
    this.status = AsyncStatus.initial,
    this.bodyStatus,
    this.batteries = const <BatteryStatus>[],
    this.loggedActivities = const <LoggedActivity>[],
    this.timelinePoints = const <TimelinePoint>[],
    this.errorMessage,
    this.isAnalyzing = false,
    this.analysisError,
    this.hasCheckInEstimate = false,
    this.lowestPhysical = 100.0,
    this.lowestPhysicalAt = -1,
    this.lowestBrain = 100.0,
    this.lowestBrainAt = -1,
  });

  final AsyncStatus status;
  final BodyStatus? bodyStatus;
  final List<BatteryStatus> batteries;
  final List<LoggedActivity> loggedActivities;

  /// Predicted physical/brain energy right after each logged activity,
  /// in chronological order — drives the outcome summary card.
  final List<TimelinePoint> timelinePoints;
  final String? errorMessage;
  final bool isAnalyzing;
  final String? analysisError;
  final bool hasCheckInEstimate;

  /// Lowest predicted energy values across today's timeline.
  /// Values are 0–100. [lowestPhysicalAt] / [lowestBrainAt] are minutes
  /// from midnight (-1 when no timeline data is available).
  final double lowestPhysical;
  final int lowestPhysicalAt;
  final double lowestBrain;
  final int lowestBrainAt;

  DashboardState copyWith({
    AsyncStatus? status,
    BodyStatus? bodyStatus,
    List<BatteryStatus>? batteries,
    List<LoggedActivity>? loggedActivities,
    List<TimelinePoint>? timelinePoints,
    String? errorMessage,
    bool? isAnalyzing,
    String? analysisError,
    bool? hasCheckInEstimate,
    double? lowestPhysical,
    int? lowestPhysicalAt,
    double? lowestBrain,
    int? lowestBrainAt,
  }) {
    return DashboardState(
      status: status ?? this.status,
      bodyStatus: bodyStatus ?? this.bodyStatus,
      batteries: batteries ?? this.batteries,
      loggedActivities: loggedActivities ?? this.loggedActivities,
      timelinePoints: timelinePoints ?? this.timelinePoints,
      errorMessage: errorMessage,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      analysisError: analysisError,
      hasCheckInEstimate: hasCheckInEstimate ?? this.hasCheckInEstimate,
      lowestPhysical: lowestPhysical ?? this.lowestPhysical,
      lowestPhysicalAt: lowestPhysicalAt ?? this.lowestPhysicalAt,
      lowestBrain: lowestBrain ?? this.lowestBrain,
      lowestBrainAt: lowestBrainAt ?? this.lowestBrainAt,
    );
  }
}
