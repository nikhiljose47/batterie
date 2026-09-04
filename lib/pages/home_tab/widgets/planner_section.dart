import 'dart:math' show cos, pi, sin;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../constants/app_colors.dart';
import '../../../engine/energy_score_engine.dart';
import '../../../models/energy_log_record.dart';
import '../../../models/logged_activity.dart';
import '../../../models/planner_session_log.dart';
import '../../../models/weather.dart';
import '../../../services/custom_mode_store.dart';
import '../../../services/daily_progress_sync_service.dart';
import '../../../services/energy_log_store.dart';
import '../../../services/google_calendar_service.dart';
import '../../../services/remote_sync.dart';
import '../../profile/profile_store.dart';
import '../../services/services_page.dart';
import '../../services/tools/toolkit.dart';
import '../../weather/weather_controller.dart';
import '../data/mode_advice.dart';

class _TimedTodo {
  const _TimedTodo({
    required this.id,
    required this.text,
    required this.done,
    required this.due,
  });

  final String id;
  final String text;
  final bool done;
  final DateTime? due;

  _TimedTodo copyWith({bool? done}) {
    return _TimedTodo(
      id: id,
      text: text,
      done: done ?? this.done,
      due: due,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'text': text,
        'done': done,
        if (due != null) 'due': due!.toIso8601String(),
      };

  factory _TimedTodo.fromMap(Map<String, dynamic> map) {
    return _TimedTodo(
      id: (map['id'] as String?) ?? '',
      text: (map['text'] as String?) ?? '',
      done: (map['done'] as bool?) ?? false,
      due: DateTime.tryParse((map['due'] as String?) ?? ''),
    );
  }
}

/// "Planner" — a mini vertical carousel of mac-style white cards, one per
/// 1–2 h slot. The card for the current time rests near the top, nudged
/// down a touch so the previous card visibly peeks. Only this list scrolls
/// — the day card above stays pinned by the parent.
///
/// Card content is mode-driven: `modeId` selects a curated list of
/// `ModeAdvice` from `mode_advice.dart`, one entry per slot.
class PlannerSection extends StatefulWidget {
  const PlannerSection({
    super.key,
    required this.nowMinutes,
    required this.wakeMinutes,
    required this.sleepMinutes,
    required this.modeId,
    required this.onModeChanged,
    this.weatherController,
    this.onSessionLogsChanged,
    this.refreshToken = 0,
    this.showCurrentOnly = false,
    this.onShowAll,
  });

  final double nowMinutes;
  final int wakeMinutes;
  final int sleepMinutes;
  final String modeId;
  final ValueChanged<String> onModeChanged;
  final WeatherController? weatherController;
  final ValueChanged<List<PlannerSessionLog>>? onSessionLogsChanged;
  final int refreshToken;
  final bool showCurrentOnly;
  final VoidCallback? onShowAll;

  @override
  State<PlannerSection> createState() => PlannerSectionState();
}

class PlannerSectionState extends State<PlannerSection> {
  static const String _plannerFontFamily = 'Inter';
  static const double _regularCardHeight = 320.0;
  static const double _currentCardHeight = 510.0;
  static const double _cardGap = 12.0;

  late final ScrollController _scrollController;

  /// slot index → "⏪ Ran easy pace (Tue)" — the best-scoring thing the user
  /// did in this window across the last week.
  Map<int, String> _bestFromPast = const <int, String>{};
  List<_TimedTodo> _todos = const <_TimedTodo>[];
  List<GoogleCalendarEvent> _googleCurrentTasks = const <GoogleCalendarEvent>[];
  bool _googleTasksLoading = false;
  Map<String, PlannerSessionLog> _sessionLogs =
      const <String, PlannerSessionLog>{};

  static const String _todoKey = 'svc.todo.items';

  List<TimeSlot> get _slots => plannerSlotsFor(
        wakeMinutes: widget.wakeMinutes,
        sleepMinutes: widget.sleepMinutes,
      );

  int get _currentIndex {
    final now = widget.nowMinutes.floor();
    final index = _slots.indexWhere((s) => s.contains(now));
    if (index != -1) return index;
    if (_slots.isNotEmpty &&
        isSleepWindowFor(
          now,
          wakeMinutes: widget.wakeMinutes,
          sleepMinutes: widget.sleepMinutes,
        )) {
      return _slots.length - 1;
    }
    return -1;
  }

  int get _currentSessionStartMinutes {
    if (_currentIndex != -1) return _slots[_currentIndex].startMinutes;
    return widget.nowMinutes.floor();
  }

  int get _currentSessionEndMinutes {
    if (_currentIndex != -1) return _slots[_currentIndex].endMinutes;
    return widget.nowMinutes.floor() + 60;
  }

