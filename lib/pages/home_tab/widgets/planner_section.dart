import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import '../../../engine/energy_score_engine.dart';
import '../../../models/energy_log_record.dart';
import '../../../models/logged_activity.dart';
import '../../../models/weather.dart';
import '../../../services/energy_log_store.dart';
import '../../weather/weather_controller.dart';
import '../data/mode_advice.dart';

/// "Planner" — a mini vertical carousel of mac-style white cards, one per
/// 1–2 h slot. The card for the current time rests near the top, nudged
/// down a touch so the previous card visibly peeks. Only this list scrolls
/// — the day card above stays pinned by the parent.
///
/// Card content is mode-driven: `modeId` selects a curated list of
/// `ModeAdvice` from `mode_advice.dart`, one entry per slot.
class PlannerSection extends StatefulWidget {
  const PlannerSection({
    super.key,
    required this.nowMinutes,
    required this.modeId,
    this.weatherController,
  });

  final double nowMinutes;
  final String modeId;
  final WeatherController? weatherController;

  @override
  State<PlannerSection> createState() => _PlannerSectionState();
}

class _PlannerSectionState extends State<PlannerSection> {
  static const double _regularCardHeight = 132.0;
  static const double _currentCardHeight = 210.0;
  static const double _cardGap = 12.0;

  late final ScrollController _scrollController;

  /// slot index → "⏪ Ran easy pace (Tue)" — the best-scoring thing the user
  /// did in this window across the last week.
  Map<int, String> _bestFromPast = const <int, String>{};

  int get _currentIndex {
    final now = widget.nowMinutes.floor();
    final i = plannerSlots.indexWhere((s) => s.contains(now));
    return i == -1 ? 0 : i;
  }

  @override
  void initState() {
    super.initState();
    const step = _regularCardHeight + _cardGap;
    // +1 because the wake card sits above index 0 in the list.
    final visualIndex = _currentIndex + 1;
    final offset =
        (visualIndex * step - 18).clamp(0.0, (plannerSlots.length + 2) * step);
    _scrollController = ScrollController(initialScrollOffset: offset);
    _loadTravelBack();
  }

