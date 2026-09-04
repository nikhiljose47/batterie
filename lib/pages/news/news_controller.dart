import 'package:flutter/foundation.dart';

import '../../constants/article_constants.dart';
import '../../constants/app_strings.dart';
import '../../models/news_article.dart';
import '../../repositories/energy_health_repository.dart';
import '../../state/async_view_state.dart';
import 'news_state.dart';

class NewsController extends ChangeNotifier {
  NewsController({
    this.repository = const EnergyHealthRepository(),
  });

  final EnergyHealthRepository repository;
  static List<NewsArticle>? _cachedArticles;

  NewsState _state = const NewsState();

  NewsState get state => _state;

  static const List<String> filters = <String>[
    ...ArticleConstants.filters,
  ];

  Future<void> load({bool forceRefresh = false}) async {
    final cached = _cachedArticles;
    if (!forceRefresh && cached != null) {
      _state = _state.copyWith(
        status: cached.isEmpty ? AsyncStatus.empty : AsyncStatus.success,
        articles: cached,
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(status: AsyncStatus.loading);
    notifyListeners();

    try {
      final articles = await repository.getNewsArticles();
      _cachedArticles = articles;

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

  Future<void> refresh() => load(forceRefresh: true);

  void selectFilter(String filter) {
    if (_state.selectedFilter == filter) {
      return;
    }

    _state = _state.copyWith(selectedFilter: filter);
    notifyListeners();
  }
}
