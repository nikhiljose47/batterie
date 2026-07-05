import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import '../../../constants/app_strings.dart';
import '../../../models/person_status.dart';

class PersonStatusCard extends StatelessWidget {
  const PersonStatusCard({
    super.key,
    required this.person,
  });

  final PersonStatus person;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: AppColors.surfaceTint,
                  foregroundColor: AppColors.primary,
                  child: Text(person.name.substring(0, 1)),
                ),
                const SizedBox(width: AppSpacing.medium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(person.name, style: textTheme.titleMedium),
                      Text(
                        person.role,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.large),
            _MetricBar(
              label: AppStrings.bodyMetric,
              value: person.energyPercent,
              color: AppColors.bodyEnergy,
            ),
            const SizedBox(height: AppSpacing.medium),
            _MetricBar(
              label: AppStrings.brainMetric,
              value: person.brainPercent,
              color: AppColors.brainEnergy,
            ),
            const SizedBox(height: AppSpacing.large),
            Text(person.note),
          ],
        ),
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percentLabel = '${(value * 100).round()}%';

    return Row(
      children: <Widget>[
        SizedBox(
          width: AppSpacing.metricLabelWidth,
          child: Text(label),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            child: LinearProgressIndicator(
              value: value,
              minHeight: AppSpacing.small,
              color: color,
              backgroundColor: AppColors.outline,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.medium),
        SizedBox(
          width: AppSpacing.metricValueWidth,
          child: Text(
            percentLabel,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
