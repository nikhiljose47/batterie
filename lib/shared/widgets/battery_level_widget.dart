import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';

enum BatteryOrientation {
  horizontal,
  vertical,
}

class BatteryLevelWidget extends StatelessWidget {
  const BatteryLevelWidget({
    super.key,
    required this.percent,
    required this.color,
    this.orientation = BatteryOrientation.vertical,
    this.width = AppSpacing.batteryMeterWidth,
    this.height = AppSpacing.batteryMeterHeight,
    this.showPercent = true,
  });

  final double percent;
  final Color color;
  final BatteryOrientation orientation;
  final double width;
  final double height;
  final bool showPercent;

  @override
  Widget build(BuildContext context) {
    final normalizedPercent = percent.clamp(0.0, 1.0).toDouble();

    return orientation == BatteryOrientation.vertical
        ? _VerticalBatteryLevel(
            percent: normalizedPercent,
            color: color,
            width: width,
            height: height,
            showPercent: showPercent,
          )
        : _HorizontalBatteryLevel(
            percent: normalizedPercent,
            color: color,
            width: width,
            height: height,
            showPercent: showPercent,
          );
  }
}

class _VerticalBatteryLevel extends StatelessWidget {
  const _VerticalBatteryLevel({
    required this.percent,
    required this.color,
    required this.width,
    required this.height,
    required this.showPercent,
  });

  final double percent;
  final Color color;
  final double width;
  final double height;
  final bool showPercent;

  @override
  Widget build(BuildContext context) {
    final capWidth = width * 0.42;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: capWidth,
          height: AppSpacing.small,
          decoration: const BoxDecoration(
            color: AppColors.outline,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusSmall),
            ),
          ),
        ),
        Container(
          width: width,
          height: height,
          padding: const EdgeInsets.all(AppSpacing.xSmall),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(color: AppColors.outline, width: 2),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                const ColoredBox(color: AppColors.batteryTrack),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                    widthFactor: 1,
                    heightFactor: percent,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSmall),
                      ),
                    ),
                  ),
                ),
                if (showPercent)
                  Text(
                    '${(percent * 100).round()}%',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HorizontalBatteryLevel extends StatelessWidget {
  const _HorizontalBatteryLevel({
    required this.percent,
    required this.color,
    required this.width,
    required this.height,
    required this.showPercent,
  });

  final double percent;
  final Color color;
  final double width;
  final double height;
  final bool showPercent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: width,
          height: height,
          padding: const EdgeInsets.all(AppSpacing.xSmall),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(color: AppColors.outline, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                const ColoredBox(color: AppColors.batteryTrack),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                    widthFactor: percent,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSmall),
                      ),
                    ),
                  ),
                ),
                if (showPercent)
                  Text(
                    '${(percent * 100).round()}%',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
              ],
            ),
          ),
        ),
        Container(
          width: AppSpacing.small,
          height: height * 0.42,
          decoration: const BoxDecoration(
            color: AppColors.outline,
            borderRadius: BorderRadius.horizontal(
              right: Radius.circular(AppSpacing.radiusSmall),
            ),
          ),
        ),
      ],
    );
  }
}
