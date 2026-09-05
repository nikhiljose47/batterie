import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../constants/avatar_constants.dart';

class GoalPeopleStrip extends StatelessWidget {
  const GoalPeopleStrip({
    super.key,
    required this.count,
    this.avatarSize = 28,
    this.overlap = 16,
    this.textStyle,
    this.compact = false,
  });

  final int count;
  final double avatarSize;
  final double overlap;
  final TextStyle? textStyle;
  final bool compact;

  int get _safeCount => count.clamp(2, 999).toInt();
  int get _avatarCount => _safeCount.clamp(2, 4).toInt();

  String get _label {
    if (compact) return '$_safeCount using';
    final firstName = AvatarConstants.samplePeopleNames.first;
    final others = _safeCount - 1;
    return others == 1 ? '$firstName + 1 other' : '$firstName + $others others';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: avatarSize + (_avatarCount - 1) * overlap,
          height: avatarSize,
          child: Stack(
            children: <Widget>[
              for (var i = 0; i < _avatarCount; i++)
                Positioned(
                  left: i * overlap,
                  child: Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: colors.shadow.withOpacity(0.08),
                          blurRadius: 5,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    foregroundDecoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.surface, width: 2),
                    ),
                    child: ClipOval(
                      child: SizedBox.expand(
                        child: SvgPicture.asset(
                          AvatarConstants.assetPath(
                            AvatarConstants
                                .avatars[i % AvatarConstants.avatars.length],
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle ??
                TextStyle(
                  color: colors.onSurface.withOpacity(0.82),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ],
    );
  }
}
