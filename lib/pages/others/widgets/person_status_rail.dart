import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import '../../../constants/avatar_constants.dart';
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
          width: 68,
          child: Column(
            children: <Widget>[
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.outline.withOpacity(0.22),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.surfaceTint,
                        child: ClipOval(
                          child: SizedBox.expand(
                            child: SvgPicture.asset(
                              AvatarConstants.assetPath(
                                AvatarConstants.defaultAvatarId,
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.primary, width: 2),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: colors.shadow.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          '$score',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: score >= 100 ? 8 : 9,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
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
            ],
          ),
        );
      },
    );
  }
}
