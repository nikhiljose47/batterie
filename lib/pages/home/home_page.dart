import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';
import '../../constants/app_strings.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/dashboard_page.dart';
import '../news/news_page.dart';
import '../others/others_page.dart';
import '../profile/profile_page.dart';
import '../profile/templates_page.dart';
import 'home_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final HomeController _controller;
  late final DashboardController _dashboardController;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _controller = HomeController();
    _dashboardController = DashboardController()..load();
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
    _dashboardController.dispose();
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
          PopupMenuButton<_ProfileMenuAction>(
            tooltip: 'Profile',
            offset: const Offset(0, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            ),
            onSelected: _handleProfileMenu,
            itemBuilder: (context) =>
                const <PopupMenuEntry<_ProfileMenuAction>>[
              PopupMenuItem<_ProfileMenuAction>(
                value: _ProfileMenuAction.profile,
                child: _ProfileMenuItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                ),
              ),
              PopupMenuItem<_ProfileMenuAction>(
                value: _ProfileMenuAction.templates,
                child: _ProfileMenuItem(
                  icon: Icons.view_list_outlined,
                  label: 'Templates',
                ),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.only(right: AppSpacing.medium),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.surfaceTint,
                child: Icon(
                  Icons.person_rounded,
                  size: 17,
                  color: AppColors.primary,
                ),
              ),
            ),
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
        children: <Widget>[
          DashboardPage(controller: _dashboardController),
          const OthersPage(),
          const NewsPage(),
        ],
      ),
    );
  }

  void _handleProfileMenu(_ProfileMenuAction action) {
    final page = switch (action) {
      _ProfileMenuAction.profile => const ProfilePage(),
      _ProfileMenuAction.templates =>
        TemplatesPage(controller: _dashboardController),
    };

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
          final offset = Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));

          return SlideTransition(
            position: animation.drive(offset),
            child: child,
          );
        },
      ),
    );
  }
}

enum _ProfileMenuAction {
  profile,
  templates,
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.medium),
        Text(label),
      ],
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
