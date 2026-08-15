import 'package:flutter/material.dart';

import 'config/routes/app_routes.dart';
import 'config/routes/route_generator.dart';
import 'config/theme/app_theme.dart';
import 'constants/app_strings.dart';
import 'services/theme_mode_store.dart';

class EnergyHealthApp extends StatelessWidget {
  const EnergyHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeModeStore.instance.mode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: AppStrings.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          initialRoute: AppRoutes.home,
          onGenerateRoute: RouteGenerator.onGenerateRoute,
        );
      },
    );
  }
}
