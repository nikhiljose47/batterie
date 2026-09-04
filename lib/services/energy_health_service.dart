import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/app_colors.dart';
import '../constants/article_constants.dart';
import '../constants/app_strings.dart';
import '../models/battery_status.dart';
import '../models/body_status.dart';
import '../models/news_article.dart';
import '../models/person_status.dart';
import 'daily_progress_sync_service.dart';

class EnergyHealthService {
  const EnergyHealthService();

  Future<BodyStatus> fetchBodyStatus() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));

    return const BodyStatus(
      status:
          'Stable with mild fatigue. Your movement score is steady and recovery is improving.',
      potential:
          'You can handle focused work, a light workout, and one meaningful social touchpoint today.',
      previousActivity:
          'Earlier you completed a morning walk, hydration check, and ten minutes of breathing.',
      supportNote:
          'Your pattern matches many people after a compressed sleep cycle. Keep the next block simple.',
      recommendedActions: <String>[
        'Take a short mobility break',
        'Choose one priority task',
        'Keep caffeine before mid-afternoon',
      ],
    );
  }

  Future<List<BatteryStatus>> fetchBatteryStatuses() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    return const <BatteryStatus>[
      BatteryStatus(
        title: AppStrings.physicalBattery,
        percent: 0.72,
        subtitle: 'Ready for moderate activity',
        color: AppColors.bodyEnergy,
      ),
      BatteryStatus(
        title: AppStrings.brainBattery,
        percent: 0.58,
        subtitle: 'Best for single-task focus',
        color: AppColors.brainEnergy,
      ),
    ];
  }

  Future<List<PersonStatus>> fetchPeopleStatuses() async {
    return DailyProgressSyncService.instance.cachedTopStatuses();
  }

  Future<List<NewsArticle>> fetchNewsArticles() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final url = ArticleConstants.articlesApiUrl.trim();
    if (url.isEmpty) return _sortedArticles(ArticleConstants.fallbackArticles);

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _sortedArticles(ArticleConstants.fallbackArticles);
      }

      final decoded = jsonDecode(response.body);
      final rawArticles = decoded is List<dynamic>
          ? decoded
          : decoded is Map<String, dynamic>
              ? decoded['articles']
              : null;
      if (rawArticles is! List<dynamic>) {
        return _sortedArticles(ArticleConstants.fallbackArticles);
      }

      final articles = rawArticles
          .whereType<Map<String, dynamic>>()
          .map(NewsArticle.fromMap)
          .where((article) => article.id.isNotEmpty && article.title.isNotEmpty)
          .toList(growable: false);
      if (articles.isEmpty) {
        return _sortedArticles(ArticleConstants.fallbackArticles);
      }
      return _sortedArticles(articles);
    } catch (_) {
      return _sortedArticles(ArticleConstants.fallbackArticles);
    }
  }

  List<NewsArticle> _sortedArticles(List<NewsArticle> articles) {
    return <NewsArticle>[
      ...articles
    ]..sort((first, second) => second.publishedAt.compareTo(first.publishedAt));
  }
}
