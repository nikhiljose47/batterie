import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

import '../../constants/app_colors.dart';
import '../../constants/avatar_constants.dart';
import '../../constants/daily_score_rules.dart';
import '../../data/world_today/world_today_repository.dart';
import '../../models/energy_log_record.dart';
import '../../models/planner_session_log.dart';
import '../../models/weather.dart';
import '../../shared/widgets/profile_avatar.dart';
import '../../services/custom_mode_store.dart';
import '../../services/daily_progress_sync_service.dart';
import '../../services/energy_log_store.dart';
import '../../services/escore_reset_service.dart';
import '../../services/google_calendar_service.dart';
import '../../services/remote_sync.dart';
import '../compare/compare_page.dart';
import '../profile/profile_bloc.dart';
import '../profile/profile_store.dart';
import '../services/data/service_catalog.dart';
import '../services/services_page.dart';
import '../services/tools/change_goal_page.dart';
import '../services/tools/toolkit.dart';
import '../weather/weather_controller.dart';
import 'bloc/home_schedule_bloc.dart';
import 'data/mode_advice.dart';
import 'widgets/planner_section.dart';

/// Fresh home tab: unified, color-coded day tube showing energy flow from
/// wake (soft morning green) through warm noon through evening dusk to sleep (night).
class HomeTabPage extends StatefulWidget {
  const HomeTabPage({
    super.key,
    this.weatherController,
    this.refreshToken = 0,
    this.onEnergyScoreChanged,
  });

  /// Optional shared controller (e.g. owned by the top bar's location
  /// button). When null the tab owns its own.
  final WeatherController? weatherController;
  final int refreshToken;
  final ValueChanged<int>? onEnergyScoreChanged;

  @override
  State<HomeTabPage> createState() => _HomeTabPageState();
}

class _HomeTabPageState extends State<HomeTabPage> with WidgetsBindingObserver {
  static bool _cachedGoogleSignedIn = false;
  static List<GoogleCalendarEvent> _cachedUpcomingGoogleItems =
      const <GoogleCalendarEvent>[];

