import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';

/// BMI Calculator — the first fully working service, and the reference
/// template for building the others: one page, self-contained state,
/// registered in `services_page.dart` → `_openService()`.
class BmiCalculatorPage extends StatefulWidget {
  const BmiCalculatorPage({super.key});

  @override
  State<BmiCalculatorPage> createState() => _BmiCalculatorPageState();
}

class _BmiCalculatorPageState extends State<BmiCalculatorPage> {
  double _heightCm = 170;
  double _weightKg = 65;

  double get _bmi {
    final m = _heightCm / 100;
    return _weightKg / (m * m);
  }

  ({String label, Color color, String advice}) get _verdict {
    final bmi = _bmi;
    if (bmi < 18.5) {
      return (
        label: 'Underweight',
        color: const Color(0xFF1565C0),
        advice: 'A little more fuel — protein-rich meals help.',
      );
    }
    if (bmi < 25) {
      return (
        label: 'Healthy',
        color: const Color(0xFF2E7D32),
        advice: 'Right in the healthy band. Keep doing what you do.',
      );
    }
    if (bmi < 30) {
      return (
        label: 'Overweight',
        color: const Color(0xFFEF6C00),
        advice: 'Small daily walks move this number more than you think.',
      );
    }
    return (
      label: 'Obese',
      color: const Color(0xFFC62828),
      advice: 'Worth a chat with a doctor — gentle, steady changes win.',
    );
  }

  /// Healthy weight window (BMI 18.5–24.9) for the current height.
  ({double low, double high}) get _healthyRange {
    final m = _heightCm / 100;
    return (low: 18.5 * m * m, high: 24.9 * m * m);
  }

  @override
  Widget build(BuildContext context) {
    final verdict = _verdict;
    final range = _healthyRange;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 44,
        scrolledUnderElevation: 0,
        title: const Text(
          '⚖️ BMI Calculator',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.large),
        children: <Widget>[
          // Result card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: verdict.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: verdict.color.withOpacity(0.35)),
            ),
            child: Column(
              children: <Widget>[
                Text(
                  _bmi.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    color: verdict.color,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  verdict.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: verdict.color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  verdict.advice,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.black.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Healthy range for this height
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outline.withOpacity(0.8)),
            ),
            child: Row(
              children: <Widget>[
                const Text('🎯', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Healthy weight for ${_heightCm.round()} cm: '
                    '${range.low.round()}–${range.high.round()} kg',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2A2E3B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          _SliderCard(
            emoji: '📏',
            label: 'Height',
            valueLabel: '${_heightCm.round()} cm',
            value: _heightCm,
            min: 120,
            max: 210,
            onChanged: (v) => setState(() => _heightCm = v),
          ),
          const SizedBox(height: 10),
          _SliderCard(
            emoji: '🏋️',
            label: 'Weight',
            valueLabel: '${_weightKg.round()} kg',
            value: _weightKg,
            min: 30,
            max: 160,
            onChanged: (v) => setState(() => _weightKg = v),
          ),
          const SizedBox(height: 14),

          Text(
            'BMI is a rough screen, not a diagnosis — it can misread '
            'muscular or older bodies. Use it as a trend, not a verdict.',
            style: TextStyle(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: AppColors.textMuted.withOpacity(0.9),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderCard extends StatelessWidget {
  const _SliderCard({
    required this.emoji,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String emoji;
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline.withOpacity(0.8)),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2A2E3B),
                ),
              ),
              const Spacer(),
              Text(
                valueLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
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
      ),
    );
  }
}
