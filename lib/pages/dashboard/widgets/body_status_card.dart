import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import '../../../constants/app_strings.dart';
import '../../../models/body_status.dart';

class BodyStatusCard extends StatelessWidget {
  const BodyStatusCard({
    super.key,
    required this.bodyStatus,
  });

  final BodyStatus bodyStatus;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              AppStrings.currentBodyStatus,
              style: textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.medium),
            Text(bodyStatus.status, style: textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.large),
            _StatusLine(
              title: AppStrings.potentialToday,
              message: bodyStatus.potential,
            ),
            const SizedBox(height: AppSpacing.medium),
            _StatusLine(
              title: AppStrings.whatYouDidEarlier,
              message: bodyStatus.previousActivity,
            ),
            const SizedBox(height: AppSpacing.medium),
            _StatusLine(
              title: AppStrings.notAlone,
              message: bodyStatus.supportNote,
            ),
            const SizedBox(height: AppSpacing.medium),
            Wrap(
              spacing: AppSpacing.xSmall,
              runSpacing: AppSpacing.xSmall,
              children: bodyStatus.recommendedActions
                  .map(
                    (action) => Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(action),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: textTheme.labelLarge?.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xSmall),
        Text(message),
      ],
    );
  }
}
