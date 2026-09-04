import 'app_images.dart';
import '../models/news_article.dart';

class ArticleConstants {
  const ArticleConstants._();

  // Replace this later when the article API is ready.
  // Expected shape:
  // [
  //   {
  //     "id": "stable-id",
  //     "title": "...",
  //     "summary": "...",
  //     "category": "Recovery",
  //     "imageUrl": "https://...",
  //     "imageTag": "recovery",
  //     "publishedAt": "2026-08-22T00:00:00.000Z",
  //     "readTimeMinutes": 4,
  //     "sections": [{"heading": "...", "body": "..."}]
  //   }
  // ]
  static const String articlesApiUrl =
      'https://batterie-322e6.web.app/articles.json';

  static const String allTag = 'All';
  static const String recentTag = 'Recently updated';
  static const String recoveryTag = 'Recovery';
  static const String sleepTag = 'Sleep';
  static const String focusTag = 'Focus';
  static const String hydrationTag = 'Hydration';
  static const String nutritionTag = 'Nutrition';
  static const String movementTag = 'Movement';
  static const String stressTag = 'Stress';
  static const String habitsTag = 'Habits';
  static const String planningTag = 'Planning';
  static const String defaultImageTag = 'hydration';
  static const int recentArticleWindowDays = 2;
  static const int preloadArticleCount = 4;
  static const double webImageCacheScale = 0.5;

  static const List<String> filters = <String>[
    allTag,
    recentTag,
    recoveryTag,
    sleepTag,
    focusTag,
    hydrationTag,
    nutritionTag,
    movementTag,
    stressTag,
    habitsTag,
    planningTag,
  ];

  static const Map<String, String> defaultWebImageByTag = <String, String>{
    'recovery': AppImages.recovery,
    'sleep': AppImages.sleep,
    'focus': AppImages.focus,
    'deep_work': AppImages.focus,
    'hydration': AppImages.hydration,
    'water': AppImages.hydration,
  };

  // Local fallback images. Put new image files in assets/articles/.
  // The article image widget also checks article words against file names, so
  // names like "sleep-rest.jpg" can match articles about sleep or rest.
  // Keep exact tag mappings here only when you want to force a specific image.
  // Example API values:
  //   "imageUrl": ""            -> app uses localImageByTag[imageTag]
  //   "imageTag": "deep_work"   -> assets/articles/deep_work.svg
  // If imageUrl is a valid https URL, that remote image is shown first.
  // If the URL is missing or fails, this local tag image is used.
  static const Map<String, String> localImageByTag = <String, String>{
    'recovery': 'assets/articles/breathing-and-workout.jpg',
    'fitness': 'assets/articles/breathing-and-workout.jpg',
    'sleep': 'assets/articles/sleep-rest.jpg',
    'morning_light': 'assets/articles/sleep-rest.jpg',
    'screen_time': 'assets/articles/sleep-rest.jpg',
    'focus': 'assets/articles/stress.jpg',
    'hydration': 'assets/articles/hydration.jpg',
    'nutrition': 'assets/articles/fruit-breakfast-bowl.jpg',
    'healthy_meal': 'assets/articles/fruit-breakfast-bowl.jpg',
    'protein': 'assets/articles/fruit-breakfast-bowl.jpg',
    'movement': 'assets/articles/breathing-and-workout.jpg',
    'movement_break': 'assets/articles/breathing-and-workout.jpg',
    'walking': 'assets/articles/breathing-and-workout.jpg',
    'stress': 'assets/articles/stress.jpg',
    'wellbeing': 'assets/articles/stress.jpg',
    'relaxation': 'assets/articles/stress.jpg',
    'habits': 'assets/articles/water.svg',
    'planning': 'assets/articles/water.svg',
    'energy': 'assets/articles/hydration.jpg',
    'morning': 'assets/articles/sleep-rest.jpg',
    'evening': 'assets/articles/sleep-rest.jpg',
    'breathing': 'assets/articles/breathing-and-workout.jpg',
    'walk': 'assets/articles/breathing-and-workout.jpg',
    'water': 'assets/articles/water.svg',
    'meal': 'assets/articles/fruit-breakfast-bowl.jpg',
    'deep_work': 'assets/articles/stress.jpg',
    'rest': 'assets/articles/sleep-rest.jpg',
    'calendar': 'assets/articles/water.svg',
    'mind': 'assets/articles/stress.jpg',
  };

