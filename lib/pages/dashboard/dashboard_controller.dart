import 'package:flutter/foundation.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../engine/energy_score_engine.dart';
import '../../models/battery_status.dart';
import '../../models/body_status.dart';
import '../../models/energy_check_in.dart';
import '../../repositories/energy_health_repository.dart';
import '../../state/async_view_state.dart';
import 'dashboard_state.dart';

class DashboardController extends ChangeNotifier {
  DashboardController({
    EnergyHealthRepository? repository,
    EnergyScoreEngine? energyScoreEngine,
  })  : repository = repository ?? const EnergyHealthRepository(),
        _energyScoreEngine = energyScoreEngine ?? const EnergyScoreEngine();

  final EnergyHealthRepository repository;
  final EnergyScoreEngine _energyScoreEngine;

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
        hasCheckInEstimate: false,
      );
    } catch (_) {
      _state = _state.copyWith(
        status: AsyncStatus.error,
        errorMessage: AppStrings.genericError,
      );
    }

    notifyListeners();
  }

  Future<void> analyzeCheckIn(EnergyCheckIn checkIn) async {
    if (_state.isAnalyzing) return;

    _state = _state.copyWith(isAnalyzing: true, analysisError: null);
    notifyListeners();

    try {
      final result = _energyScoreEngine.estimate(checkIn);

      final updatedBatteries = <BatteryStatus>[
        BatteryStatus(
          title: AppStrings.physicalBattery,
          percent: result.state.physical / 100,
          subtitle: _percentLabel(result.state.physical / 100),
          color: AppColors.bodyEnergy,
        ),
        BatteryStatus(
          title: AppStrings.brainBattery,
          percent: result.state.brain / 100,
          subtitle: _percentLabel(result.state.brain / 100),
          color: AppColors.brainEnergy,
        ),
      ];

      final updatedBodyStatus = BodyStatus(
        status: result.status,
        potential: result.potential,
        previousActivity:
            '${result.activity.name} for ${checkIn.durationMinutes} min.',
        supportNote: result.supportNote,
        recommendedActions: result.recommendations,
      );

      _state = _state.copyWith(
        bodyStatus: updatedBodyStatus,
        batteries: updatedBatteries,
        isAnalyzing: false,
        hasCheckInEstimate: true,
      );
    } catch (e) {
      _state = _state.copyWith(
        isAnalyzing: false,
        analysisError: e.toString().replaceFirst('Exception: ', ''),
      );
    }

    notifyListeners();
  }

  String _percentLabel(double percent) {
    if (percent >= 0.8) return 'High energy';
    if (percent >= 0.6) return 'Good level';
    if (percent >= 0.4) return 'Moderate — pace yourself';
    if (percent >= 0.2) return 'Low — prioritise rest';
    return 'Very low — rest now';
  }
}
