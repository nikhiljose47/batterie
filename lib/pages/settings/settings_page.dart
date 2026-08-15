import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';
import '../../services/theme_mode_store.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.large),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.outline.withOpacity(0.55)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Appearance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose how the app should look.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface.withOpacity(0.62),
                  ),
                ),
                const SizedBox(height: 14),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeModeStore.instance.mode,
                  builder: (context, mode, _) {
                    return Column(
                      children: <Widget>[
                        _ThemeModeTile(
                          icon: Icons.brightness_auto_rounded,
                          title: 'System',
                          subtitle: 'Follow your device setting',
                          selected: mode == ThemeMode.system,
                          onTap: () =>
                              ThemeModeStore.instance.setMode(ThemeMode.system),
                        ),
                        const SizedBox(height: 8),
                        _ThemeModeTile(
                          icon: Icons.light_mode_rounded,
                          title: 'Light',
                          subtitle: 'White and clean surfaces',
                          selected: mode == ThemeMode.light,
                          onTap: () =>
                              ThemeModeStore.instance.setMode(ThemeMode.light),
                        ),
                        const SizedBox(height: 8),
                        _ThemeModeTile(
                          icon: Icons.dark_mode_rounded,
                          title: 'Dark',
                          subtitle: 'Low-light app colors',
                          selected: mode == ThemeMode.dark,
                          onTap: () =>
                              ThemeModeStore.instance.setMode(ThemeMode.dark),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selectedColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.secondary
        : AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withOpacity(0.12)
              : colors.surfaceTint.withOpacity(0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? selectedColor.withOpacity(0.55)
                : colors.outline.withOpacity(0.45),
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: selected ? selectedColor : colors.onSurface),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Icon(
                Icons.check_circle_rounded,
                color: selectedColor,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
