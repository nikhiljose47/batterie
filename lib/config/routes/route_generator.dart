import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../models/news_article.dart';
import '../../pages/home/home_page.dart';
import '../../pages/news/news_detail_page.dart';
import 'app_routes.dart';

class RouteGenerator {
  const RouteGenerator._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return MaterialPageRoute<void>(
          builder: (_) => const HomePage(),
          settings: settings,
        );
      case AppRoutes.newsDetail:
        final arguments = settings.arguments;
        if (arguments is NewsArticle) {
          return MaterialPageRoute<void>(
            builder: (_) => NewsDetailPage(article: arguments),
            settings: settings,
          );
        }

        return _errorRoute(AppStrings.routeArgumentError);
      default:
        return _errorRoute(AppStrings.routeNotFound);
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text(AppStrings.appName)),
        body: Center(child: Text(message)),
      ),
    );
  }
}
