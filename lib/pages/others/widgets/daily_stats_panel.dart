import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import '../../../models/energy_log_record.dart' show dateKey;
import '../../../pages/profile/profile_store.dart';
import '../../../services/energy_log_store.dart';
import '../../services/tools/toolkit.dart';

enum StatsHeatmapRange {
  threeDays('3 days', 3),
  week('1 week', 7),
  month('1 month', 31),
  sixMonths('6 months', 183);

  const StatsHeatmapRange(this.label, this.days);
  final String label;
  final int days;
}

enum _ActivityMapView {
  heatmap('Heatmap'),
  month('Month');

  const _ActivityMapView(this.label);
  final String label;
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
  static final Map<String, List<_ContributionDay>> _heatmapCache =
      <String, List<_ContributionDay>>{};
  static final Set<String> _claimedUsers = <String>{};

  late final EnergyLogStore _store =
      widget.store ?? SqliteEnergyLogStore.instance;

  StatsHeatmapRange _heatmapRange = StatsHeatmapRange.sixMonths;
  _ActivityMapView _activityView = _ActivityMapView.heatmap;
  List<_ContributionDay> _contributionDays = const <_ContributionDay>[];
  List<_ContributionDay> _calendarDays = const <_ContributionDay>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DailyStatsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _heatmapCache.clear();
      _load();
    }
  }

  Future<void> _load() async {
    final userId = ProfileStore.instance.userId.value;
    final cached = _heatmapCache[_cacheKey(userId, _heatmapRange)];
    final calendarCached =
        _heatmapCache[_cacheKey(userId, StatsHeatmapRange.month)];
    if (cached != null &&
        (_activityView == _ActivityMapView.heatmap || calendarCached != null)) {
      setState(() {
        _contributionDays = cached;
        if (calendarCached != null) _calendarDays = calendarCached;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      if (!_claimedUsers.contains(userId)) {
        await _store.claimEnergyLogsForUser(userId);
        await _store.claimPlannerSessionLogsForUser(userId);
        _claimedUsers.add(userId);
      }
      final contributionDays = await _loadContributionDays(
        userId,
        _heatmapRange,
      );
      final calendarDays = _activityView == _ActivityMapView.month
          ? await _loadContributionDays(userId, StatsHeatmapRange.month)
          : _calendarDays;
      if (!mounted) return;
      setState(() {
        _contributionDays = contributionDays;
        _calendarDays = calendarDays;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _contributionDays = const <_ContributionDay>[];
        _loading = false;
      });
    }
  }

  String _cacheKey(String userId, StatsHeatmapRange range) {
    return '$userId:${range.name}:${dateKey(DateTime.now())}';
  }

  Future<List<_ContributionDay>> _loadContributionDays(
    String userId,
    StatsHeatmapRange range,
  ) async {
    final cacheKey = _cacheKey(userId, range);
    final cached = _heatmapCache[cacheKey];
    if (cached != null) return cached;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final fixedDays = range.days;
    final start = today.subtract(Duration(days: fixedDays - 1));
    final days = today.difference(start).inDays + 1;
    final counts = <String, int>{
      for (var i = 0; i < days; i++) dateKey(start.add(Duration(days: i))): 0,
    };

    final activityDates = (await _store.activityDates(userId: userId))
        .where(counts.containsKey)
        .toList(growable: false);
    for (final key in activityDates) {
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

    final contributionDays = counts.entries
        .map((entry) => _ContributionDay(
              date: DateTime.parse(entry.key),
              count: entry.value,
            ))
        .toList(growable: false);
    _heatmapCache[cacheKey] = contributionDays;
    return contributionDays;
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
                  'Activity Map',
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

        const SizedBox(height: AppSpacing.small),

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
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.medium,
                    AppSpacing.medium,
                    AppSpacing.medium,
                    AppSpacing.medium,
                  ),
                  children: <Widget>[
                    _ContributionHeatmapCard(
                      days: _contributionDays,
                      calendarDays: _calendarDays.isEmpty
                          ? _contributionDays
                          : _calendarDays,
                      view: _activityView,
                      range: _heatmapRange,
                      onViewChanged: (view) {
                        if (view == _activityView) return;
                        final userId = ProfileStore.instance.userId.value;
                        final cached = _heatmapCache[_cacheKey(
                          userId,
                          StatsHeatmapRange.month,
                        )];
                        setState(() {
                          _activityView = view;
                          if (cached != null) _calendarDays = cached;
                        });
                        if (view == _ActivityMapView.month && cached == null) {
                          _load();
                        }
                      },
                      onRangeChanged: (range) {
                        if (range == _heatmapRange) return;
                        final userId = ProfileStore.instance.userId.value;
                        final cached = _heatmapCache[_cacheKey(
                          userId,
                          range,
                        )];
                        if (cached != null) {
                          setState(() {
                            _heatmapRange = range;
                            _contributionDays = cached;
                          });
                          return;
                        }
                        setState(() => _heatmapRange = range);
                        _load();
                      },
                    ),
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
    required this.calendarDays,
    required this.view,
    required this.range,
    required this.onViewChanged,
    required this.onRangeChanged,
  });

  final List<_ContributionDay> days;
  final List<_ContributionDay> calendarDays;
  final _ActivityMapView view;
  final StatsHeatmapRange range;
  final ValueChanged<_ActivityMapView> onViewChanged;
  final ValueChanged<StatsHeatmapRange> onRangeChanged;

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
    final calendarTitle = _calendarTitle(calendarDays);

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
                  view == _ActivityMapView.heatmap
                      ? 'Contribution heatmap'
                      : calendarTitle,
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
                view == _ActivityMapView.heatmap ? range.label : 'Current',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface.withOpacity(0.52),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final option in _ActivityMapView.values)
                _HeatmapRangeChip(
                  label: option.label,
                  selected: option == view,
                  onTap: () => onViewChanged(option),
                ),
            ],
          ),
          if (view == _ActivityMapView.heatmap) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final option in StatsHeatmapRange.values)
                  _HeatmapRangeChip(
                    label: option.label,
                    selected: option == range,
                    onTap: () => onRangeChanged(option),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          view == _ActivityMapView.heatmap
              ? _buildHeatmapGrid(context, weeks)
              : _buildMonthCalendar(context, calendarDays),
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

  Widget _buildHeatmapGrid(
    BuildContext context,
    List<List<_ContributionDay?>> weeks,
  ) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        const labelWidth = 20.0;
        const gap = 3.0;
        final weekCount = math.max(weeks.length, 1);
        final available = math.max(0.0, constraints.maxWidth - labelWidth);
        final cell = ((available - (weekCount - 1) * gap) / weekCount)
            .clamp(5.5, 13.0)
            .toDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(left: labelWidth),
              child: Row(
                children: <Widget>[
                  for (var w = 0; w < weeks.length; w++)
                    SizedBox(
                      width: cell + (w == weeks.length - 1 ? 0 : gap),
                      child: Text(
                        _monthStartLabel(weeks[w], w),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface.withOpacity(0.46),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: labelWidth,
                  child: Column(
                    children: <Widget>[
                      _WeekdayHeatmapLabel('M', height: cell + gap),
                      _WeekdayHeatmapLabel('', height: cell + gap),
                      _WeekdayHeatmapLabel('W', height: cell + gap),
                      _WeekdayHeatmapLabel('', height: cell + gap),
                      _WeekdayHeatmapLabel('F', height: cell + gap),
                      _WeekdayHeatmapLabel('', height: cell + gap),
                      _WeekdayHeatmapLabel('', height: cell),
                    ],
                  ),
                ),
                for (var index = 0; index < weeks.length; index++)
                  Padding(
                    padding: EdgeInsets.only(
                      right: index == weeks.length - 1 ? 0 : gap,
                    ),
                    child: Column(
                      children: <Widget>[
                        for (var dayIndex = 0;
                            dayIndex < weeks[index].length;
                            dayIndex++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: dayIndex == 6 ? 0 : gap,
                            ),
                            child: Tooltip(
                              message: weeks[index][dayIndex] == null
                                  ? ''
                                  : '${dateKey(weeks[index][dayIndex]!.date)} - ${weeks[index][dayIndex]!.count} actions',
                              child: Container(
                                width: cell,
                                height: cell,
                                decoration: BoxDecoration(
                                  color: weeks[index][dayIndex] == null
                                      ? Colors.transparent
                                      : _colorFor(
                                          context,
                                          weeks[index][dayIndex]!.count,
                                        ),
                                  borderRadius: BorderRadius.circular(
                                    cell < 8 ? 2 : 3,
                                  ),
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
        );
      },
    );
  }

  Widget _buildMonthCalendar(
    BuildContext context,
    List<_ContributionDay> monthDays,
  ) {
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final first = DateTime(now.year, now.month);
    final totalDays = DateTime(now.year, now.month + 1, 0).day;
    final byKey = <String, _ContributionDay>{
      for (final day in monthDays) dateKey(day.date): day,
    };
    final cells = <DateTime?>[
      for (var i = 0; i < first.weekday - 1; i++) null,
      for (var day = 1; day <= totalDays; day++)
        DateTime(now.year, now.month, day),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final cellWidth =
            ((constraints.maxWidth - 6 * gap) / 7).clamp(30.0, 52.0).toDouble();
        return Column(
          children: <Widget>[
            const Row(
              children: <Widget>[
                _CalendarWeekday('M'),
                _CalendarWeekday('T'),
                _CalendarWeekday('W'),
                _CalendarWeekday('T'),
                _CalendarWeekday('F'),
                _CalendarWeekday('S'),
                _CalendarWeekday('S'),
              ],
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: <Widget>[
                for (final date in cells)
                  Builder(
                    builder: (context) {
                      final day = date == null ? null : byKey[dateKey(date)];
                      final isToday =
                          date != null && dateKey(date) == dateKey(now);
                      return Tooltip(
                        message: date == null
                            ? ''
                            : '${dateKey(date)} - ${day?.count ?? 0} actions',
                        child: Container(
                          width: cellWidth,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: date == null
                                ? Colors.transparent
                                : _colorFor(context, day?.count ?? 0),
                            borderRadius: BorderRadius.circular(10),
                            border: isToday
                                ? Border.all(color: colors.primary, width: 1.3)
                                : null,
                          ),
                          child: date == null
                              ? null
                              : Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    color: (day?.count ?? 0) > 0
                                        ? Colors.white
                                        : colors.onSurface.withOpacity(0.58),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _calendarTitle(List<_ContributionDay> monthDays) {
    final now = DateTime.now();
    return '${_monthLabel(now)} ${now.year} calendar';
  }
}

class _CalendarWeekday extends StatelessWidget {
  const _CalendarWeekday(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colors.onSurface.withOpacity(0.48),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HeatmapRangeChip extends StatelessWidget {
  const _HeatmapRangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withOpacity(0.12)
              : colors.surfaceContainerHighest.withOpacity(0.62),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? colors.primary.withOpacity(0.38)
                : colors.outline.withOpacity(0.18),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                selected ? colors.primary : colors.onSurface.withOpacity(0.58),
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _WeekdayHeatmapLabel extends StatelessWidget {
  const _WeekdayHeatmapLabel(this.label, {required this.height});

  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
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
