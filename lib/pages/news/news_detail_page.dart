import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../constants/app_strings.dart';
import '../../models/news_article.dart';
import 'widgets/article_hero_image.dart';

class NewsDetailPage extends StatelessWidget {
  const NewsDetailPage({
    super.key,
    required this.article,
  });

  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.readArticle),
      ),
      body: ListView(
        children: <Widget>[
          ArticleHeroImage(imageUrl: article.imageUrl),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.large),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  article.category,
                  style: textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.small),
                Text(
                  article.title,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                Text(article.summary, style: textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.large),
                Text(
                  '${AppStrings.published} ${_formatDate(article.publishedAt)} | ${article.readTimeMinutes} min read',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xLarge),
                ...article.sections.map(
                  (section) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xLarge),
                    child: Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: '${section.heading}\n',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(
                            text: section.body,
                            style: textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
