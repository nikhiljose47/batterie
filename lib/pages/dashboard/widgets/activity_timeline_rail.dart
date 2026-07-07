import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../constants/app_colors.dart';
import '../../../engine/energy_score_engine.dart';
import '../../../models/logged_activity.dart';

/// Horizontal 24-hour rail. Auto-scrolls so "now" sits near the left edge,
/// shows a live now-indicator, renders logged activities as editable cards,
/// and accepts quick-log chips via drag-and-drop.
class ActivityTimelineRail extends StatefulWidget {
  const ActivityTimelineRail({
    super.key,
    required this.activities,
    required this.onDropActivity,
    required this.onEditRequest,
    required this.onAdjustDuration,
  });

  final List<LoggedActivity> activities;

  /// Called when a chip is dropped: (activityId, startMinutes).
  final void Function(String activityId, int startMinutes) onDropActivity;
  final ValueChanged<LoggedActivity> onEditRequest;

  /// Called on hold (+30) or double-tap (−30): (activity, deltaMinutes).
  final void Function(LoggedActivity activity, int deltaMinutes)
      onAdjustDuration;

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
            // Now indication (left side of the rail header)
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
              'tap edit · hold +30m · 2×tap −30m',
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
    widget.onDropActivity(details.data, snapped);
  }

  List<Widget> _buildHourMarks() {
    return List<Widget>.generate(25, (hour) {
      final x = hour * 60 * _pixelsPerMinute;
      final showLabel = hour % 3 == 0;
      return Positioned(
        left: x,
        bottom: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 1,
              height: showLabel ? 10 : 6,
              color: AppColors.outline,
            ),
            if (showLabel)
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 2),
                child: Text(
                  _hourLabel(hour),
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.textMuted,
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

      return Positioned(
        left: logged.startMinutes * _pixelsPerMinute,
        top: 6,
        child: GestureDetector(
          onTap: () => widget.onEditRequest(logged),
          onLongPress: () {
            HapticFeedback.mediumImpact();
            widget.onAdjustDuration(logged, 30);
          },
          onDoubleTap: () {
            HapticFeedback.lightImpact();
            widget.onAdjustDuration(logged, -30);
          },
          child: Container(
            width: width,
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color:
                  isGain ? AppColors.energyBrainBg : AppColors.energyPhysicalBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withOpacity(0.4)),
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
                    color: accent.withOpacity(0.75),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
