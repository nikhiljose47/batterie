import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../engine/energy_score_engine.dart';
import '../../../models/logged_activity.dart';

/// Horizontal timeline rail with a compressed sleep zone (12 AM – 8 AM) and
/// a full-density awake zone (8 AM – 12 AM next day).
///
/// The sleep zone is squeezed to [_sleepPxPerMin] so those 8 hours take only
/// ~120 px instead of the full proportional width. The awake zone uses
/// [_awakePxPerMin] (2× the original density), giving activity cards more room.
class ActivityTimelineRail extends StatefulWidget {
  const ActivityTimelineRail({
    super.key,
    required this.activities,
    required this.onDropActivity,
    required this.onMoveActivity,
    required this.onEditRequest,
  });

  final List<LoggedActivity> activities;

  /// External chip dropped onto the rail → create a new entry.
  final void Function(String activityId, int startMinutes) onDropActivity;

  /// Existing card dragged within the rail → update its start time.
  final void Function(String loggedId, int startMinutes) onMoveActivity;

  final ValueChanged<LoggedActivity> onEditRequest;

  @override
  State<ActivityTimelineRail> createState() => _ActivityTimelineRailState();
}

class _ActivityTimelineRailState extends State<ActivityTimelineRail> {
  // ── Time-to-pixel mapping ────────────────────────────────────────────────
  static const int _sleepEndMinute = 8 * 60; // 480 — sleep zone 0 → 8 AM
  static const double _sleepPxPerMin = 0.25; // very compressed
  static const double _awakePxPerMin = 2.0; // comfortable card density
  static const double _sleepZoneW =
      _sleepEndMinute * _sleepPxPerMin; // 120 px
  static const double _awakeZoneW =
      (24 * 60 - _sleepEndMinute) * _awakePxPerMin; // 1920 px
  static const double _dayWidth = _sleepZoneW + _awakeZoneW; // 2040 px

  // ── Vertical layout (awake zone) ─────────────────────────────────────────
  static const double _railHeight = 124;
  static const double _activityTop = 8;
  static const double _activityHeight = 50;
  static const double _axisTop = 88;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  static const EnergyScoreEngine _engine = EnergyScoreEngine();

  int get _nowMinutes {
    final now = DateTime.now();
    return now.hour * 60 + now.minute;
  }

  /// Minute-of-day → x pixel on the canvas.
  double _minuteToX(int m) {
    if (m <= _sleepEndMinute) return m * _sleepPxPerMin;
    return _sleepZoneW + (m - _sleepEndMinute) * _awakePxPerMin;
  }

