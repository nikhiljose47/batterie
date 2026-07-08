import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import '../../../engine/energy_score_engine.dart';
import '../../../models/energy_log_record.dart';
import '../../../models/logged_activity.dart';
import '../../../services/energy_log_store.dart';

enum StatsMetric { both, physical, brain }

const List<String> _weekdayLabels = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// Statistics for a chosen day (today or up to 6 days back): a day rail,
/// energy chart, averages, a plain-language summary, improvement tips, an
/// editable remark, and the raw activity log — all read from the local store.
class DailyStatsPanel extends StatefulWidget {
  const DailyStatsPanel({super.key, this.store, this.onOpenCoach});

  final EnergyLogStore? store;

  /// Called when the user taps the "Chat with AI coach" entry point.
  final VoidCallback? onOpenCoach;

  @override
  State<DailyStatsPanel> createState() => _DailyStatsPanelState();
}

class _DailyStatsPanelState extends State<DailyStatsPanel> {
  static const EnergyScoreEngine _engine = EnergyScoreEngine();
  static const int _daysBack = 7;

  late final EnergyLogStore _store =
      widget.store ?? SqliteEnergyLogStore.instance;
  final TextEditingController _remarkController = TextEditingController();

  int _dayOffset = 0; // 0 = today, 1 = yesterday, ... up to _daysBack - 1
  StatsMetric _metric = StatsMetric.both;
  List<EnergyLogRecord> _records = const <EnergyLogRecord>[];
  bool _loading = true;
  bool _remarkSaved = false;

  DateTime get _selectedDate =>
      DateTime.now().subtract(Duration(days: _dayOffset));

