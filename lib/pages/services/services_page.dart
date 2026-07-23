import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';
import 'data/service_catalog.dart';
import 'service_detail_page.dart';
import 'tools/api_pages.dart';
import 'tools/bmi_calculator_page.dart';
import 'tools/breathing_page.dart';
import 'tools/counter_page.dart';
import 'tools/cycle_pages.dart';
import 'tools/emergency_page.dart';
import 'tools/food_log_page.dart';
import 'tools/habit_page.dart';
import 'tools/mental_health_page.dart';
import 'tools/money_pages.dart';
import 'tools/quick_log_page.dart';
import 'tools/recipe_pages.dart';
import 'tools/sleep_page.dart';
import 'tools/task_page.dart';
import 'tools/tdee_page.dart';
import 'tools/timer_page.dart';

// ── The 4 major UI groups ────────────────────────────────────────────────────

class _ServiceGroup {
  const _ServiceGroup({
    required this.emoji,
    required this.title,
    required this.cats,
    required this.color,
  });

  final String emoji;
  final String title;
  final List<ServiceCategory> cats;
  final Color color;
}

const List<_ServiceGroup> _groups = <_ServiceGroup>[
  _ServiceGroup(
    emoji: '🏃',
    title: 'Body & Health',
    cats: <ServiceCategory>[ServiceCategory.health],
    color: Color(0xFF2E7D32),
  ),
  _ServiceGroup(
    emoji: '🧠',
    title: 'Mind & Nutrition',
    cats: <ServiceCategory>[ServiceCategory.mind, ServiceCategory.food],
    color: Color(0xFF5E35B1),
  ),
  _ServiceGroup(
    emoji: '🌸',
    title: "Women's Health",
    cats: <ServiceCategory>[ServiceCategory.women],
    color: Color(0xFFC2185B),
  ),
  _ServiceGroup(
    emoji: '🗓️',
    title: 'Life & Plans',
    cats: <ServiceCategory>[
      ServiceCategory.finance,
      ServiceCategory.productivity,
      ServiceCategory.lifestyle,
    ],
    color: Color(0xFF1565C0),
  ),
];

// ── Page ────────────────────────────────────────────────────────────────────

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  String _query = '';

  bool get _isSearching => _query.trim().isNotEmpty;

  List<AppService> get _searchResults {
    final q = _query.trim().toLowerCase();
    return serviceCatalog.where((s) {
      return s.name.toLowerCase().contains(q) ||
          s.tagline.toLowerCase().contains(q) ||
          s.keywords.any((k) => k.contains(q));
    }).toList();
  }

  void _openService(AppService service) {
    final Widget page = switch (service.id) {
      // Health
      'bmi' => const BmiCalculatorPage(),
      'sleep_tracker' => const SleepPage(),
      'water' => const CounterToolPage(config: waterCounterConfig),
      'symptoms' => const QuickLogPage(config: symptomLogConfig),
      'medication' => const HabitToolPage(config: medsConfig),
      'nicotine' => const CounterToolPage(config: nicotineCounterConfig),
      'air_quality' => const AirQualityPage(),
      'emergency' => const EmergencyPage(),
      // Women
      'period' => const CyclePage(),
      'pregnancy' => const PregnancyPage(),
      // Mind
      'mood' => const QuickLogPage(config: moodLogConfig),
      'journal' => const QuickLogPage(config: journalLogConfig),
      'meditation' => const TimerToolPage(config: meditationTimerConfig),
      'breathing' => const BreathingPage(),
      'mental_health' => const MentalHealthPage(),
      'sleep_sounds' => const TimerToolPage(config: sleepSoundsTimerConfig),
      // Food
      'calorie_calc' => const TdeePage(),
      'calorie_counter' => const FoodLogPage(showMacros: false),
      'food_db' => const FoodDbPage(),
      'nutrition' => const FoodLogPage(showMacros: true),
      'meal_planner' => const MealPlanPage(),
      'recipes' => const RecipePage(),
      'fasting' => const TimerToolPage(config: fastingTimerConfig),
      // Money
      'expenses' => const LedgerPage(),
      'budget' => const BudgetPage(),
      'subscriptions' => const RecurringPage(config: subsConfig),
      'bills' => const RecurringPage(config: billsConfig),
      // Plan
      'todo' => const TaskToolPage(config: todoConfig),
      'daily_planner' => const TaskToolPage(config: plannerConfig),
      'reminders' => const TaskToolPage(config: remindersConfig),
      'notes' => const QuickLogPage(config: notesLogConfig),
      'focus' => const TimerToolPage(config: focusTimerConfig),
      // Track
      'habits' => const HabitToolPage(config: habitsConfig),
      'hobby' => const QuickLogPage(config: hobbyLogConfig),
      'screen_time' => const QuickLogPage(config: screenTimeLogConfig),
      'holidays' => const HolidaysPage(),
      _ => ServiceDetailPage(service: service),
    };
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 44,
        scrolledUnderElevation: 0,
        title: const Text(
          'Services',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildSearchBar(),
            if (_isSearching)
              _buildSearchResults()
            else
              for (int i = 0; i < _groups.length; i++) ...<Widget>[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.large),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.outline.withValues(alpha: 0.5),
                    ),
                  ),
                _buildGroup(_groups[i]),
              ],
            const SizedBox(height: AppSpacing.large),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.large, AppSpacing.medium, AppSpacing.large, 0),
      child: SizedBox(
        height: 38,
        child: TextField(
          onChanged: (v) => setState(() => _query = v),
          style: const TextStyle(fontSize: 12.5),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search — "water", "budget", "sleep"…',
            hintStyle: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted.withValues(alpha: 0.8),
            ),
            prefixIcon: const Icon(Icons.search_rounded,
                size: 18, color: AppColors.textMuted),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppColors.outline.withValues(alpha: 0.9)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroup(_ServiceGroup g) {
    final items = serviceCatalog
        .where((s) => g.cats.contains(s.category))
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.large, 30, AppSpacing.large, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: g.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(g.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 7),
              Text(
                g.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C2030),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: g.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: g.color,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 96,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => _ServiceTile(
              service: items[i],
              onTap: () => _openService(items[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    final results = _searchResults;
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            'Nothing matches "${_query.trim()}"',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.large, AppSpacing.medium, AppSpacing.large, 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 96,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: results.length,
        itemBuilder: (_, i) => _ServiceTile(
          service: results[i],
          onTap: () => _openService(results[i]),
        ),
      ),
    );
  }
}

// ── Tile ────────────────────────────────────────────────────────────────────

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.onTap});

  final AppService service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = categoryAccent(service.category);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outline.withOpacity(0.8)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: categoryTint(service.category),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(service.emoji,
                      style: const TextStyle(fontSize: 15)),
                ),
                const Spacer(),
                Text(
                  service.category.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: accent.withOpacity(0.8),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              service.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2A2E3B),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              service.tagline,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
