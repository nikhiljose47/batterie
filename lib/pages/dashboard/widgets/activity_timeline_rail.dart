import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../engine/energy_score_engine.dart';
import '../../../models/logged_activity.dart';

/// Horizontal 24-hour rail. Auto-scrolls so "now" sits near the left edge,
/// shows a live now-indicator, renders logged activities as draggable cards,
/// and accepts quick-log chips via drag-and-drop from outside the rail.
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
  static const double _pixelsPerMinute = 1.2;
  static const double _dayWidth = 24 * 60 * _pixelsPerMinute;
  static const double _railHeight = 92;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  static const EnergyScoreEngine _engine = EnergyScoreEngine();

  int get _nowMinutes {
    final now = DateTime.now();
    return now.hour * 60 + now.minute;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = (_nowMinutes * _pixelsPerMinute - 72)
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
            const Text(
              'tap edit · hold & drag to move',
              style: TextStyle(fontSize: 9, color: AppColors.textMuted),
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
                  color: isHovering ? AppColors.surfaceTint : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isHovering ? AppColors.primary : AppColors.outline,
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
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.offset);
    final minutes =
        ((local.dx + _scrollController.offset) / _pixelsPerMinute).round();
    // Snap to 15-minute steps
    final snapped = ((minutes / 15).round() * 15).clamp(0, 1425);

    final data = details.data;
    if (data.startsWith('move:')) {
      // Internal card drag — just update the start time
      widget.onMoveActivity(data.substring(5), snapped);
    } else {
      // External chip drop — create a new logged entry
      widget.onDropActivity(data, snapped);
    }
  }

  /// Tick + label for every hour. Major ticks at 0 / 6 / 12 / 18 are taller
  /// and labelled in a slightly larger font for orientation.
  List<Widget> _buildHourMarks() {
    return List<Widget>.generate(25, (hour) {
      final x = hour * 60 * _pixelsPerMinute;
      final isMajor = hour % 6 == 0;
      return Positioned(
        left: x,
        bottom: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 1,
              height: isMajor ? 10 : 6,
              color: isMajor ? AppColors.textMuted : AppColors.outline,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 2),
              child: Text(
                _hourLabel(hour),
                style: TextStyle(
                  fontSize: isMajor ? 9 : 8,
                  color: isMajor ? AppColors.textMuted : AppColors.outline,
                  fontWeight: isMajor ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildNowLine() {
    final x = _nowMinutes * _pixelsPerMinute;
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

  List<Widget> _buildActivityCards() {
    return widget.activities.map((logged) {
      final activity = _engine.activityById(logged.activityId);
      final isGain = activity.physicalDelta + activity.brainDelta > 0;
      final accent =
          isGain ? AppColors.energyBrainAccent : AppColors.energyPhysicalAccent;
      final width =
          (logged.durationMinutes * _pixelsPerMinute).clamp(64.0, _dayWidth);

      final card = Container(
        width: width,
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isGain ? AppColors.energyBrainBg : AppColors.energyPhysicalBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha:0.4)),
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
                color: accent.withValues(alpha:0.75),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );

      return Positioned(
        left: logged.startMinutes * _pixelsPerMinute,
        top: 6,
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
    if (h == 0) return '12a';
    if (h == 12) return '12p';
    return h < 12 ? '${h}a' : '${h - 12}p';
  }
}
