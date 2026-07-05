import 'package:flutter/foundation.dart';

import '../../constants/app_strings.dart';
import '../../repositories/energy_health_repository.dart';
import '../../state/async_view_state.dart';
import 'news_state.dart';

class NewsController extends ChangeNotifier {
  NewsController({
    this.repository = const EnergyHealthRepository(),
  });

  final EnergyHealthRepository repository;

  NewsState _state = const NewsState();

  NewsState get state => _state;

  static const List<String> filters = <String>[
    AppStrings.allFilter,
    AppStrings.recoveryFilter,
    AppStrings.sleepFilter,
    AppStrings.focusFilter,
  ];

  Future<void> load() async {
    _state = _state.copyWith(status: AsyncStatus.loading);
    notifyListeners();

    try {
      final articles = await repository.getNewsArticles();

      _state = _state.copyWith(
        status: articles.isEmpty ? AsyncStatus.empty : AsyncStatus.success,
        articles: articles,
      );
    } catch (_) {
      _state = _state.copyWith(
        status: AsyncStatus.error,
        errorMessage: AppStrings.genericError,
      );
    }

    notifyListeners();
  }

  void selectFilter(String filter) {
    if (_state.selectedFilter == filter) {
      return;
    }

    _state = _state.copyWith(selectedFilter: filter);
    notifyListeners();
  }
}
