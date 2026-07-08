import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import '../../../models/person_status.dart';
import 'person_status_card.dart';

/// Horizontal row of compact status "bubbles" for people you follow —
/// a ring showing physical energy, an avatar, and a percent readout.
/// Tapping one opens the full [PersonStatusCard] in a bottom sheet.
class PersonStatusRail extends StatelessWidget {
  const PersonStatusRail({super.key, required this.people});

  final List<PersonStatus> people;

  void _openDetail(BuildContext context, PersonStatus person) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.large,
          0,
          AppSpacing.large,
          AppSpacing.xLarge,
        ),
        child: PersonStatusCard(person: person),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
      itemCount: people.length,
      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.medium),
      itemBuilder: (context, index) {
        final person = people[index];
        return GestureDetector(
          onTap: () => _openDetail(context, person),
          child: SizedBox(
            width: 66,
            child: Column(
              children: <Widget>[
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          value: person.energyPercent.clamp(0.0, 1.0),
                          strokeWidth: 3,
                          backgroundColor: AppColors.outline,
                          color: AppColors.bodyEnergy,
                        ),
                      ),
                      CircleAvatar(
                        radius: 21,
                        backgroundColor: AppColors.surfaceTint,
                        foregroundColor: AppColors.primary,
                        child: Text(
                          person.name.isEmpty
                              ? '?'
                              : person.name.substring(0, 1),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  person.name.split(' ').first,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${(person.energyPercent * 100).round()}%',
                  style:
                      const TextStyle(fontSize: 9, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
