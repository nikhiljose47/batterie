import 'package:flutter/material.dart';

import '../../config/routes/app_routes.dart';
import '../../constants/app_spacing.dart';
import '../../constants/app_strings.dart';
import '../../models/news_article.dart';
import '../../shared/widgets/empty_state_view.dart';
import '../../shared/widgets/error_state_view.dart';
import '../../shared/widgets/loading_state_view.dart';
import '../../state/async_view_state.dart';
import 'news_controller.dart';
import 'widgets/news_article_card.dart';
import 'widgets/news_filter_bar.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  late final NewsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = NewsController()..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;

        switch (state.status) {
          case AsyncStatus.initial:
          case AsyncStatus.loading:
            return const LoadingStateView();
          case AsyncStatus.empty:
            return const EmptyStateView(message: AppStrings.emptyTitle);
          case AsyncStatus.error:
            return ErrorStateView(
              message: state.errorMessage ?? AppStrings.genericError,
              onRetry: _controller.load,
            );
          case AsyncStatus.success:
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.large,
                    AppSpacing.large,
                    AppSpacing.large,
                    AppSpacing.small,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        AppStrings.newsTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xSmall),
                      Text(
                        AppStrings.sortedRecent,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                NewsFilterBar(
                  filters: NewsController.filters,
                  selectedFilter: state.selectedFilter,
                  onSelected: _controller.selectFilter,
                ),
                Expanded(
                  child: state.visibleArticles.isEmpty
                      ? const EmptyStateView(message: AppStrings.emptyTitle)
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.large),
                          itemCount: state.visibleArticles.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.large),
                          itemBuilder: (context, index) {
                            final article = state.visibleArticles[index];

                            return NewsArticleCard(
                              article: article,
                              onTap: () => _openArticle(article),
                            );
                          },
                        ),
                ),
              ],
            );
        }
      },
    );
  }

  void _openArticle(NewsArticle article) {
    Navigator.of(context).pushNamed(
      AppRoutes.newsDetail,
      arguments: article,
    );
  }
}
