import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../constants/app_strings.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/dashboard_page.dart';
import '../dev/data_inspector_page.dart';
import '../home_tab/home_tab_page.dart';
import '../news/news_page.dart';
import '../others/others_page.dart';
import '../profile/profile_page.dart';
import '../profile/templates_page.dart';
import '../settings/settings_page.dart';
import '../services/services_page.dart';
import '../weather/weather_controller.dart';
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

  /// Shared with the Home tab so the top-bar location chip and the planner
  /// weather read from the same snapshot.
  late final WeatherController _weatherController;

  @override
  void initState() {
    super.initState();
    _controller = HomeController();
    _dashboardController = DashboardController()..load();
    _weatherController = WeatherController()..load();
    _tabController = TabController(
      length: 4,
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
    _weatherController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
          // Services hub — all the mini-apps (trackers, calculators…).
          InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ServicesPage()),
            ),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.widgets_outlined,
                size: 19,
                color: colors.onSurface.withOpacity(0.58),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Location chip — "Location off" until we have a fix, then the
          // short lat,lon code. Tapping re-requests / refreshes.
          _LocationChip(controller: _weatherController),
          const SizedBox(width: 6),
          // Test-tube: pick a data store, land on the inspector page.
          PopupMenuButton<InspectorSource>(
            tooltip: 'Inspect app data',
            offset: const Offset(0, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            ),
            onSelected: (source) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DataInspectorPage(source: source),
                ),
              );
            },
            itemBuilder: (context) => <PopupMenuEntry<InspectorSource>>[
              for (final source in InspectorSource.values)
                PopupMenuItem<InspectorSource>(
                  value: source,
                  child: _ProfileMenuItem(
                    icon: source.icon,
                    label: source.label,
                  ),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.science_outlined,
                size: 19,
                color: colors.onSurface.withOpacity(0.58),
              ),
            ),
          ),
          const SizedBox(width: 4),
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
              PopupMenuItem<_ProfileMenuAction>(
                value: _ProfileMenuAction.settings,
                child: _ProfileMenuItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.medium),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: colors.surfaceTint,
                child: Icon(
                  Icons.person_rounded,
                  size: 17,
                  color: colors.primary,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                bottom: BorderSide(color: colors.outline.withOpacity(0.6)),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: colors.primary,
              indicatorWeight: 2,
              labelColor: colors.primary,
              unselectedLabelColor: colors.onSurface.withOpacity(0.58),
              labelPadding: EdgeInsets.zero,
              tabs: const <Widget>[
                _ThinTab(icon: Icons.home_outlined, label: AppStrings.homeTab),
                _ThinTab(
                    icon: Icons.update_rounded, label: AppStrings.updatesTab),
                _ThinTab(icon: Icons.bolt_outlined, label: AppStrings.youTab),
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
          HomeTabPage(weatherController: _weatherController),
          const OthersPage(),
          DashboardPage(controller: _dashboardController),
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
      _ProfileMenuAction.settings => const SettingsPage(),
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
  settings,
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
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: colors.onSurface.withOpacity(0.62)),
        const SizedBox(width: AppSpacing.medium),
        Text(label),
      ],
    );
  }
}

/// Top-bar chip reflecting location state: red-tinted "Location off" when
/// we can't get a fix, green chip with the lat,lon short code when we can.
/// Tapping always retries/refreshes.
class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.controller});

  final WeatherController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        final location = state.snapshot?.location;

        final bool isOff = location == null &&
            (state.status == WeatherStatus.permissionDenied ||
                state.status == WeatherStatus.permissionDeniedForever ||
                state.status == WeatherStatus.serviceDisabled ||
                state.status == WeatherStatus.error);

        final String label;
        final Color fg;
        final Color bg;
        if (location != null) {
          label = location.placeLabel ??
              '${location.latitude.toStringAsFixed(1)}°,'
                  '${location.longitude.toStringAsFixed(1)}°';
          fg = colors.primary;
          bg = colors.primary.withOpacity(0.12);
        } else if (isOff) {
          label = 'Location off';
          fg = colors.error;
          bg = colors.error.withOpacity(0.12);
        } else {
          label = 'Locating…';
          fg = colors.onSurface.withOpacity(0.62);
          bg = colors.surfaceTint;
        }

        final needsPermission =
            state.status == WeatherStatus.permissionDenied ||
                state.status == WeatherStatus.permissionDeniedForever;
        return InkWell(
          onTap: needsPermission
              ? controller.requestPermissionAndLoad
              : controller.refresh,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: fg.withOpacity(0.35),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  location != null
                      ? Icons.location_on_rounded
                      : Icons.location_off_rounded,
                  size: 12,
                  color: fg,
                ),
                const SizedBox(width: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
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
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
