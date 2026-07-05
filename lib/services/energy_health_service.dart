import '../constants/app_colors.dart';
import '../constants/app_images.dart';
import '../constants/app_strings.dart';
import '../models/battery_status.dart';
import '../models/body_status.dart';
import '../models/news_article.dart';
import '../models/person_status.dart';

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
    await Future<void>.delayed(const Duration(milliseconds: 300));

    return const <PersonStatus>[
      PersonStatus(
        name: 'Aarav',
        role: 'Training partner',
        energyPercent: 0.81,
        brainPercent: 0.64,
        note: 'High readiness, keep session intensity controlled.',
      ),
      PersonStatus(
        name: 'Mira',
        role: 'Family',
        energyPercent: 0.49,
        brainPercent: 0.52,
        note: 'Low sleep trend. Suggest a lighter evening.',
      ),
      PersonStatus(
        name: 'Dev',
        role: 'Team member',
        energyPercent: 0.67,
        brainPercent: 0.75,
        note: 'Good focus window until late afternoon.',
      ),
    ];
  }

  Future<List<NewsArticle>> fetchNewsArticles() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    return <NewsArticle>[
      NewsArticle(
        id: 'recovery-hrv',
        title: 'Using recovery signals without overreacting',
        summary:
            'A practical way to read energy, heart-rate variability, and fatigue trends together.',
        category: AppStrings.recoveryFilter,
        imageUrl: AppImages.recovery,
        publishedAt: DateTime(2026, 7, 3),
        readTimeMinutes: 4,
        sections: const <ArticleSection>[
          ArticleSection(
            heading: 'What matters',
            body:
                'One low score is a prompt, not a verdict. Look for repeated dips across sleep, soreness, mood, and resting heart rate before changing a whole plan.',
          ),
          ArticleSection(
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
            'Recent wellness tracking trends show how sleep consistency affects appetite, focus, and perceived effort.',
        category: AppStrings.sleepFilter,
        imageUrl: AppImages.sleep,
        publishedAt: DateTime(2026, 7, 2),
        readTimeMinutes: 5,
        sections: const <ArticleSection>[
          ArticleSection(
            heading: 'The pattern',
            body:
                'Short sleep often shows up the next day as higher effort for normal tasks. The body may feel capable while decision speed and patience run lower.',
          ),
          ArticleSection(
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
            'Teams and health apps are beginning to separate physical readiness from cognitive readiness.',
        category: AppStrings.focusFilter,
        imageUrl: AppImages.focus,
        publishedAt: DateTime(2026, 6, 30),
        readTimeMinutes: 3,
        sections: const <ArticleSection>[
          ArticleSection(
            heading: 'Why separate it',
            body:
                'You can be physically rested and mentally overloaded. Separating the two makes planning kinder and more accurate.',
          ),
          ArticleSection(
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
        category: AppStrings.recoveryFilter,
        imageUrl: AppImages.hydration,
        publishedAt: DateTime(2026, 6, 28),
        readTimeMinutes: 4,
        sections: const <ArticleSection>[
          ArticleSection(
            heading: 'Make it visible',
            body:
                'People are more consistent when water is already in the place where the next activity begins.',
          ),
          ArticleSection(
            heading: 'Pair it',
            body:
                'Anchor hydration to routines you already do, like starting work, finishing exercise, or preparing dinner.',
          ),
        ],
      ),
    ]..sort((first, second) => second.publishedAt.compareTo(first.publishedAt));
  }
}