  /// Scans the last 7 days of the energy log and, per slot, keeps the
  /// activity that left the user with the highest combined energy.
  Future<void> _loadTravelBack() async {
    const engine = EnergyScoreEngine();
    const weekdays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    try {
      final store = SqliteEnergyLogStore.instance;
      final today = DateTime.now();
      final best = <int, ({int score, String label})>{};

      for (var back = 1; back <= 7; back++) {
        final day = today.subtract(Duration(days: back));
        List<EnergyLogRecord> records;
        try {
          records = await store.recordsForDate(dateKey(day));
        } catch (_) {
          continue;
        }
        for (final record in records) {
          final slotIndex =
              plannerSlots.indexWhere((s) => s.contains(record.startMinutes));
          if (slotIndex == -1) continue;

          final score = record.physicalAfter + record.brainAfter;
          final current = best[slotIndex];
          if (current == null || score > current.score) {
            final emoji = activityEmojis[record.activityId] ?? '⚡';
            final name = engine.activityById(record.activityId).name;
            best[slotIndex] = (
              score: score,
              label: '⏪ $emoji $name (${weekdays[day.weekday - 1]})',
            );
          }
        }
      }

      if (!mounted || best.isEmpty) return;
      setState(() {
        _bestFromPast = <int, String>{
          for (final entry in best.entries) entry.key: entry.value.label,
        };
      });
    } catch (_) {
      // No history (or no DB on this platform) — cards just skip the tag.
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adviceList = adviceForMode(widget.modeId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: AppSpacing.small),
          child: Text(
            'PLANNER',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(
          child: widget.weatherController == null
              ? _buildList(adviceList, null)
              : AnimatedBuilder(
                  animation: widget.weatherController!,
                  builder: (context, _) => _buildList(
                    adviceList,
                    widget.weatherController!.state.snapshot,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildList(List<ModeAdvice> adviceList, WeatherSnapshot? weather) {
    final currentIndex = _currentIndex;
    return ShaderMask(
      // Soft fade at top and bottom edges — carousel feel.
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.transparent,
          Colors.black,
          Colors.black,
          Colors.transparent,
        ],
        stops: <double>[0.0, 0.05, 0.93, 1.0],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      // Layout: [wake card] + [7 planner cards] + [sleep card].
      // Index math: 0 = wake, 1..7 = slots, 8 = sleep.
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: plannerSlots.length + 2,
        separatorBuilder: (_, __) => const SizedBox(height: _cardGap),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const _WakeSleepCard(
              content: wakeCardContent,
              variant: _WakeSleepVariant.wake,
              assetPath: 'assets/icons/wakeup_alarm.svg',
            );
          }
          if (index == plannerSlots.length + 1) {
            return const _WakeSleepCard(
              content: sleepCardContent,
              variant: _WakeSleepVariant.sleep,
              assetPath: 'assets/icons/going_to_sleep.svg',
            );
          }
          final slotIndex = index - 1;
          final slot = plannerSlots[slotIndex];
          final advice = adviceList[slotIndex];
          final isCurrent = slotIndex == currentIndex;
          return _PlannerCard(
            slot: slot,
            advice: advice,
            isCurrent: isCurrent,
            weatherTag: _weatherTagFor(weather),
            travelBackTag: _bestFromPast[slotIndex],
            weather: isCurrent ? weather : null,
            // Upcoming slots get their own hour-accurate prediction at the
            // user's location, from the cached hourly forecast.
            slotForecast: slotIndex > currentIndex
                ? _forecastForSlot(slot, weather)
                : null,
            height: isCurrent ? _currentCardHeight : _regularCardHeight,
          );
        },
      ),
    );
  }

  /// Hour-accurate prediction for an upcoming slot: the cached hourly
  /// forecast sampled at the slot's midpoint today.
  HourlyForecast? _forecastForSlot(TimeSlot slot, WeatherSnapshot? weather) {
    if (weather == null) return null;
    final now = DateTime.now();
    final midMinutes = ((slot.startHour + slot.endHour) * 60) ~/ 2;
    final when = DateTime(
        now.year, now.month, now.day, midMinutes ~/ 60, midMinutes % 60);
    return weather.hourlyAt(when);
  }

  /// A weather tag only when it matters — used on non-current cards as a
  /// small badge. The current card gets the full weather block instead.
  String? _weatherTagFor(WeatherSnapshot? weather) {
    if (weather == null) return null;
    final current = weather.current;
    final rainChance = weather.daily.isEmpty
        ? null
        : weather.daily.first.precipitationProbability;

    final rainy = switch (current.condition) {
      WeatherCondition.rain ||
      WeatherCondition.drizzle ||
      WeatherCondition.showers ||
      WeatherCondition.thunderstorm =>
        true,
      _ => (rainChance ?? 0) >= 55,
    };
    if (rainy) return '🌧 Rain';
    if (current.temperatureC >= 33) return '🔥 Hot';
    if (current.temperatureC >= 18 &&
        current.temperatureC <= 28 &&
        (current.condition == WeatherCondition.clear ||
            current.condition == WeatherCondition.partlyCloudy)) {
      return '🌿 Pleasant';
    }
    return null;
  }
}

/// White mac-style card.
///
/// Layout: 70% left column (recommendation quote, attribution, previous
/// best), 10% gap, 20% right column (weather block on the current card,
/// small tag stack on others). The card for the current slot is taller
/// and more emphasized than its neighbors.
class _PlannerCard extends StatelessWidget {
  const _PlannerCard({
    required this.slot,
    required this.advice,
    required this.isCurrent,
    required this.weatherTag,
    required this.travelBackTag,
    required this.weather,
    required this.slotForecast,
    required this.height,
  });

  final TimeSlot slot;
  final ModeAdvice advice;
  final bool isCurrent;
  final String? weatherTag;

  /// "⏪ 🏃 Running (Tue)" — best past activity in this window, if any.
  final String? travelBackTag;

  /// Full weather snapshot — passed only to the current card.
  final WeatherSnapshot? weather;

  /// Hourly prediction for this slot — passed only to upcoming cards.
  final HourlyForecast? slotForecast;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: EdgeInsets.fromLTRB(
        isCurrent ? 18 : 14,
        isCurrent ? 14 : 10,
        isCurrent ? 14 : 12,
        isCurrent ? 14 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isCurrent ? 22 : 16),
        border: Border.all(
          color: isCurrent
              ? AppColors.primary.withOpacity(0.55)
              : AppColors.outline.withOpacity(0.8),
          width: isCurrent ? 1.6 : 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(isCurrent ? 0.10 : 0.04),
            blurRadius: isCurrent ? 20 : 8,
            offset: Offset(0, isCurrent ? 6 : 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildHeader(),
          const SizedBox(height: 8),
          // 70% left (spotlit main content) / 10% gap / 20% right
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 70,
                  child: isCurrent
                      // Spotlight: a soft tinted wash behind the main
                      // content so the eye lands there first.
                      ? Container(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                AppColors.surfaceTint.withOpacity(0.55),
                                AppColors.surfaceTint.withOpacity(0.15),
                              ],
                            ),
                          ),
                          child: _buildLeft(),
                        )
                      : _buildLeft(),
                ),
                const Spacer(flex: 10),
                Expanded(flex: 20, child: _buildRight()),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _buildFootnote(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: <Widget>[
        Text(
          slot.rangeLabel,
          style: TextStyle(
            fontSize: isCurrent ? 10 : 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
            color: isCurrent ? AppColors.primary : AppColors.textMuted,
          ),
        ),
        if (isCurrent) ...<Widget>[
          const SizedBox(width: 6),
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'NOW',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.primary,
            ),
          ),
        ],
      ],
    );
  }

  /// The star row. Recommendation is set in a MacBook-keynote-style serif
  /// with the attribution as a subtle author line below.
  Widget _buildLeft() {
    final recSize = isCurrent ? 17.0 : 13.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '“${advice.recommendation}”',
          maxLines: isCurrent ? 4 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: recSize,
            height: 1.28,
            fontStyle: FontStyle.italic,
            fontFamily: 'Georgia',
            fontFamilyFallback: const <String>['serif'],
            fontWeight: FontWeight.w500,
            color: const Color(0xFF2A2E3B),
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          advice.attribution,
          style: TextStyle(
            fontSize: isCurrent ? 11 : 9.5,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        if (travelBackTag != null)
          _PreviousBestLine(label: travelBackTag!, emphasized: isCurrent)
        else if (isCurrent)
          _PreviousBestPlaceholder(),
        SizedBox(height: isCurrent ? 6 : 4),
        Text(
          advice.tip,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isCurrent ? 11.5 : 10,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  /// Right column by card kind:
  ///  • current card — full weather block (it's the slot you're in),
  ///  • upcoming card — that slot's own hourly prediction,
  ///  • past card — just the crowd tag.
  Widget _buildRight() {
    if (isCurrent) {
      return _CurrentWeatherBlock(weather: weather, crowd: advice.crowd);
    }
    if (slotForecast != null) {
      return _SlotForecastBlock(forecast: slotForecast!, crowd: advice.crowd);
    }
    final tags = <Widget>[
      if (weatherTag != null) _Tag(label: weatherTag!, emphasized: true),
      _Tag(label: advice.crowd),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (var i = 0; i < tags.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 4),
          tags[i],
        ],
      ],
    );
  }

  Widget _buildFootnote() {
    return Row(
      children: <Widget>[
        Text(
          'Do you know?',
          style: TextStyle(
            fontSize: isCurrent ? 9 : 8,
            fontWeight: FontWeight.w800,
            color: AppColors.bedtimeAccent,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            advice.history,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isCurrent ? 9 : 8,
              fontStyle: FontStyle.italic,
              color: AppColors.textMuted.withOpacity(0.9),
            ),
          ),
        ),
      ],
    );
  }
}

