import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import 'toolkit.dart';

/// Calorie Calculator — Mifflin-St Jeor BMR × activity → TDEE, with
/// cut / maintain / bulk targets and a macro split. "Set as target"
/// pushes the number into the Calorie Counter / Nutrition Tracker.
class TdeePage extends StatefulWidget {
  const TdeePage({super.key});

  @override
  State<TdeePage> createState() => _TdeePageState();
}

class _TdeePageState extends State<TdeePage> {
  bool _male = true;
  double _age = 28;
  double _heightCm = 170;
  double _weightKg = 65;
  int _activity = 1;

  static const List<(String, double)> _activityLevels = <(String, double)>[
    ('Desk job, little exercise', 1.2),
    ('Light — 1-3 workouts/week', 1.375),
    ('Moderate — 3-5 workouts/week', 1.55),
    ('Active — 6-7 workouts/week', 1.725),
    ('Athlete — hard daily training', 1.9),
  ];

  double get _bmr {
    final base = 10 * _weightKg + 6.25 * _heightCm - 5 * _age;
    return _male ? base + 5 : base - 161;
  }

  double get _tdee => _bmr * _activityLevels[_activity].$2;

  Future<void> _setAsTarget(int kcal) async {
    final settings = await ServiceStore.loadMap('svc.food.settings');
    settings['targetKcal'] = kcal;
    await ServiceStore.saveMap('svc.food.settings', settings);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Daily target set to $kcal kcal — the Calorie '
            'Counter now uses it.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tdee = _tdee.round();
    final cut = (tdee - 500).clamp(1200, 9999);
    final bulk = tdee + 300;

    return Scaffold(
      appBar: svcAppBar('🔢 Calorie Calculator'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.large),
        children: <Widget>[
          // Result
          WhiteCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: <Widget>[
                Text('$tdee',
                    style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        height: 1.0)),
                const Text('kcal/day to maintain',
                    style: TextStyle(
                        fontSize: 10.5, color: AppColors.textMuted)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    _TargetChip(
                        label: 'Lose', kcal: cut, onSet: _setAsTarget),
                    _TargetChip(
                        label: 'Maintain', kcal: tdee, onSet: _setAsTarget),
                    _TargetChip(
                        label: 'Gain', kcal: bulk, onSet: _setAsTarget),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Suggested split @$tdee kcal: '
                  '${(tdee * 0.3 / 4).round()}g protein · '
                  '${(tdee * 0.4 / 4).round()}g carbs · '
                  '${(tdee * 0.3 / 9).round()}g fat',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 10.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Inputs
          WhiteCard(
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Text('Sex', style: TextStyle(fontSize: 12)),
                    const Spacer(),
                    SvcChip(
                        label: '♂ Male',
                        selected: _male,
                        onTap: () => setState(() => _male = true)),
                    const SizedBox(width: 6),
                    SvcChip(
                        label: '♀ Female',
                        selected: !_male,
                        onTap: () => setState(() => _male = false)),
                  ],
                ),
                _slider('Age', _age, 15, 80, 'yrs',
                    (v) => setState(() => _age = v)),
                _slider('Height', _heightCm, 130, 210, 'cm',
                    (v) => setState(() => _heightCm = v)),
                _slider('Weight', _weightKg, 35, 150, 'kg',
                    (v) => setState(() => _weightKg = v)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const SectionLabel('Activity level'),
          for (var i = 0; i < _activityLevels.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () => setState(() => _activity = i),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _activity == i
                        ? AppColors.surfaceTint
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _activity == i
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : AppColors.outline.withValues(alpha: 0.8),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        _activity == i
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 16,
                        color: _activity == i
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(_activityLevels[i].$1,
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max,
      String unit, ValueChanged<double> onChanged) {
    return Column(
      children: <Widget>[
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            Text(label, style: const TextStyle(fontSize: 12)),
            const Spacer(),
            Text('${value.round()} $unit',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.surfaceTint,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _TargetChip extends StatelessWidget {
  const _TargetChip(
      {required this.label, required this.kcal, required this.onSet});

  final String label;
  final int kcal;
  final ValueChanged<int> onSet;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onSet(kcal),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceTint.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: <Widget>[
            Text('$kcal',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary)),
            Text('$label · tap to set',
                style: const TextStyle(
                    fontSize: 8.5, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
