import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../constants/app_colors.dart';
import '../../pages/profile/profile_bloc.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    this.radius = 16,
    this.iconSize,
    this.border,
    this.backgroundColor,
  });

  final double radius;
  final double? iconSize;
  final BoxBorder? border;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ProfileBloc, ProfileState, String?>(
      selector: (state) => state.photoPath,
      builder: (context, path) {
        final hasPhoto = path != null && File(path).existsSync();
        final avatar = CircleAvatar(
          key: ValueKey<String?>(path),
          radius: radius,
          backgroundColor: backgroundColor ?? AppColors.surfaceTint,
          backgroundImage: hasPhoto ? FileImage(File(path)) : null,
          child: hasPhoto
              ? null
              : Icon(
                  Icons.person_rounded,
                  size: iconSize ?? radius * 1.2,
                  color: AppColors.primary,
                ),
        );

        if (border == null) return avatar;

        return Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: border,
          ),
          child: avatar,
        );
      },
    );
  }
}
