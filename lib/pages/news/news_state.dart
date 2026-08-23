import '../../constants/article_constants.dart';
import '../../models/news_article.dart';
import '../../state/async_view_state.dart';

class NewsState {
  const NewsState({
    this.status = AsyncStatus.initial,
    this.articles = const <NewsArticle>[],
    this.selectedFilter = ArticleConstants.allTag,
    this.errorMessage,
  });

  final AsyncStatus status;
  final List<NewsArticle> articles;
  final String selectedFilter;
  final String? errorMessage;

  List<NewsArticle> get visibleArticles {
    if (selectedFilter == ArticleConstants.allTag) {
      return articles;
    }
    if (selectedFilter == ArticleConstants.recentTag) {
      final cutoff = DateTime.now().subtract(
        const Duration(days: ArticleConstants.recentArticleWindowDays),
      );
      return articles
          .where((article) => !article.publishedAt.isBefore(cutoff))
          .toList(growable: false);
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
