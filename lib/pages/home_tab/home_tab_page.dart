import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';
import '../../models/logged_activity.dart';
import '../../services/sleep_schedule_store.dart';
import '../profile/profile_store.dart';
import '../services/tools/sleep_page.dart';
import '../weather/weather_controller.dart';
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
  Timer? _ticker;
  late final WeatherController _weatherController;
  late final bool _ownsWeatherController;

  @override
  void initState() {
    super.initState();
    _modeId = ProfileStore.instance.plannerMode.value;
    // Live clock — header time and tube fill track the real time.
    _ticker = Timer.periodic(
      const Duration(seconds: 20),
      (_) => setState(() {}),
    );
    _ownsWeatherController = widget.weatherController == null;
    _weatherController = widget.weatherController ?? WeatherController();
    if (_ownsWeatherController) _weatherController.load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_ownsWeatherController) _weatherController.dispose();
    super.dispose();
  }

  /// Fractional minutes since midnight, so the fill creeps smoothly.
  double get _nowMinutes {
    final now = DateTime.now();
    return now.hour * 60 + now.minute + now.second / 60.0;
  }

  String get _todayLabel {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[DateTime.now().weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    // Fixed day card at the top; only the planner list below scrolls.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.small,
        AppSpacing.xSmall,
        AppSpacing.small,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildDayCard(context),
          const SizedBox(height: AppSpacing.medium),
          Expanded(
            child: PlannerSection(
              nowMinutes: _nowMinutes,
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
    );
  }

  Widget _buildDayCard(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFF7FBF8),
              Color(0xFFFEFAEC),
              Color(0xFFFDF4E4),
              Color(0xFFF2EAE2),
            ],
            stops: <double>[0.0, 0.4, 0.7, 1.0],
          ),
          // Glass shell: bright hairline like light catching a frosted edge.
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.9),
            width: 1.2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF8B7355).withValues(alpha: 0.10),
              blurRadius: 18,
              spreadRadius: -6,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xLarge,
            AppSpacing.medium,
            AppSpacing.xLarge,
            AppSpacing.small,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // ── Header: name + current time + mode dropdown ──────────────
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: <Widget>[
                            const Text(
                              'Bob',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatMinutes(_nowMinutes.floor()),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black.withValues(alpha: 0.55),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _modeLabelOf(_modeId).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ModeDropdown(
                    modeId: _modeId,
                    onChanged: (id) => setState(() => _modeId = id),
                  ),
                ],
              ),

              // Tight spacing — pull tube close to header
              const SizedBox(height: 8),

              // Tube — tight hairpin, compact height
              SizedBox(
                height: 132,
                child: _DayTube(nowMinutes: _nowMinutes),
              ),
            ],
          ),
        ),
    );
  }

  String _modeLabelOf(String id) =>
      _dayModes.firstWhere((m) => m.id == id).label;
}

// ── Mode dropdown ─────────────────────────────────────────────────────────

class _ModeDropdown extends StatelessWidget {
  const _ModeDropdown({required this.modeId, required this.onChanged});

  final String modeId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = _dayModes.firstWhere((m) => m.id == modeId);
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.7),
          width: 0.8,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: modeId,
          isDense: true,
          alignment: Alignment.center,
          borderRadius: BorderRadius.circular(14),
          icon: const Padding(
            padding: EdgeInsets.only(left: 2),
            child: Icon(Icons.keyboard_arrow_down_rounded,
                size: 16, color: AppColors.primary),
          ),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
          selectedItemBuilder: (context) => _dayModes
              .map(
                (m) => Center(
                  child: Text(
                    '${m.emoji} ${m.label}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              )
              .toList(),
          items: _dayModes
              .map(
                (m) => DropdownMenuItem<String>(
                  value: m.id,
                  child: Text('${m.emoji} ${m.label}'),
                ),
              )
              .toList(),
          onChanged: (id) {
            if (id != null) onChanged(id);
          },
          hint: Text('${selected.emoji} ${selected.label}'),
        ),
      ),
    );
  }
}

// ── Day tube ──────────────────────────────────────────────────────────────

/// Left gutter reserved for the sleeping panda.
const double _sleepGutter = 44.0;

