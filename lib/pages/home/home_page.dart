import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../constants/app_strings.dart';
import '../dashboard/dashboard_page.dart';
import '../news/news_page.dart';
import '../others/others_page.dart';
import 'home_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HomeController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 48,
            scrolledUnderElevation: 0,
            title: const Text(
              AppStrings.appName,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            actions: <Widget>[
              IconButton(
                tooltip: AppStrings.settings,
                onPressed: _showSettingsSheet,
                icon: const Icon(Icons.settings_outlined, size: 20),
              ),
            ],
          ),
          body: _buildSelectedPage(_controller.state.selectedIndex),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _controller.state.selectedIndex,
            onTap: _controller.updateSelectedIndex,
            iconSize: AppSpacing.bottomNavigationIconSize,
            selectedFontSize: 10,
            unselectedFontSize: 10,
            type: BottomNavigationBarType.fixed,
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.bolt_outlined),
                label: AppStrings.youTab,
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.groups_2_outlined),
                label: AppStrings.othersTab,
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.article_outlined),
                label: AppStrings.newsTab,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectedPage(int selectedIndex) {
    switch (selectedIndex) {
      case 1:
        return const OthersPage();
      case 2:
        return const NewsPage();
      case 0:
      default:
        return const DashboardPage();
    }
  }

  void _showSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.xLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                AppStrings.settings,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.medium),
              const Text(AppStrings.settingsMessage),
            ],
          ),
        );
      },
    );
  }
}