  double get _currentCardOffset {
    const step = _regularCardHeight + _cardGap;
    if (_currentIndex == -1) return 0.0;
    return (_currentIndex * step).clamp(0.0, _slots.length * step);
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadTravelBack();
    _loadTodos();
    _loadSessionLogs();
    // Refresh the cards whenever the user edits their custom plan — makes
    // the round-trip through the Daily Planner service feel instantaneous.
    CustomModeStore.instance.slots.addListener(_onCustomChanged);
    // Start one card above the current slot, then glide into place — a short,
    // purposeful reveal rather than a full-list fly-down from the top.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrent();
      if (widget.showCurrentOnly) _loadGoogleItemsForCurrentPeriod();
    });
  }

  @override
  void didUpdateWidget(covariant PlannerSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wakeMinutes != widget.wakeMinutes ||
        oldWidget.sleepMinutes != widget.sleepMinutes ||
        oldWidget.nowMinutes.floor() != widget.nowMinutes.floor()) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    }
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadTodos();
      _loadSessionLogs();
      _loadTravelBack();
    }
    if (!oldWidget.showCurrentOnly && widget.showCurrentOnly) {
      _loadGoogleItemsForCurrentPeriod();
    } else if (widget.showCurrentOnly &&
        (oldWidget.nowMinutes.floor() != widget.nowMinutes.floor() ||
            oldWidget.wakeMinutes != widget.wakeMinutes ||
            oldWidget.sleepMinutes != widget.sleepMinutes)) {
      _loadGoogleItemsForCurrentPeriod();
    }
  }

  void _scrollToCurrent() {
    if (!mounted || !_scrollController.hasClients) return;
    if (!_scrollController.position.hasContentDimensions) return;
    final target = _currentCardOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.jumpTo(target);
  }

  void _animateToCurrent() {
    if (!mounted || !_scrollController.hasClients) return;
    if (!_scrollController.position.hasContentDimensions) return;
    final target = _currentCardOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  void scrollToCurrentCard() => _animateToCurrent();

  Future<void> refreshGoogleCurrentItems() async {
    await _loadGoogleItemsForCurrentPeriod(force: true);
  }

  Future<void> openTodoForCurrentSession() async {
    await _openTodoService(_currentSessionStartMinutes);
  }

  void _onCustomChanged() {
    if (mounted && CustomModeStore.isCustomModeId(widget.modeId)) {
      setState(() {});
    }
  }

  Future<void> _loadTodos() async {
    final items = await ServiceStore.loadList(_todoKey);
    if (!mounted) return;
    setState(() {
      _todos = items.map(_TimedTodo.fromMap).where((todo) {
        return todo.id.isNotEmpty && todo.text.isNotEmpty && todo.due != null;
      }).toList();
    });
  }

  Future<void> _loadGoogleItemsForCurrentPeriod({bool force = false}) async {
    if (!force && !widget.showCurrentOnly) return;
    if (_googleTasksLoading) return;
    setState(() => _googleTasksLoading = true);
    try {
      final items = await GoogleCalendarService.instance.todayItems();
      if (!mounted) return;
      final (start, end) = _currentPeriodDateRange();
      setState(() {
        _googleCurrentTasks = items
            .where((item) => _googleItemBelongsToCurrentPeriod(
                  item,
                  start,
                  end,
                ))
            .toList();
        _googleTasksLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _googleCurrentTasks = const <GoogleCalendarEvent>[];
        _googleTasksLoading = false;
      });
    }
  }

  bool _googleItemBelongsToCurrentPeriod(
    GoogleCalendarEvent item,
    DateTime start,
    DateTime end,
  ) {
    final itemStart = item.start;
    final itemEnd = item.end;
    if (item.isTask && (item.isAllDay || itemStart == null)) {
      return true;
    }
    if (itemStart == null) return false;
    if (item.isTask && _isDateOnlyGoogleTask(itemStart)) {
      return svcDay(itemStart) == svcDay(DateTime.now());
    }
    final effectiveEnd = itemEnd ?? itemStart.add(const Duration(minutes: 30));
    return itemStart.isBefore(end) && effectiveEnd.isAfter(start);
  }

  bool _isDateOnlyGoogleTask(DateTime value) {
    return (value.hour == 0 && value.minute == 0 && value.second == 0) ||
        value.toUtc().hour == 0 &&
            value.toUtc().minute == 0 &&
            value.toUtc().second == 0;
  }

  (DateTime, DateTime) _currentPeriodDateRange() {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    return (
      dayStart.add(Duration(minutes: _currentSessionStartMinutes)),
      dayStart.add(Duration(minutes: _currentSessionEndMinutes)),
    );
  }

  Future<void> _saveTodos() async {
    await ServiceStore.saveList(
      _todoKey,
      _todos.map((todo) => todo.toMap()).toList(),
    );
  }

  Future<void> _loadSessionLogs() async {
    try {
      final userId = ProfileStore.instance.userId.value;
      await SqliteEnergyLogStore.instance
          .claimPlannerSessionLogsForUser(userId);
      final logs =
          await SqliteEnergyLogStore.instance.plannerSessionLogsForDate(
        dateKey(DateTime.now()),
        userId: userId,
      );
      if (!mounted) return;
      setState(() {
        _sessionLogs = <String, PlannerSessionLog>{
          for (final log in logs) log.sessionId: log,
        };
      });
      widget.onSessionLogsChanged?.call(logs);
    } catch (_) {}
  }

  Future<void> _toggleSessionDone({
    required String sessionId,
    required int startMinutes,
    required int endMinutes,
    required String title,
  }) async {
    final existing = _sessionLogs[sessionId];
    final isDone = !(existing?.isDone ?? false);
    final today = dateKey(DateTime.now());
    final userId = ProfileStore.instance.userId.value;
    final log = PlannerSessionLog(
      id: 'planner_${userId}_${today}_$sessionId',
      userId: userId,
      date: today,
      sessionId: sessionId,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      title: title,
      isDone: isDone,
    );

    setState(() {
      _sessionLogs = <String, PlannerSessionLog>{
        ..._sessionLogs,
        sessionId: log,
      };
    });
    widget.onSessionLogsChanged?.call(_sessionLogs.values.toList());

    try {
      await SqliteEnergyLogStore.instance.savePlannerSessionLog(log);
      await RemoteSync.instance.upsertPlannerSessionLog(log, userId: userId);
      await DailyProgressSyncService.instance.syncToday();
    } catch (_) {}
  }

  Future<void> _toggleTodo(String id) async {
    setState(() {
      _todos = <_TimedTodo>[
        for (final todo in _todos)
          todo.id == id ? todo.copyWith(done: !todo.done) : todo,
      ];
    });
    await _saveTodos();
  }

  Future<void> _completeTodos(Iterable<_TimedTodo> todos) async {
    final ids = todos.map((todo) => todo.id).toSet();
    if (ids.isEmpty) return;
    setState(() {
      _todos = <_TimedTodo>[
        for (final todo in _todos)
          ids.contains(todo.id) ? todo.copyWith(done: true) : todo,
      ];
    });
    await _saveTodos();
  }

  Future<void> _openTodoService(int initialMinutes) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ServicesPage(
          autoOpenServiceId: 'todo',
          initialTodoMinutes: initialMinutes,
        ),
      ),
    );
    await _loadTodos();
  }

  Future<void> _openAlarmService(int initialMinutes) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ServicesPage(
          autoOpenServiceId: 'alarms',
          initialAlarmMinutes: initialMinutes,
        ),
      ),
    );
  }

  List<_TimedTodo> _todosForSlot(TimeSlot slot) {
    return _todos.where((todo) {
      final due = todo.due;
      if (due == null || svcDay(due) != svcDay(DateTime.now())) return false;
      return slot.contains(due.hour * 60 + due.minute);
    }).toList();
  }

  /// Scans the last 7 days of the energy log and, per slot, keeps the
  /// activity that left the user with the highest combined energy.
  Future<void> _loadTravelBack() async {
    const engine = EnergyScoreEngine();
    const weekdays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    try {
      final store = SqliteEnergyLogStore.instance;
      final userId = ProfileStore.instance.userId.value;
      await store.claimEnergyLogsForUser(userId);
      final today = DateTime.now();
      final best = <int, ({int score, String label})>{};

      for (var back = 1; back <= 7; back++) {
        final day = today.subtract(Duration(days: back));
        List<EnergyLogRecord> records;
        try {
          records = await store.recordsForDate(dateKey(day), userId: userId);
        } catch (_) {
          continue;
        }
        for (final record in records) {
          final slotIndex =
              _slots.indexWhere((s) => s.contains(record.startMinutes));
          if (slotIndex == -1) continue;

          final score = record.physicalAfter + record.brainAfter;
          final current = best[slotIndex];
          if (current == null || score > current.score) {
            final emoji = activityEmojis[record.activityId] ?? '⚡';
            final name = engine.activityById(record.activityId).name;
            best[slotIndex] = (
              score: score,
              label: '⏪ $emoji $name (${weekdays[day.weekday - 1]})',
            );
          }
        }
      }

      if (!mounted || best.isEmpty) return;
      setState(() {
        _bestFromPast = <int, String>{
          for (final entry in best.entries) entry.key: entry.value.label,
        };
      });
    } catch (_) {
      // No history (or no DB on this platform) — cards just skip the tag.
    }
  }

  @override
  void dispose() {
    CustomModeStore.instance.slots.removeListener(_onCustomChanged);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adviceList = adviceForMode(widget.modeId);
    if (widget.weatherController != null) {
      return AnimatedBuilder(
        animation: widget.weatherController!,
        builder: (context, _) => _buildBody(
          adviceList,
          widget.weatherController!.state.snapshot,
        ),
      );
    }
    return _buildBody(adviceList, null);
  }

  Widget _buildBody(List<ModeAdvice> adviceList, WeatherSnapshot? weather) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: _plannerFontFamily),
      child: widget.showCurrentOnly
          ? _buildCurrentOnly(adviceList, weather)
          : _buildList(adviceList, weather),
    );
  }

  Widget _buildCurrentOnly(
    List<ModeAdvice> adviceList,
    WeatherSnapshot? weather,
  ) {
    final currentIndex = _currentIndex;
    final child = _buildCurrentPeriodCard(adviceList, weather, currentIndex);
    return LayoutBuilder(
      builder: (context, constraints) {
        final colors = Theme.of(context).colorScheme;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  height: 42,
                  padding: const EdgeInsets.only(left: 10, right: 4),
                  decoration: BoxDecoration(
                    color: colors.surface.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.outline.withOpacity(0.24),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.my_location_rounded,
                        size: 18,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentPeriodLabel(currentIndex),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Show list',
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onShowAll,
                        icon: Icon(
                          Icons.view_list_rounded,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                child,
                _buildGoogleCurrentTasksSection(),
              ],
            ),
          ),
        );
      },
    );
  }

  String _currentPeriodLabel(int currentIndex) {
    if (currentIndex != -1) return _slots[currentIndex].rangeLabel;
    return 'Current period';
  }

  Widget _buildCurrentPeriodCard(
    List<ModeAdvice> adviceList,
    WeatherSnapshot? weather,
    int currentIndex,
  ) {
    if (currentIndex == -1) return const SizedBox.shrink();
    final slot = _slots[currentIndex];
    final advice = adviceList[currentIndex];
    return _CurrentModeCard(
      slotIndex: currentIndex,
      slot: slot,
      advice: advice,
      sessionDone: _sessionLogs['slot_$currentIndex']?.isDone ?? false,
      onToggleSessionDone: () => _toggleSessionDone(
        sessionId: 'slot_$currentIndex',
        startMinutes: slot.startMinutes,
        endMinutes: slot.endMinutes,
        title: advice.tip,
      ),
      history: historyForPlannerSlot(currentIndex),
    );
  }

  Widget _buildGoogleCurrentTasksSection() {
    if (_googleTasksLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 10),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (_googleCurrentTasks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: _GoogleCurrentTasksCard(tasks: _googleCurrentTasks),
    );
  }

  void showPastBestSummary(BuildContext context) {
    final slotLabel = _currentIndex != -1
        ? _slots[_currentIndex].rangeLabel
        : 'Current period';
    final label = _currentIndex != -1 ? _bestFromPast[_currentIndex] : null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          label == null
              ? 'Your best · $slotLabel: start tracking an activity'
              : 'Your best · $slotLabel: $label',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void showRainSummary(BuildContext context) {
    final weather = widget.weatherController?.state.snapshot;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Expected rain: ${_rainSummary(weather)}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool _isRainy(WeatherCondition c) =>
      c == WeatherCondition.rain ||
      c == WeatherCondition.drizzle ||
      c == WeatherCondition.showers ||
      c == WeatherCondition.thunderstorm ||
      c == WeatherCondition.freezingRain;

  String _rainSummary(WeatherSnapshot? weather) {
    if (weather == null) return 'Weather off';

    final current = weather.current;
    if (_isRainy(current.condition)) {
      return 'Raining now';
    }

    for (final hour in weather.hourly.take(12)) {
      final prob = hour.precipitationProbability;
      if (_isRainy(hour.condition) || (prob != null && prob >= 30)) {
        final label = formatMinutes(hour.time.hour * 60 + hour.time.minute);
        return prob != null && prob > 0 ? '$label · $prob%' : label;
      }
    }

    if (weather.daily.isNotEmpty) {
      final today = weather.daily.first;
      final prob = today.precipitationProbability;
      if (_isRainy(today.condition)) {
        return prob != null && prob > 0 ? 'Today · $prob%' : 'Today';
      }
      if (prob != null && prob >= 30) return 'Today · $prob%';
    }

    return 'No rain today';
  }

  Widget _buildList(List<ModeAdvice> adviceList, WeatherSnapshot? weather) {
    final currentIndex = _currentIndex;
    return Stack(
      children: <Widget>[
        ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          itemCount: _slots.length,
          separatorBuilder: (_, __) => const SizedBox(height: _cardGap),
          itemBuilder: (context, index) {
            final slotIndex = index;
            final slot = _slots[slotIndex];
            final advice = adviceList[slotIndex];
            final isCurrent = currentIndex != -1 && slotIndex == currentIndex;
            final slotTodos = _todosForSlot(slot);
            return _SessionListRow(
              height: isCurrent ? _currentCardHeight : _regularCardHeight,
              child: _PlannerCard(
                slotIndex: slotIndex,
                slot: slot,
                advice: advice,
                isCurrent: isCurrent,
                weatherTag: _weatherTagFor(weather),
                weather: isCurrent ? weather : null,
                slotForecast: slotIndex > currentIndex
                    ? _forecastForSlot(slot, weather)
                    : null,
                height: isCurrent ? _currentCardHeight : _regularCardHeight,
                todos: slotTodos,
                onAddTodo: () => _openTodoService(slot.startMinutes),
                onSetAlarm: () => _openAlarmService(slot.startMinutes),
                onToggleTodo: _toggleTodo,
                onCompleteTodos: _completeTodos,
                sessionDone: _sessionLogs['slot_$slotIndex']?.isDone ?? false,
                onToggleSessionDone: () => _toggleSessionDone(
                  sessionId: 'slot_$slotIndex',
                  startMinutes: slot.startMinutes,
                  endMinutes: slot.endMinutes,
                  title: advice.tip,
                ),
                history: historyForPlannerSlot(slotIndex),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Hour-accurate prediction for an upcoming slot: the cached hourly
  /// forecast sampled at the slot's midpoint today.
  HourlyForecast? _forecastForSlot(TimeSlot slot, WeatherSnapshot? weather) {
    if (weather == null) return null;
    final now = DateTime.now();
    final midMinutes = (slot.startMinutes + slot.endMinutes) ~/ 2;
    final when = DateTime(
        now.year, now.month, now.day, midMinutes ~/ 60, midMinutes % 60);
    return weather.hourlyAt(when);
  }

  /// A weather tag only when it matters — used on non-current cards as a
  /// small badge. The current card gets the full weather block instead.
  String? _weatherTagFor(WeatherSnapshot? weather) {
    if (weather == null) return null;
    final current = weather.current;
    final rainChance = weather.daily.isEmpty
        ? null
        : weather.daily.first.precipitationProbability;

    final rainy = switch (current.condition) {
      WeatherCondition.rain ||
      WeatherCondition.drizzle ||
      WeatherCondition.showers ||
      WeatherCondition.thunderstorm =>
        true,
      _ => (rainChance ?? 0) >= 55,
    };
    if (rainy) return '🌧 Rain';
    if (current.temperatureC >= 33) return '🔥 Hot';
    if (current.temperatureC >= 18 &&
        current.temperatureC <= 28 &&
        (current.condition == WeatherCondition.clear ||
            current.condition == WeatherCondition.partlyCloudy)) {
      return '🌿 Pleasant';
    }
    return null;
  }
}

class _SessionListRow extends StatelessWidget {
  const _SessionListRow({
    required this.height,
    required this.child,
  });

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height, child: Center(child: child));
  }
}

class CurrentSessionClockCard extends StatelessWidget {
  const CurrentSessionClockCard({
    required this.startMinutes,
    required this.endMinutes,
    required this.onTap,
  });

  final int startMinutes;
  final int endMinutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 38,
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: colors.surface.withOpacity(dark ? 0.92 : 0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.primary.withOpacity(0.24)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(dark ? 0.24 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _MiniClock(minutes: startMinutes, active: true, size: 24),
              Container(
                width: 2,
                height: 8,
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.42),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              _MiniClock(minutes: endMinutes, active: true, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniClock extends StatelessWidget {
  const _MiniClock({
    required this.minutes,
    required this.active,
    this.size,
  });

  final int minutes;
  final bool active;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final diameter = size ?? (active ? 34.0 : 32.0);
    return SizedBox(
      width: diameter + 8,
      height: diameter + 8,
      child: Center(
        child: Container(
          width: diameter + 4,
          height: diameter + 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.16),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: SizedBox(
              width: diameter,
              height: diameter,
              child: CustomPaint(
                painter: _ClockFacePainter(
                  hour: (minutes ~/ 60) % 24,
                  minute: minutes % 60,
                  active: active,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClockFacePainter extends CustomPainter {
  const _ClockFacePainter({
    required this.hour,
    required this.minute,
    required this.active,
  });

  final int hour;
  final int minute;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.2;
    final primary = active ? AppColors.primary : const Color(0xFF4B5968);
    final border = active ? AppColors.primary : AppColors.outline;

    canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 2.0 : 1.4
        ..color = border,
    );

    for (var i = 0; i < 12; i++) {
      final angle = i / 12 * 2 * pi - pi / 2;
      final outer = Offset(
        center.dx + cos(angle) * (radius - 2.2),
        center.dy + sin(angle) * (radius - 2.2),
      );
      final inner = Offset(
        center.dx + cos(angle) * (radius - (i % 3 == 0 ? 5.2 : 4.0)),
        center.dy + sin(angle) * (radius - (i % 3 == 0 ? 5.2 : 4.0)),
      );
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = primary.withOpacity(i % 3 == 0 ? 0.72 : 0.42)
          ..strokeWidth = i % 3 == 0 ? 1.2 : 0.8
          ..strokeCap = StrokeCap.round,
      );
    }

    final hourAngle = ((hour % 12) + minute / 60.0) / 12 * 2 * pi - pi / 2;
    final minuteAngle = minute / 60 * 2 * pi - pi / 2;
    canvas.drawLine(
      center,
      Offset(
        center.dx + cos(hourAngle) * radius * 0.46,
        center.dy + sin(hourAngle) * radius * 0.46,
      ),
      Paint()
        ..color = primary
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      center,
      Offset(
        center.dx + cos(minuteAngle) * radius * 0.68,
        center.dy + sin(minuteAngle) * radius * 0.68,
      ),
      Paint()
        ..color = active ? AppColors.secondary : primary.withOpacity(0.78)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 2.2, Paint()..color = primary);
  }

  @override
  bool shouldRepaint(_ClockFacePainter oldDelegate) {
    return oldDelegate.hour != hour ||
        oldDelegate.minute != minute ||
        oldDelegate.active != active;
  }
}

class _CurrentModeCard extends StatelessWidget {
  const _CurrentModeCard({
    required this.slotIndex,
    required this.slot,
    required this.advice,
    required this.sessionDone,
    required this.onToggleSessionDone,
    required this.history,
  });

  final int slotIndex;
  final TimeSlot slot;
  final ModeAdvice advice;
  final bool sessionDone;
  final VoidCallback onToggleSessionDone;
  final String history;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minHeight: 168),
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
      decoration: BoxDecoration(
        gradient: _slotGradient(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.primary.withOpacity(0.36)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.28 : 0.045),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const _NowBadge(compact: true),
                    const SizedBox(width: 8),
                    Flexible(child: _TimeRangeBadge(label: slot.rangeLabel)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  advice.tip,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 21,
                    height: 1.16,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  advice.recommendation,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.34,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface.withOpacity(0.68),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  history,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: colors.onSurface.withOpacity(0.52),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _SessionDoneButton(
            done: sessionDone,
            onTap: onToggleSessionDone,
            size: 42,
          ),
        ],
      ),
    );
  }

  LinearGradient _slotGradient(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    const lightStops = <Color>[
      Color(0xFFF4FFF7),
      Color(0xFFFFFAEF),
      Color(0xFFFFF8D9),
      Color(0xFFFFF0C9),
      Color(0xFFFFE5CF),
      Color(0xFFFFD7BC),
      Color(0xFFFFC6A4),
    ];
    const darkStops = <Color>[
      Color(0xFF17231B),
      Color(0xFF221F18),
      Color(0xFF2A2415),
      Color(0xFF2E2117),
      Color(0xFF331E17),
      Color(0xFF351A18),
      Color(0xFF2A1820),
    ];
    final palette = dark ? darkStops : lightStops;
    final accent = palette[slotIndex.clamp(0, palette.length - 1)];
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[colors.surface, accent],
    );
  }
}

class _CurrentWakeSleepCard extends StatelessWidget {
  const _CurrentWakeSleepCard({
    required this.content,
    required this.variant,
    required this.sessionDone,
    required this.onToggleSessionDone,
  });

  final WakeSleepCopy content;
  final _WakeSleepVariant variant;
  final bool sessionDone;
  final VoidCallback onToggleSessionDone;

  bool get _isWake => variant == _WakeSleepVariant.wake;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = _isWake ? AppColors.primary : AppColors.bedtimeAccent;
    final bg = _isWake ? const Color(0xFFF3FFF7) : const Color(0xFFF7F5FF);
    return Container(
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            _isWake ? Icons.wb_sunny_rounded : Icons.bedtime_rounded,
            color: accent,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  content.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content.headline,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 20,
                    height: 1.18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content.tip,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface.withOpacity(0.64),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _SessionDoneButton(
            done: sessionDone,
            onTap: onToggleSessionDone,
            size: 42,
          ),
        ],
      ),
    );
  }
}

class _GoogleCurrentTasksCard extends StatelessWidget {
  const _GoogleCurrentTasksCard({required this.tasks});

  final List<GoogleCalendarEvent> tasks;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outline.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.task_alt_rounded,
                size: 16,
                color: colors.primary,
              ),
              const SizedBox(width: 7),
              Text(
                'Google calendar',
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final task in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: <Widget>[
                  Icon(
                    task.isTask
                        ? task.isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded
                        : Icons.event_rounded,
                    size: 15,
                    color: task.isCompleted
                        ? AppColors.primary
                        : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface.withOpacity(
                          task.isCompleted ? 0.48 : 0.82,
                        ),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                  Text(
                    _timeLabel(task),
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _timeLabel(GoogleCalendarEvent item) {
    final start = item.start;
    if (start == null || item.isAllDay) return 'Today';
    if (item.isTask && start.hour == 0 && start.minute == 0) return 'Today';
    return formatMinutes(start.hour * 60 + start.minute);
  }
}

/// White mac-style card.
///
/// Layout: 70% left column (recommendation quote, attribution, previous
/// best), 10% gap, 20% right column (weather block on the current card,
/// small tag stack on others). The card for the current slot is taller
/// and more emphasized than its neighbors.
class _PlannerCard extends StatelessWidget {
  const _PlannerCard({
    required this.slotIndex,
    required this.slot,
    required this.advice,
    required this.isCurrent,
    required this.weatherTag,
    required this.weather,
    required this.slotForecast,
    required this.height,
    required this.history,
    required this.todos,
    required this.onAddTodo,
    required this.onSetAlarm,
    required this.onToggleTodo,
    required this.onCompleteTodos,
    required this.sessionDone,
    required this.onToggleSessionDone,
    this.allowAddTodo = true,
  });

  final int slotIndex;
  final TimeSlot slot;
  final ModeAdvice advice;
  final bool isCurrent;
  final String? weatherTag;

  /// Full weather snapshot — passed only to the current card.
  final WeatherSnapshot? weather;

  /// Hourly prediction for this slot — passed only to upcoming cards.
  final HourlyForecast? slotForecast;
  final double height;
  final String history;
  final List<_TimedTodo> todos;
  final VoidCallback onAddTodo;
  final VoidCallback onSetAlarm;
  final ValueChanged<String> onToggleTodo;
  final ValueChanged<Iterable<_TimedTodo>> onCompleteTodos;
  final bool sessionDone;
  final VoidCallback onToggleSessionDone;
  final bool allowAddTodo;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardGradient = _slotGradient(context);
    return Container(
      height: height,
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isCurrent ? 18 : 14,
        isCurrent ? 16 : 12,
        isCurrent ? 18 : 14,
        isCurrent ? 14 : 12,
      ),
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(isCurrent ? 20 : 16),
        border: Border.all(
          color: isCurrent
              ? colors.primary.withOpacity(0.45)
              : colors.outline.withOpacity(0.62),
          width: isCurrent ? 1.2 : 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(
              dark ? (isCurrent ? 0.34 : 0.22) : (isCurrent ? 0.055 : 0.035),
            ),
            blurRadius: isCurrent ? 18 : 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (isCurrent)
                const _NowBadge()
              else
                _TimeRangeBadge(label: slot.rangeLabel),
              const Spacer(),
              _SessionDoneButton(
                done: sessionDone,
                onTap: onToggleSessionDone,
                size: isCurrent ? 42 : 36,
              ),
            ],
          ),
          SizedBox(height: isCurrent ? 14 : 10),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildContent(context),
            ),
          ),
          const SizedBox(height: 10),
          _CardActionRow(
            weatherLabel: _weatherActionLabel(),
            onSetAlarm: onSetAlarm,
          ),
          const SizedBox(height: 8),
          _TodoSummaryStrip(
            todos: todos,
            onAdd: allowAddTodo ? onAddTodo : null,
            onComplete: () => onCompleteTodos(
              todos.where((todo) => !todo.done),
            ),
          ),
          const SizedBox(height: 8),
          _buildFootnote(context),
        ],
      ),
    );
  }

  LinearGradient _slotGradient(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    const lightStops = <Color>[
      Color(0xFFF4FFF7),
      Color(0xFFFFFAEF),
      Color(0xFFFFF8D9),
      Color(0xFFFFF0C9),
      Color(0xFFFFE5CF),
      Color(0xFFFFD7BC),
      Color(0xFFFFC6A4),
    ];
    const darkStops = <Color>[
      Color(0xFF17231B),
      Color(0xFF221F18),
      Color(0xFF2A2415),
      Color(0xFF2E2117),
      Color(0xFF331E17),
      Color(0xFF351A18),
      Color(0xFF2A1820),
    ];
    final palette = dark ? darkStops : lightStops;
    final accent = palette[slotIndex.clamp(0, palette.length - 1)];
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? <Color>[colors.surface, accent]
          : <Color>[colors.surface, accent],
    );
  }

  Widget _buildDescriptionBullets(
    BuildContext context, {
    required bool compact,
  }) {
    final colors = Theme.of(context).colorScheme;
    final bullets = advice.descriptions.isNotEmpty
        ? advice.descriptions
        : <String>[advice.tip];
    final shown = bullets.take(compact ? 2 : 3).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final bullet in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: compact ? 3 : 4,
                    height: compact ? 3 : 4,
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.72),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    bullet,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.34,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface.withOpacity(0.68),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final headlineColor = colors.onSurface.withOpacity(0.88);
    final bodyColor = colors.onSurface.withOpacity(0.68);
    if (isCurrent) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            advice.tip,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 24,
              height: 1.18,
              fontWeight: FontWeight.w700,
              color: headlineColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            advice.recommendation,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: bodyColor,
            ),
          ),
          const SizedBox(height: 14),
          _buildDescriptionBullets(context, compact: false),
        ],
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          advice.tip,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.left,
          style: TextStyle(
            fontSize: 18,
            height: 1.12,
            fontWeight: FontWeight.w700,
            color: headlineColor,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          advice.recommendation,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.left,
          style: TextStyle(
            fontSize: 13,
            height: 1.24,
            fontWeight: FontWeight.w600,
            color: bodyColor,
          ),
        ),
        const SizedBox(height: 8),
        _buildDescriptionBullets(context, compact: true),
      ],
    );
  }

  String _weatherActionLabel() {
    if (isCurrent && weather != null) {
      final current = weather!.current;
      return '${current.temperatureC.round()}° ${current.condition.label}';
    }
    if (slotForecast != null) {
      return '${slotForecast!.temperatureC.round()}° ${slotForecast!.condition.label}';
    }
    return weatherTag ?? 'Weather';
  }

  Widget _buildFootnote(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Icon(
          Icons.auto_awesome_rounded,
          size: isCurrent ? 13 : 11,
          color: AppColors.bedtimeAccent,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            history,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isCurrent ? 9 : 8,
              color: colors.onSurface.withOpacity(0.55),
            ),
          ),
        ),
      ],
    );
  }
}

