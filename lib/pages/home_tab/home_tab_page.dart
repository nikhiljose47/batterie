import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

import '../../constants/app_colors.dart';
import '../../models/planner_session_log.dart';
import '../../services/custom_mode_store.dart';
import '../../services/sleep_schedule_store.dart';
import '../profile/profile_store.dart';
import '../services/services_page.dart';
import '../weather/weather_controller.dart';
import 'bloc/home_schedule_bloc.dart';
import 'data/mode_advice.dart';
import 'widgets/planner_section.dart';

/// Fresh home tab: unified, color-coded day tube showing energy flow from
/// wake (morning green) through warm noon through evening dusk to sleep (night).
class HomeTabPage extends StatefulWidget {
  const HomeTabPage({super.key, this.weatherController});

  /// Optional shared controller (e.g. owned by the top bar's location
  /// button). When null the tab owns its own.
  final WeatherController? weatherController;

  @override
  State<HomeTabPage> createState() => _HomeTabPageState();
}

class _HomeTabPageState extends State<HomeTabPage> {
  late String _modeId;
  late final HomeScheduleBloc _scheduleBloc;
  late final WeatherController _weatherController;
  late final bool _ownsWeatherController;
  List<PlannerSessionLog> _sessionLogs = const <PlannerSessionLog>[];
  int _plannerRefreshToken = 0;

  @override
  void initState() {
    super.initState();
    _modeId = ProfileStore.instance.plannerMode.value;
    _scheduleBloc = HomeScheduleBloc();
    _ownsWeatherController = widget.weatherController == null;
    _weatherController = widget.weatherController ?? WeatherController();
    if (_ownsWeatherController) _weatherController.load();
  }

  @override
  void dispose() {
    _scheduleBloc.close();
    if (_ownsWeatherController) _weatherController.dispose();
    super.dispose();
  }

