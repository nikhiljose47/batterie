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
    required this.onModeChanged,
    this.weatherController,
  });

  final double nowMinutes;
  final String modeId;
  final ValueChanged<String> onModeChanged;
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
    return plannerSlots.indexWhere((s) => s.contains(now));
  }

  bool get _isWakeCurrent {
    final now = widget.nowMinutes;
    return now >= homeDayWakeMinutes &&
        now < plannerSlots.first.startHour * 60.0;
  }

  bool get _isSleepCurrent {
    final now = widget.nowMinutes;
    return now < homeDayWakeMinutes || now >= homeDaySleepMinutes;
  }

  double get _currentCardOffset {
    const step = _regularCardHeight + _cardGap;
    if (_isSleepCurrent) {
      return (plannerSlots.length + 1) * step - 18.0;
    } else if (_isWakeCurrent || _currentIndex == -1) {
      return 0.0;
    }
    final visualIndex = _currentIndex + 1;
    return (visualIndex * step - 18)
        .clamp(0.0, (plannerSlots.length + 2) * step);
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadTravelBack();
    // Start one card above the current slot, then glide into place — a short,
    // purposeful reveal rather than a full-list fly-down from the top.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _currentCardOffset;
      const step = _regularCardHeight + _cardGap;
      _scrollController.jumpTo((target - step).clamp(0.0, double.infinity));
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    });
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
    if (widget.weatherController != null) {
      return AnimatedBuilder(
        animation: widget.weatherController!,
        builder: (context, _) => _buildBody(
          adviceList,
          widget.weatherController!.state.snapshot,
        ),
      );
    }
    return _buildBody(adviceList, null);
  }

  Widget _buildBody(List<ModeAdvice> adviceList, WeatherSnapshot? weather) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.small),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const Text(
                'PLANNER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              _ModeDropdown(
                modeId: widget.modeId,
                onChanged: widget.onModeChanged,
              ),
            ],
          ),
        ),
        Expanded(child: _buildList(adviceList, weather)),
        _PastBestFooter(
          label: _currentIndex != -1 ? _bestFromPast[_currentIndex] : null,
          slotLabel: _currentIndex != -1
              ? plannerSlots[_currentIndex].rangeLabel
              : null,
          weather: weather,
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
            return _WakeSleepCard(
              content: wakeCardContent,
              variant: _WakeSleepVariant.wake,
              assetPath: 'assets/icons/wakeup_alarm.svg',
              isCurrent: _isWakeCurrent,
            );
          }
          if (index == plannerSlots.length + 1) {
            return _WakeSleepCard(
              content: sleepCardContent,
              variant: _WakeSleepVariant.sleep,
              assetPath: 'assets/icons/going_to_sleep.svg',
              isCurrent: _isSleepCurrent,
            );
          }
          final slotIndex = index - 1;
          final slot = plannerSlots[slotIndex];
          final advice = adviceList[slotIndex];
          final isCurrent = currentIndex != -1 && slotIndex == currentIndex;
          return _PlannerCard(
            slot: slot,
            advice: advice,
            isCurrent: isCurrent,
            weatherTag: _weatherTagFor(weather),
            weather: isCurrent ? weather : null,
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
    required this.weather,
    required this.slotForecast,
    required this.height,
  });

  final TimeSlot slot;
  final ModeAdvice advice;
  final bool isCurrent;
  final String? weatherTag;

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
        isCurrent ? 18 : 13,
        isCurrent ? 14 : 10,
        isCurrent ? 14 : 10,
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
            color: isCurrent
                ? AppColors.primary.withValues(alpha: 0.14)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: isCurrent ? 22 : 8,
            spreadRadius: isCurrent ? 1 : 0,
            offset: Offset(0, isCurrent ? 8 : 3),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          // ── Main content — the star of the card ────────────────────
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                right: isCurrent ? 72 : 60, // clearance for the right column
                bottom: isCurrent ? 20 : 16, // clearance for footnote
              ),
              child: _buildContent(),
            ),
          ),
          // ── Time chip (non-current only) / Right column ───────────
          Positioned(top: 0, right: 0, child: _buildTimeChip()),
          Positioned(
            top: isCurrent ? 8 : 30,
            right: 0,
            bottom: isCurrent ? 22 : 18,
            width: isCurrent ? 66 : 54,
            child: _buildRight(),
          ),
          // ── Footnote pinned at the bottom edge ─────────────────────
          Positioned(left: 0, right: 0, bottom: 0, child: _buildFootnote()),
        ],
      ),
    );
  }

  /// Time pill in the top-right corner. On the current card it doubles as
  /// the NOW badge — filled primary, pulse-dot, both the label and range.
  Widget _buildTimeChip() {
    if (isCurrent) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.7),
          width: 0.7,
        ),
      ),
      child: Text(
        slot.rangeLabel,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (isCurrent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            advice.tip,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16.5,
              height: 1.28,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            advice.recommendation,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF141824).withValues(alpha: 0.58),
              letterSpacing: 0,
            ),
          ),
        ],
      );
    }
    // Non-current card: recommendation as headline, tip as pill at bottom.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          advice.recommendation,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.26,
            fontWeight: FontWeight.w600,
            color: Color(0xFF141824),
            letterSpacing: -0.2,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.32),
              width: 0.8,
            ),
          ),
          child: Text(
            advice.tip,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 0.2,
            ),
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

