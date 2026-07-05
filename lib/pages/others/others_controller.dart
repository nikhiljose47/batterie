import 'package:flutter/foundation.dart';

import '../../constants/app_strings.dart';
import '../../repositories/energy_health_repository.dart';
import '../../state/async_view_state.dart';
import 'others_state.dart';

class OthersController extends ChangeNotifier {
  OthersController({
    this.repository = const EnergyHealthRepository(),
  });

  final EnergyHealthRepository repository;

  OthersState _state = const OthersState();

  OthersState get state => _state;

  Future<void> load() async {
    _state = _state.copyWith(status: AsyncStatus.loading);
    notifyListeners();

    try {
      final people = await repository.getPeopleStatuses();

      _state = _state.copyWith(
        status: people.isEmpty ? AsyncStatus.empty : AsyncStatus.success,
        people: people,
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
