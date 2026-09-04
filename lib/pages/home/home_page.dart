import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../constants/article_constants.dart';
import '../../constants/app_spacing.dart';
import '../../constants/app_strings.dart';
import '../../repositories/energy_health_repository.dart';
import '../../shared/widgets/energy_score_pill.dart';
import '../../shared/widgets/profile_avatar.dart';
import '../auth/auth_page.dart';
import '../dev/data_inspector_page.dart';
import '../home_tab/home_tab_page.dart';
import '../news/news_page.dart';
import '../others/others_page.dart';
import '../profile/profile_page.dart';
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
  late final TabController _tabController;
  Timer? _articlePreloadTimer;
  int _homeRefreshToken = 0;
  int _othersRefreshToken = 0;
  int _energyScore = 0;
  Offset? _swipeStart;
  Offset? _swipeLatest;

  /// Shared with the Home tab so the top-bar location chip and the planner
  /// weather read from the same snapshot.
  late final WeatherController _weatherController;

  @override
  void initState() {
    super.initState();
    _controller = HomeController();
    _weatherController = WeatherController()..load();
    final initialIndex = _controller.state.selectedIndex.clamp(0, 2) as int;
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _controller.updateSelectedIndex(_tabController.index);
        if (!mounted) return;
        if (_tabController.index == 0) {
          setState(() => _homeRefreshToken++);
        } else if (_tabController.index == 1) {
          setState(() => _othersRefreshToken++);
        }
      }
    });
    _articlePreloadTimer = Timer(
      const Duration(seconds: 4),
      _preloadArticleImages,
    );
  }

  @override
  void dispose() {
    _articlePreloadTimer?.cancel();
    _tabController.dispose();
    _weatherController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _preloadArticleImages() async {
    if (!mounted) return;
    try {
      final articles = await const EnergyHealthRepository().getNewsArticles();
      if (!mounted) return;
      final urls = articles
          .take(ArticleConstants.preloadArticleCount)
          .map(ArticleConstants.webImageForArticle)
          .whereType<String>()
          .where((url) => url.isNotEmpty)
          .toSet();
      for (final url in urls) {
        if (!mounted) return;
        await precacheImage(NetworkImage(url), context);
      }
    } catch (_) {
      // Article loading is non-critical; the Articles tab keeps its own
      // local image fallback if a warm-up request fails.
    }
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
          StreamBuilder<User?>(
            stream: _authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.data != null) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AuthPage()),
                ),
                child: const Text('Sign in'),
              );
            },
          ),
          const SizedBox(width: 4),
          _EnergyScoreChip(score: _energyScore),
          const SizedBox(width: 4),
          InkWell(
            onTap: _openProfilePage,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.medium),
              child: ProfileAvatar(
                radius: 14,
                backgroundColor: colors.surfaceTint,
                iconSize: 17,
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
                  icon: Icons.stacked_line_chart_rounded,
                  label: AppStrings.statusTab,
                ),
                _ThinTab(
                  icon: Icons.article_outlined,
                  label: AppStrings.articlesTab,
                ),
              ],
            ),
          ),
        ),
      ),
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          _swipeStart = event.position;
          _swipeLatest = event.position;
        },
        onPointerMove: (event) => _swipeLatest = event.position,
        onPointerUp: (_) => _handleBodySwipe(),
        onPointerCancel: (_) {
          _swipeStart = null;
          _swipeLatest = null;
        },
        child: TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(),
          children: <Widget>[
            HomeTabPage(
              weatherController: _weatherController,
              refreshToken: _homeRefreshToken,
              onEnergyScoreChanged: (score) {
                if (!mounted || score == _energyScore) return;
                setState(() => _energyScore = score);
              },
            ),
            OthersPage(refreshToken: _othersRefreshToken),
            const NewsPage(),
          ],
        ),
      ),
    );
  }

  void _handleBodySwipe() {
    final start = _swipeStart;
    final end = _swipeLatest;
    _swipeStart = null;
    _swipeLatest = null;
    if (start == null || end == null) return;

    final delta = end - start;
    final dx = delta.dx;
    final dy = delta.dy;
    const minHorizontalDistance = 72.0;
    const maxVerticalToHorizontalRatio = 1.43; // about +/-55 degrees
    if (dx.abs() < minHorizontalDistance) return;
    if (dy.abs() / dx.abs() > maxVerticalToHorizontalRatio) return;

    final nextIndex =
        dx < 0 ? _tabController.index + 1 : _tabController.index - 1;
    if (nextIndex < 0 || nextIndex >= _tabController.length) return;
    _tabController.animateTo(nextIndex);
  }

  Stream<User?> _authStateChanges() {
    if (Firebase.apps.isEmpty) return const Stream<User?>.empty();
    return FirebaseAuth.instance.authStateChanges();
  }

  void _openProfilePage() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const ProfilePage(),
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

class _EnergyScoreChip extends StatelessWidget {
  const _EnergyScoreChip({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return EnergyScorePill(score: score, height: 26, compact: true);
  }
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
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
