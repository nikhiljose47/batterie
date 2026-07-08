import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.large),
        children: const <Widget>[
          _ProfileHeader(),
          SizedBox(height: AppSpacing.large),
          _InfoTile(
            icon: Icons.cake_outlined,
            label: 'Age',
            value: '28',
          ),
          _InfoTile(
            icon: Icons.public_rounded,
            label: 'Country',
            value: 'India',
          ),
          _InfoTile(
            icon: Icons.monitor_heart_outlined,
            label: 'Details',
            value:
                'Uses sleep, activity, stress, pain, heat, and fitness signals to estimate physical and brain readiness.',
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.large),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.outline),
      ),
      child: const Row(
        children: <Widget>[
          CircleAvatar(
            radius: 34,
            backgroundColor: AppColors.surfaceTint,
            child: Icon(
              Icons.person_rounded,
              size: 34,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: AppSpacing.large),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Nikhil',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: AppSpacing.xSmall),
                Text(
                  'Energy Health profile',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.small),
      child: ListTile(
        tileColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          side: const BorderSide(color: AppColors.outline),
        ),
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label),
        subtitle: Text(value),
      ),
    );
  }
}
