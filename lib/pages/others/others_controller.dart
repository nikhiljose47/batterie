import 'package:flutter/foundation.dart';

import '../../constants/app_strings.dart';
import '../../models/person_status.dart';
import '../../services/daily_progress_sync_service.dart';
import '../../state/async_view_state.dart';
import 'others_state.dart';

class OthersController extends ChangeNotifier {
  OthersController();

  OthersState _state = const OthersState();
  bool _disposed = false;

  OthersState get state => _state;

  Future<void> load() async {
    if (_disposed) return;
    _state = _state.copyWith(status: AsyncStatus.loading);
    notifyListeners();

    try {
      final current =
          await DailyProgressSyncService.instance.currentUserStatus();
      final loaded =
          await DailyProgressSyncService.instance.cachedTopStatuses();
      final people = <PersonStatus>[
        if (current != null) current,
        ...loaded,
      ]..sort((a, b) {
          final aScore = a.scorePercent ?? (a.energyPercent * 100).round();
          final bScore = b.scorePercent ?? (b.energyPercent * 100).round();
          return bScore.compareTo(aScore);
        });
      final topPeople = people.take(7).toList(growable: false);
      if (_disposed) return;

      _state = _state.copyWith(
        status: topPeople.isEmpty ? AsyncStatus.empty : AsyncStatus.success,
        people: topPeople,
      );
    } catch (_) {
      if (_disposed) return;
      _state = _state.copyWith(
        status: AsyncStatus.error,
        errorMessage: AppStrings.genericError,
      );
    }

    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