/// Builds the hairpin centerline — runs pulled close together for a tight,
/// hard bend, with breathing room on both sides.
Path _buildTubePath(Size size) {
  const padRight = 28.0;
  final topY = size.height * 0.28;
  final bottomY = size.height * 0.72;
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
  const _DayTube({required this.nowMinutes});

  final double nowMinutes;

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

  int get _wakeMinutes => SleepScheduleStore.instance.wakeMinutes;
  int get _sleepMinutes => SleepScheduleStore.instance.sleepMinutes;

  double get _progress {
    final t = (widget.nowMinutes - _wakeMinutes) /
        (_sleepMinutes - _wakeMinutes);
    return t.clamp(0.0, 1.0);
  }

  bool get _isWakeCurrent =>
      widget.nowMinutes >= _wakeMinutes &&
      widget.nowMinutes < _wakeMinutes + 3 * 60;

  bool get _isSleepCurrent =>
      widget.nowMinutes < _wakeMinutes ||
      widget.nowMinutes >= _sleepMinutes;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final path = _buildTubePath(size);
        final metric = path.computeMetrics().first;

        final nowTangent =
            metric.getTangentForOffset(metric.length * _progress);
        final nowPos = nowTangent?.position ?? Offset.zero;

        final topY = size.height * 0.28;
        final bottomY = size.height * 0.72;

        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            // Tube, ticks, progress fill, needle
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _flow,
                builder: (context, _) => CustomPaint(
                  painter: _DayTubePainter(
                    progress: _progress,
                    flowPhase: _flow.value,
                    wakeMinutes: _wakeMinutes,
                    sleepMinutes: _sleepMinutes,
                  ),
                ),
              ),
            ),

            // Wake-up box: sits just before the tube's top-left endpoint,
            // its right edge flush against startX so the tube extends
            // rightward out of it. The green matches the tube fill's morning
            // start color — continuous fill across box → tube.
            _EndpointBox(
              left: _sleepGutter - 40,
              top: topY - 20,
              size: const Size(40, 40),
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
              left: _sleepGutter - 40,
              top: bottomY - 20,
              size: const Size(40, 40),
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
              left: nowPos.dx - 17,
              top: nowPos.dy - 17,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text('🧑', style: TextStyle(fontSize: 15)),
              ),
            ),
          ],
        );
      },
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

  static const double _tubeWidth = 48;

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
    final shadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _tubeWidth
      ..strokeCap = StrokeCap.round
      ..color = Colors.black.withValues(alpha: 0.07)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.save();
    canvas.translate(0, 3);
    canvas.drawPath(path, shadow);
    canvas.restore();

    // Frosted translucent body — butt caps so ends butt against endpoint
    // boxes cleanly instead of a rounded bulge overlapping them.
    final glassBody = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _tubeWidth
      ..strokeCap = StrokeCap.butt
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.white.withOpacity(0.8),
          Colors.white.withOpacity(0.45),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, glassBody);

    // Hairline rim
    final rimLight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _tubeWidth
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.35);
    canvas.drawPath(path, rimLight);

    // Elapsed portion with day-to-night gradient — liquid inside the glass
    if (progress > 0) {
      final done = metric.extractPath(0, metric.length * progress);
      final fill = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _tubeWidth - 12
        ..strokeCap = StrokeCap.butt
        ..shader = _dayGradient().createShader(Offset.zero & size);
      canvas.drawPath(done, fill);

      // Sheen on the liquid — brightens the fill's top edge
      final sheen = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (_tubeWidth - 12) / 3
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withOpacity(0.22);
      canvas.save();
      canvas.translate(0, -(_tubeWidth - 12) / 4);
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
            ..strokeWidth = (_tubeWidth - 12) / 2.6
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withOpacity(0.16 * edgeFade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
    }

    // ── Timeline markers inside the tube — cute capsule labels ─────────
    final total = sleepMinutes - wakeMinutes;
    if (total <= 0) return;
    final wakeHour = wakeMinutes ~/ 60;
    final sleepHour = sleepMinutes ~/ 60;

    for (var m = wakeMinutes; m <= sleepMinutes; m += 60) {
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
      final t = (phase.minute - wakeMinutes) / total;
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
      final pos = tangent.position -
          Offset(tp.width / 2, tp.height / 2 + _tubeWidth / 2 - 11);
      tp.paint(canvas, pos);
    }

    // Now marker — short bright cap at the liquid's leading edge
    final nowTangent =
        metric.getTangentForOffset(metric.length * progress.clamp(0.0, 1.0));
    if (nowTangent != null) {
      final pos = nowTangent.position;
      final normal = Offset(-nowTangent.vector.dy, nowTangent.vector.dx);
      final n = normal / normal.distance;
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
      oldDelegate.flowPhase != flowPhase;
}

