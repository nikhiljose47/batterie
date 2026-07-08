import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
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

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final HomeController _controller;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _controller = HomeController();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _controller.state.selectedIndex,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _controller.updateSelectedIndex(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40,
        scrolledUnderElevation: 0,
        titleSpacing: AppSpacing.large,
        title: const Text(
          AppStrings.appName,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: AppStrings.settings,
            onPressed: _showSettingsSheet,
            icon: const Icon(Icons.settings_outlined, size: 18),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(34),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.outline)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              labelPadding: EdgeInsets.zero,
              tabs: const <Widget>[
                _ThinTab(icon: Icons.bolt_outlined, label: AppStrings.youTab),
                _ThinTab(
                    icon: Icons.groups_2_outlined, label: AppStrings.othersTab),
                _ThinTab(
                    icon: Icons.article_outlined, label: AppStrings.newsTab),
              ],
            ),
          ),
        ),
      ),
      // Swipe left/right between tabs, WhatsApp-style. The dashboard's rail
      // still scrolls fine underneath — the deepest scrollable under the
      // finger wins the gesture, so dragging on the rail scrolls the rail,
      // and dragging anywhere else changes tabs.
      body: TabBarView(
        controller: _tabController,
        children: const <Widget>[
          DashboardPage(),
          OthersPage(),
          NewsPage(),
        ],
      ),
    );
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

/// Compact icon+label tab, sized to keep the whole top bar thin.
class _ThinTab extends StatelessWidget {
  const _ThinTab({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 34,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15),
          const SizedBox(width: 5),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
