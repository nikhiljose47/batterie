import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import 'toolkit.dart';

/// Daily counter template — one number per day vs a goal.
/// Powers Water Tracker (higher is better) and Nicotine Tracker
/// (lower is better, streak of clean days).
class CounterConfig {
  const CounterConfig({
    required this.id,
    required this.title,
    required this.emoji,
    required this.unit,
    required this.defaultGoal,
    required this.lowerIsBetter,
    required this.accent,
  });

  final String id;
  final String title;
  final String emoji;
  final String unit;
  final int defaultGoal;
  final bool lowerIsBetter;
  final Color accent;
}

const waterCounterConfig = CounterConfig(
  id: 'water',
  title: '💧 Water Tracker',
  emoji: '🥤',
  unit: 'glasses',
  defaultGoal: 8,
  lowerIsBetter: false,
  accent: Color(0xFF1565C0),
);

const nicotineCounterConfig = CounterConfig(
  id: 'nicotine',
  title: '🚭 Nicotine Tracker',
  emoji: '🚬',
  unit: 'cigarettes',
  defaultGoal: 0,
  lowerIsBetter: true,
  accent: Color(0xFFC62828),
);

class CounterToolPage extends StatefulWidget {
  const CounterToolPage({super.key, required this.config});
  final CounterConfig config;

  @override
  State<CounterToolPage> createState() => _CounterToolPageState();
}

class _CounterToolPageState extends State<CounterToolPage> {
  Map<String, dynamic> _days = <String, dynamic>{};
  int _goal = 0;
  bool _loaded = false;

  String get _daysKey => 'svc.${widget.config.id}.days';
  String get _goalKey => 'svc.${widget.config.id}.goal';

  int get _today => (_days[svcDay(DateTime.now())] as num?)?.toInt() ?? 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final days = await ServiceStore.loadMap(_daysKey);
    final settings = await ServiceStore.loadMap(_goalKey);
    if (!mounted) return;
    setState(() {
      _days = days;
      _goal = (settings['goal'] as num?)?.toInt() ?? widget.config.defaultGoal;
      _loaded = true;
    });
  }

  Future<void> _bump(int delta) async {
    final key = svcDay(DateTime.now());
    final next = (_today + delta).clamp(0, 99);
    setState(() => _days[key] = next);
    await ServiceStore.saveMap(_daysKey, _days);
  }

  Future<void> _setGoal(int goal) async {
    setState(() => _goal = goal.clamp(0, 99));
    await ServiceStore.saveMap(_goalKey, <String, dynamic>{'goal': _goal});
  }

  /// Consecutive days (ending today) that met the goal.
  int get _streak {
    var streak = 0;
    var day = DateTime.now();
    while (true) {
      final v = (_days[svcDay(day)] as num?)?.toInt();
      final met = widget.config.lowerIsBetter
          ? (v ?? 0) <= _goal
          : (v ?? 0) >= _goal && _goal > 0;
      // An unlogged past day only counts as clean for lower-is-better.
      if (v == null && !widget.config.lowerIsBetter) break;
      if (!met) break;
      streak++;
      day = day.subtract(const Duration(days: 1));
      if (streak > 365) break;
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    final goalMet =
        c.lowerIsBetter ? _today <= _goal : _goal > 0 && _today >= _goal;
    final progress = c.lowerIsBetter
        ? null
        : (_goal == 0 ? 0.0 : (_today / _goal).clamp(0.0, 1.0));

    return Scaffold(
      appBar: svcAppBar(c.title),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.large),
              children: <Widget>[
                // Big today card
                WhiteCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: <Widget>[
                      if (progress != null)
                        SizedBox(
                          width: 110,
                          height: 110,
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              SizedBox(
                                width: 110,
                                height: 110,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 8,
                                  color: c.accent,
                                  backgroundColor: c.accent.withOpacity(0.12),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    '$_today',
                                    style: TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                      color: c.accent,
                                      height: 1.0,
                                    ),
                                  ),
                                  Text(
                                    'of $_goal ${c.unit}',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: <Widget>[
                            Text(
                              '$_today',
                              style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                                color: goalMet
                                    ? const Color(0xFF2E7D32)
                                    : c.accent,
                                height: 1.0,
                              ),
                            ),
                            Text(
                              '${c.unit} today — aim ≤ $_goal',
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          _RoundBtn(
                              icon: Icons.remove_rounded,
                              onTap: () => _bump(-1)),
                          const SizedBox(width: 18),
                          _RoundBtn(
                            icon: Icons.add_rounded,
                            filled: true,
                            accent: c.accent,
                            onTap: () => _bump(1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        goalMet
                            ? (c.lowerIsBetter
                                ? '🎉 Clean so far today'
                                : '🎉 Goal reached!')
                            : (c.lowerIsBetter
                                ? 'Each one logged honestly counts.'
                                : 'Keep sipping — ${(_goal - _today).clamp(0, 99)} to go.'),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Streak + goal row
                Row(
                  children: <Widget>[
                    Expanded(
                      child: WhiteCard(
                        child: Column(
                          children: <Widget>[
                            Text('🔥 $_streak',
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            const Text('day streak',
                                style: TextStyle(
                                    fontSize: 10, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: WhiteCard(
                        child: Column(
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                InkWell(
                                  onTap: () => _setGoal(_goal - 1),
                                  child: const Icon(Icons.remove_rounded,
                                      size: 18, color: AppColors.textMuted),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  child: Text('$_goal',
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800)),
                                ),
                                InkWell(
                                  onTap: () => _setGoal(_goal + 1),
                                  child: const Icon(Icons.add_rounded,
                                      size: 18, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(c.lowerIsBetter ? 'daily limit' : 'daily goal',
                                style: const TextStyle(
                                    fontSize: 10, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const SectionLabel('Last 7 days'),
                WhiteCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      for (var back = 6; back >= 0; back--)
                        _DayBar(
                          day: DateTime.now().subtract(Duration(days: back)),
                          value: (_days[svcDay(DateTime.now()
                                      .subtract(Duration(days: back)))] as num?)
                                  ?.toInt() ??
                              0,
                          max: c.lowerIsBetter ? 10 : (_goal == 0 ? 8 : _goal),
                          accent: c.accent,
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.accent = AppColors.primary,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: filled ? accent : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
              color: filled ? accent : AppColors.outline.withOpacity(0.9)),
        ),
        child: Icon(icon,
            size: 26, color: filled ? Colors.white : AppColors.textMuted),
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.day,
    required this.value,
    required this.max,
    required this.accent,
  });

  final DateTime day;
  final int value;
  final int max;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    const wd = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final h = max == 0 ? 0.0 : (value / max).clamp(0.0, 1.0) * 56;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('$value',
            style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
        const SizedBox(height: 3),
        Container(
          width: 18,
          height: 56,
          alignment: Alignment.bottomCenter,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Container(
            width: 18,
            height: h,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.75),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(wd[day.weekday - 1],
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted)),
      ],
    );
  }
}