/// Solid info bar docked at the very bottom of the planner column.
/// Two panels side by side: past best for the current slot (left) and
/// today's next rain window (right). Square corners — no border radius —
/// so it reads as a flat shelf, not a floating card.
class _PastBestFooter extends StatelessWidget {
  const _PastBestFooter({
    required this.label,
    required this.slotLabel,
    required this.weather,
  });

  final String? label;
  final String? slotLabel;
  final WeatherSnapshot? weather;

  bool _isRainy(WeatherCondition c) =>
      c == WeatherCondition.rain ||
      c == WeatherCondition.drizzle ||
      c == WeatherCondition.showers ||
      c == WeatherCondition.thunderstorm ||
      c == WeatherCondition.freezingRain;

  /// First rainy hourly slot later today, or today's daily rain probability.
  /// Returns a compact display string like "3 PM · 72%" or "No rain today".
  String _rainSummary() {
    if (weather == null) return '—';
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59);

    for (final h in weather!.hourly) {
      if (h.time.isBefore(now) || h.time.isAfter(todayEnd)) continue;
      final prob = h.precipitationProbability ?? 0;
      if (!_isRainy(h.condition) && prob < 50) continue;
      final hr = h.time.hour;
      final label = hr == 0
          ? '12 AM'
          : hr < 12
              ? '$hr AM'
              : hr == 12
                  ? '12 PM'
                  : '${hr - 12} PM';
      return prob > 0 ? '$label · $prob%' : label;
    }

    if (weather!.daily.isNotEmpty) {
      final today = weather!.daily.first;
      final prob = today.precipitationProbability;
      if (_isRainy(today.condition)) {
        return prob != null && prob > 0 ? 'Today · $prob%' : 'Today';
      }
      if (prob != null && prob >= 30) return 'Today · $prob%';
    }

