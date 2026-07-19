import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import 'toolkit.dart';

/// Breathing Exercises — an animated breathe-along circle.
/// Patterns are (inhale, hold, exhale, hold) seconds.
class _Pattern {
  const _Pattern(this.name, this.inhale, this.hold1, this.exhale, this.hold2);
  final String name;
  final int inhale;
  final int hold1;
  final int exhale;
  final int hold2;

  int get total => inhale + hold1 + exhale + hold2;
}

const List<_Pattern> _patterns = <_Pattern>[
  _Pattern('Box 4-4-4-4', 4, 4, 4, 4),
  _Pattern('Relax 4-7-8', 4, 7, 8, 0),
  _Pattern('Calm 4-6', 4, 0, 6, 0),
];

class BreathingPage extends StatefulWidget {
  const BreathingPage({super.key});

  @override
  State<BreathingPage> createState() => _BreathingPageState();
}

class _BreathingPageState extends State<BreathingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _patternIndex = 0;
  bool _running = false;

  _Pattern get _pattern => _patterns[_patternIndex];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: _pattern.total),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _running = !_running);
    if (_running) {
      _controller.duration = Duration(seconds: _pattern.total);
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.reset();
    }
  }

  /// Phase + scale (0..1) for the current cycle position.
  (String, double) _phaseAt(double t) {
    final p = _pattern;
    final seconds = t * p.total;
    if (seconds < p.inhale) {
      return ('Breathe in…', seconds / p.inhale);
    }
    if (seconds < p.inhale + p.hold1) {
      return ('Hold', 1.0);
    }
    if (seconds < p.inhale + p.hold1 + p.exhale) {
      final e = (seconds - p.inhale - p.hold1) / p.exhale;
      return ('Breathe out…', 1.0 - e);
    }
    return ('Hold', 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: svcAppBar('🌬️ Breathing'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.large),
        children: <Widget>[
          WhiteCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 220,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final (phase, scale) = _running
                            ? _phaseAt(_controller.value)
                            : ('Ready', 0.35);
                        final size = 90 + scale * 110;
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            SizedBox(
                              height: 176,
                              child: Center(
                                child: Container(
                                  width: size,
                                  height: size,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: <Color>[
                                        AppColors.primary
                                            .withValues(alpha: 0.55),
                                        AppColors.primary
                                            .withValues(alpha: 0.15),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.6),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              phase,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2A2E3B),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: <Widget>[
                    for (var i = 0; i < _patterns.length; i++)
                      SvcChip(
                        label: _patterns[i].name,
                        selected: _patternIndex == i,
                        onTap: _running
                            ? () {}
                            : () => setState(() => _patternIndex = i),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: FilledButton(
                    onPressed: _toggle,
                    style: FilledButton.styleFrom(
                      backgroundColor: _running
                          ? const Color(0xFFC62828)
                          : AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _running ? 'Stop' : 'Start breathing',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const WhiteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('When to use which',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text(
                  '• Box 4-4-4-4 — steady focus before work or sport.\n'
                  '• 4-7-8 — winding down, falling asleep, anxiety spikes.\n'
                  '• Calm 4-6 — anytime reset; longer exhale slows the '
                  'heart rate.',
                  style: TextStyle(
                      fontSize: 11,
                      height: 1.6,
                      color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
