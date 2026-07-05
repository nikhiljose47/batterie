import 'package:flutter/foundation.dart';

import '../../constants/app_strings.dart';
import '../../repositories/energy_health_repository.dart';
import '../../state/async_view_state.dart';
import 'dashboard_state.dart';

class DashboardController extends ChangeNotifier {
  DashboardController({
    this.repository = const EnergyHealthRepository(),
  });

  final EnergyHealthRepository repository;

  DashboardState _state = const DashboardState();

  DashboardState get state => _state;

  Future<void> load() async {
    _state = _state.copyWith(status: AsyncStatus.loading);
    notifyListeners();

    try {
      final bodyStatusFuture = repository.getBodyStatus();
      final batteriesFuture = repository.getBatteryStatuses();
      final bodyStatus = await bodyStatusFuture;
      final batteries = await batteriesFuture;

      _state = _state.copyWith(
        status: batteries.isEmpty ? AsyncStatus.empty : AsyncStatus.success,
        bodyStatus: bodyStatus,
        batteries: batteries,
      );
    } catch (_) {
      _state = _state.copyWith(
        status: AsyncStatus.error,
        errorMessage: AppStrings.genericError,
      );
    }

    notifyListeners();
  }
}