class _CardActionRow extends StatelessWidget {
  const _CardActionRow({
    required this.weatherLabel,
    required this.onSetAlarm,
  });

  final String weatherLabel;
  final VoidCallback onSetAlarm;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _ActionPill(
            icon: Icons.cloud_queue_rounded,
            label: weatherLabel,
            onTap: null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionPill(
            icon: Icons.alarm_add_rounded,
            label: 'Set alarm',
            onTap: onSetAlarm,
          ),
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: colors.surfaceTint.withOpacity(0.72),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.outline.withOpacity(0.52)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 16, color: colors.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface.withOpacity(0.82),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodoSummaryStrip extends StatelessWidget {
  const _TodoSummaryStrip({
    required this.todos,
    required this.onAdd,
    required this.onComplete,
  });

  final List<_TimedTodo> todos;
  final VoidCallback? onAdd;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final open = todos.where((todo) => !todo.done).toList();
    final label = todos.isEmpty
        ? 'No tasks added'
        : open.isEmpty
            ? 'All tasks done'
            : '${open.length} task${open.length == 1 ? '' : 's'} pending';
    final preview = open.isNotEmpty
        ? open.first.text
        : todos.isNotEmpty
            ? todos.first.text
            : 'No tasks yet';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surfaceTint.withOpacity(0.62),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.outline.withOpacity(0.5)),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                open.isEmpty && todos.isNotEmpty
                    ? Icons.check_circle_rounded
                    : Icons.task_alt_rounded,
                size: 18,
                color: colors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface.withOpacity(0.88),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface.withOpacity(0.62),
                      ),
                    ),
                  ],
                ),
              ),
              if (open.isNotEmpty)
                IconButton(
                  tooltip: 'Complete tasks',
                  visualDensity: VisualDensity.compact,
                  onPressed: onComplete,
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  color: AppColors.primary,
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionTodoPanel extends StatelessWidget {
  const _SessionTodoPanel({
    required this.todos,
    required this.compact,
    required this.onAdd,
    required this.onToggle,
    required this.onComplete,
    this.dark = false,
  });

  final List<_TimedTodo> todos;
  final bool compact;
  final bool dark;
  final VoidCallback? onAdd;
  final ValueChanged<String> onToggle;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final todoWidth = compact ? 132.0 : 166.0;
    final boxSize = compact ? 58.0 : 66.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _TodoActionBox(
          todos: todos,
          width: todoWidth,
          height: boxSize,
          dark: dark,
          onAdd: onAdd,
          onComplete: onComplete,
        ),
        const SizedBox(width: 8),
        _AlarmActionChip(size: boxSize, dark: dark),
      ],
    );
  }
}

