import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import '../../../engine/energy_score_engine.dart';
import '../../../models/energy_log_record.dart';
import '../../../models/logged_activity.dart';
import '../../../models/planner_session_log.dart';
import '../../../pages/profile/profile_store.dart';
import '../../../services/energy_log_store.dart';
import '../../services/tools/toolkit.dart';

enum StatsHeatmapRange {
  threeDays('3 days', 3),
  week('1 week', 7),
  month('1 month', 31),
  threeMonths('3 months', 92),
  sixMonths('6 months', 183),
  all('All time', null);

  const StatsHeatmapRange(this.label, this.days);
  final String label;
  final int? days;
}

const List<String> _contributionListKeys = <String>[
  'svc.notes.entries',
  'svc.journal.entries',
  'svc.symptoms.entries',
  'svc.hobby.entries',
  'svc.mood.entries',
  'svc.screen_time.entries',
  'svc.food.entries',
  'svc.sleep.entries',
  'svc.focus.sessions',
  'svc.meditation.sessions',
  'svc.sleep_sounds.sessions',
  'svc.fasting.sessions',
  'svc.expenses.entries',
];

const List<String> _contributionTaskKeys = <String>[
  'svc.todo.items',
  'svc.reminders.items',
];

const List<String> _contributionCounterKeys = <String>[
  'svc.water.days',
  'svc.nicotine.days',
];

const List<String> _weekdayLabels = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// Statistics for a chosen day plus a GitHub-style activity heatmap. The
/// heatmap reads persisted state, so actions that are added and then removed
/// do not leave a counted contribution behind.
class DailyStatsPanel extends StatefulWidget {
  const DailyStatsPanel({
    super.key,
    this.store,
    this.onOpenCoach,
    this.refreshToken = 0,
  });

  final EnergyLogStore? store;
  final int refreshToken;

  /// Called when the user taps the "Chat with AI coach" entry point.
  final VoidCallback? onOpenCoach;

  @override
  State<DailyStatsPanel> createState() => _DailyStatsPanelState();
}

class _DailyStatsPanelState extends State<DailyStatsPanel> {
  static const EnergyScoreEngine _engine = EnergyScoreEngine();
  static const int _daysBack = 7;

  late final EnergyLogStore _store =
      widget.store ?? SqliteEnergyLogStore.instance;
  final TextEditingController _remarkController = TextEditingController();

  int _dayOffset = 0; // 0 = today, 1 = yesterday, ... up to _daysBack - 1
  StatsHeatmapRange _heatmapRange = StatsHeatmapRange.month;
  List<EnergyLogRecord> _records = const <EnergyLogRecord>[];
  List<PlannerSessionLog> _sessionLogs = const <PlannerSessionLog>[];
  List<_ContributionDay> _contributionDays = const <_ContributionDay>[];
  bool _loading = true;
  bool _remarkSaved = false;

  DateTime get _selectedDate =>
      DateTime.now().subtract(Duration(days: _dayOffset));