  /// X pixel on the canvas → minute-of-day.
  int _xToMinute(double x) {
    if (x <= _sleepZoneW) return (x / _sleepPxPerMin).round();
    return _sleepEndMinute +
        ((x - _sleepZoneW) / _awakePxPerMin).round();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = (_minuteToX(_nowMinutes) - 72)
          .clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.jumpTo(target);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Text(
              'TODAY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE5484D),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Now ${formatMinutes(_nowMinutes)}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            const Flexible(
              child: Text(
                'hold & drag to move',
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 9, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: _railHeight,
          child: DragTarget<String>(
            onAcceptWithDetails: _handleDrop,
            builder: (context, candidates, _) {
              final isHovering = candidates.isNotEmpty;
              return Container(
                key: _viewportKey,
                decoration: BoxDecoration(
                  color: isHovering
                      ? AppColors.surfaceTint
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isHovering
                        ? AppColors.primary
                        : AppColors.outline,
                    width: isHovering ? 1.5 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: _dayWidth,
                    height: _railHeight,
                    child: Stack(
                      children: <Widget>[
                        _buildSleepBlock(),
                        ..._buildHourMarks(),
                        ..._buildActivityCards(),
                        _buildNowLine(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _handleDrop(DragTargetDetails<String> details) {
    final box =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.offset);
    final rawMinutes =
        _xToMinute(local.dx + _scrollController.offset);
    final snapped =
        ((rawMinutes / 15).round() * 15).clamp(0, 1425);

    final data = details.data;
    if (data.startsWith('move:')) {
      widget.onMoveActivity(data.substring(5), snapped);
    } else {
      widget.onDropActivity(data, snapped);
    }
  }

  // ── Sleep block — full-height night zone ───────────────────────────────

  // Fixed star dot positions: (x, y, diameter) within the 120 × 124 block.
  static const List<(double, double, double)> _stars = <(double, double, double)>[
    (8.0, 10.0, 2.5),
    (38.0, 5.0, 1.8),
    (72.0, 14.0, 2.2),
    (105.0, 8.0, 1.6),
    (18.0, 42.0, 1.4),
    (55.0, 34.0, 2.0),
    (95.0, 50.0, 1.8),
    (28.0, 72.0, 1.6),
    (82.0, 78.0, 2.4),
    (10.0, 95.0, 1.4),
    (60.0, 105.0, 1.8),
    (100.0, 98.0, 1.2),
  ];

  Widget _buildSleepBlock() {
    return Positioned(
      left: 0,
      top: 0,
      width: _sleepZoneW,
      bottom: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF0D0F2B), Color(0xFF1A1C4A)],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: <Widget>[
            // Star field
            for (final s in _stars)
              Positioned(
                left: s.$1,
                top: s.$2,
                child: Container(
                  width: s.$3,
                  height: s.$3,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

            // Central content
            const Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('🌙', style: TextStyle(fontSize: 18)),
                  SizedBox(height: 2),
                  Text('🦉', style: TextStyle(fontSize: 13)),
                  SizedBox(height: 5),
                  Text(
                    'Sleep',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFAAAED6),
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    '12 AM – 8 AM',
                    style: TextStyle(
                      fontSize: 7,
                      color: Color(0xFF6B6F9A),
                    ),
                  ),
                ],
              ),
            ),

            // Right-edge separator
            const Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: SizedBox(
                width: 1,
                child: ColoredBox(color: Color(0xFF3A3D6E)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hour axis — awake zone only (8 AM → 12 AM) ─────────────────────────

  List<Widget> _buildHourMarks() {
    final marks = <Widget>[];
    for (var hour = 8; hour <= 24; hour++) {
      final x = _minuteToX(hour * 60);
      final isMajor = hour % 2 == 0;
      marks.add(Stack(
        children: <Widget>[
          Positioned(
            left: x,
            top: isMajor ? _axisTop : _axisTop + 5,
            child: Container(
              width: 1,
              height: isMajor ? 12 : 7,
              color: isMajor ? AppColors.textMuted : AppColors.outline,
            ),
          ),
          if (isMajor)
            Positioned(
              left: (x - 18).clamp(0.0, _dayWidth - 40),
              top: _axisTop + 16,
              child: SizedBox(
                width: 40,
                child: Text(
                  _hourLabel(hour),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
        ],
      ));
    }
    return marks;
  }

  // ── Now indicator ────────────────────────────────────────────────────────

  Widget _buildNowLine() {
    final x = _minuteToX(_nowMinutes);
    return Positioned(
      left: x - 1,
      top: 0,
      bottom: 0,
      child: Column(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFE5484D),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(width: 2, color: const Color(0xFFE5484D)),
          ),
        ],
      ),
    );
  }

  // ── Activity cards ───────────────────────────────────────────────────────

  List<Widget> _buildActivityCards() {
    return widget.activities.map((logged) {
      final activity = _engine.activityById(logged.activityId);
      final isGain = activity.physicalDelta + activity.brainDelta > 0;
      final accent = isGain
          ? AppColors.energyBrainAccent
          : AppColors.energyPhysicalAccent;

      final left = _minuteToX(logged.startMinutes);
      final right =
          _minuteToX(logged.startMinutes + logged.durationMinutes);
      final width = (right - left).clamp(64.0, _dayWidth);

      final card = Container(
        width: width,
        height: _activityHeight,
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isGain
              ? AppColors.energyBrainBg
              : AppColors.energyPhysicalBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              '${activityEmojis[logged.activityId] ?? '⚡'} ${activity.name}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${formatMinutes(logged.startMinutes)} · ${logged.durationMinutes} min',
              style: TextStyle(
                fontSize: 9,
                color: accent.withValues(alpha: 0.75),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );

      return Positioned(
        left: left,
        top: _activityTop,
        child: LongPressDraggable<String>(
          data: 'move:${logged.id}',
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(opacity: 0.85, child: card),
          ),
          childWhenDragging: Opacity(opacity: 0.28, child: card),
          child: GestureDetector(
            onTap: () => widget.onEditRequest(logged),
            child: card,
          ),
        ),
      );
    }).toList();
  }

  String _hourLabel(int hour) {
    final h = hour % 24;
    if (h == 0) return '12 AM';
    if (h == 12) return '12 PM';
    return h < 12 ? '$h AM' : '${h - 12} PM';
  }
}