class _TodoActionBox extends StatelessWidget {
  const _TodoActionBox({
    required this.todos,
    required this.width,
    required this.height,
    required this.dark,
    required this.onAdd,
    required this.onComplete,
  });

  final List<_TimedTodo> todos;
  final double width;
  final double height;
  final bool dark;
  final VoidCallback? onAdd;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final open = todos.where((todo) => !todo.done).toList();
    final visible = <_TimedTodo>[
      ...open,
      ...todos.where((todo) => todo.done),
    ].take(3).toList();
    final bg = dark ? Colors.white.withOpacity(0.10) : Colors.white;
    final border = dark ? Colors.white.withOpacity(0.20) : AppColors.outline;
    final muted = dark ? Colors.white.withOpacity(0.72) : AppColors.textMuted;
    final strong = dark ? Colors.white : const Color(0xFF1D2736);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.fromLTRB(9, 7, 7, 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 0.9),
          ),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                right: 22,
                child: todos.isEmpty
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'No tasks',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: muted,
                          ),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          for (final todo in visible)
                            Text(
                              todo.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
                                height: 1.15,
                                fontWeight: FontWeight.w700,
                                color: todo.done ? muted : strong,
                                decoration: todo.done
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          if (todos.length > visible.length)
                            Text(
                              '+${todos.length - visible.length} more',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: muted,
                              ),
                            ),
                        ],
                      ),
              ),
              if (onAdd != null)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: dark ? Colors.white : AppColors.primary,
                  ),
                ),
              if (open.isNotEmpty)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: InkWell(
                    onTap: onComplete,
                    borderRadius: BorderRadius.circular(8),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 17,
                      color: dark ? Colors.white : AppColors.energyBrainAccent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlarmActionChip extends StatelessWidget {
  const _AlarmActionChip({required this.size, required this.dark});

  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = dark ? Colors.white : AppColors.secondary;
    final bg = dark ? Colors.white.withOpacity(0.10) : AppColors.softAccent;
    final border = dark
        ? Colors.white.withOpacity(0.18)
        : AppColors.secondary.withOpacity(0.24);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 0.9),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.alarm_add_rounded, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            'Alarm',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionDoneButton extends StatefulWidget {
  const _SessionDoneButton({
    required this.done,
    required this.onTap,
    this.dark = false,
    this.size = 50,
  });

  final bool done;
  final bool dark;
  final double size;
  final VoidCallback onTap;

  @override
  State<_SessionDoneButton> createState() => _SessionDoneButtonState();
}

class _SessionDoneButtonState extends State<_SessionDoneButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pop;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _pop = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    if (widget.done) _controller.value = 1;
  }

  @override
  void didUpdateWidget(covariant _SessionDoneButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.done == widget.done) return;
    if (widget.done) {
      _controller.forward(from: 0);
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF00B386);
    final idleColor =
        widget.dark ? Colors.white.withOpacity(0.30) : AppColors.outline;
    final idleIcon =
        widget.dark ? Colors.white.withOpacity(0.82) : AppColors.textMuted;

    return Semantics(
      button: true,
      selected: widget.done,
      label: widget.done ? 'Mark session not done' : 'Mark session done',
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.done
                ? activeColor
                : (widget.dark ? Colors.white.withOpacity(0.08) : Colors.white),
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.done ? activeColor : idleColor,
              width: widget.done ? 0 : 1.3,
            ),
            boxShadow: widget.done
                ? <BoxShadow>[
                    BoxShadow(
                      color: activeColor.withOpacity(0.32),
                      blurRadius: 16,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: ScaleTransition(
            scale: widget.done ? _pop : const AlwaysStoppedAnimation<double>(1),
            child: Icon(
              Icons.check_rounded,
              size: widget.size * 0.54,
              color: widget.done ? Colors.white : idleIcon,
            ),
          ),
        ),
      ),
    );
  }
}

