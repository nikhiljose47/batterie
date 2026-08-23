import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';
import '../compare/compare_page.dart';
import 'data/service_catalog.dart';
import 'service_detail_page.dart';
import 'tools/api_pages.dart';
import 'tools/alarm_page.dart';
import 'tools/bmi_calculator_page.dart';
import 'tools/breathing_page.dart';
import 'tools/calculator_page.dart';
import 'tools/counter_page.dart';
import 'tools/daily_planner_page.dart';
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
  const ServicesPage({
    super.key,
    this.autoOpenServiceId,
    this.filteredServiceIds,
    this.filterTitle,
    this.initialTodoMinutes,
    this.initialAlarmMinutes,
    this.closeOnAutoOpenReturn = false,
  });

  /// When set, the page immediately pushes the matching tool on top of
  /// itself so back-navigation from the tool lands here (not on whichever
  /// screen opened us). Used by the home-tab "Custom" mode shortcut.
  final String? autoOpenServiceId;
  final List<String>? filteredServiceIds;
  final String? filterTitle;
  final bool closeOnAutoOpenReturn;

  /// Optional minute-of-day used when auto-opening the To-Do service from
  /// a planner card.
  final int? initialTodoMinutes;
  final int? initialAlarmMinutes;

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  String _query = '';
  List<String> _recentServiceIds = const <String>[];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _loadRecentServices();
    final autoId = widget.autoOpenServiceId;
    if (autoId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final match = serviceCatalog.firstWhere(
          (s) => s.id == autoId,
          orElse: () => serviceCatalog.first,
        );
        await _openService(match);
        if (widget.closeOnAutoOpenReturn && mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  bool get _isSearching => _query.trim().isNotEmpty;

  List<AppService> get _recentServices {
    return <AppService>[
      for (final id in _recentServiceIds)
        for (final service in serviceCatalog)
          if (service.id == id) service,
    ];
  }

  List<AppService> get _baseServices {
    final ids = widget.filteredServiceIds;
    if (ids == null || ids.isEmpty) return serviceCatalog;
    return <AppService>[
      for (final id in ids)
        for (final service in serviceCatalog)
          if (service.id == id) service,
    ];
  }

  List<AppService> get _searchResults {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const <AppService>[];
    return _servicesMatching(q).toList();
  }

  Iterable<AppService> _servicesMatching(String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return const <AppService>[];
    return _baseServices.where((s) {
      return s.name.toLowerCase().contains(q) ||
          s.tagline.toLowerCase().contains(q) ||
          s.category.label.toLowerCase().contains(q) ||
          s.keywords.any((k) => k.contains(q));
    });
  }

  Future<void> _loadRecentServices() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _recentServiceIds =
          prefs.getStringList(serviceRecentIdsPrefsKey) ?? const <String>[];
    });
  }

  Future<void> _rememberService(AppService service) async {
    final next = <String>[
      service.id,
      ..._recentServiceIds.where((id) => id != service.id),
    ].take(serviceRecentMaxItems).toList(growable: false);
    setState(() => _recentServiceIds = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(serviceRecentIdsPrefsKey, next);
  }

  Future<void> _openService(AppService service) async {
    await _rememberService(service);
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
      'todo' => TaskToolPage(
          config: todoConfig,
          initialDueMinutes: widget.initialTodoMinutes,
        ),
      'daily_planner' => const DailyPlannerPage(),
      'day_mode' => const ComparePage(),
      'calculator' => const CalculatorPage(),
      'alarms' => AlarmPage(initialAlarmMinutes: widget.initialAlarmMinutes),
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: _ServicesTopSearch(
          controller: _searchController,
          focusNode: _searchFocusNode,
          query: _query,
          onChanged: (value) => setState(() => _query = value),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (_isSearching)
              _buildSearchResults()
            else if (widget.filteredServiceIds != null)
              _buildFilteredServices()
            else ...<Widget>[
              _buildRecentServices(),
              for (int i = 0; i < _groups.length; i++) ...<Widget>[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.large),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.outline.withOpacity(0.5),
                    ),
                  ),
                _buildGroup(_groups[i]),
              ],
            ],
            const SizedBox(height: AppSpacing.large),
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredServices() {
    final items = _baseServices;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.large,
        AppSpacing.medium,
        AppSpacing.large,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (widget.filterTitle != null) ...<Widget>[
            Text(
              widget.filterTitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C2030),
              ),
            ),
            const SizedBox(height: 10),
          ],
          GridView.builder(
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
        ],
      ),
    );
  }

  Widget _buildRecentServices() {
    final items = _recentServices;
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.large,
            AppSpacing.medium,
            AppSpacing.large,
            12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.history_rounded,
                size: 17,
                color: AppColors.primary,
              ),
              const SizedBox(width: 7),
              const Text(
                'Favourites / Recent',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C2030),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${items.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
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
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
          child: Divider(
            height: 1,
            thickness: 1,
            color: AppColors.outline.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildGroup(_ServiceGroup g) {
    final items =
        serviceCatalog.where((s) => g.cats.contains(s.category)).toList();
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
                  color: g.color.withOpacity(0.10),
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

class _ServicesTopSearch extends StatelessWidget {
  const _ServicesTopSearch({
    required this.controller,
    required this.focusNode,
    required this.query,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String query;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.medium),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colors.outline.withOpacity(0.18)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.045),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search',
            hintStyle: TextStyle(
              fontSize: 12.5,
              color: colors.onSurfaceVariant.withOpacity(0.72),
              fontWeight: FontWeight.w600,
            ),
            suffixIcon: SizedBox(
              width: query.isEmpty ? 44 : 76,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  if (query.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear search',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                        focusNode.requestFocus();
                      },
                      icon: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            filled: true,
            fillColor: Colors.transparent,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
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
                  child:
                      Text(service.emoji, style: const TextStyle(fontSize: 15)),
                ),
                const Spacer(),
                Text(
                  service.category.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w700,
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
