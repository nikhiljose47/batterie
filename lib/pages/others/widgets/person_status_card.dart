import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
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
    final score = person.scorePercent ?? (person.energyPercent * 100).round();
    final goalTotal = person.goalTotalCount ?? 0;
    final goalDone = person.goalDoneCount ?? 0;
    final goalValue = goalTotal == 0 ? 0.0 : goalDone / goalTotal;
    final appUseValue = ((person.appUseMinutes ?? 0) / 45).clamp(0.0, 1.0);
    final focusValue = ((person.focusMinutes ?? 0) / 60).clamp(0.0, 1.0);

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
              label: 'Daily score',
              value: score / 100,
              color: AppColors.bodyEnergy,
            ),
            const SizedBox(height: AppSpacing.medium),
            _MetricBar(
              label: 'Goal done',
              value: goalValue,
              color: AppColors.brainEnergy,
            ),
            const SizedBox(height: AppSpacing.medium),
            _MetricBar(
              label: 'App use',
              value: appUseValue,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.medium),
            _MetricBar(
              label: 'Focus use',
              value: focusValue,
              color: const Color(0xFF4F7FE5),
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
