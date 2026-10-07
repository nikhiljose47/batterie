import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'config/routes/app_routes.dart';
import 'config/routes/route_generator.dart';
import 'config/theme/app_theme.dart';
import 'constants/app_strings.dart';
import 'constants/app_typography.dart';
import 'pages/profile/profile_bloc.dart';
import 'pages/profile/profile_store.dart';
import 'services/theme_mode_store.dart';

class EnergyHealthApp extends StatelessWidget {
  const EnergyHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProfileBloc>(
      create: (_) => ProfileBloc(),
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeModeStore.instance.mode,
        builder: (context, mode, _) {
          return MaterialApp(
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: mode == ThemeMode.system ? ThemeMode.light : mode,
            builder: (context, child) => _SystemNavigationShield(
              child: child ?? const SizedBox.shrink(),
            ),
            initialRoute: ProfileStore.instance.onboardingComplete.value
                ? AppRoutes.home
                : AppRoutes.onboarding,
            onGenerateRoute: RouteGenerator.onGenerateRoute,
          );
        },
      ),
    );
  }
}

class _SystemNavigationShield extends StatelessWidget {
  const _SystemNavigationShield({required this.child});

  static const Color _barColor = Color(0xFFF7F9FC);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final bottomPadding = bottomInset > 0 ? 0.0 : media.viewPadding.bottom;
    final scaledMedia = media.copyWith(
      textScaler: const TextScaler.linear(AppTypography.appTextScale),
    );

    return MediaQuery(
      data: scaledMedia,
      child: Column(
        children: <Widget>[
          Expanded(child: child),
          if (bottomPadding > 0)
            SizedBox(
              height: bottomPadding,
              width: double.infinity,
              child: const ColoredBox(color: _barColor),
            ),
        ],
      ),
    );
  }
}