  late String _modeId;
  late final HomeScheduleBloc _scheduleBloc;
  late final WeatherController _weatherController;
  late final bool _ownsWeatherController;
  final GlobalKey<PlannerSectionState> _plannerKey =
      GlobalKey<PlannerSectionState>();
  List<PlannerSessionLog> _sessionLogs = const <PlannerSessionLog>[];
  int _plannerRefreshToken = 0;
  bool _showCalendarTimeline = false;
  bool _showCurrentOnlyPlanner = false;
  bool _calendarLoading = false;
  int _todayTodoCount = 0;
  int _todayAppUseMinutes = 0;
  int _storedAppUseMinutes = 0;
  int _todayFocusMinutes = 0;
  int _todayServiceActionCount = 0;
  int _todayPlanDoneCount = 0;
  int _todayPlanTotalCount = kSlotCount;
  int _dayStreak = 0;
  List<DailyProgressRecord> _goalPeerProgress = const <DailyProgressRecord>[];
  DateTime? _escoreResetAfter;
  _BodyMetrics? _bodyMetrics;
  bool _googleUpcomingLoading = false;
  bool _googleUpcomingSyncing = false;
  bool _googleSignedIn = _cachedGoogleSignedIn;
  List<GoogleCalendarEvent> _calendarEvents = const <GoogleCalendarEvent>[];
  List<GoogleCalendarEvent> _upcomingGoogleItems = _cachedUpcomingGoogleItems;
  final WorldTodayRepository _worldTodayRepository =
      const WorldTodayRepository();
  Timer? _appUseTimer;
  Timer? _googleUpcomingSyncTimer;
  DateTime _appUseSessionStartedAt = DateTime.now();
  int _googleUpcomingSyncDelayMinutes = 1;
  static const String _todoKey = 'svc.todo.items';
  static const String _bodyMetricsKey = 'svc.body.metrics';
  static const String _focusSessionsKey = 'svc.focus.sessions';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _modeId = ProfileStore.instance.plannerMode.value;
    _scheduleBloc = HomeScheduleBloc();
    _ownsWeatherController = widget.weatherController == null;
    _weatherController = widget.weatherController ?? WeatherController();
    if (_ownsWeatherController) _weatherController.load();
    _refreshHome();
    _startGoogleUpcomingBackoff();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshHome();
    });
  }

  @override
  void didUpdateWidget(covariant HomeTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _refreshHome();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appUseTimer?.cancel();
    _googleUpcomingSyncTimer?.cancel();
    _scheduleBloc.close();
    if (_ownsWeatherController) _weatherController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(
        DailyProgressSyncService.instance.saveTodayAppUseMinutes(
          _todayAppUseMinutes,
        ),
      );
      unawaited(DailyProgressSyncService.instance.syncToday());
      _appUseTimer?.cancel();
      _appUseTimer = null;
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    _appUseSessionStartedAt = DateTime.now();
    _syncAppUseTimer();
    _refreshHome();
  }

  void _refreshHome() {
    _scheduleBloc.add(const HomeScheduleStarted());
    _weatherController.load();
    _loadHomeInfo();
  }

  void _startGoogleUpcomingBackoff() {
    _googleUpcomingSyncTimer?.cancel();
    _googleUpcomingSyncDelayMinutes = 1;
    _scheduleGoogleUpcomingSync(Duration.zero);
  }

  void _scheduleGoogleUpcomingSync(Duration delay) {
    _googleUpcomingSyncTimer = Timer(delay, () async {
      await _loadGoogleUpcoming();
      if (!mounted) return;
      final nextDelay = _googleUpcomingSyncDelayMinutes;
      _googleUpcomingSyncDelayMinutes =
          math.min(_googleUpcomingSyncDelayMinutes * 2, 60);
      _scheduleGoogleUpcomingSync(Duration(minutes: nextDelay));
    });
  }

  Future<void> _manualRefreshGoogleUpcoming() async {
    _googleUpcomingSyncDelayMinutes = 1;
    await _loadGoogleUpcoming(showLoading: true);
  }

  int get _liveAppUseMinutes {
    final liveMinutes = DateTime.now()
        .difference(_appUseSessionStartedAt)
        .inMinutes
        .clamp(0, 1440);
    return math.min(_storedAppUseMinutes + liveMinutes, 1440);
  }

  void _syncAppUseTimer() {
    _appUseTimer?.cancel();
    _appUseTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      final next = _liveAppUseMinutes;
      if (next != _todayAppUseMinutes) {
        setState(() {
          _todayAppUseMinutes = next;
          if (next > 0 && _dayStreak == 0) _dayStreak = 1;
        });
        _notifyEnergyScore();
        unawaited(
          DailyProgressSyncService.instance.saveTodayAppUseMinutes(next),
        );
      }
    });
  }

  Future<void> _openDayCardEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ServicesPage(
          filteredServiceIds: <String>[
            'daily_planner',
            'sleep_tracker',
            'todo',
            'alarms',
          ],
          filterTitle: 'Day card tools',
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _modeId = ProfileStore.instance.plannerMode.value;
      _plannerRefreshToken++;
    });
    _scheduleBloc.add(const HomeScheduleStarted());
    await _loadHomeInfo();
  }

  static const List<String> _weekdayAbbr = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const List<String> _monthAbbr = <String>[
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

  /// e.g. "Fri, 24 Jul 2026" — the weekday, date, and year for the header.
  String get _todayLabel {
    final n = DateTime.now();
    return '${_weekdayAbbr[n.weekday - 1]}, '
        '${n.day} ${_monthAbbr[n.month - 1]} ${n.year}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HomeScheduleBloc>.value(
      value: _scheduleBloc,
      child: BlocListener<ProfileBloc, ProfileState>(
        listenWhen: (previous, current) =>
            previous.plannerMode != current.plannerMode,
        listener: (context, profile) {
          if (!mounted || _modeId == profile.plannerMode) return;
          setState(() {
            _modeId = profile.plannerMode;
            _plannerRefreshToken++;
          });
        },
        child: BlocBuilder<HomeScheduleBloc, HomeScheduleState>(
          builder: (context, schedule) {
            // Fixed day card at the top; only the planner list below scrolls.
            return Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildDayCard(context, schedule),
                  const SizedBox(height: 18),
                  _HomeSectionTitle(
                    title: 'Quick actions',
                    action: _HomeTitleAction(
                      icon: Icons.apps_rounded,
                      label: 'More',
                      onTap: _openServicesHub,
                    ),
                  ),
                  const SizedBox(height: 7),
                  _HomeShortcutSection(
                    services: _homeShortcutServices,
                    onTodo: _openTodoService,
                    onService: _openServiceShortcut,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _NowUpcomingSection(
                      current: _currentPlanData(schedule),
                      upcoming: _upcomingGoogleItems,
                      googleSignedIn: _googleSignedIn,
                      loading: _googleUpcomingLoading,
                      onConnect: _connectGoogleCalendar,
                      onRefresh: _manualRefreshGoogleUpcoming,
                      onChangeGoal: _openChangeGoal,
                      onTrackGoal: _openModeCompare,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _DidYouKnowTodayCard(
                    facts: _worldTodayRepository.factsFor(DateTime.now()),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _onSessionLogsChanged(List<PlannerSessionLog> logs) {
    if (!mounted) return;
    setState(() => _sessionLogs = logs);
  }

  _CurrentPlanData _currentPlanData(HomeScheduleState schedule) {
    final now = schedule.nowMinutes.floor();
    final mode = allSelectableDayModes.firstWhere(
      (mode) => mode.id == _modeId,
      orElse: () => allSelectableDayModes.first,
    );
    final phases = dayPhasesForMode(
      _modeId,
      wakeMinutes: schedule.wakeMinutes,
      sleepMinutes: schedule.sleepMinutes,
    );
    final slots = phases.map((phase) => phase.slot).toList(growable: false);
    final currentIndex = slots.indexWhere((slot) => slot.contains(now));

    final adviceList = adviceForMode(_modeId);
    final safeIndex = currentIndex == -1
        ? adviceList.length - 1
        : currentIndex.clamp(0, adviceList.length - 1);
    final advice = adviceList[safeIndex];
    final phase = currentIndex == -1 ? phases.last : phases[currentIndex];
    final slot = phase.slot;
    return _CurrentPlanData(
      sourceLabel: mode.shortLabel,
      range: slot.rangeLabel,
      suggestion: _modeSuggestion(mode, advice),
      cue: _modeCue(advice),
      rhythmNote: '${phase.label} · ${phase.foundationLabel}',
      accent: AppColors.primary,
      peerProgress: _goalPeerProgress,
    );
  }

  String _modeSuggestion(DayMode mode, ModeAdvice advice) {
    final label = mode.shortLabel.toLowerCase();
    final base = advice.tip.trim().isNotEmpty
        ? advice.tip.trim()
        : advice.recommendation.trim();
    if (base.isEmpty) {
      return 'Now, finish one useful thing in this block.';
    }
    return 'Now, $base';
  }

  String _modeCue(ModeAdvice advice) {
    final source = advice.tip.trim().isNotEmpty
        ? advice.tip.trim()
        : advice.recommendation.trim();
    final words = source
        .replaceAll(RegExp(r'[^\w\s-]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .take(4)
        .toList(growable: false);
    if (words.isEmpty) return 'Start now';
    if (words.length == 1) return '${words.first} now';
    return words.join(' ');
  }

  Future<void> _loadGoogleUpcoming({bool showLoading = false}) async {
    if (_googleUpcomingSyncing) return;
    _googleUpcomingSyncing = true;
    if (showLoading) {
      setState(() => _googleUpcomingLoading = true);
    }
    try {
      final signedIn = await GoogleCalendarService.instance.isSignedIn();
      if (!mounted) return;
      if (!signedIn) {
        setState(() => _googleUpcomingLoading = false);
        return;
      }

      final items = await GoogleCalendarService.instance.todayItems();
      final upcoming = _upcomingGoogleItemsFor(items);
      if (!mounted) return;
      setState(() {
        _googleSignedIn = true;
        _upcomingGoogleItems = upcoming;
        _googleUpcomingLoading = false;
      });
      _cachedGoogleSignedIn = true;
      _cachedUpcomingGoogleItems = upcoming;
    } catch (_) {
      if (!mounted) return;
      setState(() => _googleUpcomingLoading = false);
    } finally {
      _googleUpcomingSyncing = false;
    }
  }

  List<GoogleCalendarEvent> _upcomingGoogleItemsFor(
    List<GoogleCalendarEvent> items,
  ) {
    final now = DateTime.now();
    return items.where((item) {
      if (item.isCompleted) return false;
      final start = item.start;
      final end = item.end;
      if (start == null) return true;
      if (start.isAfter(now) || start.isAtSameMomentAs(now)) return true;
      return end != null && end.isAfter(now);
    }).toList(growable: false);
  }

  Future<void> _connectGoogleCalendar() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await GoogleCalendarService.instance.signIn();
      await _manualRefreshGoogleUpcoming();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Google Calendar sign-in failed: $error')),
      );
    }
  }

  Future<void> _loadHomeInfo() async {
    try {
      final today = DateTime.now();
      await DailyProgressSyncService.instance.saveTodayAppUseMinutes(
        _liveAppUseMinutes,
      );
      final userId = ProfileStore.instance.userId.value;
      final store = SqliteEnergyLogStore.instance;
      await store.claimEnergyLogsForUser(userId);
      final records = await store.recordsForDate(
        dateKey(today),
        userId: userId,
      );
      final plannerLogs = await store.plannerSessionLogsForDate(
        dateKey(today),
        userId: userId,
      );
      final planTotal = plannerSlotsForMode(
        _modeId,
        wakeMinutes: _scheduleBloc.state.wakeMinutes,
        sleepMinutes: _scheduleBloc.state.sleepMinutes,
      ).length;
      final todos = await ServiceStore.loadList(_todoKey);
      final focusSessions = await ServiceStore.loadList(_focusSessionsKey);
      final bodyMetrics = await _loadBodyMetrics();
      final resetAfter = await EscoreResetService.instance.appliedResetAfter();
      final cachedCommunityProgress =
          await DailyProgressSyncService.instance.cachedProgress();
      final todayKey = dateKey(today);
      final currentUserId = ProfileStore.instance.userId.value;
      final activeRecords = records.where((record) {
        return EscoreResetService.instance.isAfterAppliedReset(
          date: record.date,
          startMinutes: record.startMinutes,
          resetAfter: resetAfter,
        );
      }).toList(growable: false);
      final activePlannerLogs = plannerLogs.where((log) {
        return EscoreResetService.instance.isAfterAppliedReset(
          date: log.date,
          startMinutes: log.startMinutes,
          resetAfter: resetAfter,
        );
      }).toList(growable: false);
      final todoCount = todos.where((todo) {
        final text = (todo['text'] as String?)?.trim() ?? '';
        final done = (todo['done'] as bool?) ?? false;
        final due = DateTime.tryParse((todo['due'] as String?) ?? '');
        return text.isNotEmpty &&
            !done &&
            due != null &&
            svcDay(due) == svcDay(today);
      }).length;
      if (!mounted) return;
      final storedAppUseMinutes =
          await DailyProgressSyncService.instance.appUseMinutesForDay(today);
      final todayFocusMinutes = _focusMinutesForToday(focusSessions, today);
      final todayHasActivity = storedAppUseMinutes > 0 ||
          activeRecords.isNotEmpty ||
          activePlannerLogs.isNotEmpty ||
          todayFocusMinutes > 0;
      final dayStreak = await _dayStreakFor(
        userId: userId,
        today: today,
        todayHasActivity: todayHasActivity,
      );
      if (!mounted) return;
      final goalPeerProgress = cachedCommunityProgress.where((record) {
        return record.dateKey == todayKey &&
            record.userId != currentUserId &&
            record.plannerMode == ProfileStore.instance.plannerMode.value &&
            record.goalDoneCount > 0;
      }).toList(growable: false)
        ..sort((a, b) => b.goalDoneCount.compareTo(a.goalDoneCount));
      _appUseSessionStartedAt = DateTime.now();
      setState(() {
        _todayTodoCount = todoCount;
        _storedAppUseMinutes = storedAppUseMinutes;
        _todayAppUseMinutes = storedAppUseMinutes;
        _todayFocusMinutes = todayFocusMinutes;
        _todayServiceActionCount = activeRecords.length;
        _todayPlanDoneCount =
            activePlannerLogs.where((log) => log.isDone).length;
        _todayPlanTotalCount = planTotal;
        _dayStreak = dayStreak;
        _goalPeerProgress = goalPeerProgress;
        _escoreResetAfter = resetAfter;
        _bodyMetrics = bodyMetrics;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _todayTodoCount = 0;
        _todayAppUseMinutes = 0;
        _storedAppUseMinutes = 0;
        _todayFocusMinutes = 0;
        _todayServiceActionCount = 0;
        _todayPlanDoneCount = 0;
        _todayPlanTotalCount = kSlotCount;
        _dayStreak = 0;
        _goalPeerProgress = const <DailyProgressRecord>[];
        _escoreResetAfter = null;
        _bodyMetrics = null;
      });
    }
    _syncAppUseTimer();
    _notifyEnergyScore();
    unawaited(
      DailyProgressSyncService.instance.saveTodayAppUseMinutes(
        _todayAppUseMinutes,
      ),
    );
    unawaited(DailyProgressSyncService.instance.syncToday());
  }

  int get _energyScorePercent {
    return DailyScoreRules.appUsePoints(_todayAppUseMinutes) +
        DailyScoreRules.serviceLogPoints(_todayServiceActionCount) +
        DailyScoreRules.dayTrackPoints(
          loggedCount: _sessionLogs.where((log) {
            return EscoreResetService.instance.isAfterAppliedReset(
              date: log.date,
              startMinutes: log.startMinutes,
              resetAfter: _escoreResetAfter,
            );
          }).length,
          totalCount: _todayPlanTotalCount,
        );
  }

  void _notifyEnergyScore() {
    widget.onEnergyScoreChanged?.call(_energyScorePercent);
  }

  int _focusMinutesForToday(
    List<Map<String, dynamic>> sessions,
    DateTime today,
  ) {
    return sessions.fold<int>(0, (sum, session) {
      final when = DateTime.tryParse((session['t'] as String?) ?? '');
      if (when == null || svcDay(when) != svcDay(today)) return sum;
      return sum + ((session['minutes'] as num?)?.round() ?? 0);
    });
  }

  Future<int> _dayStreakFor({
    required String userId,
    required DateTime today,
    required bool todayHasActivity,
  }) async {
    final activeDays =
        (await SqliteEnergyLogStore.instance.activityDates(userId: userId))
            .toSet();
    if (todayHasActivity) activeDays.add(dateKey(today));

    var streak = 0;
    var cursor = DateTime(today.year, today.month, today.day);
    while (activeDays.contains(dateKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
      if (streak >= 999) break;
    }
    return streak;
  }

  Future<_BodyMetrics?> _loadBodyMetrics() async {
    final map = await ServiceStore.loadMap(_bodyMetricsKey);
    final height = (map['heightCm'] as num?)?.toDouble();
    final weight = (map['weightKg'] as num?)?.toDouble();
    if (height == null || weight == null || height <= 0 || weight <= 0) {
      return null;
    }
    return _BodyMetrics(heightCm: height, weightKg: weight);
  }

  List<AppService> get _homeShortcutServices {
    const shortcutIds = <String>[
      'focus',
      'breathing',
      'air_quality',
    ];
    return <AppService>[
      for (final id in shortcutIds)
        if (serviceById(id) case final service?) service,
    ];
  }

  Future<void> _openModeCompare() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ComparePage()),
    );
    if (!mounted) return;
    await _loadHomeInfo();
  }

  Future<void> _openChangeGoal() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ChangeGoalPage()),
    );
    if (!mounted) return;
    setState(() => _modeId = ProfileStore.instance.plannerMode.value);
    await _loadHomeInfo();
  }

  Future<void> _openTodoService() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ServicesPage(
          autoOpenServiceId: 'todo',
          closeOnAutoOpenReturn: true,
        ),
      ),
    );
    if (!mounted) return;
    await _loadHomeInfo();
  }

  Future<void> _openSleepTrackerService() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ServicesPage(
          autoOpenServiceId: 'sleep_tracker',
          closeOnAutoOpenReturn: true,
        ),
      ),
    );
    if (!mounted) return;
    _scheduleBloc.add(const HomeScheduleStarted());
    await _loadHomeInfo();
  }

  Future<void> _openServicesHub() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ServicesPage()),
    );
    if (!mounted) return;
    await _loadHomeInfo();
  }

  Future<void> _openServiceShortcut(AppService service) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ServicesPage(
          autoOpenServiceId: service.id,
          closeOnAutoOpenReturn: true,
        ),
      ),
    );
    if (!mounted) return;
    await _loadHomeInfo();
  }

  void _showCurrentPlannerCard() {
    if (_showCalendarTimeline) {
      setState(() {
        _showCalendarTimeline = false;
        _showCurrentOnlyPlanner = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _plannerKey.currentState?.refreshGoogleCurrentItems();
      });
      return;
    }
    setState(() => _showCurrentOnlyPlanner = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _plannerKey.currentState?.refreshGoogleCurrentItems();
    });
  }

  Future<void> _openCurrentAddFlow() async {
    if (_showCalendarTimeline) {
      await _openGoogleCalendarAddSheet();
      return;
    }
    await _plannerKey.currentState?.openTodoForCurrentSession();
    await _loadHomeInfo();
  }

  void _showBestSummary() {
    _plannerKey.currentState?.showPastBestSummary(context);
  }

  void _showRainSummary() {
    _plannerKey.currentState?.showRainSummary(context);
  }

  Future<void> _openGoogleCalendarTimeline() async {
    setState(() {
      _showCalendarTimeline = true;
      _showCurrentOnlyPlanner = false;
    });
    await _refreshGoogleCalendarTimeline(showLoading: true);
  }

  Future<void> _refreshGoogleCalendarTimeline(
      {bool showLoading = false}) async {
    if (!_showCalendarTimeline && !showLoading) return;
    final messenger = ScaffoldMessenger.of(context);
    if (showLoading && mounted) {
      setState(() => _calendarLoading = true);
    }
    try {
      final events = await GoogleCalendarService.instance.todayItems();
      if (!mounted) return;
      setState(() {
        _calendarEvents = events;
        _calendarLoading = false;
      });
    } catch (error) {
      if (mounted) setState(() => _calendarLoading = false);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Google Calendar failed: $error')),
        );
      }
    }
  }

  Future<void> _moveGoogleCalendarItem(
    GoogleCalendarEvent event,
    DateTime start,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (event.id.isEmpty) return;
    final fallbackEnd = event.end ?? event.start?.add(const Duration(hours: 1));
    final duration =
        event.isAllDay || event.start == null || fallbackEnd == null
            ? const Duration(hours: 1)
            : fallbackEnd.difference(event.start!);
    final end = start
        .add(duration <= Duration.zero ? const Duration(hours: 1) : duration);

    setState(() {
      _calendarEvents = _calendarEvents
          .map((item) => identical(item, event) || item.id == event.id
              ? item.copyWith(start: start, end: end, isAllDay: false)
              : item)
          .toList();
    });

    try {
      if (event.isTask) {
        final taskListId = event.taskListId;
        if (taskListId == null) return;
        await GoogleCalendarService.instance.moveTask(
          taskListId: taskListId,
          id: event.id,
          due: start,
        );
      } else {
        await GoogleCalendarService.instance.moveEvent(
          id: event.id,
          start: start,
          end: end,
        );
      }
      await _refreshGoogleCalendarTimeline();
      await _plannerKey.currentState?.refreshGoogleCurrentItems();
      await _manualRefreshGoogleUpcoming();
    } catch (error) {
      await _refreshGoogleCalendarTimeline();
      await _plannerKey.currentState?.refreshGoogleCurrentItems();
      await _manualRefreshGoogleUpcoming();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Google move failed: $error')),
        );
      }
    }
  }

  Future<void> _openGoogleCalendarAddSheet([DateTime? initialStart]) async {
    final fallback = DateTime.now();
    final start = initialStart ??
        DateTime(
            fallback.year, fallback.month, fallback.day, fallback.hour + 1);
    final end = start.add(const Duration(hours: 1));

    final request = await showModalBottomSheet<_GoogleCalendarAddRequest>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _GoogleCalendarAddSheet(start: start, end: end),
    );
    if (request == null) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      if (request.type == _GoogleCalendarAddType.task) {
        await GoogleCalendarService.instance.createTask(
          title: request.title,
          due: start,
        );
      } else {
        await GoogleCalendarService.instance.createEvent(
          title: request.title,
          start: start,
          end: end,
        );
      }
      if (!mounted) return;
      await _refreshGoogleCalendarTimeline(showLoading: true);
      await _plannerKey.currentState?.refreshGoogleCurrentItems();
      await _loadHomeInfo();
      await _manualRefreshGoogleUpcoming();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Google add failed: $error')),
      );
    }
  }

  bool _isRainy(WeatherCondition c) =>
      c == WeatherCondition.rain ||
      c == WeatherCondition.drizzle ||
      c == WeatherCondition.showers ||
      c == WeatherCondition.thunderstorm ||
      c == WeatherCondition.freezingRain;

  String _rainSummary(WeatherSnapshot? weather) {
    if (weather == null) return 'Weather off';
    if (_isRainy(weather.current.condition))
      return '${_weatherLocation(weather)} now';

    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59);
    for (final hour in weather.hourly) {
      if (hour.time.isBefore(now) || hour.time.isAfter(todayEnd)) continue;
      final probability = hour.precipitationProbability;
      if (_isRainy(hour.condition) ||
          (probability != null && probability >= 70)) {
        return '${_weatherLocation(weather)} ${svcClock(hour.time)}';
      }
    }

    if (weather.daily.isNotEmpty) {
      final today = weather.daily.first;
      final probability = today.precipitationProbability;
      if (_isRainy(today.condition) ||
          (probability != null && probability >= 70)) {
        return probability == null
            ? '${_weatherLocation(weather)} today'
            : '${_weatherLocation(weather)} $probability%';
      }
    }

    return 'No rain / clear';
  }

  String _weatherLocation(WeatherSnapshot weather) {
    final place = weather.location.placeLabel?.split(',').first.trim();
    if (place != null && place.isNotEmpty) return place;
    return '${weather.location.latitude.toStringAsFixed(1)},${weather.location.longitude.toStringAsFixed(1)}';
  }

  Widget _buildDayCard(BuildContext context, HomeScheduleState schedule) {
    final colors = Theme.of(context).colorScheme;
    return _HomeSurfaceCard(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ValueListenableBuilder<String>(
            valueListenable: ProfileStore.instance.name,
            builder: (context, name, _) {
              return Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Hi, ${name.trim().isEmpty ? 'User' : name.trim()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _WakeEditAction(
                    label: timeOfDayLabel(schedule.wake),
                    onTap: _openSleepTrackerService,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                flex: 22,
                child: _DayCardClockToggle(
                  minutes: schedule.nowMinutes.floor(),
                  dateLabel: _todayLabel,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 78,
                child: SizedBox(
                  height: 72,
                  child: _DayTube(
                    nowMinutes: schedule.nowMinutes,
                    wakeMinutes: schedule.wakeMinutes,
                    sleepMinutes: schedule.sleepMinutes,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Divider(
            height: 1,
            thickness: 1,
            color: colors.outline.withOpacity(0.18),
          ),
          const SizedBox(height: 6),
          AnimatedBuilder(
            animation: _weatherController,
            builder: (context, _) {
              final mode = allSelectableDayModes.firstWhere(
                (mode) => mode.id == _modeId,
                orElse: () => allSelectableDayModes.first,
              );
              return _HomeInfoCard(
                goalLabel: mode.shortLabel,
                rainLabel: _rainSummary(
                  _weatherController.state.snapshot,
                ),
                weatherState: _weatherController.state,
                onEnableWeather: _weatherController.requestPermissionAndLoad,
                todoCount: _todayTodoCount,
                dayStreak: _dayStreak,
                focusMinutes: _todayFocusMinutes,
                planDoneCount: _todayPlanDoneCount,
                planTotalCount: _todayPlanTotalCount,
                bodyMetrics: _bodyMetrics,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HomeSectionTitle extends StatelessWidget {
  const _HomeSectionTitle({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1,
                fontWeight: FontWeight.w700,
                color: colors.onSurface.withOpacity(0.72),
              ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _HomeTitleAction extends StatelessWidget {
  const _HomeTitleAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: colors.primary),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WakeEditAction extends StatelessWidget {
  const _WakeEditAction({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withOpacity(0.42),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.outline.withOpacity(0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.wb_twilight_rounded,
              size: 12,
              color: colors.onSurface.withOpacity(0.52),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                height: 1,
                fontWeight: FontWeight.w700,
                color: colors.onSurface.withOpacity(0.66),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.edit_rounded,
              size: 11,
              color: colors.primary.withOpacity(0.72),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentPlanData {
  const _CurrentPlanData({
    required this.sourceLabel,
    required this.range,
    required this.suggestion,
    required this.cue,
    required this.rhythmNote,
    required this.accent,
    required this.peerProgress,
  });

  final String sourceLabel;
  final String range;
  final String suggestion;
  final String cue;
  final String rhythmNote;
  final Color accent;
  final List<DailyProgressRecord> peerProgress;
}

class _BodyMetrics {
  const _BodyMetrics({
    required this.heightCm,
    required this.weightKg,
  });

  final double heightCm;
  final double weightKg;

  double get bmi {
    final meters = heightCm / 100;
    return weightKg / (meters * meters);
  }
}

class _NowUpcomingSection extends StatelessWidget {
  const _NowUpcomingSection({
    required this.current,
    required this.upcoming,
    required this.googleSignedIn,
    required this.loading,
    required this.onConnect,
    required this.onRefresh,
    required this.onChangeGoal,
    required this.onTrackGoal,
  });

  final _CurrentPlanData current;
  final List<GoogleCalendarEvent> upcoming;
  final bool googleSignedIn;
  final bool loading;
  final VoidCallback onConnect;
  final VoidCallback onRefresh;
  final VoidCallback onChangeGoal;
  final VoidCallback onTrackGoal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _HomeSectionTitle(
          title: 'Goal',
          action: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _HomeTitleAction(
                icon: Icons.edit_note_rounded,
                label: 'Change',
                onTap: onChangeGoal,
              ),
              const SizedBox(width: 2),
              _HomeTitleAction(
                icon: Icons.flag_rounded,
                label: 'Track',
                onTap: onTrackGoal,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _DayScheduleList(
            current: current,
            events: upcoming,
            signedIn: googleSignedIn,
            loading: loading,
            onConnect: onConnect,
            onRefresh: onRefresh,
            onTrackGoal: onTrackGoal,
          ),
        ),
      ],
    );
  }
}

class _DayScheduleList extends StatelessWidget {
  const _DayScheduleList({
    required this.current,
    required this.events,
    required this.signedIn,
    required this.loading,
    required this.onConnect,
    required this.onRefresh,
    required this.onTrackGoal,
  });

  final _CurrentPlanData current;
  final List<GoogleCalendarEvent> events;
  final bool signedIn;
  final bool loading;
  final VoidCallback onConnect;
  final VoidCallback onRefresh;
  final VoidCallback onTrackGoal;

  String _eventTimeLabel(GoogleCalendarEvent item) {
    if (item.start == null) return 'Any time today';
    final end = item.end;
    if (end == null || end.isAtSameMomentAs(item.start!)) {
      return svcClock(item.start!);
    }
    return '${svcClock(item.start!)} - ${svcClock(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final showExistingCalendar = signedIn || events.isNotEmpty;
    final rows = <Widget>[
      _CurrentPlanCard(data: current, onTap: onTrackGoal),
      if (loading && events.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        )
      else if (!showExistingCalendar)
        _CalendarAgendaRow(
          icon: Icons.calendar_month_rounded,
          color: const Color(0xFF4285F4),
          child: _GoogleConnectPrompt(onConnect: onConnect),
        )
      else ...<Widget>[
        if (events.isEmpty)
          const _CalendarEmptyRow()
        else
          for (final event in events)
            _CalendarAgendaRow(
              icon: event.isTask
                  ? Icons.task_alt_rounded
                  : Icons.event_available_rounded,
              color: const Color(0xFF4285F4),
              child: _UpcomingCalendarListItem(
                event: event,
                timeLabel: _eventTimeLabel(event),
              ),
            ),
      ],
    ];

    return ListView.separated(
      padding: EdgeInsets.zero,
      physics: const BouncingScrollPhysics(),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => rows[index],
    );
  }
}

class _CalendarEmptyRow extends StatelessWidget {
  const _CalendarEmptyRow();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _CalendarAgendaRow(
      icon: Icons.calendar_month_rounded,
      color: const Color(0xFF4285F4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          'No upcoming Google Calendar items today.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            height: 1.22,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w700,
            color: colors.onSurface.withOpacity(0.58),
          ),
        ),
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.data, required this.onTap});

  final _CurrentPlanData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _CalendarAgendaRow(
      icon: Icons.flag_circle_rounded,
      color: data.accent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.fromLTRB(13, 20, 13, 19),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                colors.surface,
                data.accent.withOpacity(dark ? 0.18 : 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: data.accent.withOpacity(0.34), width: 1),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: data.accent.withOpacity(dark ? 0.16 : 0.10),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: data.accent.withOpacity(dark ? 0.22 : 0.14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      Icons.track_changes_rounded,
                      size: 18,
                      color: data.accent,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      data.sourceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface.withOpacity(0.62),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _CalendarTimeLabel(data.range),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                data.suggestion,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16.2,
                  height: 1.18,
                  fontFamily: 'Kalam',
                  fontFamilyFallback: const <String>['Inter'],
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface.withOpacity(0.92),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      data.rhythmNote,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface.withOpacity(0.45),
                        fontSize: 10.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _GoalFriendDoneBadge(
                    peers: data.peerProgress,
                    color: data.accent,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalFriendDoneBadge extends StatelessWidget {
  const _GoalFriendDoneBadge({required this.peers, required this.color});

  final List<DailyProgressRecord> peers;
  final Color color;

  String get _label {
    if (peers.isEmpty) return 'Solo today';
    final firstName = _firstUsefulPeerName(peers) ?? 'Friend';
    final extra = peers.length - 1;
    if (extra <= 0) return '$firstName done';
    if (extra == 1) return '$firstName + 1';
    if (extra < 9) return '$firstName + others';
    if (extra < 99) return '$firstName + 9+';
    return '$firstName + 99+';
  }

  String? _firstUsefulPeerName(List<DailyProgressRecord> records) {
    const ignored = <String>{'alf', 'friend', 'someone', 'user', 'you'};
    for (final record in records) {
      final name = record.displayName.trim();
      if (name.isEmpty) continue;
      final first = name.split(RegExp(r'\s+')).first;
      if (first.length < 3 || ignored.contains(first.toLowerCase())) continue;
      return first;
    }
    return null;
  }

  int get _avatarCount => peers.isEmpty ? 1 : math.min(2, peers.length);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const avatarSize = 18.0;
    const overlap = 10.0;
    return Container(
      constraints: const BoxConstraints(maxWidth: 128),
      padding: const EdgeInsets.fromLTRB(5, 4, 8, 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: avatarSize + (_avatarCount - 1) * overlap,
            height: avatarSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                for (var i = 0; i < _avatarCount; i++)
                  Positioned(
                    left: i * overlap,
                    child: Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: colors.shadow.withOpacity(0.08),
                            blurRadius: 5,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      foregroundDecoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.surface, width: 1.5),
                      ),
                      child: ClipOval(
                        child: Transform.scale(
                          scale: 1.18,
                          child: SvgPicture.asset(
                            AvatarConstants.assetPath(
                              AvatarConstants
                                  .avatars[i % AvatarConstants.avatars.length],
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.8,
                height: 1,
                fontWeight: FontWeight.w800,
                color: colors.onSurface.withOpacity(0.68),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarAgendaRow extends StatelessWidget {
  const _CalendarAgendaRow({
    required this.icon,
    required this.color,
    required this.child,
  });

  final IconData icon;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 20,
          child: Column(
            children: <Widget>[
              Container(
                width: 19,
                height: 19,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.22)),
                ),
                child: Icon(icon, size: 11, color: color),
              ),
              Container(
                width: 1,
                height: 54,
                color: colors.outline.withOpacity(0.18),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }
}

class _CalendarSourceRow extends StatelessWidget {
  const _CalendarSourceRow({
    required this.source,
    required this.child,
  });

  final Widget source;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        source,
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }
}

class _CalendarSourceBadge extends StatelessWidget {
  const _CalendarSourceBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 54,
      height: 58,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: colors.outline.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 17, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              height: 1,
              fontWeight: FontWeight.w700,
              color: colors.onSurface.withOpacity(0.66),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarTimeLabel extends StatelessWidget {
  const _CalendarTimeLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      _compactTimeRange(label),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.56),
      ),
    );
  }
}

String _compactTimeRange(String value) {
  final normalized = value
      .replaceAll('AM', 'am')
      .replaceAll('PM', 'pm')
      .replaceAll('–', '-')
      .replaceAll(':00 ', ' ');
  final parts = normalized.split(RegExp(r'\s+-\s+'));
  if (parts.length == 2) {
    for (final period in const <String>[' am', ' pm']) {
      if (parts[0].endsWith(period) && parts[1].endsWith(period)) {
        return '${parts[0].substring(0, parts[0].length - period.length)} - ${parts[1]}';
      }
    }
  }
  return normalized;
}

class _UpcomingCalendarCard extends StatelessWidget {
  const _UpcomingCalendarCard({
    required this.events,
    required this.signedIn,
    required this.loading,
    required this.onConnect,
    required this.onRefresh,
  });

  final List<GoogleCalendarEvent> events;
  final bool signedIn;
  final bool loading;
  final VoidCallback onConnect;
  final VoidCallback onRefresh;

  String _eventTimeLabel(GoogleCalendarEvent item) {
    if (item.start == null) return 'Any time today';
    final end = item.end;
    if (end == null || end.isAtSameMomentAs(item.start!)) {
      return svcClock(item.start!);
    }
    return '${svcClock(item.start!)} - ${svcClock(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _CalendarSourceRow(
      source: const _CalendarSourceBadge(
        icon: Icons.calendar_month_rounded,
        label: 'Google',
        color: Color(0xFF4285F4),
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withOpacity(0.42),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (loading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (!signedIn) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: _GoogleConnectPrompt(onConnect: onConnect),
      );
    }

    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'No upcoming Google Calendar items today.',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            height: 1.22,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w700,
            color: colors.onSurface.withOpacity(0.58),
          ),
        ),
      );
    }

    return Stack(
      children: <Widget>[
        ListView.separated(
          padding: const EdgeInsets.all(8),
          physics: const BouncingScrollPhysics(),
          itemCount: events.length,
          separatorBuilder: (_, __) => const SizedBox(height: 7),
          itemBuilder: (context, index) => _UpcomingCalendarListItem(
            event: events[index],
            timeLabel: _eventTimeLabel(events[index]),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: IconButton(
            tooltip: 'Refresh Google Calendar',
            visualDensity: VisualDensity.compact,
            onPressed: onRefresh,
            icon: Icon(
              Icons.refresh_rounded,
              size: 16,
              color: colors.onSurface.withOpacity(0.46),
            ),
          ),
        ),
      ],
    );
  }
}

class _GoogleConnectPrompt extends StatelessWidget {
  const _GoogleConnectPrompt({required this.onConnect});

  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onConnect,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.outline.withOpacity(0.16)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withOpacity(0.52),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'G',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4285F4),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'Sign in to show today\'s Google Calendar items.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.16,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface.withOpacity(0.7),
                ),
              ),
            ),
            Icon(Icons.login_rounded, size: 17, color: colors.primary),
          ],
        ),
      ),
    );
  }
}

class _UpcomingCalendarListItem extends StatelessWidget {
  const _UpcomingCalendarListItem({
    required this.event,
    required this.timeLabel,
  });

  final GoogleCalendarEvent event;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isTask = event.isTask;
    final background = isTask
        ? (dark ? const Color(0xFF5A2B36) : const Color(0xFFFFD2D0))
        : (dark ? const Color(0xFF613022) : const Color(0xFFFFC7B8));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
      decoration: BoxDecoration(
        color: background.withOpacity(dark ? 0.72 : 1),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withOpacity(dark ? 0.06 : 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            event.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              height: 1.05,
              fontFamily: 'Kalam',
              fontFamilyFallback: const <String>['Inter'],
              fontWeight: FontWeight.w400,
              color: dark ? Colors.white.withOpacity(0.88) : colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Icon(
                isTask ? Icons.task_alt_rounded : Icons.event_available_rounded,
                size: 12,
                color: (dark ? Colors.white : colors.onSurface).withOpacity(
                  0.52,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  _compactTimeRange(timeLabel),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w700,
                    color: (dark ? Colors.white : colors.onSurface).withOpacity(
                      0.58,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeInfoCard extends StatelessWidget {
  const _HomeInfoCard({
    required this.goalLabel,
    required this.rainLabel,
    required this.weatherState,
    required this.onEnableWeather,
    required this.todoCount,
    required this.dayStreak,
    required this.focusMinutes,
    required this.planDoneCount,
    required this.planTotalCount,
    required this.bodyMetrics,
  });

  final String goalLabel;
  final String rainLabel;
  final WeatherState weatherState;
  final VoidCallback onEnableWeather;
  final int todoCount;
  final int dayStreak;
  final int focusMinutes;
  final int planDoneCount;
  final int planTotalCount;
  final _BodyMetrics? bodyMetrics;

  bool get _expectsRain =>
      rainLabel != 'Weather off' &&
      rainLabel != 'Location off' &&
      rainLabel != 'No rain / clear' &&
      rainLabel != 'Checking...';

  bool get _needsWeatherAction =>
      weatherState.snapshot == null &&
      (weatherState.status == WeatherStatus.permissionDenied ||
          weatherState.status == WeatherStatus.permissionDeniedForever ||
          weatherState.status == WeatherStatus.serviceDisabled ||
          weatherState.status == WeatherStatus.error);

  bool get _weatherLoading =>
      weatherState.status == WeatherStatus.loading ||
      weatherState.status == WeatherStatus.refreshing;

  String get _weatherPlace {
    final snapshot = weatherState.snapshot;
    if (snapshot == null) return '';
    final place = snapshot.location.placeLabel?.split(',').first.trim();
    if (place != null && place.isNotEmpty) return place;
    return '${snapshot.location.latitude.toStringAsFixed(1)},${snapshot.location.longitude.toStringAsFixed(1)}';
  }

  String get _weatherTimeLabel {
    if (_weatherLoading) return 'Checking...';
    if (_needsWeatherAction) return 'Location off';
    if (rainLabel == 'Weather off' || rainLabel == 'No rain / clear') {
      return rainLabel;
    }
    final place = _weatherPlace;
    var text = place.isNotEmpty && rainLabel.startsWith(place)
        ? rainLabel.substring(place.length).trim()
        : rainLabel;
    if (text == 'now') return 'Now';
    if (text == 'today') return 'Today';
    if (text.endsWith('%')) return '$text chance';
    return text;
  }

  String get _regainValue {
    if (focusMinutes <= 0) return '0 min';
    if (focusMinutes < 60) return '$focusMinutes min';
    final hours = focusMinutes ~/ 60;
    final minutes = focusMinutes % 60;
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(2, 2, 2, 0),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline.withOpacity(0.72)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.shadow.withOpacity(0.035),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _HomeGoalInfoItem(
                  label: 'Goal: $goalLabel',
                  value:
                      '${math.min(planDoneCount, planTotalCount)}/$planTotalCount done',
                ),
              ),
              _InfoDivider(color: colors.outline),
              Expanded(
                child: _WeatherInfoItem(
                  icon: _expectsRain
                      ? Icons.water_drop_rounded
                      : Icons.wb_sunny_rounded,
                  value: _weatherLoading
                      ? 'Checking...'
                      : _needsWeatherAction
                          ? 'Location off'
                          : _weatherTimeLabel,
                  detail: _weatherPlace,
                  accent:
                      _expectsRain ? AppColors.info : const Color(0xFFE0A224),
                  onSync: _weatherLoading ? null : onEnableWeather,
                  loading: _weatherLoading,
                ),
              ),
              _InfoDivider(color: colors.outline),
              Expanded(
                child: _HomeInfoItem(
                  icon: Icons.task_alt_rounded,
                  label: 'Todos',
                  value: '$todoCount left',
                  accent: todoCount == 0 ? AppColors.primary : colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: _HomeInfoItem(
                  icon: Icons.monitor_weight_outlined,
                  label: 'BMI',
                  value: bodyMetrics == null
                      ? _blankInfoValue
                      : bodyMetrics!.bmi.toStringAsFixed(1),
                  accent: const Color(0xFF7B61FF),
                ),
              ),
              _InfoDivider(color: colors.outline),
              Expanded(
                child: _HomeInfoItem(
                  icon: Icons.local_fire_department_rounded,
                  label: 'Day streak',
                  value: '$dayStreak day${dayStreak == 1 ? '' : 's'}',
                  accent: const Color(0xFFE08A1E),
                ),
              ),
              _InfoDivider(color: colors.outline),
              Expanded(
                child: _HomeInfoItem(
                  icon: Icons.timer_outlined,
                  label: 'Regain',
                  value: _regainValue,
                  accent: AppColors.info,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const String _blankInfoValue = ' \n ';

class _InfoDivider extends StatelessWidget {
  const _InfoDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      color: color.withOpacity(0.24),
    );
  }
}

class _WeatherInfoItem extends StatelessWidget {
  const _WeatherInfoItem({
    required this.icon,
    required this.value,
    required this.detail,
    required this.accent,
    required this.loading,
    required this.onSync,
  });

  final IconData icon;
  final String value;
  final String detail;
  final Color accent;
  final bool loading;
  final VoidCallback? onSync;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 18,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 15, color: accent),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Expected rain',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurface.withOpacity(0.46),
                          fontSize: 9,
                          height: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 13,
                      height: 13,
                      child: ClipRect(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: loading ? null : onSync,
                          child: Icon(
                            Icons.sync_rounded,
                            size: 11,
                            color: loading
                                ? colors.onSurface.withOpacity(0.28)
                                : AppColors.info,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: <Widget>[
                    if (loading) ...<Widget>[
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurface.withOpacity(0.86),
                          fontSize: 10.5,
                          height: 1.08,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (detail.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    '($detail)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface.withOpacity(0.58),
                      fontSize: 8.5,
                      height: 1.05,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeInfoItem extends StatelessWidget {
  const _HomeInfoItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.actionLabel,
    this.onAction,
    this.onInfoTap,
    this.loading = false,
    this.valueLines = 2,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onInfoTap;
  final bool loading;
  final int valueLines;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 18,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 15, color: accent),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurface.withOpacity(0.46),
                          fontSize: 9,
                          height: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (onInfoTap != null)
                      SizedBox(
                        width: 13,
                        height: 13,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onInfoTap,
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 11,
                            color: colors.onSurface.withOpacity(0.45),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 5,
                  runSpacing: 2,
                  children: <Widget>[
                    if (loading)
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                    Text(
                      value,
                      maxLines: valueLines,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface.withOpacity(0.86),
                        fontSize: 10.5,
                        height: 1.08,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (actionLabel != null && onAction != null)
                      InkWell(
                        onTap: loading ? null : onAction,
                        borderRadius: BorderRadius.circular(999),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 1,
                          ),
                          child: Text(
                            actionLabel!,
                            maxLines: 1,
                            style: const TextStyle(
                              color: AppColors.info,
                              fontSize: 10,
                              height: 1,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeGoalInfoItem extends StatelessWidget {
  const _HomeGoalInfoItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(
            width: 18,
            child: Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.flag_rounded,
                size: 15,
                color: AppColors.success,
              ),
            ),
          ),
          const SizedBox(width: 6),
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
                    color: colors.onSurface.withOpacity(0.46),
                    fontSize: 9,
                    height: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface.withOpacity(0.86),
                    fontSize: 10.5,
                    height: 1.08,
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
}

class _HomeShortcutSection extends StatelessWidget {
  const _HomeShortcutSection({
    required this.services,
    required this.onTodo,
    required this.onService,
  });

  final List<AppService> services;
  final VoidCallback onTodo;
  final ValueChanged<AppService> onService;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tiles = <Widget>[
      _HomeShortcutTile(
        icon: Icons.task_alt_rounded,
        label: 'Todo',
        tint: AppColors.primary,
        onTap: onTodo,
      ),
      for (final service in services)
        _HomeShortcutTile(
          emoji: service.emoji,
          label: service.name,
          tint: colors.primary,
          onTap: () => onService(service),
        ),
    ].take(6).toList(growable: false);
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: tiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) => SizedBox(
          width: 106,
          child: tiles[index],
        ),
      ),
    );
  }
}

class _HomeShortcutTile extends StatelessWidget {
  const _HomeShortcutTile({
    required this.label,
    required this.tint,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.emoji,
  });

  final String label;
  final String? subtitle;
  final Color tint;
  final VoidCallback onTap;
  final IconData? icon;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outline.withOpacity(0.32)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tint.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: icon == null
                    ? Text(
                        emoji ?? '',
                        maxLines: 1,
                        style: const TextStyle(fontSize: 15, height: 1),
                      )
                    : Icon(icon, size: 17, color: tint),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      maxLines: subtitle == null ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface.withOpacity(0.88),
                        fontSize: 10.5,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurface.withOpacity(0.48),
                          fontSize: 9.5,
                          height: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DidYouKnowTodayCard extends StatefulWidget {
  const _DidYouKnowTodayCard({required this.facts});

  final List<String> facts;

  @override
  State<_DidYouKnowTodayCard> createState() => _DidYouKnowTodayCardState();
}

class _DidYouKnowTodayCardState extends State<_DidYouKnowTodayCard> {
  int _index = 0;

  void _showNext() {
    if (widget.facts.length < 2) return;
    setState(() => _index = (_index + 1) % widget.facts.length);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final facts = widget.facts.isEmpty ? const <String>[''] : widget.facts;
    final fact = facts[_index.clamp(0, facts.length - 1).toInt()];
    return InkWell(
      onTap: _showNext,
      child: Container(
        decoration: BoxDecoration(
          color: dark
              ? colors.surfaceContainerHighest.withOpacity(0.42)
              : const Color(0xFFF6F9FC),
          // borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: 1,
              //   margin: const EdgeInsets.symmetric(horizontal: 12),
              color: colors.outline.withOpacity(dark ? 0.16 : 0.26),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F7FE5).withOpacity(
                        dark ? 0.18 : 0.11,
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 16,
                      color: Color(0xFF4F7FE5),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'Did you know today?',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1,
                                  fontWeight: FontWeight.w700,
                                  color: colors.onSurface.withOpacity(0.88),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fact,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.18,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface.withOpacity(0.64),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.facts.length > 1) ...<Widget>[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.swap_horiz_rounded,
                      size: 17,
                      color: colors.onSurface.withOpacity(0.42),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCardClockToggle extends StatefulWidget {
  const _DayCardClockToggle({
    required this.minutes,
    required this.dateLabel,
  });

  final int minutes;
  final String dateLabel;

  @override
  State<_DayCardClockToggle> createState() => _DayCardClockToggleState();
}

class _DayCardClockToggleState extends State<_DayCardClockToggle> {
  bool _showDigital = false;

  String _digitalLabel() {
    final hour24 = (widget.minutes ~/ 60) % 24;
    final minute = widget.minutes % 60;
    final hour = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final suffix = hour24 < 12 ? 'AM' : 'PM';
    return '$hour:${minute.toString().padLeft(2, '0')} $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _showDigital = !_showDigital),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 84,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _showDigital
                ? const Color(0xFF1F2937)
                : colors.surfaceContainerHighest.withOpacity(0.45),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _showDigital
                  ? const Color(0xFF8FB8FF).withOpacity(0.42)
                  : colors.outline.withOpacity(0.22),
            ),
            boxShadow: _showDigital
                ? <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: Column(
              key: ValueKey<String>(_showDigital ? 'digital' : 'analog'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Center(
                    child: _showDigital
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.12),
                                ),
                              ),
                              child: Text(
                                _digitalLabel(),
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                  color: Color(0xFFEAF2FF),
                                ),
                              ),
                            ),
                          )
                        : CustomPaint(
                            size: const Size.square(48),
                            painter: _MiniAnalogClockPainter(
                              minutes: widget.minutes,
                              faceColor: colors.surface,
                              tickColor: colors.onSurface.withOpacity(0.42),
                              hourColor: colors.onSurface.withOpacity(0.82),
                              minuteColor: colors.primary,
                              accentColor: AppColors.primary,
                              shadowColor: Colors.black.withOpacity(0.08),
                            ),
                          ),
                  ),
                ),
                Text(
                  _shortDate(widget.dateLabel),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: (_showDigital ? Colors.white : colors.onSurface)
                        .withOpacity(0.54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _shortDate(String label) {
    final parts = label.split(',');
    if (parts.length < 2) return label;
    final date = parts[1].trim().split(' ');
    if (date.length < 2) return parts[1].trim();
    return '${date[0]} ${date[1]}';
  }
}

class _MiniAnalogClockPainter extends CustomPainter {
  const _MiniAnalogClockPainter({
    required this.minutes,
    required this.faceColor,
    required this.tickColor,
    required this.hourColor,
    required this.minuteColor,
    required this.accentColor,
    required this.shadowColor,
  });

  final int minutes;
  final Color faceColor;
  final Color tickColor;
  final Color hourColor;
  final Color minuteColor;
  final Color accentColor;
  final Color shadowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final faceRadius = radius - 3;

    canvas.drawCircle(
      center + const Offset(0, 2),
      faceRadius,
      Paint()..color = shadowColor,
    );
    canvas.drawCircle(
      center,
      faceRadius,
      Paint()..color = faceColor,
    );
    canvas.drawCircle(
      center,
      faceRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = tickColor.withOpacity(0.3),
    );

    for (var i = 0; i < 12; i++) {
      final angle = (i / 12) * 2 * math.pi - math.pi / 2;
      final tickStart =
          center + Offset(math.cos(angle), math.sin(angle)) * (faceRadius - 5);
      final tickEnd = center +
          Offset(math.cos(angle), math.sin(angle)) * (faceRadius - 2.4);
      canvas.drawLine(
        tickStart,
        tickEnd,
        Paint()
          ..strokeWidth = i % 3 == 0 ? 1.35 : 0.8
          ..strokeCap = StrokeCap.round
          ..color = tickColor.withOpacity(i % 3 == 0 ? 0.68 : 0.36),
      );
    }

    final hour = (minutes ~/ 60) % 12;
    final minute = minutes % 60;
    final hourAngle = ((hour + minute / 60) / 12) * 2 * math.pi - math.pi / 2;
    final minuteAngle = (minute / 60) * 2 * math.pi - math.pi / 2;

    canvas.drawLine(
      center,
      center + Offset(math.cos(hourAngle), math.sin(hourAngle)) * 13,
      Paint()
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = hourColor,
    );
    canvas.drawLine(
      center,
      center + Offset(math.cos(minuteAngle), math.sin(minuteAngle)) * 18,
      Paint()
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round
        ..color = minuteColor,
    );
    canvas.drawCircle(center, 2.6, Paint()..color = accentColor);
  }

  @override
  bool shouldRepaint(covariant _MiniAnalogClockPainter oldDelegate) {
    return oldDelegate.minutes != minutes ||
        oldDelegate.faceColor != faceColor ||
        oldDelegate.tickColor != tickColor ||
        oldDelegate.hourColor != hourColor ||
        oldDelegate.minuteColor != minuteColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.shadowColor != shadowColor;
  }
}

class _PlannerSideActions extends StatelessWidget {
  const _PlannerSideActions({
    required this.onCurrent,
    required this.onCalendar,
    required this.onDayTools,
    required this.onAdd,
    required this.onBest,
    required this.onRain,
  });

  final VoidCallback onCurrent;
  final VoidCallback onCalendar;
  final VoidCallback onDayTools;
  final VoidCallback onAdd;
  final VoidCallback onBest;
  final VoidCallback onRain;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: <Widget>[
            _SideActionButton(
              icon: Icons.my_location_rounded,
              onTap: onCurrent,
            ),
            const SizedBox(height: 3),
            _SideActionButton(
              icon: Icons.calendar_month_rounded,
              onTap: onCalendar,
            ),
            const SizedBox(height: 3),
            _SideActionButton(
              icon: Icons.edit_calendar_rounded,
              onTap: onDayTools,
            ),
            const SizedBox(height: 3),
            _SideActionButton(icon: Icons.add_task_rounded, onTap: onAdd),
            const SizedBox(height: 3),
            _SideActionButton(
              icon: Icons.emoji_events_rounded,
              onTap: onBest,
            ),
            const SizedBox(height: 3),
            _SideActionButton(
              icon: Icons.water_drop_outlined,
              onTap: onRain,
            ),
          ],
        ),
      ),
    );
  }
}

class _SideActionButton extends StatelessWidget {
  const _SideActionButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.outline.withOpacity(0.62)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, size: 17, color: colors.primary),
        ),
      ),
    );
  }
}

const double _kCalendarAllDayHeight = 40;
const double _kCalendarHourHeight = 52;
const double _kCalendarTimeGutterWidth = 54;

class _GoogleCalendarTimeline extends StatefulWidget {
  const _GoogleCalendarTimeline({
    required this.events,
    required this.loading,
    required this.onAdd,
    required this.onMove,
  });

  final List<GoogleCalendarEvent> events;
  final bool loading;
  final ValueChanged<DateTime> onAdd;
  final void Function(GoogleCalendarEvent event, DateTime start) onMove;

  @override
  State<_GoogleCalendarTimeline> createState() =>
      _GoogleCalendarTimelineState();
}

class _GoogleCalendarTimelineState extends State<_GoogleCalendarTimeline> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _scrollController = ScrollController(
      initialScrollOffset: _initialCurrentTimeOffset(now),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _initialCurrentTimeOffset(DateTime.now()),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double _initialCurrentTimeOffset(DateTime now) {
    final minuteOffset =
        _kCalendarAllDayHeight + (now.hour * _kCalendarHourHeight);
    return (minuteOffset - (_kCalendarHourHeight * 1.4))
        .clamp(
          0,
          _kCalendarAllDayHeight + (24 * _kCalendarHourHeight),
        )
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final allDayEvents =
        widget.events.where((event) => event.isAllDay).toList();
    final timedEvents =
        widget.events.where((event) => !event.isAllDay).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface.withOpacity(0.74),
          border: Border.all(color: colors.outline.withOpacity(0.18)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: <Widget>[
            ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 18),
              itemCount: 25,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _CalendarAllDayRow(events: allDayEvents);
                }
                final hour = index - 1;
                final hourStart = dayStart.add(Duration(hours: hour));
                final hourEvents = timedEvents.where((event) {
                  final start = event.start!;
                  return start.hour == hour && start.day == dayStart.day;
                }).toList();
                return _CalendarHourRow(
                  hour: hour,
                  events: hourEvents,
                  onAdd: () => widget.onAdd(hourStart),
                  onMove: (event) => widget.onMove(event, hourStart),
                  currentMinute: hour == now.hour ? now.minute : null,
                );
              },
            ),
            if (widget.loading)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.28),
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _GoogleCalendarAddType { event, task }

class _GoogleCalendarAddRequest {
  const _GoogleCalendarAddRequest({
    required this.type,
    required this.title,
  });

  final _GoogleCalendarAddType type;
  final String title;
}

class _GoogleCalendarAddSheet extends StatefulWidget {
  const _GoogleCalendarAddSheet({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;

  @override
  State<_GoogleCalendarAddSheet> createState() =>
      _GoogleCalendarAddSheetState();
}

class _GoogleCalendarAddSheetState extends State<_GoogleCalendarAddSheet> {
  late final TextEditingController _titleController;
  _GoogleCalendarAddType _addType = _GoogleCalendarAddType.event;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(
      _GoogleCalendarAddRequest(type: _addType, title: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 4, 18, bottomInset + 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Add to Google Calendar',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _GoogleCalendarAddTypeTile(
                  icon: Icons.event_rounded,
                  title: 'Event',
                  subtitle: _formatAddTimeRange(widget.start, widget.end),
                  selected: _addType == _GoogleCalendarAddType.event,
                  onTap: () => setState(
                    () => _addType = _GoogleCalendarAddType.event,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GoogleCalendarAddTypeTile(
                  icon: Icons.task_alt_rounded,
                  title: 'Task',
                  subtitle: 'Due ${_formatAddTime(widget.start)}',
                  selected: _addType == _GoogleCalendarAddType.task,
                  onTap: () => setState(
                    () => _addType = _GoogleCalendarAddType.task,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _titleController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Title',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

String _formatAddTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final suffix = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

String _formatAddTimeRange(DateTime start, DateTime end) {
  return '${_formatAddTime(start)} - ${_formatAddTime(end)}';
}

class _GoogleCalendarAddTypeTile extends StatelessWidget {
  const _GoogleCalendarAddTypeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colors.primaryContainer.withOpacity(0.72)
          : colors.surfaceContainerHighest.withOpacity(0.52),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? colors.primary.withOpacity(0.72)
                  : colors.outline.withOpacity(0.16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                icon,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarAllDayRow extends StatelessWidget {
  const _CalendarAllDayRow({required this.events});

  final List<GoogleCalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: _kCalendarAllDayHeight,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: _kCalendarTimeGutterWidth,
            child: Icon(
              Icons.today_rounded,
              size: 14,
              color: colors.onSurfaceVariant.withOpacity(0.72),
            ),
          ),
          Expanded(
            child: events.isEmpty
                ? const SizedBox.shrink()
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) => _CalendarAllDayChip(
                      event: events[index],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CalendarHourRow extends StatelessWidget {
  const _CalendarHourRow({
    required this.hour,
    required this.events,
    required this.onAdd,
    required this.onMove,
    required this.currentMinute,
  });

  final int hour;
  final List<GoogleCalendarEvent> events;
  final VoidCallback onAdd;
  final ValueChanged<GoogleCalendarEvent> onMove;
  final int? currentMinute;

  String get _label {
    if (hour == 0) return '';
    if (hour == 12) return '12 PM';
    return hour < 12 ? '$hour AM' : '${hour - 12} PM';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: _kCalendarHourHeight,
      child: Stack(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: _kCalendarTimeGutterWidth,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, right: 6),
                  child: Text(
                    _label,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: DragTarget<GoogleCalendarEvent>(
                  onAcceptWithDetails: (details) => onMove(details.data),
                  builder: (context, candidates, _) {
                    final hovering = candidates.isNotEmpty;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onAdd,
                        splashColor: colors.primary.withOpacity(0.08),
                        highlightColor: colors.primary.withOpacity(0.04),
                        child: Container(
                          decoration: BoxDecoration(
                            color: hovering
                                ? colors.primary.withOpacity(0.06)
                                : Colors.transparent,
                            border: Border(
                              top: BorderSide(
                                color: hovering
                                    ? colors.primary.withOpacity(0.42)
                                    : colors.outline.withOpacity(0.24),
                                width: hovering ? 1.2 : 0.8,
                              ),
                              left: BorderSide(
                                color: colors.outline.withOpacity(0.18),
                                width: 0.8,
                              ),
                            ),
                          ),
                          child: Stack(
                            children: <Widget>[
                              for (var i = 0; i < events.length; i++)
                                Positioned(
                                  left: 2,
                                  right: 4,
                                  top: 4.0 + i * 24,
                                  child: _CalendarEventChip(event: events[i]),
                                ),
                              if (events.isEmpty)
                                Positioned(
                                  top: 16,
                                  right: 8,
                                  child: Icon(
                                    Icons.add_rounded,
                                    size: 14,
                                    color: colors.onSurfaceVariant.withOpacity(
                                      hovering ? 0.8 : 0.28,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          if (currentMinute != null)
            Positioned(
              left: 0,
              right: 0,
              top: ((currentMinute! / 60) * _kCalendarHourHeight)
                  .clamp(0, _kCalendarHourHeight - 2)
                  .toDouble(),
              child: IgnorePointer(
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: _kCalendarTimeGutterWidth,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.error,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _formatAddTime(DateTime(
                              2024,
                              1,
                              1,
                              hour,
                              currentMinute!,
                            )),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colors.error,
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.surface),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 2,
                              decoration: BoxDecoration(
                                color: colors.error,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CalendarAllDayChip extends StatelessWidget {
  const _CalendarAllDayChip({required this.event});

  final GoogleCalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = event.isTask
        ? colors.primaryContainer.withOpacity(0.92)
        : colors.secondaryContainer.withOpacity(0.9);
    final foreground =
        event.isTask ? colors.onPrimaryContainer : colors.onSecondaryContainer;
    final chip = Container(
      margin: const EdgeInsets.only(top: 6, bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (event.isTask) ...<Widget>[
            Icon(
              event.isCompleted
                  ? Icons.task_alt_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 13,
              color: foreground,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            event.title,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    if (event.id.isEmpty) return chip;
    return LongPressDraggable<GoogleCalendarEvent>(
      data: event,
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: chip,
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: chip),
      child: chip,
    );
  }
}

class _CalendarEventChip extends StatelessWidget {
  const _CalendarEventChip({required this.event});

  final GoogleCalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = event.isTask
        ? colors.primaryContainer.withOpacity(0.92)
        : colors.secondaryContainer.withOpacity(0.9);
    final foreground =
        event.isTask ? colors.onPrimaryContainer : colors.onSecondaryContainer;
    final chip = Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: <Widget>[
          if (event.isTask) ...<Widget>[
            Icon(
              event.isCompleted
                  ? Icons.task_alt_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 13,
              color: foreground,
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (event.id.isEmpty) return chip;
    return LongPressDraggable<GoogleCalendarEvent>(
      data: event,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 220, child: chip),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: chip),
      child: chip,
    );
  }
}

class _HomeSurfaceCard extends StatelessWidget {
  const _HomeSurfaceCard({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark
            ? colors.surfaceContainerHighest.withOpacity(0.34)
            : const Color(0xFFF6F9FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.outline.withOpacity(dark ? 0.22 : 0.18),
          width: 0.8,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.12 : 0.018),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Sleep-edit shortcut ───────────────────────────────────────────────────

/// Compact "wake → sleep" pill with an edit icon. Tapping it opens the sleep
/// tracker, where the user can adjust their schedule; when they return, the
/// home-tab listener rebuilds the tube against the new times.
// ignore: unused_element
class _SleepEditButton extends StatelessWidget {
  const _SleepEditButton({
    required this.wake,
    required this.sleep,
    required this.onTap,
  });

  final TimeOfDay wake;
  final TimeOfDay sleep;
  final VoidCallback onTap;

  String _fmt(TimeOfDay t) {
    final h = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
    return t.hour < 12 ? '${h}A' : '${h}P';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: dark
                ? colors.surfaceTint.withOpacity(0.92)
                : colors.surface.withOpacity(0.78),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: colors.outline.withOpacity(0.7),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${_fmt(wake)} → ${_fmt(sleep)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.edit_outlined,
                size: 14,
                color: colors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Day tube ──────────────────────────────────────────────────────────────

// ignore: unused_element
class _DayModePickerPage extends StatelessWidget {
  const _DayModePickerPage({
    required this.modeId,
    required this.onModeChanged,
  });

  final String modeId;
  final ValueChanged<String> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final modes = allSelectableDayModes;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 44,
        scrolledUnderElevation: 0,
        title: const Text(
          'Choose a goal',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 82,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: modes.length,
        itemBuilder: (context, index) {
          final mode = modes[index];
          final selected = mode.id == modeId;
          final colors = Theme.of(context).colorScheme;
          return Material(
            color: selected ? colors.primary.withOpacity(0.12) : colors.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () async {
                if (CustomModeStore.isCustomModeId(mode.id)) {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ServicesPage(
                        autoOpenServiceId: 'daily_planner',
                        closeOnAutoOpenReturn: true,
                      ),
                    ),
                  );
                  onModeChanged(ProfileStore.instance.plannerMode.value);
                  if (context.mounted) Navigator.of(context).pop(true);
                  return;
                }
                onModeChanged(mode.id);
                Navigator.of(context).pop(true);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? colors.primary.withOpacity(0.5)
                        : colors.outline.withOpacity(0.55),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(mode.emoji, style: const TextStyle(fontSize: 18)),
                        const Spacer(),
                        if (selected)
                          Icon(Icons.check_circle_rounded,
                              size: 17, color: colors.primary),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      mode.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected ? colors.primary : colors.onSurface,
                      ),
                    ),
                    if (mode.isPro)
                      Text(
                        'Pro plan',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: colors.onSurface.withOpacity(0.56),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Left gutter reserved for the sleeping panda.
const double _sleepGutter = 36.0;

/// Builds the hairpin centerline — runs pulled close together for a tight,
/// hard bend, with breathing room on both sides.
Path _buildTubePath(Size size) {
  const padRight = 22.0;
  final topY = size.height * 0.26;
  final bottomY = size.height * 0.74;
  final bendRadius = (bottomY - topY) / 2;

  const startX = _sleepGutter;
  final bendX = size.width - padRight - bendRadius;

  return Path()
    ..moveTo(startX, topY)
    ..lineTo(bendX, topY)
    ..arcTo(
      Rect.fromCircle(
          center: Offset(bendX, topY + bendRadius), radius: bendRadius),
      -math.pi / 2,
      math.pi,
      false,
    )
    ..lineTo(startX, bottomY);
}

class _DayTube extends StatefulWidget {
  const _DayTube({
    required this.nowMinutes,
    required this.wakeMinutes,
    required this.sleepMinutes,
  });

  final double nowMinutes;
  final int wakeMinutes;
  final int sleepMinutes;

  @override
  State<_DayTube> createState() => _DayTubeState();
}

class _DayTubeState extends State<_DayTube>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flow;

  @override
  void initState() {
    super.initState();
    // Slow, endless drift — the liquid inside the tube never sits still.
    _flow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  /// Fill/avatar position along the tube.
  /// Daytime  (wake ≤ now < sleep)      → linear (now − wake) / (sleep − wake)
  /// Nighttime, first half              → 1.0 (parked at the sleep box)
  /// Nighttime, second half             → 0.0 (parked at the wake box)
  double get _progress {
    var now = widget.nowMinutes;
    final wake = widget.wakeMinutes.toDouble();
    var sleep = widget.sleepMinutes.toDouble();
    if (sleep <= wake) sleep += 24 * 60;
    while (now < wake) {
      now += 24 * 60;
    }

    if (now >= wake && now < sleep) {
      return ((now - wake) / (sleep - wake)).clamp(0.0, 1.0);
    }

    final nextWake = wake + 24 * 60;
    final nightDuration = nextWake - sleep;
    final into = now - sleep;
    return into < nightDuration / 2 ? 1.0 : 0.0;
  }

  bool get _isWakeCurrent => isWakeWindowFor(
        widget.nowMinutes,
        wakeMinutes: widget.wakeMinutes,
      );
  bool get _isSleepCurrent => isSleepWindowFor(
        widget.nowMinutes,
        wakeMinutes: widget.wakeMinutes,
        sleepMinutes: widget.sleepMinutes,
      );

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _progress),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, smoothProgress, _) => LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final path = _buildTubePath(size);
          final metric = path.computeMetrics().first;

          final nowTangent =
              metric.getTangentForOffset(metric.length * smoothProgress);
          final nowPos = nowTangent?.position ?? Offset.zero;

          final topY = size.height * 0.26;
          final bottomY = size.height * 0.74;

          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              // Tube, ticks, progress fill, needle
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _flow,
                  builder: (context, _) => CustomPaint(
                    painter: _DayTubePainter(
                      progress: smoothProgress,
                      flowPhase: _flow.value,
                      wakeMinutes: widget.wakeMinutes,
                      sleepMinutes: widget.sleepMinutes,
                    ),
                  ),
                ),
              ),

              // Wake-up box: sits just before the tube's top-left endpoint,
              // its right edge flush against startX so the tube extends
              // rightward out of it. The green matches the tube fill's morning
              // start color — continuous fill across box → tube.
              _EndpointBox(
                left: _sleepGutter - 24,
                top: topY - 12,
                size: const Size(24, 24),
                baseColor: const Color(0xFF8BCFA4),
                accentColor: AppColors.success,
                animate: _isWakeCurrent,
                pulse: _flow,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: SvgPicture.asset(
                    'assets/icons/wakeup_alarm.svg',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // Sleep box: sits just before the tube's bottom-left endpoint.
              // Deep indigo matches the tube fill's night end — the panda
              // Lottie always plays; the box itself pulses when it's the
              // current window.
              _EndpointBox(
                left: _sleepGutter - 24,
                top: bottomY - 12,
                size: const Size(24, 24),
                baseColor: const Color(0xFF303F9F),
                accentColor: const Color(0xFF1B1E4A),
                animate: _isSleepCurrent,
                pulse: _flow,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(18),
                ),
                child: RotatedBox(
                  quarterTurns: 1,
                  child: Lottie.asset(
                    'assets/lottie/panda_sleeping.json',
                    fit: BoxFit.cover,
                    repeat: true,
                  ),
                ),
              ),

              // User avatar riding the tube at "now"
              Positioned(
                left: nowPos.dx - 12,
                top: nowPos.dy - 12,
                child: AnimatedBuilder(
                  animation: _flow,
                  builder: (context, _) {
                    final pulse =
                        1 + 0.035 * math.sin(_flow.value * 2 * math.pi);
                    return Transform.scale(
                      scale: pulse,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.primary, width: 2),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const ProfileAvatar(
                          radius: 10,
                          iconSize: 12,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DayTubePainter extends CustomPainter {
  _DayTubePainter({
    required this.progress,
    required this.flowPhase,
    required this.wakeMinutes,
    required this.sleepMinutes,
  });

  final double progress;
  final double flowPhase;
  final int wakeMinutes;
  final int sleepMinutes;

  static const double _tubeWidth = 32;

  /// Time-of-day mood icons drawn inside the tube. Each sits at its minute
  /// mark: sprout for the soft green morning, sun for noon, dusk for the golden
  /// hour, moon rising as the dark settles in.
  static const List<({int minute, String emoji})> _phaseIcons =
      <({int minute, String emoji})>[
    (minute: 7 * 60 + 30, emoji: '🌱'),
    (minute: 12 * 60, emoji: '☀️'),
    (minute: 16 * 60 + 30, emoji: '🌇'),
    (minute: 20 * 60 + 30, emoji: '🌙'),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildTubePath(size);
    final metric = path.computeMetrics().first;

    // ── Glass tube (Apple liquid-glass feel) ──────────────────────────
    // Soft drop shadow under the tube
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _tubeWidth
      ..strokeCap = StrokeCap.butt
      ..color = const Color(0xFFEAF0ED);
    canvas.drawPath(path, track);

    final innerTrack = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _tubeWidth - 10
      ..strokeCap = StrokeCap.butt
      ..color = Colors.white.withOpacity(0.9);
    canvas.drawPath(path, innerTrack);

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _tubeWidth
      ..strokeCap = StrokeCap.butt
      ..color = Colors.white.withOpacity(0.72);
    canvas.drawPath(path, rim);

    // Elapsed portion with day-to-night gradient — liquid inside the glass
    if (progress > 0) {
      final done = metric.extractPath(0, metric.length * progress);
      final fill = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _tubeWidth - 8
        ..strokeCap = StrokeCap.butt
        ..shader = _dayGradient().createShader(Offset.zero & size);
      canvas.drawPath(done, fill);

      // Sheen on the liquid — brightens the fill's top edge
      final sheen = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (_tubeWidth - 8) / 3
        ..strokeCap = StrokeCap.butt
        ..color = Colors.white.withOpacity(0.22);
      canvas.save();
      canvas.translate(0, -(_tubeWidth - 8) / 4);
      canvas.drawPath(done, sheen);
      canvas.restore();

      // ── Living liquid: soft glints drifting along the fill ──────────
      // A few blurred white dashes slide slowly through the elapsed
      // portion and fade out near the leading edge.
      final doneLen = metric.length * progress;
      const glintCount = 4;
      for (var i = 0; i < glintCount; i++) {
        final head = ((flowPhase + i / glintCount) % 1.0) * doneLen;
        const glintLen = 26.0;
        final start = head - glintLen;
        if (start < 0) continue;
        // Fade the glint as it approaches the "now" edge.
        final edgeFade = ((doneLen - head) / 60.0).clamp(0.0, 1.0);
        if (edgeFade == 0) continue;
        final glint = metric.extractPath(start, head);
        canvas.drawPath(
          glint,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = (_tubeWidth - 8) / 2.6
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withOpacity(0.16 * edgeFade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
    }

    // ── Timeline markers inside the tube — cute capsule labels ─────────
    final sleepEnd =
        sleepMinutes <= wakeMinutes ? sleepMinutes + 24 * 60 : sleepMinutes;
    final total = sleepEnd - wakeMinutes;
    if (total <= 0) return;
    final wakeHour = wakeMinutes ~/ 60;
    final sleepHour = sleepEnd ~/ 60;

    for (var m = wakeMinutes; m <= sleepEnd; m += 60) {
      final t = (m - wakeMinutes) / total;
      final tangent = metric.getTangentForOffset(metric.length * t);
      if (tangent == null) continue;

      final pos = tangent.position;
      final hour = m ~/ 60;
      final isMajor = hour == sleepHour || (hour - wakeHour) % 3 == 0;
      final isElapsed = t <= progress;
      final isEndpoint = m == wakeMinutes || m == sleepEnd;
      final labelPos = isEndpoint && pos.dx < _sleepGutter + 28
          ? Offset(_sleepGutter + 28, pos.dy)
          : pos;

      if (isMajor) {
        _drawHourCapsule(canvas, labelPos, _hourLabel(hour), isElapsed);
      } else {
        // Off hours — a tiny two-tone dot on the centerline.
        canvas.drawCircle(
          pos,
          2.2,
          Paint()
            ..color = isElapsed
                ? Colors.white.withOpacity(0.35)
                : Colors.black.withOpacity(0.08),
        );
        canvas.drawCircle(
          pos,
          1.1,
          Paint()
            ..color = isElapsed
                ? Colors.white.withOpacity(0.85)
                : Colors.black.withOpacity(0.25),
        );
      }
    }

    // ── Time-of-day mood icons riding inside the tube ──────────────────
    for (final phase in _phaseIcons) {
      final phaseMinute =
          phase.minute < wakeMinutes ? phase.minute + 24 * 60 : phase.minute;
      final t = (phaseMinute - wakeMinutes) / total;
      if (t < 0 || t > 1) continue;
      final tangent = metric.getTangentForOffset(metric.length * t);
      if (tangent == null) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: phase.emoji,
          style: const TextStyle(fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // Nudge above the centerline so capsules & dots keep their lane.
      final float =
          math.sin(flowPhase * 2 * math.pi + phase.minute / 180) * 1.5;
      final pos = tangent.position -
          Offset(tp.width / 2, tp.height / 2 + _tubeWidth / 2 - 8);
      canvas.save();
      canvas.translate(0, float);
      tp.paint(canvas, pos);
      canvas.restore();
    }

    // Now marker — short bright cap at the liquid's leading edge
    final nowTangent =
        metric.getTangentForOffset(metric.length * progress.clamp(0.0, 1.0));
    if (nowTangent != null) {
      final pos = nowTangent.position;
      final normal = Offset(-nowTangent.vector.dy, nowTangent.vector.dx);
      final n = normal / normal.distance;
      canvas.drawCircle(
        pos,
        5.5,
        Paint()
          ..color = Colors.white.withOpacity(0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      final needle = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        pos - n * 7,
        pos + n * 7,
        needle,
      );
    }
  }

  /// Gradient: top rail = soft morning green, bend = golden sun → warm orange,
  /// bottom rail = twilight. Dark blues stay below the tube (night).
  /// Top-to-bottom orientation so the hairpin bend never shows night colors.
  LinearGradient _dayGradient() {
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        Color(0xFFA7DDB8), // above tube — soft morning green
        Color(0xFF8BCFA4), // 6 AM — top rail start
        Color(0xFFF9A825), // ~noon — upper bend, golden sun
        Color(0xFFFF7043), // ~3 PM — lower bend, warm orange-dusk
        Color(0xFF5C6BC0), // ~10 PM — bottom rail, soft twilight
        Color(0xFF1A237E), // below tube — deep night
      ],
      // stops keyed to tube geometry: topY ≈ 28%, bottomY ≈ 72%
      stops: <double>[0.0, 0.28, 0.46, 0.58, 0.72, 1.0],
    );
  }

  /// A tiny pill riding the tube centerline with the hour inside — white
  /// text on a dark chip once the liquid has passed it, dark text on a
  /// frosted chip while it's still ahead.
  void _drawHourCapsule(
      Canvas canvas, Offset pos, String label, bool isElapsed) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 7.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: isElapsed ? Colors.white : Colors.black.withOpacity(0.55),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: pos,
        width: tp.width + 10,
        height: tp.height + 5,
      ),
      const Radius.circular(8),
    );

    canvas.drawRRect(
      rect,
      Paint()
        ..color = isElapsed
            ? Colors.black.withOpacity(0.28)
            : Colors.white.withOpacity(0.75),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = isElapsed
            ? Colors.white.withOpacity(0.45)
            : Colors.black.withOpacity(0.12),
    );
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  String _hourLabel(int hour) {
    final h = hour % 24;
    if (h == 0) return '12AM';
    if (h == 12) return '12PM';
    return h < 12 ? '${h}AM' : '${h - 12}PM';
  }

  @override
  bool shouldRepaint(_DayTubePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.flowPhase != flowPhase ||
      oldDelegate.wakeMinutes != wakeMinutes ||
      oldDelegate.sleepMinutes != sleepMinutes;
}

/// A small square box anchored at [left],[top] that sits at the tube's
/// endpoint. When [animate] is true it pulses in sync with [pulse].
class _EndpointBox extends StatelessWidget {
  const _EndpointBox({
    required this.left,
    required this.top,
    required this.size,
    required this.baseColor,
    required this.accentColor,
    required this.animate,
    required this.pulse,
    required this.child,
    this.borderRadius,
  });

  final double left;
  final double top;
  final Size size;
  final Color baseColor;
  final Color accentColor;
  final bool animate;
  final Animation<double> pulse;
  final Widget child;
  final BorderRadiusGeometry? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      width: size.width,
      height: size.height,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (_, __) {
          final glow = animate
              ? (0.18 + 0.12 * math.sin(pulse.value * 2 * math.pi))
              : 0.0;
          final radius = borderRadius ?? BorderRadius.circular(11);
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[baseColor, accentColor],
              ),
              borderRadius: radius,
              border: Border.all(color: Colors.white.withOpacity(0.62)),
              boxShadow: animate
                  ? <BoxShadow>[
                      BoxShadow(
                        color: baseColor.withOpacity(glow),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: child,
            ),
          );
        },
      ),
    );
  }
}
