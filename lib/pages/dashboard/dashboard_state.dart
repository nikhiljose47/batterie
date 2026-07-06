import '../../models/battery_status.dart';
import '../../models/body_status.dart';
import '../../state/async_view_state.dart';

class DashboardState {
  const DashboardState({
    this.status = AsyncStatus.initial,
    this.bodyStatus,
    this.batteries = const <BatteryStatus>[],
    this.errorMessage,
    this.isAnalyzing = false,
    this.analysisError,
    this.hasCheckInEstimate = false,
  });

  final AsyncStatus status;
  final BodyStatus? bodyStatus;
  final List<BatteryStatus> batteries;
  final String? errorMessage;
  final bool isAnalyzing;
  final String? analysisError;
  final bool hasCheckInEstimate;

  DashboardState copyWith({
    AsyncStatus? status,
    BodyStatus? bodyStatus,
    List<BatteryStatus>? batteries,
    String? errorMessage,
    bool? isAnalyzing,
    String? analysisError,
    bool? hasCheckInEstimate,
  }) {
    return DashboardState(
      status: status ?? this.status,
      bodyStatus: bodyStatus ?? this.bodyStatus,
      batteries: batteries ?? this.batteries,
      errorMessage: errorMessage,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      analysisError: analysisError,
      hasCheckInEstimate: hasCheckInEstimate ?? this.hasCheckInEstimate,
    );
  }
}
