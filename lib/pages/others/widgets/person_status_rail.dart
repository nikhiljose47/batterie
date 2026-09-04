import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import '../../../models/person_status.dart';

class PersonStatusRail extends StatelessWidget {
  const PersonStatusRail({super.key, required this.people});

  final List<PersonStatus> people;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
      itemCount: people.length,
      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.medium),
      itemBuilder: (context, index) {
        final person = people[index];
        final score =
            person.scorePercent ?? (person.energyPercent * 100).round();
        return SizedBox(
          width: 70,
          child: Column(
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.outline.withOpacity(0.22)),
                ),
                alignment: Alignment.center,
                child: CircleAvatar(
                  radius: 21,
                  backgroundColor: AppColors.surfaceTint,
                  foregroundColor: AppColors.primary,
                  child: Text(
                    person.name.isEmpty ? '?' : person.name.substring(0, 1),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                person.name.split(' ').first,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Container(
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.18),
                  ),
                ),
                child: Text(
                  'eScore $score',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
