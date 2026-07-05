import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import '../../../models/battery_status.dart';
import '../../../shared/widgets/battery_level_widget.dart';

class BatteryCard extends StatelessWidget {
  const BatteryCard({
    super.key,
    required this.status,
  });

  final BatteryStatus status;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: SizedBox(
        height: AppSpacing.batteryHeight,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                status.title,
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Expanded(
                child: Center(
                  child: BatteryLevelWidget(
                    percent: status.percent,
                    color: status.color,
                  ),
                ),
              ),
              Text(
                status.subtitle,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
