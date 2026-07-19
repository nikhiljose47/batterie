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

/// Services hub — every mini-app in one place.
///
/// Selection paths, per the spec:
///  1. Thin search bar at the top (matches name + keywords).
///  2. Horizontally scrollable category tags under it.
///  3. The tile grid itself — every tile is a button.
class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  String _query = '';
  ServiceCategory? _category;

  List<AppService> get _filtered {
    final q = _query.trim().toLowerCase();
    return serviceCatalog.where((s) {
      final inCategory = _category == null || s.category == _category;
      final inQuery = q.isEmpty ||
          s.name.toLowerCase().contains(q) ||
          s.tagline.toLowerCase().contains(q) ||
          s.keywords.any((k) => k.contains(q));
      return inCategory && inQuery;
    }).toList();
  }

  /// Route table — every service id maps to its working page.
  /// New services fall through to the scaffolded detail page until
  /// their page is built and registered here.
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
    final services = _filtered;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 44,
        scrolledUnderElevation: 0,
        title: const Text(
          'Services',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ── Thin search bar ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.large, AppSpacing.medium, AppSpacing.large, 0),
            child: SizedBox(
              height: 38,
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                style: const TextStyle(fontSize: 12.5),
                decoration: InputDecoration(
                  isDense: true,
                  hintText:
                      'Search a service — "water", "budget", "sleep"…',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted.withOpacity(0.8),
                  ),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 18, color: AppColors.textMuted),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.zero,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: AppColors.outline.withOpacity(0.9)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Scrollable category tags ────────────────────────────────
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
              children: <Widget>[
                _CategoryChip(
                  label: 'All',
                  emoji: '✨',
                  selected: _category == null,
                  onTap: () => setState(() => _category = null),
                ),
                for (final c in ServiceCategory.values) ...<Widget>[
                  const SizedBox(width: 6),
                  _CategoryChip(
                    label: c.label,
                    emoji: c.emoji,
                    selected: _category == c,
                    onTap: () =>
                        setState(() => _category = _category == c ? null : c),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Tile grid ───────────────────────────────────────────────
          Expanded(
            child: services.isEmpty
                ? Center(
                    child: Text(
                      'Nothing matches "$_query"',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.large, 2,
                        AppSpacing.large, AppSpacing.large),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisExtent: 96,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: services.length,
                    itemBuilder: (context, index) => _ServiceTile(
                      service: services[index],
                      onTap: () => _openService(services[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.outline.withOpacity(0.9),
          ),
        ),
        child: Text(
          '$emoji $label',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

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
                  child:
                      Text(service.emoji, style: const TextStyle(fontSize: 15)),
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
              style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