    return 'No rain today';
  }

  @override
  Widget build(BuildContext context) {
    if (slotLabel == null) return const SizedBox.shrink();
    final hasHistory = label != null;
    final rainText = _rainSummary();

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 36),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FF),
        border: Border(
          top: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.30),
            width: 2,
          ),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // ── Left: past best ──────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'YOUR BEST · $slotLabel',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: <Widget>[
                      const Text('🏆', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          hasHistory
                              ? label!
                              : 'Log an activity to start tracking',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: hasHistory
                                ? FontWeight.w700
                                : FontWeight.w400,
                            fontStyle: hasHistory
                                ? FontStyle.normal
                                : FontStyle.italic,
                            color: hasHistory
                                ? const Color(0xFF2A2E3B)
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Divider ──────────────────────────────────────────────────
            Container(
              height: 48,
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: AppColors.outline.withValues(alpha: 0.5),
            ),

            // ── Right: next rain ─────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'EXPECTED RAIN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text('🌧', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(
                      rainText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2A2E3B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
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
    this.isCurrent = false,
  });

  final WakeSleepCopy content;
  final _WakeSleepVariant variant;
  final String assetPath;
  final bool isCurrent;

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
          color: isCurrent
              ? (_isWake
                  ? const Color(0xFFB86A00).withValues(alpha: 0.75)
                  : const Color(0xFFB5B8FF).withValues(alpha: 0.65))
              : (_isWake ? Colors.white : Colors.white)
                  .withValues(alpha: _isWake ? 0.7 : 0.15),
          width: isCurrent ? 2.0 : 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: (_isWake
                    ? const Color(0xFFB88A3A)
                    : const Color(0xFF0A0C2A))
                .withValues(alpha: isCurrent ? 0.35 : 0.18),
            blurRadius: isCurrent ? 22 : 14,
            spreadRadius: isCurrent ? 2 : 0,
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
                Row(
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
                    if (isCurrent) ...<Widget>[
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _isWake
                              ? const Color(0xFFB86A00)
                              : const Color(0xFFB5B8FF),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'NOW',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: _isWake
                              ? const Color(0xFFB86A00)
                              : const Color(0xFFB5B8FF),
                        ),
                      ),
                    ],
                  ],
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

/// Trigger button + custom overlay dropdown for the PLANNER header.
/// Always opens below the button, 2-column grid, no PRO badge.
class _ModeDropdown extends StatefulWidget {
  const _ModeDropdown({required this.modeId, required this.onChanged});

  final String modeId;
  final ValueChanged<String> onChanged;

  @override
  State<_ModeDropdown> createState() => _ModeDropdownState();
}

class _ModeDropdownState extends State<_ModeDropdown> {
  OverlayEntry? _entry;

  bool get _isOpen => _entry != null;

  void _toggle() => _isOpen ? _close() : _open();

  void _open() {
    final box = context.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;

    _entry = OverlayEntry(builder: (ctx) {
      final screenWidth = MediaQuery.of(ctx).size.width;
      // Right-align panel with button's right edge, clamp to screen.
      const panelWidth = 230.0;
      final right = screenWidth - pos.dx - size.width;

      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _close,
          ),
          Positioned(
            top: pos.dy + size.height + 6,
            right: right,
            width: panelWidth,
            child: _ModePanel(
              modeId: widget.modeId,
              onSelect: (id) {
                _close();
                widget.onChanged(id);
              },
            ),
          ),
        ],
      );
    });

    Overlay.of(context).insert(_entry!);
    setState(() {});
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _entry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = allDayModes.firstWhere(
      (m) => m.id == widget.modeId,
      orElse: () => allDayModes.first,
    );

    return GestureDetector(
      onTap: _toggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.28),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '${selected.emoji} ${selected.label}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(width: 2),
            AnimatedRotation(
              turns: _isOpen ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 13,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The floating 2-column panel shown by [_ModeDropdown].
class _ModePanel extends StatelessWidget {
  const _ModePanel({required this.modeId, required this.onSelect});

  final String modeId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    const cols = 2;
    final rows = (allDayModes.length / cols).ceil();

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.outline.withValues(alpha: 0.35),
            width: 0.8,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.11),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(rows, (row) {
            return Row(
              children: List.generate(cols, (col) {
                final i = row * cols + col;
                if (i >= allDayModes.length) {
                  return const Expanded(child: SizedBox());
                }
                final m = allDayModes[i];
                final selected = m.id == modeId;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onSelect(m.id),
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.10)
                            : AppColors.scaffoldBackground
                                .withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.45)
                              : AppColors.outline.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '${m.emoji} ${m.label}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ),
      ),
    );
  }
}
