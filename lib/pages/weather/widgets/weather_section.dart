import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../constants/app_spacing.dart';
import '../../../models/weather.dart';
import '../weather_controller.dart';

/// Complete Material 3 weather module — current strip + details grid +
/// 7-day forecast, plus permission and error states.
class WeatherSection extends StatefulWidget {
  const WeatherSection({super.key, this.controller});

  final WeatherController? controller;

  @override
  State<WeatherSection> createState() => _WeatherSectionState();
}

class _WeatherSectionState extends State<WeatherSection> {
  late final WeatherController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? WeatherController();
    _controller.load();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;
        return Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: scheme.surface,
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  scheme.surfaceContainerHighest,
                  scheme.surface,
                ],
              ),
            ),
            padding: const EdgeInsets.all(AppSpacing.large),
            child: _buildBody(context, state),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, WeatherState state) {
    switch (state.status) {
      case WeatherStatus.initial:
      case WeatherStatus.loading:
        return const _WeatherLoading();
      case WeatherStatus.permissionDenied:
      case WeatherStatus.permissionDeniedForever:
        return _WeatherPermissionState(
          permanent: state.status == WeatherStatus.permissionDeniedForever,
          onRetry: _controller.refresh,
        );
      case WeatherStatus.serviceDisabled:
        return _WeatherMessageState(
          icon: Icons.location_off_rounded,
          title: 'Location is off',
          body:
              'Turn on location services in your device settings to see local weather.',
          actionLabel: 'Open location settings',
          onAction: () async {
            await Geolocator.openLocationSettings();
          },
        );
      case WeatherStatus.error:
        return _WeatherMessageState(
          icon: Icons.error_outline_rounded,
          title: 'Couldn\'t load weather',
          body: state.errorMessage ?? 'Please try again.',
          actionLabel: 'Retry',
          onAction: _controller.refresh,
        );
      case WeatherStatus.success:
      case WeatherStatus.refreshing:
        final snapshot = state.snapshot;
        if (snapshot == null) return const _WeatherLoading();
        return _WeatherContent(
          snapshot: snapshot,
          isRefreshing: state.status == WeatherStatus.refreshing,
          onRefresh: _controller.refresh,
        );
    }
  }
}

// ── Success content ───────────────────────────────────────────────────────

class _WeatherContent extends StatelessWidget {
  const _WeatherContent({
    required this.snapshot,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final WeatherSnapshot snapshot;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final current = snapshot.current;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(current.condition.icon, size: 42, color: scheme.primary),
            const SizedBox(width: AppSpacing.medium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${current.temperatureC.round()}°C',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    current.condition.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: isRefreshing ? null : onRefresh,
              icon: isRefreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.small),
        Text(
          'Feels like ${current.apparentTemperatureC.round()}°C',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.large),

        // Details grid — humidity, wind
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 340;
            final children = <Widget>[
              _StatTile(
                icon: Icons.water_drop_outlined,
                label: 'Humidity',
                value: '${current.humidityPercent}%',
              ),
              _StatTile(
                icon: Icons.air_rounded,
                label: 'Wind',
                value: '${current.windSpeedKph.round()} km/h',
              ),
            ];
            if (narrow) {
              return Column(
                children: children
                    .map((c) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.small),
                          child: c,
                        ))
                    .toList(),
              );
            }
            return Row(
              children: <Widget>[
                Expanded(child: children[0]),
                const SizedBox(width: AppSpacing.small),
                Expanded(child: children[1]),
              ],
            );
          },
        ),

        const SizedBox(height: AppSpacing.large),

        // 7-day forecast
        Text(
          '7-DAY FORECAST',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        _ForecastList(days: snapshot.daily),

        const SizedBox(height: AppSpacing.small),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Updated ${_relativeTime(snapshot.fetchedAt)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  static String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.medium, vertical: AppSpacing.small),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
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

class _ForecastList extends StatelessWidget {
  const _ForecastList({required this.days});

  final List<DailyForecast> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: <Widget>[
          for (var i = 0; i < days.length; i++) ...<Widget>[
            _ForecastRow(day: days[i], isToday: i == 0),
            if (i < days.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: scheme.outlineVariant.withOpacity(0.4),
                indent: 16,
                endIndent: 16,
              ),
          ],
        ],
      ),
    );
  }
}

class _ForecastRow extends StatelessWidget {
  const _ForecastRow({required this.day, required this.isToday});

  final DailyForecast day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final weekday = _weekdayLabel(day.date, isToday: isToday);

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.medium, vertical: AppSpacing.small),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 56,
            child: Text(
              weekday,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Icon(day.condition.icon, size: 22, color: scheme.primary),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: day.precipitationProbability == null
                ? const SizedBox.shrink()
                : Row(
                    children: <Widget>[
                      Icon(Icons.water_drop_outlined,
                          size: 12, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 2),
                      Text(
                        '${day.precipitationProbability}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
          ),
          Text(
            '${day.tempMinC.round()}°',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: AppSpacing.small),
          Text(
            '${day.tempMaxC.round()}°',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  static const List<String> _weekdayShortNames = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static String _weekdayLabel(DateTime d, {required bool isToday}) {
    if (isToday) return 'Today';
    return _weekdayShortNames[d.weekday - 1];
  }
}

// ── State widgets ─────────────────────────────────────────────────────────

class _WeatherLoading extends StatelessWidget {
  const _WeatherLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 220,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _WeatherMessageState extends StatelessWidget {
  const _WeatherMessageState({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 28, color: scheme.primary),
            const SizedBox(width: AppSpacing.small),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.small),
        Text(
          body,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.medium),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () async {
              await onAction();
            },
            child: Text(actionLabel),
          ),
        ),
      ],
    );
  }
}

class _WeatherPermissionState extends StatelessWidget {
  const _WeatherPermissionState({
    required this.permanent,
    required this.onRetry,
  });

  final bool permanent;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.location_disabled_rounded,
                size: 28, color: scheme.primary),
            const SizedBox(width: AppSpacing.small),
            Expanded(
              child: Text(
                'Location needed for weather',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.small),
        Text(
          permanent
              ? 'Location permission is permanently denied. Enable it from app settings to see local weather.'
              : 'We use your location once to fetch today\'s conditions. It never leaves the device.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.medium),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () async {
              if (permanent) {
                await Geolocator.openAppSettings();
              } else {
                await onRetry();
              }
            },
            child: Text(permanent ? 'Open settings' : 'Allow location'),
          ),
        ),
      ],
    );
  }
}