  static String assetForTag(String tag) {
    final key = tag.trim().toLowerCase().replaceAll(' ', '_');
    return localImageByTag[key] ?? localImageByTag[defaultImageTag]!;
  }

  static String? defaultWebImageForTag(String tag) {
    final key = tag.trim().toLowerCase().replaceAll(' ', '_');
    return defaultWebImageByTag[key];
  }

  static String? webImageForArticle(NewsArticle article) {
    final explicitUrl = article.imageUrl.trim();
    if (explicitUrl.startsWith('http://') ||
        explicitUrl.startsWith('https://')) {
      return explicitUrl;
    }
    return defaultWebImageForTag(article.imageTag);
  }

  static final List<NewsArticle> fallbackArticles = <NewsArticle>[
    NewsArticle(
      id: 'recovery-hrv',
      title: 'Using recovery signals without overreacting',
      summary:
          'A practical way to read energy, heart-rate variability, and fatigue trends together.',
      category: recoveryTag,
      imageUrl: AppImages.recovery,
      imageTag: 'recovery',
      publishedAt: DateTime(2026, 7, 3),
      readTimeMinutes: 4,
      sections: <ArticleSection>[
        const ArticleSection(
          heading: 'What matters',
          body:
              'One low score is a prompt, not a verdict. Look for repeated dips across sleep, soreness, mood, and resting heart rate before changing a whole plan.',
        ),
        const ArticleSection(
          heading: 'How to act',
          body:
              'When signals are mixed, choose the smallest useful adjustment: reduce intensity, add warm-up time, or move deep work into your clearest hour.',
        ),
      ],
    ),
    NewsArticle(
      id: 'sleep-debt',
      title: 'Sleep debt changes more than tiredness',
      summary:
          'Sleep consistency affects appetite, focus, and perceived effort more than most people expect.',
      category: sleepTag,
      imageUrl: AppImages.sleep,
      imageTag: 'sleep',
      publishedAt: DateTime(2026, 7, 2),
      readTimeMinutes: 5,
      sections: <ArticleSection>[
        const ArticleSection(
          heading: 'The pattern',
          body:
              'Short sleep often shows up the next day as higher effort for normal tasks. The body may feel capable while decision speed and patience run lower.',
        ),
        const ArticleSection(
          heading: 'The reset',
          body:
              'A consistent wake time, morning light, and a calmer final hour usually beat aggressive catch-up naps for rebuilding rhythm.',
        ),
      ],
    ),
    NewsArticle(
      id: 'brain-battery',
      title: 'Brain battery is becoming a daily planning metric',
      summary:
          'Planning works better when physical readiness and cognitive readiness are tracked separately.',
      category: focusTag,
      imageUrl: AppImages.focus,
      imageTag: 'deep_work',
      publishedAt: DateTime(2026, 6, 30),
      readTimeMinutes: 3,
      sections: <ArticleSection>[
        const ArticleSection(
          heading: 'Why separate it',
          body:
              'You can be physically rested and mentally overloaded. Separating the two makes planning kinder and more accurate.',
        ),
        const ArticleSection(
          heading: 'Try this',
          body:
              'Put complex decisions in the highest-focus window, then reserve lower-focus time for movement, admin, and recovery tasks.',
        ),
      ],
    ),
    NewsArticle(
      id: 'hydration-recovery',
      title: 'Hydration nudges that actually stick',
      summary:
          'Small environmental cues can improve energy consistency without turning hydration into another chore.',
      category: hydrationTag,
      imageUrl: AppImages.hydration,
      imageTag: 'water',
      publishedAt: DateTime(2026, 6, 28),
      readTimeMinutes: 4,
      sections: <ArticleSection>[
        const ArticleSection(
          heading: 'Make it visible',
          body:
              'People are more consistent when water is already in the place where the next activity begins.',
        ),
        const ArticleSection(
          heading: 'Pair it',
          body:
              'Anchor hydration to routines you already do, like starting work, finishing exercise, or preparing dinner.',
        ),
      ],
    ),
  ];
}
