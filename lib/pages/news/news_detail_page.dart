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
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        children: <Widget>[
          ArticleHeroImage(
            imageUrl: article.imageUrl,
            imageTag: article.imageTag,
            searchText:
                '${article.title} ${article.summary} ${article.category}',
            height: 260,
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      article.category.toUpperCase(),
                      style: textTheme.labelMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      article.title,
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      article.summary,
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.onSurface.withOpacity(0.7),
                        height: 1.45,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${AppStrings.published} ${_formatDate(article.publishedAt)}  •  ${article.readTimeMinutes} min read',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withOpacity(0.52),
                      ),
                    ),
                    const SizedBox(height: 30),
                    ...article.sections.map(
                      (section) => Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSpacing.xLarge),
                        child: Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              TextSpan(
                                text: '${section.heading}\n',
                                style: textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                              TextSpan(
                                text: '\n${section.body}',
                                style: textTheme.bodyLarge?.copyWith(
                                  height: 1.65,
                                  color: colors.onSurface.withOpacity(0.82),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