/// The current card's right column: a compact weather panel with the info
/// the user needs while they're actually in this slot. Falls back to the
/// crowd tag if there's no snapshot yet, so the column never sits empty.
class _CurrentWeatherBlock extends StatelessWidget {
  const _CurrentWeatherBlock({required this.weather, required this.crowd});

  final WeatherSnapshot? weather;
  final String crowd;

  @override
  Widget build(BuildContext context) {
    if (weather == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Icon(Icons.cloud_queue_rounded,
              size: 22, color: AppColors.primary.withOpacity(0.45)),
          const SizedBox(height: 4),
          Text(
            'Loading',
            style: TextStyle(
              fontSize: 9,
              color: AppColors.textMuted.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
          const Spacer(),
          _Tag(label: crowd),
        ],
      );
    }

    final current = weather!.current;
    final today = weather!.daily.isEmpty ? null : weather!.daily.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Icon(current.condition.icon, size: 24, color: AppColors.primary),
        const SizedBox(height: 2),
        Text(
          '${current.temperatureC.round()}°',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2A2E3B),
            height: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          current.condition.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Colors.black.withOpacity(0.55),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Feels ${current.apparentTemperatureC.round()}°',
          style: TextStyle(
            fontSize: 9,
            color: AppColors.textMuted.withOpacity(0.85),
          ),
        ),
        const Spacer(),
        if (today != null)
          Text(
            '↑${today.tempMaxC.round()}° ↓${today.tempMinC.round()}°',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.black.withOpacity(0.6),
            ),
          ),
        const SizedBox(height: 2),
        Text(
          '💧${current.humidityPercent}%  💨${current.windSpeedKph.round()}',
          style: TextStyle(
            fontSize: 9,
            color: AppColors.textMuted.withOpacity(0.85),
          ),
        ),
      ],
    );
  }
}

