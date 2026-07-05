import '../../constants/app_strings.dart';
import '../../models/news_article.dart';
import '../../state/async_view_state.dart';

class NewsState {
  const NewsState({
    this.status = AsyncStatus.initial,
    this.articles = const <NewsArticle>[],
    this.selectedFilter = AppStrings.allFilter,
    this.errorMessage,
  });

  final AsyncStatus status;
  final List<NewsArticle> articles;
  final String selectedFilter;
  final String? errorMessage;

  List<NewsArticle> get visibleArticles {
    if (selectedFilter == AppStrings.allFilter) {
      return articles;
    }

    return articles
        .where((article) => article.category == selectedFilter)
        .toList(growable: false);
  }

  NewsState copyWith({
    AsyncStatus? status,
    List<NewsArticle>? articles,
    String? selectedFilter,
    String? errorMessage,
  }) {
    return NewsState(
      status: status ?? this.status,
      articles: articles ?? this.articles,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      errorMessage: errorMessage,
    );
  }
}