  Future<void> _openDayCardEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _DayCardEditPage(
          modeId: _modeId,
          onModeChanged: (id) {
            setState(() => _modeId = id);
            ProfileStore.instance.setPlannerMode(id);
          },
          onScheduleChanged: () {
            if (mounted) _scheduleBloc.add(const HomeScheduleStarted());
          },
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _modeId = ProfileStore.instance.plannerMode.value;
      _plannerRefreshToken++;
    });
    _scheduleBloc.add(const HomeScheduleStarted());
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

  /// A friendly phrase for the current time. Schedule-aware: says "Sleep
  /// time" during the user's off-hours and "Just woke up" during the wake
  /// buffer; falls back to clock-based phrases the rest of the day.
  String _timeOfDayPhrase(int minutes, HomeScheduleState schedule) {
    if (isSleepWindowFor(
      minutes,
      wakeMinutes: schedule.wakeMinutes,
      sleepMinutes: schedule.sleepMinutes,
    )) {
      return 'Sleep time';
    }
    if (isWakeWindowFor(minutes, wakeMinutes: schedule.wakeMinutes)) {
      return 'Just woke up';
    }
    final h = (minutes ~/ 60) % 24;
    if (h < 11) return 'Morning';
    if (h < 13) return 'Midday';
    if (h < 16) return 'Afternoon';
    if (h < 18) return 'Late afternoon';
    if (h < 21) return 'Evening';
    return 'Night';
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HomeScheduleBloc>.value(
      value: _scheduleBloc,
      child: BlocBuilder<HomeScheduleBloc, HomeScheduleState>(
        builder: (context, schedule) {
          final colors = Theme.of(context).colorScheme;
          // Fixed day card at the top; only the planner list below scrolls.
          return Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildDayCard(context, schedule),
                const SizedBox(height: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          "Today's Plan",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      Expanded(
                        child: PlannerSection(
                          nowMinutes: schedule.nowMinutes,
                          wakeMinutes: schedule.wakeMinutes,
                          sleepMinutes: schedule.sleepMinutes,
                          modeId: _modeId,
                          onModeChanged: (id) {
                            setState(() => _modeId = id);
                            ProfileStore.instance.setPlannerMode(id);
                          },
                          weatherController: _weatherController,
                          onSessionLogsChanged: _onSessionLogsChanged,
                          refreshToken: _plannerRefreshToken,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _onSessionLogsChanged(List<PlannerSessionLog> logs) {
    if (!mounted) return;
    setState(() => _sessionLogs = logs);
  }

  Widget _buildDayCard(BuildContext context, HomeScheduleState schedule) {
    final colors = Theme.of(context).colorScheme;
    final muted = colors.onSurface.withOpacity(0.58);
    final selectedMode = allSelectableDayModes.firstWhere(
      (mode) => mode.id == _modeId,
      orElse: () => allSelectableDayModes.first,
    );
    return _HomeSurfaceCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFE8F5E9),
                child: Text('🧑', style: TextStyle(fontSize: 15)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ValueListenableBuilder<String>(
                      valueListenable: ProfileStore.instance.name,
                      builder: (context, name, _) {
                        return Text(
                          'Hi, ${name.trim().isEmpty ? 'User' : name.trim()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.1,
                            color: colors.onSurface,
                          ),
                        );
                      },
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            _todayLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: muted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _timeOfDayPhrase(
                            schedule.nowMinutes.floor(),
                            schedule,
                          ).toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: colors.primary,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ModeStatusChip(mode: selectedMode),
              const SizedBox(width: 6),
              _DayCardEditButton(onTap: _openDayCardEditor),
            ],
          ),
          SizedBox(
            height: 105,
            child: _DayTube(
              nowMinutes: schedule.nowMinutes,
              wakeMinutes: schedule.wakeMinutes,
              sleepMinutes: schedule.sleepMinutes,
              sessionLogs: _sessionLogs,
            ),
          ),
        ],
      ),
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
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.outline.withOpacity(dark ? 0.34 : 0.28),
          width: 0.8,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.22 : 0.045),
            blurRadius: 24,
            offset: const Offset(0, 10),
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

class _ModeStatusChip extends StatelessWidget {
  const _ModeStatusChip({required this.mode});

  final DayMode mode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 108),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: colors.primary.withOpacity(0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(mode.emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  mode.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: colors.primary,
                  ),
                ),
                Text(
                  'MODE',
                  style: TextStyle(
                    fontSize: 7,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    color: colors.primary.withOpacity(0.68),
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

class _DayCardEditButton extends StatelessWidget {
  const _DayCardEditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Edit day card',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(
                Theme.of(context).brightness == Brightness.dark ? 0.26 : 0.11,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF1565C0).withOpacity(0.34),
                width: 1,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF1565C0).withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.tune_rounded,
              size: 17,
              color: Color(0xFF1565C0),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayCardEditPage extends StatelessWidget {
  const _DayCardEditPage({
    required this.modeId,
    required this.onModeChanged,
    required this.onScheduleChanged,
  });

  final String modeId;
  final ValueChanged<String> onModeChanged;
  final VoidCallback onScheduleChanged;

  String _fmtTime(TimeOfDay t) {
    final h = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
    final suffix = t.hour < 12 ? 'AM' : 'PM';
    if (t.minute == 0) return '$h $suffix';
    return '$h:${t.minute.toString().padLeft(2, '0')} $suffix';
  }

  Future<void> _openService(
    BuildContext context,
    String serviceId, {
    VoidCallback? onReturn,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ServicesPage(
          autoOpenServiceId: serviceId,
          closeOnAutoOpenReturn: true,
        ),
      ),
    );
    onReturn?.call();
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = allSelectableDayModes.firstWhere(
      (mode) => mode.id == modeId,
      orElse: () => allSelectableDayModes.first,
    );
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 44,
        scrolledUnderElevation: 0,
        title: const Text(
          'Edit day card',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.92,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: <Widget>[
            _DayEditTile(
              icon: Icons.auto_awesome_motion_outlined,
              iconColor: colors.primary,
              title: 'Day mode',
              value: selected.label,
              description: 'Plan style and coaching rhythm.',
              onTap: () => _openService(
                context,
                'daily_planner',
                onReturn: () => onModeChanged(
                  ProfileStore.instance.plannerMode.value,
                ),
              ),
            ),
            _DayEditTile(
              icon: Icons.bedtime_outlined,
              iconColor: const Color(0xFF5E35B1),
              title: 'Sleep schedule',
              value:
                  '${_fmtTime(SleepScheduleStore.instance.wakeTime.value)} - '
                  '${_fmtTime(SleepScheduleStore.instance.sleepTime.value)}',
              description: 'Wake and sleep anchors for the tube.',
              onTap: () => _openService(
                context,
                'sleep_tracker',
                onReturn: onScheduleChanged,
              ),
            ),
            _DayEditTile(
              icon: Icons.checklist_rounded,
              iconColor: const Color(0xFF2E7D32),
              title: 'To-do list',
              value: "Today's tasks",
              description: 'Tasks shown inside plan cards.',
              onTap: () => _openService(context, 'todo'),
            ),
            _DayEditTile(
              icon: Icons.alarm_outlined,
              iconColor: const Color(0xFF1565C0),
              title: 'Alarms',
              value: 'Planner alerts',
              description: 'Reminders for card start times.',
              onTap: () => _openService(context, 'alarms'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayEditTile extends StatelessWidget {
  const _DayEditTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outline.withOpacity(0.48)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(dark ? 0.16 : 0.025),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 21, color: iconColor),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colors.onSurface.withOpacity(0.38),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 7),
              Container(
                constraints: const BoxConstraints(minHeight: 24),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: iconColor.withOpacity(0.28)),
                ),
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: iconColor,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.22,
                  color: colors.onSurface.withOpacity(0.58),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
          'Day mode',
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
                        fontWeight: FontWeight.w800,
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
  final topY = size.height * 0.34;
  final bottomY = size.height * 0.66;
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

Path _buildDoneLanePath(Size size) {
  final sourcePath = _buildTubePath(size);
  final metric = sourcePath.computeMetrics().first;
  const laneOffset = _DayTubePainter._tubeWidth * 0.56;
  const sampleCount = 90;

  final lane = Path();
  for (var i = 0; i <= sampleCount; i++) {
    final offset = metric.length * i / sampleCount;
    final tangent = metric.getTangentForOffset(offset);
    if (tangent == null) continue;
    final normal = Offset(tangent.vector.dy, -tangent.vector.dx);
    final p = tangent.position + normal * laneOffset;
    if (i == 0) {
      lane.moveTo(p.dx, p.dy);
    } else {
      lane.lineTo(p.dx, p.dy);
    }
  }
  return lane;
}

class _TubeDoneSegment {
  const _TubeDoneSegment({required this.start, required this.end});

  final double start;
  final double end;
}

class _DayTube extends StatefulWidget {
  const _DayTube({
    required this.nowMinutes,
    required this.wakeMinutes,
    required this.sleepMinutes,
    required this.sessionLogs,
  });

  final double nowMinutes;
  final int wakeMinutes;
  final int sleepMinutes;
  final List<PlannerSessionLog> sessionLogs;

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

  List<_TubeDoneSegment> get _doneSegments {
    final wake = widget.wakeMinutes;
    var dayEnd = widget.sleepMinutes;
    if (dayEnd <= wake) dayEnd += kDayMinutes;
    final total = dayEnd - wake;
    if (total <= 0) return const <_TubeDoneSegment>[];

    final segments = <_TubeDoneSegment>[];
    for (final log in widget.sessionLogs) {
      if (!log.isDone) continue;

      if (log.sessionId == 'sleep') {
        segments.add(const _TubeDoneSegment(start: 0.965, end: 1.0));
        continue;
      }

      var start = log.startMinutes;
      var end = log.endMinutes;
      while (start < wake) {
        start += kDayMinutes;
      }
      while (end <= start) {
        end += kDayMinutes;
      }

      final clippedStart = start.clamp(wake, dayEnd);
      final clippedEnd = end.clamp(wake, dayEnd);
      if (clippedEnd <= clippedStart) continue;

      var startT = (clippedStart - wake) / total;
      var endT = (clippedEnd - wake) / total;
      if (log.sessionId == 'wake') {
        startT = 0;
        endT = math.max(endT, 0.035);
      }
      segments.add(_TubeDoneSegment(
        start: startT.clamp(0.0, 1.0),
        end: endT.clamp(0.0, 1.0),
      ));
    }
    return segments;
  }

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

          final topY = size.height * 0.34;
          final bottomY = size.height * 0.66;

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
                      doneSegments: _doneSegments,
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
                baseColor: const Color(0xFF66BB6A),
                accentColor: const Color(0xFF43A047),
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
                left: nowPos.dx - 15,
                top: nowPos.dy - 15,
                child: AnimatedBuilder(
                  animation: _flow,
                  builder: (context, _) {
                    final pulse =
                        1 + 0.035 * math.sin(_flow.value * 2 * math.pi);
                    return Transform.scale(
                      scale: pulse,
                      child: Container(
                        width: 30,
                        height: 30,
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
                        child: const Text('🧑', style: TextStyle(fontSize: 15)),
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
    required this.doneSegments,
  });

  final double progress;
  final double flowPhase;
  final int wakeMinutes;
  final int sleepMinutes;
  final List<_TubeDoneSegment> doneSegments;

  static const double _tubeWidth = 32;

  /// Time-of-day mood icons drawn inside the tube. Each sits at its minute
  /// mark: sprout for the green morning, sun for noon, dusk for the golden
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

    // Completed-card marker: a light-blue trace just outside the tube. It
    // follows the same curve and marks Today Plan card time ranges.
    final doneLane = _buildDoneLanePath(size);
    final doneMetric = doneLane.computeMetrics().first;
    final doneLaneTrack = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF90CAF9).withOpacity(0.22);
    canvas.drawPath(doneLane, doneLaneTrack);

    final donePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF42A5F5).withOpacity(0.96);

    for (final segment in doneSegments) {
      final start =
          (doneMetric.length * segment.start).clamp(0.0, doneMetric.length);
      final end = (doneMetric.length * segment.end)
          .clamp(start + 0.1, doneMetric.length);
      canvas.drawPath(doneMetric.extractPath(start, end), donePaint);
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

  /// Gradient: top rail = morning green, bend = golden sun → warm orange,
  /// bottom rail = twilight. Dark blues stay below the tube (night).
  /// Top-to-bottom orientation so the hairpin bend never shows night colors.
  LinearGradient _dayGradient() {
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        Color(0xFF4CAF50), // above tube — vivid morning green
        Color(0xFF66BB6A), // 6 AM — top rail start
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
          fontWeight: FontWeight.w800,
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
      oldDelegate.sleepMinutes != sleepMinutes ||
      oldDelegate.doneSegments != doneSegments;
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
