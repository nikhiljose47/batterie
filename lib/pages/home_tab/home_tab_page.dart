import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

import '../../constants/app_colors.dart';
import '../profile/profile_store.dart';
import '../services/tools/sleep_page.dart';
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

  Future<void> _openSleepEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SleepPage()),
    );
    if (mounted) _scheduleBloc.add(const HomeScheduleStarted());
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

  Widget _buildDayCard(BuildContext context, HomeScheduleState schedule) {
    final colors = Theme.of(context).colorScheme;
    final muted = colors.onSurface.withOpacity(0.58);
    return _HomeSurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
              ModeDropdown(
                modeId: _modeId,
                onChanged: (id) {
                  setState(() => _modeId = id);
                  ProfileStore.instance.setPlannerMode(id);
                },
              ),
              const SizedBox(width: 6),
              _SleepEditButton(
                wake: schedule.wake,
                sleep: schedule.sleep,
                onTap: _openSleepEditor,
              ),
            ],
          ),
          SizedBox(
            height: 105,
            child: _DayTube(
              nowMinutes: schedule.nowMinutes,
              wakeMinutes: schedule.wakeMinutes,
              sleepMinutes: schedule.sleepMinutes,
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outline.withOpacity(0.58)),
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
                    ),
                  ),
                ),
              ),

              // Wake-up box: sits just before the tube's top-left endpoint,
              // its right edge flush against startX so the tube extends
              // rightward out of it. The green matches the tube fill's morning
              // start color — continuous fill across box → tube.
              _EndpointBox(
                left: _sleepGutter - 32,
                top: topY - 16,
                size: const Size(32, 32),
                baseColor: const Color(0xFF66BB6A),
                accentColor: const Color(0xFF43A047),
                animate: _isWakeCurrent,
                pulse: _flow,
                child: Padding(
                  padding: const EdgeInsets.all(5),
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
                left: _sleepGutter - 32,
                top: bottomY - 16,
                size: const Size(32, 32),
                baseColor: const Color(0xFF303F9F),
                accentColor: const Color(0xFF1B1E4A),
                animate: _isSleepCurrent,
                pulse: _flow,
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
  });

  final double progress;
  final double flowPhase;
  final int wakeMinutes;
  final int sleepMinutes;

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
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFEAF0ED);
    canvas.drawPath(path, track);

    final innerTrack = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _tubeWidth - 10
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.9);
    canvas.drawPath(path, innerTrack);

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _tubeWidth
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.72);
    canvas.drawPath(path, rim);

    // Elapsed portion with day-to-night gradient — liquid inside the glass
    if (progress > 0) {
      final done = metric.extractPath(0, metric.length * progress);
      final fill = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _tubeWidth - 8
        ..strokeCap = StrokeCap.round
        ..shader = _dayGradient().createShader(Offset.zero & size);
      canvas.drawPath(done, fill);

      // Sheen on the liquid — brightens the fill's top edge
      final sheen = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (_tubeWidth - 8) / 3
        ..strokeCap = StrokeCap.round
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

      if (isMajor) {
        _drawHourCapsule(canvas, pos, _hourLabel(hour), isElapsed);
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
  });

  final double left;
  final double top;
  final Size size;
  final Color baseColor;
  final Color accentColor;
  final bool animate;
  final Animation<double> pulse;
  final Widget child;

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
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[baseColor, accentColor],
              ),
              borderRadius: BorderRadius.circular(11),
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
              borderRadius: BorderRadius.circular(11),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
