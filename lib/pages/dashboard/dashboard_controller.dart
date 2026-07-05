import 'package:flutter/foundation.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../models/battery_status.dart';
import '../../models/body_status.dart';
import '../../repositories/energy_health_repository.dart';
import '../../services/open_router_service.dart';
import '../../services/settings_service.dart';
import '../../state/async_view_state.dart';
import 'dashboard_state.dart';

class DashboardController extends ChangeNotifier {
  DashboardController({
    EnergyHealthRepository? repository,
    OpenRouterService? openRouterService,
    SettingsService? settingsService,
  })  : repository = repository ?? const EnergyHealthRepository(),
        _openRouterService = openRouterService ?? const OpenRouterService(),
        _settingsService = settingsService ?? SettingsService();

  final EnergyHealthRepository repository;
  final OpenRouterService _openRouterService;
  final SettingsService _settingsService;

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
        isAiPowered: false,
      );
    } catch (_) {
      _state = _state.copyWith(
        status: AsyncStatus.error,
        errorMessage: AppStrings.genericError,
      );
    }

    notifyListeners();
  }

  Future<void> analyzeCheckIn(String userInput) async {
    if (userInput.trim().isEmpty || _state.isAnalyzing) return;

    _state = _state.copyWith(isAnalyzing: true, analysisError: null);
    notifyListeners();

    try {
      final apiKey = _settingsService.getApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        _state = _state.copyWith(
          isAnalyzing: false,
          analysisError:
              'No API key set. Add your OpenRouter key in Settings.',
        );
        notifyListeners();
        return;
      }

      final analysis = await _openRouterService.analyzeEnergyLevels(
        apiKey: apiKey,
        userInput: userInput.trim(),
      );

      final updatedBatteries = <BatteryStatus>[
        BatteryStatus(
          title: AppStrings.physicalBattery,
          percent: analysis.physicalPercent,
          subtitle: _percentLabel(analysis.physicalPercent),
          color: AppColors.bodyEnergy,
        ),
        BatteryStatus(
          title: AppStrings.brainBattery,
          percent: analysis.brainPercent,
          subtitle: _percentLabel(analysis.brainPercent),
          color: AppColors.brainEnergy,
        ),
      ];

      final updatedBodyStatus = BodyStatus(
        status: analysis.status,
        potential: analysis.potential,
        previousActivity: _state.bodyStatus?.previousActivity ?? '',
        supportNote: _state.bodyStatus?.supportNote ?? '',
        recommendedActions: analysis.recommendations,
      );

      _state = _state.copyWith(
        bodyStatus: updatedBodyStatus,
        batteries: updatedBatteries,
        isAnalyzing: false,
        isAiPowered: true,
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