/// Upcoming card's right column: the hour-accurate prediction for that
/// slot at the user's location — icon, expected temp, rain chance — with
/// the crowd tag anchored at the bottom.
class _SlotForecastBlock extends StatelessWidget {
  const _SlotForecastBlock({required this.forecast, required this.crowd});

  final HourlyForecast forecast;
  final String crowd;

  @override
  Widget build(BuildContext context) {
    final rain = forecast.precipitationProbability;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Icon(forecast.condition.icon,
            size: 18, color: AppColors.primary.withOpacity(0.85)),
        const SizedBox(height: 2),
        Text(
          '${forecast.temperatureC.round()}°',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2A2E3B),
            height: 1.0,
          ),
        ),
        if (rain != null && rain > 0) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            '💧$rain%',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted.withOpacity(0.9),
            ),
          ),
        ],
        const Spacer(),
        _Tag(label: crowd),
      ],
    );
  }
}

/// "Your previous best in this slot" — a highlighted one-liner with a
/// trophy affordance. Sits inside the left column so the eye lands on it
/// after the recommendation.
class _PreviousBestLine extends StatelessWidget {
  const _PreviousBestLine({required this.label, required this.emphasized});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: emphasized ? 9 : 7,
        vertical: emphasized ? 4 : 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint.withOpacity(0.7),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.28),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('🏆', style: TextStyle(fontSize: emphasized ? 11 : 9)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: emphasized ? 11 : 9.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder when no past activity was logged for this slot yet.
class _PreviousBestPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text('🏆',
            style: TextStyle(
                fontSize: 10, color: AppColors.textMuted.withOpacity(0.5))),
        const SizedBox(width: 5),
        Text(
          'No past best yet',
          style: TextStyle(
            fontSize: 10,
            fontStyle: FontStyle.italic,
            color: AppColors.textMuted.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

/// Themed bookend for the planner list — the "wake up" card at the top and
/// the "going to sleep" card at the bottom. Same footprint as a regular
/// planner card but with an SVG illustration and its own palette.
enum _WakeSleepVariant { wake, sleep }

class _WakeSleepCard extends StatelessWidget {
  const _WakeSleepCard({
    required this.content,
    required this.variant,
    required this.assetPath,
  });

  final WakeSleepCopy content;
  final _WakeSleepVariant variant;
  final String assetPath;

  bool get _isWake => variant == _WakeSleepVariant.wake;

  @override
  Widget build(BuildContext context) {
    // Dawn: warm sunrise wash. Night: cool moonlit indigo.
    final gradientColors = _isWake
        ? const <Color>[Color(0xFFFFF5D6), Color(0xFFFFE0B2), Color(0xFFFFD1A6)]
        : const <Color>[
            Color(0xFF1B1E4A),
            Color(0xFF2E2F6E),
            Color(0xFF3D3E85)
          ];
    final foreground = _isWake ? const Color(0xFF3A2A0F) : Colors.white;
    final subFg = _isWake
        ? const Color(0xFF3A2A0F).withOpacity(0.65)
        : Colors.white.withOpacity(0.75);
    final tipBg = _isWake
        ? Colors.white.withOpacity(0.65)
        : Colors.white.withOpacity(0.12);
    final tipBorder = _isWake
        ? const Color(0xFFB88A3A).withOpacity(0.35)
        : Colors.white.withOpacity(0.25);
    final titleFg = _isWake ? const Color(0xFFB86A00) : const Color(0xFFB5B8FF);

    return Container(
      height: 148,
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: _isWake ? Alignment.topLeft : Alignment.bottomLeft,
          end: _isWake ? Alignment.bottomRight : Alignment.topRight,
          colors: gradientColors,
        ),
        border: Border.all(
          color: (_isWake ? Colors.white : Colors.white)
              .withOpacity(_isWake ? 0.7 : 0.15),
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: (_isWake ? const Color(0xFFB88A3A) : const Color(0xFF0A0C2A))
                .withOpacity(0.18),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  content.title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: titleFg,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '“${content.headline}”',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.28,
                    fontStyle: FontStyle.italic,
                    fontFamily: 'Georgia',
                    fontFamilyFallback: const <String>['serif'],
                    fontWeight: FontWeight.w500,
                    color: foreground,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content.sub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: subFg,
                    height: 1.3,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tipBg,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: tipBorder, width: 0.8),
                  ),
                  child: Text(
                    content.tip,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Wake: sunrise SVG illustration.
          // Sleep: Lottie panda animation, rotated 90° and clipped to fill
          //        the same footprint as the SVG slot.
          if (_isWake)
            SvgPicture.asset(
              assetPath,
              width: 88,
              height: 120,
              fit: BoxFit.contain,
              placeholderBuilder: (context) => SizedBox(
                width: 88,
                height: 120,
                child: Center(
                  child: Icon(
                    Icons.wb_sunny_rounded,
                    size: 40,
                    color: foreground.withOpacity(0.7),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: 88,
              height: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: RotatedBox(
                  quarterTurns: 1,
                  child: Lottie.asset(
                    'assets/lottie/panda_sleeping.json',
                    fit: BoxFit.cover,
                    repeat: true,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:
            emphasized ? AppColors.surfaceTint : AppColors.scaffoldBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: emphasized
              ? AppColors.primary.withOpacity(0.35)
              : AppColors.outline.withOpacity(0.7),
          width: 0.7,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: emphasized ? AppColors.primary : AppColors.textMuted,
        ),
      ),
    );
  }
}