  String get _dateKey => dateKey(_selectedDate);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final records = await _store.recordsForDate(_dateKey);
      final remark = await _store.remarkForDate(_dateKey);
      if (!mounted) return;
      setState(() {
        _records = records;
        _remarkController.text = remark ?? '';
        _loading = false;
        _remarkSaved = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _records = const <EnergyLogRecord>[];
        _loading = false;
      });
    }
  }

  Future<void> _saveRemark() async {
    try {
      await _store.saveRemark(_dateKey, _remarkController.text.trim());
      if (!mounted) return;
      setState(() => _remarkSaved = true);
    } catch (_) {}
  }

  int? get _avgPhysical => _records.isEmpty
      ? null
      : (_records.map((r) => r.physicalAfter).reduce((a, b) => a + b) /
              _records.length)
          .round();

  int? get _avgBrain => _records.isEmpty
      ? null
      : (_records.map((r) => r.brainAfter).reduce((a, b) => a + b) /
              _records.length)
          .round();

  /// Plain-language read of the day: best case "all green", otherwise names
  /// the activity right before the lowest dip.
  String? get _summary {
    if (_records.isEmpty) return null;

    var minPhysical = 100;
    var minBrain = 100;
    EnergyLogRecord? worst;
    for (final r in _records) {
      if (r.physicalAfter < minPhysical) minPhysical = r.physicalAfter;
      if (r.brainAfter < minBrain) minBrain = r.brainAfter;
      final worstSoFar =
          worst == null ? 101 : math.min(worst.physicalAfter, worst.brainAfter);
      if (math.min(r.physicalAfter, r.brainAfter) < worstSoFar) worst = r;
    }

    final overallMin = math.min(minPhysical, minBrain);
    if (overallMin >= 80) return 'Great day — energy stayed 80%+ all day.';
    if (worst == null) return 'Energy dipped to $overallMin%.';

    final name = _engine.activityById(worst.activityId).name;
    final metric =
        worst.physicalAfter <= worst.brainAfter ? 'physical' : 'brain';
    final time = formatMinutes(worst.startMinutes);
    return overallMin < 40
        ? 'Low $metric energy after $name ($time).'
        : 'Dipped to $overallMin% $metric after $name ($time).';
  }

  /// A couple of simple, data-driven suggestions for the selected day.
  List<String> get _tips {
    if (_records.isEmpty) return const <String>[];
    final tips = <String>[];

    final drainCount = _records.where((r) {
      final a = _engine.activityById(r.activityId);
      return a.physicalDelta + a.brainDelta < 0;
    }).length;

    if (drainCount == _records.length && _records.length >= 2) {
      tips.add(
        'Every logged activity drained energy — add a short walk, breathing break, or nap between draining tasks.',
      );
    }

    final avgBrain = _avgBrain;
    if (avgBrain != null && avgBrain < 50) {
      tips.add(
        'Brain energy averaged $avgBrain% — try shorter focus blocks with a break every 60–90 minutes.',
      );
    }

    final avgPhysical = _avgPhysical;
    if (avgPhysical != null && avgPhysical < 50) {
      tips.add(
        'Physical energy averaged $avgPhysical% — a brisk walk or light meal break can help recovery.',
      );
    }

    return tips.take(2).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // ── Day rail + metric filter ────────────────────────────────────
        const SizedBox(height: AppSpacing.small),
        SizedBox(
          height: 52,
          child: _DayRail(
            selectedOffset: _dayOffset,
            daysBack: _daysBack,
            onSelect: (offset) {
              setState(() => _dayOffset = offset);
              _load();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.large,
            AppSpacing.small,
            AppSpacing.large,
            0,
          ),
          child: Row(
            children: <Widget>[
              const Spacer(),
              _FilterChipGroup<StatsMetric>(
                value: _metric,
                options: const <(StatsMetric, String)>[
                  (StatsMetric.both, 'Both'),
                  (StatsMetric.physical, 'Physical'),
                  (StatsMetric.brain, 'Brain'),
                ],
                onChanged: (metric) => setState(() => _metric = metric),
              ),
            ],
          ),
        ),

        // ── Scrollable stats content ─────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _records.isEmpty
                  ? _EmptyDay(isToday: _dayOffset == 0)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.large,
                        AppSpacing.medium,
                        AppSpacing.large,
                        AppSpacing.medium,
                      ),
                      children: <Widget>[
                        if (_summary != null)
                          Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppSpacing.medium),
                            child: Text(
                              _summary!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                        // Chart
                        Container(
                          height: 150,
                          padding: const EdgeInsets.all(AppSpacing.medium),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.outline),
                          ),
                          child: CustomPaint(
                            painter: _EnergyChartPainter(
                              records: _records,
                              metric: _metric,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.small),
                        _ChartLegend(metric: _metric),
                        const SizedBox(height: AppSpacing.medium),

                        // Averages
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _AverageCard(
                                label: 'Avg physical',
                                value: _avgPhysical,
                                color: AppColors.energyPhysicalAccent,
                                background: AppColors.energyPhysicalBg,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.small),
                            Expanded(
                              child: _AverageCard(
                                label: 'Avg brain',
                                value: _avgBrain,
                                color: AppColors.energyBrainAccent,
                                background: AppColors.energyBrainBg,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.small),
                            Expanded(
                              child: _AverageCard(
                                label: 'Activities',
                                value: _records.length,
                                suffix: '',
                                color: AppColors.primary,
                                background: AppColors.surfaceTint,
                              ),
                            ),
                          ],
                        ),

                        if (_tips.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.medium),
                          const Text(
                            'HELP TO IMPROVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.small),
                          ..._tips.map((tip) => _TipCard(text: tip)),
                        ],

                        const SizedBox(height: AppSpacing.medium),

                        // Remark
                        TextField(
                          controller: _remarkController,
                          onChanged: (_) =>
                              setState(() => _remarkSaved = false),
                          onSubmitted: (_) => _saveRemark(),
                          decoration: InputDecoration(
                            labelText: 'Remark for this day',
                            hintText: 'e.g. slept badly, deadline week…',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            suffixIcon: IconButton(
                              tooltip: 'Save remark',
                              icon: Icon(
                                _remarkSaved
                                    ? Icons.check_circle_rounded
                                    : Icons.save_outlined,
                                size: 18,
                                color: _remarkSaved
                                    ? AppColors.energyBrainAccent
                                    : AppColors.textMuted,
                              ),
                              onPressed: _saveRemark,
                            ),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: AppSpacing.medium),

                        // Log entries
                        const Text(
                          'LOG',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.small),
                        ..._records.map((r) => _LogRow(
                              record: r,
                              activityName:
                                  _engine.activityById(r.activityId).name,
                            )),

                        if (widget.onOpenCoach != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.medium),
                          _CoachEntry(onTap: widget.onOpenCoach!),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }
}

// ── Day rail ────────────────────────────────────────────────────────────────

class _DayRail extends StatelessWidget {
  const _DayRail({
    required this.selectedOffset,
    required this.daysBack,
    required this.onSelect,
  });