class _NowBadge extends StatelessWidget {
  const _NowBadge({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: compact ? 5 : 6,
            height: compact ? 5 : 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: compact ? 4 : 5),
          Text(
            'NOW',
            style: TextStyle(
              fontSize: compact ? 8 : 9,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeRangeBadge extends StatelessWidget {
  const _TimeRangeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceTint.withOpacity(0.78),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: colors.outline.withOpacity(0.62),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: colors.primary,
        ),
      ),
    );
  }
}

/// Themed bookend for the planner list — the "wake up" card at the top and
/// the "going to sleep" card at the bottom. Same footprint as a regular
/// planner card but with an SVG illustration and its own palette.
enum _WakeSleepVariant { wake, sleep }

class _WakeSleepCard extends StatelessWidget {
  const _WakeSleepCard({
    required this.content,
    required this.variant,
    required this.assetPath,
    required this.height,
    required this.todos,
    required this.onAddTodo,
    required this.onToggleTodo,
    required this.onCompleteTodos,
    required this.sessionDone,
    required this.onToggleSessionDone,
    this.isCurrent = false,
    this.allowAddTodo = true,
  });

  final WakeSleepCopy content;
  final _WakeSleepVariant variant;
  final String assetPath;
  final double height;
  final List<_TimedTodo> todos;
  final VoidCallback onAddTodo;
  final ValueChanged<String> onToggleTodo;
  final ValueChanged<Iterable<_TimedTodo>> onCompleteTodos;
  final bool sessionDone;
  final VoidCallback onToggleSessionDone;
  final bool isCurrent;
  final bool allowAddTodo;

