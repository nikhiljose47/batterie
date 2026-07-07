import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import '../../../engine/energy_score_engine.dart';
import '../../../models/energy_log_record.dart';
import '../../../models/logged_activity.dart';
import '../../../services/energy_log_store.dart';

enum StatsDay { today, yesterday }

enum StatsMetric { both, physical, brain }

/// Statistics for one day: filters, energy chart, averages, an editable
/// remark, and the raw activity log — all read from the local store.
class DailyStatsPanel extends StatefulWidget {
  const DailyStatsPanel({super.key, this.store});

  final EnergyLogStore? store;

  @override
  State<DailyStatsPanel> createState() => _DailyStatsPanelState();
}

class _DailyStatsPanelState extends State<DailyStatsPanel> {
  static const EnergyScoreEngine _engine = EnergyScoreEngine();

  late final EnergyLogStore _store =
      widget.store ?? SqliteEnergyLogStore.instance;
  final TextEditingController _remarkController = TextEditingController();

  StatsDay _day = StatsDay.today;
  StatsMetric _metric = StatsMetric.both;
  List<EnergyLogRecord> _records = const <EnergyLogRecord>[];
  bool _loading = true;
  bool _remarkSaved = false;

  String get _dateKey {
    final now = DateTime.now();
    final target =
        _day == StatsDay.today ? now : now.subtract(const Duration(days: 1));
    return dateKey(target);
  }

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // ── Filters ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.large,
            AppSpacing.medium,
            AppSpacing.large,
            0,
          ),
          child: Row(
            children: <Widget>[
              _FilterChipGroup<StatsDay>(
                value: _day,
                options: const <(StatsDay, String)>[
                  (StatsDay.today, 'Today'),
                  (StatsDay.yesterday, 'Yesterday'),
                ],
                onChanged: (day) {
                  setState(() => _day = day);
                  _load();
                },
              ),
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
                  ? _EmptyDay(day: _day)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.large,
                        AppSpacing.medium,
                        AppSpacing.large,
                        AppSpacing.medium,
                      ),
                      children: <Widget>[
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
                      ],
                    ),
        ),
      ],
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
              color: color.withValues(alpha:0.8),
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
  const _EmptyDay({required this.day});

  final StatsDay day;

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
              day == StatsDay.today
                  ? 'Nothing logged today yet.\nAdd activities from the You tab.'
                  : 'Nothing was logged yesterday.',
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
