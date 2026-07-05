import '../../models/battery_status.dart';
import '../../models/body_status.dart';
import '../../state/async_view_state.dart';

class DashboardState {
  const DashboardState({
    this.status = AsyncStatus.initial,
    this.bodyStatus,
    this.batteries = const <BatteryStatus>[],
    this.errorMessage,
  });

  final AsyncStatus status;
  final BodyStatus? bodyStatus;
  final List<BatteryStatus> batteries;
  final String? errorMessage;

  DashboardState copyWith({
    AsyncStatus? status,
    BodyStatus? bodyStatus,
    List<BatteryStatus>? batteries,
    String? errorMessage,
  }) {
    return DashboardState(
      status: status ?? this.status,
      bodyStatus: bodyStatus ?? this.bodyStatus,
      batteries: batteries ?? this.batteries,
      errorMessage: errorMessage,
    );
  }
}