  bool get _isWake => variant == _WakeSleepVariant.wake;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Dawn: warm sunrise wash. Night: cool moonlit indigo.
    final gradientColors = dark
        ? <Color>[
            colors.surface,
            _isWake
                ? colors.primary.withOpacity(0.16)
                : AppColors.bedtimeAccent.withOpacity(0.18),
          ]
        : (_isWake
            ? const <Color>[Colors.white, Color(0xFFF3FFF7)]
            : const <Color>[Colors.white, Color(0xFFF7F5FF)]);
    final foreground = colors.onSurface;
    final subFg = colors.onSurface.withOpacity(0.62);
    final tipBg = dark
        ? colors.surfaceTint.withOpacity(0.78)
        : (_isWake ? AppColors.softAccent : AppColors.bedtimeBg);
    final tipBorder = (_isWake ? AppColors.primary : AppColors.bedtimeAccent)
        .withOpacity(0.2);
    final titleFg = _isWake ? AppColors.primary : AppColors.bedtimeAccent;

    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: _isWake ? Alignment.topLeft : Alignment.bottomLeft,
          end: _isWake ? Alignment.bottomRight : Alignment.topRight,
          colors: gradientColors,
        ),
        border: Border.all(
          color: isCurrent
              ? titleFg.withOpacity(0.34)
              : colors.outline.withOpacity(0.72),
          width: isCurrent ? 1.2 : 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(
              dark ? (isCurrent ? 0.34 : 0.22) : (isCurrent ? 0.055 : 0.035),
            ),
            blurRadius: isCurrent ? 18 : 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: 62,
            bottom: 18,
            child: IgnorePointer(
              child: Opacity(
                opacity: isCurrent ? 0.92 : 0.72,
                child: SvgPicture.asset(
                  assetPath,
                  width: isCurrent ? 88 : 72,
                  height: isCurrent ? 118 : 96,
                  fit: BoxFit.contain,
                  placeholderBuilder: (context) => SizedBox(
                    width: isCurrent ? 88 : 72,
                    height: isCurrent ? 118 : 96,
                    child: Center(
                      child: Icon(
                        _isWake
                            ? Icons.wb_sunny_rounded
                            : Icons.bedtime_rounded,
                        size: 40,
                        color: foreground.withOpacity(0.7),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: _SessionDoneButton(
                done: sessionDone,
                onTap: onToggleSessionDone,
                dark: dark,
                size: 52,
              ),
            ),
          ),
          Positioned.fill(
            right: 68,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      content.title.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: titleFg,
                      ),
                    ),
                    if (isCurrent) ...<Widget>[
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _isWake
                              ? const Color(0xFFB86A00)
                              : const Color(0xFFB5B8FF),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'NOW',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: _isWake
                              ? const Color(0xFFB86A00)
                              : const Color(0xFFB5B8FF),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '“${content.headline}”',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.28,
                    fontFamily: 'Georgia',
                    fontFamilyFallback: const <String>['serif'],
                    fontWeight: FontWeight.w500,
                    color: foreground.withOpacity(0.9),
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content.sub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: subFg,
                    height: 1.3,
                  ),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: _SessionTodoPanel(
                    todos: todos,
                    compact: !isCurrent,
                    dark: dark,
                    onAdd: allowAddTodo ? onAddTodo : null,
                    onToggle: onToggleTodo,
                    onComplete: () => onCompleteTodos(
                      todos.where((todo) => !todo.done),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tipBg,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: tipBorder, width: 0.8),
                  ),
                  child: Text(
                    content.tip,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: foreground.withOpacity(0.88),
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
}

/// Trigger button + custom overlay dropdown for the PLANNER header.
/// Always opens below the button, 2-column grid, no PRO badge.
class ModeDropdown extends StatefulWidget {
  const ModeDropdown(
      {super.key, required this.modeId, required this.onChanged});

  final String modeId;
  final ValueChanged<String> onChanged;

  @override
  State<ModeDropdown> createState() => _ModeDropdownState();
}

class _ModeDropdownState extends State<ModeDropdown> {
  OverlayEntry? _entry;

  bool get _isOpen => _entry != null;

  void _toggle() => _isOpen ? _close() : _open();

  void _open() {
    final box = context.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;

    _entry = OverlayEntry(builder: (ctx) {
      final screenWidth = MediaQuery.of(ctx).size.width;
      // Right-align panel with button's right edge, clamp to screen.
      const panelWidth = 230.0;
      final right = screenWidth - pos.dx - size.width;

      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _close,
          ),
          Positioned(
            top: pos.dy + size.height + 6,
            right: right,
            width: panelWidth,
            child: _ModePanel(
              modeId: widget.modeId,
              onSelect: (id) {
                _close();
                if (CustomModeStore.isCustomModeId(id)) {
                  _openCustomPlanner();
                } else {
                  widget.onChanged(id);
                }
              },
            ),
          ),
        ],
      );
    });

    Overlay.of(context).insert(_entry!);
    setState(() {});
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  /// Push Services page with the Daily Planner auto-opened on top. When the
  /// user pops the planner they land on the Services listing, not back on
  /// the home tab.
  Future<void> _openCustomPlanner() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ServicesPage(autoOpenServiceId: 'daily_planner'),
      ),
    );
    // The DailyPlannerPage flips the mode to `custom` on save; make sure
    // the parent picks that up regardless of how they got back.
    if (mounted) widget.onChanged(ProfileStore.instance.plannerMode.value);
  }

  @override
  void dispose() {
    _entry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final modes = allSelectableDayModes;
    final selected = modes.firstWhere(
      (m) => m.id == widget.modeId,
      orElse: () => modes.first,
    );

    return GestureDetector(
      onTap: _toggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: colors.primary.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colors.primary.withOpacity(0.34),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '${selected.emoji} ${selected.label}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: colors.primary,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(width: 2),
            AnimatedRotation(
              turns: _isOpen ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 13,
                color: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The floating 2-column panel shown by [_ModeDropdown].
class _ModePanel extends StatelessWidget {
  const _ModePanel({required this.modeId, required this.onSelect});

  final String modeId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const cols = 2;
    final modes = allSelectableDayModes;
    final rows = (modes.length / cols).ceil();

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.outline.withOpacity(0.5),
            width: 0.8,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(
                Theme.of(context).brightness == Brightness.dark ? 0.34 : 0.11,
              ),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(rows, (row) {
            return Row(
              children: List.generate(cols, (col) {
                final i = row * cols + col;
                if (i >= modes.length) {
                  return const Expanded(child: SizedBox());
                }
                final m = modes[i];
                final selected = m.id == modeId;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onSelect(m.id),
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? colors.primary.withOpacity(0.14)
                            : colors.surfaceTint.withOpacity(0.62),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? colors.primary.withOpacity(0.48)
                              : colors.outline.withOpacity(0.38),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '${m.emoji} ${m.label}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? colors.primary
                              : colors.onSurface.withOpacity(0.62),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ),
      ),
    );
  }
}