  final int selectedOffset;
  final int daysBack;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
      itemCount: daysBack,
      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.small),
      itemBuilder: (context, offset) {
        final date = now.subtract(Duration(days: offset));
        final selected = offset == selectedOffset;
        final topLabel = offset == 0
            ? 'Today'
            : offset == 1
                ? 'Yesterday'
                : _weekdayLabels[date.weekday - 1];

        return GestureDetector(
          onTap: () => onSelect(offset),
          child: Container(
            width: offset <= 1 ? 64 : 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.surfaceTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  topLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.textMuted,
                  ),
                ),
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.primary,
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

// ── Filter chips ──────────────────────────────────────────────────────────────

class _FilterChipGroup<T> extends StatelessWidget {
  const _FilterChipGroup({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((option) {
          final selected = option.$1 == value;
          return GestureDetector(
            onTap: () => onChanged(option.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: selected ? Border.all(color: AppColors.outline) : null,
              ),
              child: Text(
                option.$2,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Chart ─────────────────────────────────────────────────────────────────────

class _EnergyChartPainter extends CustomPainter {
  const _EnergyChartPainter({required this.records, required this.metric});

  final List<EnergyLogRecord> records;
  final StatsMetric metric;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.outline
      ..strokeWidth = 1;

    // Horizontal gridlines at 0 / 50 / 100
    for (final level in <double>[0, 0.5, 1.0]) {
      final y = size.height * (1 - level);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${(level * 100).round()}',
          style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas,
          Offset(0, y - (level == 0 ? 12 : 0) - (level == 1.0 ? -2 : 0)));
    }

    if (records.isEmpty) return;

    final minX = records.first.startMinutes - 30;
    final maxX = records.last.startMinutes + 30;
    final span = (maxX - minX).clamp(60, 1440);

    double xFor(int minutes) =>
        ((minutes - minX) / span) * (size.width - 24) + 20;
    double yFor(int score) => size.height * (1 - score / 100);

    void drawSeries(List<int> values, Color color) {
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final dotPaint = Paint()..color = color;

      final path = Path();
      for (var i = 0; i < records.length; i++) {
        final point = Offset(xFor(records[i].startMinutes), yFor(values[i]));
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path, linePaint);
      for (var i = 0; i < records.length; i++) {
        canvas.drawCircle(
          Offset(xFor(records[i].startMinutes), yFor(values[i])),
          3,
          dotPaint,
        );
      }
    }

    if (metric != StatsMetric.brain) {
      drawSeries(
        records.map((r) => r.physicalAfter).toList(),
        AppColors.energyPhysicalAccent,
      );
    }
    if (metric != StatsMetric.physical) {
      drawSeries(
        records.map((r) => r.brainAfter).toList(),
        AppColors.energyBrainAccent,
      );
    }
  }

  @override
  bool shouldRepaint(_EnergyChartPainter oldDelegate) =>
      oldDelegate.records != records || oldDelegate.metric != metric;
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.metric});

  final StatsMetric metric;

  @override
  Widget build(BuildContext context) {
    Widget dot(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        );

    return Row(
      children: <Widget>[
        if (metric != StatsMetric.brain) ...<Widget>[
          dot(AppColors.energyPhysicalAccent, 'Physical'),
          const SizedBox(width: AppSpacing.medium),
        ],
        if (metric != StatsMetric.physical)
          dot(AppColors.energyBrainAccent, 'Brain'),
      ],
    );
  }
}

// ── Averages ──────────────────────────────────────────────────────────────────

class _AverageCard extends StatelessWidget {
  const _AverageCard({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
    this.suffix = '%',
  });

  final String label;
  final int? value;
  final Color color;
  final Color background;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.small,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value == null ? '—' : '$value$suffix',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tips ──────────────────────────────────────────────────────────────────────

class _TipCard extends StatelessWidget {
  const _TipCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3DC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('💡', style: TextStyle(fontSize: 14)),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8A6D1D)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI coach entry point ─────────────────────────────────────────────────────

class _CoachEntry extends StatelessWidget {
  const _CoachEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.large),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[AppColors.primary, Color(0xFF7B88FF)],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        ),
        child: Row(
          children: <Widget>[
            const CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white24,
              child: Icon(Icons.bolt, color: Colors.white),
            ),
            const SizedBox(width: AppSpacing.medium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'AI Energy Coach',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Chat about sleep, focus, recovery, and more.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ── Log rows ──────────────────────────────────────────────────────────────────

class _LogRow extends StatelessWidget {
  const _LogRow({required this.record, required this.activityName});

  final EnergyLogRecord record;
  final String activityName;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.small,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: <Widget>[
          Text(
            activityEmojis[record.activityId] ?? '⚡',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  activityName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${formatMinutes(record.startMinutes)} · ${record.durationMinutes} min',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '💪 ${record.physicalAfter}%',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.energyPhysicalAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppSpacing.small),
          Text(
            '🧠 ${record.brainAfter}%',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.energyBrainAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.isToday});

  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.insights_rounded,
                size: 32, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.small),
            Text(
              isToday
                  ? 'Nothing logged today yet.\nAdd activities from the You tab.'
                  : 'Nothing was logged on this day.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