  String get _dateKey => dateKey(_selectedDate);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DailyStatsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _load();
    }
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = ProfileStore.instance.userId.value;
      await _store.claimEnergyLogsForUser(userId);
      await _store.claimPlannerSessionLogsForUser(userId);
      final records = await _store.recordsForDate(_dateKey, userId: userId);
      final sessionLogs = await _store.plannerSessionLogsForDate(
        _dateKey,
        userId: userId,
      );
      final remark = await _store.remarkForDate(_dateKey);
      final contributionDays = await _loadContributionDays(userId);
      if (!mounted) return;
      setState(() {
        _records = records;
        _sessionLogs = sessionLogs;
        _contributionDays = contributionDays;
        _remarkController.text = remark ?? '';
        _loading = false;
        _remarkSaved = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _records = const <EnergyLogRecord>[];
        _sessionLogs = const <PlannerSessionLog>[];
        _contributionDays = const <_ContributionDay>[];
        _loading = false;
      });
    }
  }

  Future<List<_ContributionDay>> _loadContributionDays(String userId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final fixedDays = _heatmapRange.days;
    final start = fixedDays == null
        ? (await _earliestContributionDate(userId)) ?? today
        : today.subtract(Duration(days: fixedDays - 1));
    final days = today.difference(start).inDays + 1;
    final counts = <String, int>{
      for (var i = 0; i < days; i++) dateKey(start.add(Duration(days: i))): 0,
    };

    for (final key in counts.keys.toList()) {
      final energyRecords = await _store.recordsForDate(key, userId: userId);
      final plannerLogs =
          await _store.plannerSessionLogsForDate(key, userId: userId);
      counts[key] = (counts[key] ?? 0) +
          energyRecords.length +
          plannerLogs.where((log) => log.isDone).length;
    }

    await _addListEntryCounts(counts, _contributionListKeys);
    await _addTaskCounts(counts, _contributionTaskKeys);
    await _addCounterCounts(counts, _contributionCounterKeys);

    return counts.entries
        .map((entry) => _ContributionDay(
              date: DateTime.parse(entry.key),
              count: entry.value,
            ))
        .toList(growable: false);
  }

  Future<DateTime?> _earliestContributionDate(String userId) async {
    DateTime? earliest;

    void include(DateTime? date) {
      if (date == null) return;
      final day = DateTime(date.year, date.month, date.day);
      if (earliest == null || day.isBefore(earliest!)) earliest = day;
    }

    for (final key in await _store.activityDates(userId: userId)) {
      include(DateTime.tryParse(key));
    }
    for (final key in _contributionListKeys) {
      final entries = await ServiceStore.loadList(key);
      for (final entry in entries) {
        final raw = entry['t'] ?? entry['createdAt'] ?? entry['date'];
        include(raw is String ? DateTime.tryParse(raw) : null);
      }
    }
    for (final key in _contributionTaskKeys) {
      final items = await ServiceStore.loadList(key);
      for (final item in items) {
        include(DateTime.tryParse((item['due'] as String?) ?? ''));
      }
    }
    for (final key in _contributionCounterKeys) {
      final days = await ServiceStore.loadMap(key);
      for (final entry in days.entries) {
        final count = (entry.value as num?)?.round() ?? 0;
        if (count > 0) include(DateTime.tryParse(entry.key));
      }
    }

    return earliest;
  }

  Future<void> _addListEntryCounts(
    Map<String, int> counts,
    List<String> keys,
  ) async {
    for (final key in keys) {
      final entries = await ServiceStore.loadList(key);
      for (final entry in entries) {
        final raw = entry['t'] ?? entry['createdAt'] ?? entry['date'];
        final when = raw is String ? DateTime.tryParse(raw) : null;
        if (when == null) continue;
        final day = dateKey(when);
        if (counts.containsKey(day)) counts[day] = counts[day]! + 1;
      }
    }
  }

  Future<void> _addTaskCounts(
    Map<String, int> counts,
    List<String> keys,
  ) async {
    for (final key in keys) {
      final items = await ServiceStore.loadList(key);
      for (final item in items) {
        final due = DateTime.tryParse((item['due'] as String?) ?? '');
        if (due == null) continue;
        final day = dateKey(due);
        if (counts.containsKey(day)) counts[day] = counts[day]! + 1;
      }
    }
  }

  Future<void> _addCounterCounts(
    Map<String, int> counts,
    List<String> keys,
  ) async {
    for (final key in keys) {
      final days = await ServiceStore.loadMap(key);
      for (final entry in days.entries) {
        final count = (entry.value as num?)?.round() ?? 0;
        if (count <= 0 || !counts.containsKey(entry.key)) continue;
        counts[entry.key] = counts[entry.key]! + count;
      }
    }
  }

  Future<void> _saveRemark() async {
    try {
      await _store.saveRemark(_dateKey, _remarkController.text.trim());
      if (!mounted) return;
      setState(() => _remarkSaved = true);
    } catch (_) {}
  }

  int? get _avgPhysical => _records.isEmpty
      ? null
      : (_records.map((r) => r.physicalAfter).reduce((a, b) => a + b) /
              _records.length)
          .round();

  int? get _avgBrain => _records.isEmpty
      ? null
      : (_records.map((r) => r.brainAfter).reduce((a, b) => a + b) /
              _records.length)
          .round();

  int? get _donePercent {
    if (_sessionLogs.isEmpty) return null;
    final done = _sessionLogs.where((log) => log.isDone).length;
    return ((done / _sessionLogs.length) * 100).round();
  }

  /// Plain-language read of the day: best case "all green", otherwise names
  /// the activity right before the lowest dip.
  String? get _summary {
    if (_records.isEmpty) return null;

    var minPhysical = 100;
    var minBrain = 100;
    EnergyLogRecord? worst;
    for (final r in _records) {
      if (r.physicalAfter < minPhysical) minPhysical = r.physicalAfter;
      if (r.brainAfter < minBrain) minBrain = r.brainAfter;
      final worstSoFar =
          worst == null ? 101 : math.min(worst.physicalAfter, worst.brainAfter);
      if (math.min(r.physicalAfter, r.brainAfter) < worstSoFar) worst = r;
    }

    final overallMin = math.min(minPhysical, minBrain);
    if (overallMin >= 80) return 'Great day — energy stayed 80%+ all day.';
    if (worst == null) return 'Energy dipped to $overallMin%.';

    final name = _engine.activityById(worst.activityId).name;
    final metric =
        worst.physicalAfter <= worst.brainAfter ? 'physical' : 'brain';
    final time = formatMinutes(worst.startMinutes);
    return overallMin < 40
        ? 'Low $metric energy after $name ($time).'
        : 'Dipped to $overallMin% $metric after $name ($time).';
  }

  /// A couple of simple, data-driven suggestions for the selected day.
  List<String> get _tips {
    if (_records.isEmpty) return const <String>[];
    final tips = <String>[];

    final drainCount = _records.where((r) {
      final a = _engine.activityById(r.activityId);
      return a.physicalDelta + a.brainDelta < 0;
    }).length;

    if (drainCount == _records.length && _records.length >= 2) {
      tips.add(
        'Every logged activity drained energy — add a short walk, breathing break, or nap between draining tasks.',
      );
    }

    final avgBrain = _avgBrain;
    if (avgBrain != null && avgBrain < 50) {
      tips.add(
        'Brain energy averaged $avgBrain% — try shorter focus blocks with a break every 60–90 minutes.',
      );
    }

    final avgPhysical = _avgPhysical;
    if (avgPhysical != null && avgPhysical < 50) {
      tips.add(
        'Physical energy averaged $avgPhysical% — a brisk walk or light meal break can help recovery.',
      );
    }

    return tips.take(2).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.large,
            AppSpacing.medium,
            AppSpacing.large,
            AppSpacing.small,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.grid_view_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Your Activity',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C2030),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Day rail + contribution range filter ────────────────────────
        const SizedBox(height: AppSpacing.small),
        SizedBox(
          height: 52,
          child: _DayRail(
            selectedOffset: _dayOffset,
            daysBack: _daysBack,
            onSelect: (offset) {
              setState(() => _dayOffset = offset);
              _load();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.large,
            AppSpacing.small,
            AppSpacing.large,
            0,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _FilterChipGroup<StatsHeatmapRange>(
                    value: _heatmapRange,
                    options: StatsHeatmapRange.values
                        .map((range) => (range, range.label))
                        .toList(growable: false),
                    onChanged: (range) {
                      setState(() => _heatmapRange = range);
                      _load();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Scrollable stats content ─────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _records.isEmpty &&
                      _sessionLogs.isEmpty &&
                      !_contributionDays.any((day) => day.count > 0)
                  ? _EmptyDay(isToday: _dayOffset == 0)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.large,
                        AppSpacing.medium,
                        AppSpacing.large,
                        AppSpacing.medium,
                      ),
                      children: <Widget>[
                        if (_summary != null)
                          Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppSpacing.medium),
                            child: Text(
                              _summary!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (_summary == null && _sessionLogs.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppSpacing.medium),
                            child: Text(
                              '${_sessionLogs.where((log) => log.isDone).length}/${_sessionLogs.length} planner cards marked done.',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                        _ContributionHeatmapCard(
                          days: _contributionDays,
                          range: _heatmapRange,
                        ),
                        const SizedBox(height: AppSpacing.medium),

                        // Averages
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _AverageCard(
                                label: 'Avg physical',
                                value: _avgPhysical,
                                color: AppColors.energyPhysicalAccent,
                                background: AppColors.energyPhysicalBg,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.small),
                            Expanded(
                              child: _AverageCard(
                                label: 'Avg brain',
                                value: _avgBrain,
                                color: AppColors.energyBrainAccent,
                                background: AppColors.energyBrainBg,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.small),
                            Expanded(
                              child: _AverageCard(
                                label: 'Sessions done',
                                value: _donePercent,
                                color: AppColors.primary,
                                background: AppColors.surfaceTint,
                              ),
                            ),
                          ],
                        ),

                        if (_tips.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.medium),
                          const Text(
                            'HELP TO IMPROVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.small),
                          ..._tips.map((tip) => _TipCard(text: tip)),
                        ],

                        const SizedBox(height: AppSpacing.medium),

                        // Remark
                        TextField(
                          controller: _remarkController,
                          onChanged: (_) =>
                              setState(() => _remarkSaved = false),
                          onSubmitted: (_) => _saveRemark(),
                          decoration: InputDecoration(
                            labelText: 'Remark for this day',
                            hintText: 'e.g. slept badly, deadline week…',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            suffixIcon: IconButton(
                              tooltip: 'Save remark',
                              icon: Icon(
                                _remarkSaved
                                    ? Icons.check_circle_rounded
                                    : Icons.save_outlined,
                                size: 18,
                                color: _remarkSaved
                                    ? AppColors.energyBrainAccent
                                    : AppColors.textMuted,
                              ),
                              onPressed: _saveRemark,
                            ),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: AppSpacing.medium),

                        // Log entries
                        const Text(
                          'LOG',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.small),
                        ..._sessionLogs.map((log) => _PlannerLogRow(log: log)),
                        ..._records.map((r) => _LogRow(
                              record: r,
                              activityName:
                                  _engine.activityById(r.activityId).name,
                            )),

                        if (widget.onOpenCoach != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.medium),
                          _CoachEntry(onTap: widget.onOpenCoach!),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }
}

// ── Day rail ────────────────────────────────────────────────────────────────

class _DayRail extends StatelessWidget {
  const _DayRail({
    required this.selectedOffset,
    required this.daysBack,
    required this.onSelect,
  });

  final int selectedOffset;
  final int daysBack;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
      itemCount: daysBack,
      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.small),
      itemBuilder: (context, offset) {
        final date = now.subtract(Duration(days: offset));
        final selected = offset == selectedOffset;
        final topLabel = offset == 0
            ? 'Today'
            : offset == 1
                ? 'Yesterday'
                : _weekdayLabels[date.weekday - 1];

        return GestureDetector(
          onTap: () => onSelect(offset),
          child: Container(
            width: offset <= 1 ? 64 : 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.surfaceTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  topLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.textMuted,
                  ),
                ),
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Filter chips ──────────────────────────────────────────────────────────────

class _FilterChipGroup<T> extends StatelessWidget {
  const _FilterChipGroup({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((option) {
          final selected = option.$1 == value;
          return GestureDetector(
            onTap: () => onChanged(option.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: selected ? Border.all(color: AppColors.outline) : null,
              ),
              child: Text(
                option.$2,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Contribution heatmap ────────────────────────────────────────────────────

class _ContributionDay {
  const _ContributionDay({
    required this.date,
    required this.count,
  });

  final DateTime date;
  final int count;
}

class _ContributionHeatmapCard extends StatelessWidget {
  const _ContributionHeatmapCard({
    required this.days,
    required this.range,
  });

  final List<_ContributionDay> days;
  final StatsHeatmapRange range;

  int get _total => days.fold<int>(0, (sum, day) => sum + day.count);
  int get _activeDays => days.where((day) => day.count > 0).length;

  int get _currentStreak {
    var streak = 0;
    for (final day in days.reversed) {
      if (day.count <= 0) break;
      streak++;
    }
    return streak;
  }

  Color _colorFor(BuildContext context, int count) {
    final colors = Theme.of(context).colorScheme;
    if (count <= 0) return colors.surfaceContainerHighest.withOpacity(0.7);
    if (count == 1) return const Color(0xFFC8E6A0);
    if (count <= 3) return const Color(0xFF8BC766);
    if (count <= 6) return const Color(0xFF4FA646);
    return const Color(0xFF216E39);
  }

  String _monthLabel(DateTime date) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[date.month - 1];
  }

  List<List<_ContributionDay?>> _weeks() {
    if (days.isEmpty) return const <List<_ContributionDay?>>[];
    final first = days.first.date;
    final leading = first.weekday - 1;
    final cells = <_ContributionDay?>[
      for (var i = 0; i < leading; i++) null,
      ...days,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return <List<_ContributionDay?>>[
      for (var i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final weeks = _weeks();
    const cell = 13.0;
    const gap = 4.0;
    final chartWidth = math.max(
      220.0,
      weeks.length * (cell + gap) - gap,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outline.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.apps_rounded,
                size: 18,
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'App activity contributions',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ),
              Text(
                range.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface.withOpacity(0.52),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Counts saved actions still present: done cards, service entries, tasks, counters, and logs.',
            style: TextStyle(
              fontSize: 11,
              height: 1.28,
              color: colors.onSurface.withOpacity(0.58),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: chartWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    height: 18,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (var w = 0; w < weeks.length; w++)
                          SizedBox(
                            width: cell + gap,
                            child: Text(
                              _monthStartLabel(weeks[w], w),
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface.withOpacity(0.46),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 24,
                        child: Column(
                          children: const <Widget>[
                            _WeekdayHeatmapLabel('M'),
                            _WeekdayHeatmapLabel(''),
                            _WeekdayHeatmapLabel('W'),
                            _WeekdayHeatmapLabel(''),
                            _WeekdayHeatmapLabel('F'),
                            _WeekdayHeatmapLabel(''),
                            _WeekdayHeatmapLabel(''),
                          ],
                        ),
                      ),
                      for (final week in weeks)
                        Padding(
                          padding: const EdgeInsets.only(right: gap),
                          child: Column(
                            children: <Widget>[
                              for (final day in week)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: gap),
                                  child: Tooltip(
                                    message: day == null
                                        ? ''
                                        : '${dateKey(day.date)} · ${day.count} actions',
                                    child: Container(
                                      width: cell,
                                      height: cell,
                                      decoration: BoxDecoration(
                                        color: day == null
                                            ? Colors.transparent
                                            : _colorFor(context, day.count),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Text(
                'Less',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.onSurface.withOpacity(0.52),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 5),
              for (final count in const <int>[0, 1, 3, 6, 9]) ...<Widget>[
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: _colorFor(context, count),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                'More',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.onSurface.withOpacity(0.52),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _ContributionStat(
                  value: '$_total',
                  label: 'Total actions',
                ),
              ),
              Expanded(
                child: _ContributionStat(
                  value: '$_activeDays',
                  label: 'Active days',
                ),
              ),
              Expanded(
                child: _ContributionStat(
                  value: '$_currentStreak',
                  label: 'Current streak',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _monthStartLabel(List<_ContributionDay?> week, int index) {
    _ContributionDay? first;
    for (final day in week) {
      if (day != null) {
        first = day;
        break;
      }
    }
    if (first == null) return '';
    if (first.date.day <= 7 || index == 0) {
      return _monthLabel(first.date);
    }
    return '';
  }
}

class _WeekdayHeatmapLabel extends StatelessWidget {
  const _WeekdayHeatmapLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 17,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.42),
        ),
      ),
    );
  }
}

class _ContributionStat extends StatelessWidget {
  const _ContributionStat({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: colors.onSurface.withOpacity(0.52),
          ),
        ),
      ],
    );
  }
}

// ── Averages ──────────────────────────────────────────────────────────────────

class _AverageCard extends StatelessWidget {
  const _AverageCard({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final String label;
  final int? value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.small,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value == null ? '—' : '$value%',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tips ──────────────────────────────────────────────────────────────────────

class _TipCard extends StatelessWidget {
  const _TipCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3DC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('💡', style: TextStyle(fontSize: 14)),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8A6D1D)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI coach entry point ─────────────────────────────────────────────────────

class _CoachEntry extends StatelessWidget {
  const _CoachEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.medium,
          vertical: AppSpacing.small,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outline.withOpacity(0.45)),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.bolt_outlined, color: colors.primary, size: 18),
            const SizedBox(width: AppSpacing.medium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'AI Energy Coach',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Chat about sleep, focus, recovery, and more.',
                    style: TextStyle(
                      color: colors.onSurface.withOpacity(0.58),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.onSurfaceVariant, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Log rows ──────────────────────────────────────────────────────────────────

class _PlannerLogRow extends StatelessWidget {
  const _PlannerLogRow({required this.log});

  final PlannerSessionLog log;

  @override
  Widget build(BuildContext context) {
    final color = log.isDone ? AppColors.primary : AppColors.error;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.small,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            log.isDone ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  log.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${formatMinutes(log.startMinutes)} · ${formatMinutes(log.endMinutes)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            log.isDone ? 'Done' : 'Not done',
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.record, required this.activityName});

  final EnergyLogRecord record;
  final String activityName;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.small,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: <Widget>[
          Text(
            activityEmojis[record.activityId] ?? '⚡',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  activityName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${formatMinutes(record.startMinutes)} · ${record.durationMinutes} min',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '💪 ${record.physicalAfter}%',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.energyPhysicalAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppSpacing.small),
          Text(
            '🧠 ${record.brainAfter}%',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.energyBrainAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.isToday});

  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.insights_rounded,
                size: 32, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.small),
            Text(
              isToday
                  ? 'Nothing logged today yet.\nAdd activities from the You tab.'
                  : 'Nothing was logged on this day.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
