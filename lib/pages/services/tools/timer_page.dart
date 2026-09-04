import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import '../../../services/service_energy_logger.dart';
import '../../../shared/widgets/service_energy_score_app_bar.dart';
import 'toolkit.dart';

/// Timer template.
///  • countdown mode — pick a preset, ring counts down (Focus, Meditation,
///    Sleep-sounds wind-down timer). Finished sessions are logged.
///  • countUp mode — fasting: start persists across app restarts, elapsed
///    shows live with stage labels, end logs the fast.
enum TimerMode { countdown, countUp }

class TimerConfig {
  const TimerConfig({
    required this.id,
    required this.title,
    required this.mode,
    required this.presets,
    required this.startLabel,
    this.stages = const <(int, String)>[],
    this.note,
  });

  final String id;
  final String title;
  final TimerMode mode;

  /// Countdown: minutes options. CountUp: target hours options.
  final List<int> presets;
  final String startLabel;

  /// CountUp stage labels: (hoursFromStart, label).
  final List<(int, String)> stages;
  final String? note;
}

const focusTimerConfig = TimerConfig(
  id: 'focus',
  title: '⚡ Regain',
  mode: TimerMode.countdown,
  presets: <int>[15, 25, 45, 60],
  startLabel: 'Start Regain',
  note:
      'Pick a short block, keep one thing open, and finish with a cleaner mind.',
);

const meditationTimerConfig = TimerConfig(
  id: 'meditation',
  title: '🧘 Meditation',
  mode: TimerMode.countdown,
  presets: <int>[5, 10, 15, 20],
  startLabel: 'Begin',
  note: 'Sit comfortably, eyes soft. When the mind wanders, come back '
      'to the breath — that return IS the rep.',
);

const sleepSoundsTimerConfig = TimerConfig(
  id: 'sleep_sounds',
  title: '🎵 Sleep Sounds',
  mode: TimerMode.countdown,
  presets: <int>[15, 30, 45, 60],
  startLabel: 'Start wind-down',
  note: 'Play rain/waves from your music app, set this timer, put the '
      'phone face down. Built-in soundscapes arrive once audio files '
      'are added to the app.',
);

const fastingTimerConfig = TimerConfig(
  id: 'fasting',
  title: '⏳ Fasting Tracker',
  mode: TimerMode.countUp,
  presets: <int>[14, 16, 18, 20],
  startLabel: 'Start fast',
  stages: <(int, String)>[
    (0, '🍽️ Fed state — insulin high'),
    (4, '⚙️ Digesting done — settling'),
    (8, '🔥 Fat-burning ramps up'),
    (12, '⚡ Ketosis approaching'),
    (16, '🏆 Deep burn — autophagy zone'),
  ],
);

class TimerToolPage extends StatefulWidget {
  const TimerToolPage({super.key, required this.config});
  final TimerConfig config;

  @override
  State<TimerToolPage> createState() => _TimerToolPageState();
}

class _TimerToolPageState extends State<TimerToolPage> {
  Timer? _ticker;
  int _preset = 0;

  // Countdown state.
  int _remainingSeconds = 0;
  bool _running = false;

  // CountUp state (fasting).
  DateTime? _fastStart;

  List<Map<String, dynamic>> _sessions = <Map<String, dynamic>>[];
  bool _loaded = false;
  int _scoreRefreshToken = 0;

  String get _sessionsKey => 'svc.${widget.config.id}.sessions';
  String get _stateKey => 'svc.${widget.config.id}.state';

  @override
  void initState() {
    super.initState();
    _preset = widget.config.presets.length > 1 ? 1 : 0;
    _load();
  }

  Future<void> _load() async {
    final sessions = await ServiceStore.loadList(_sessionsKey);
    final state = await ServiceStore.loadMap(_stateKey);
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      if (widget.config.mode == TimerMode.countUp) {
        final startIso = state['start'] as String?;
        _fastStart = startIso == null ? null : DateTime.tryParse(startIso);
        final target = (state['target'] as num?)?.toInt();
        if (target != null) {
          final i = widget.config.presets.indexOf(target);
          if (i != -1) _preset = i;
        }
        if (_fastStart != null) _startTicker();
      }
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (widget.config.mode == TimerMode.countdown) {
        if (_remainingSeconds <= 1) {
          _finishCountdown();
        } else {
          setState(() => _remainingSeconds--);
        }
      } else {
        setState(() {}); // repaint elapsed
      }
    });
  }

  void _startCountdown() {
    setState(() {
      _remainingSeconds = widget.config.presets[_preset] * 60;
      _running = true;
    });
    _startTicker();
  }

  Future<void> _finishCountdown() async {
    _ticker?.cancel();
    HapticFeedback.vibrate();
    final minutes = widget.config.presets[_preset];
    setState(() {
      _running = false;
      _remainingSeconds = 0;
      _sessions.insert(0, <String, dynamic>{
        't': DateTime.now().toIso8601String(),
        'minutes': minutes,
      });
    });
    await ServiceStore.saveList(_sessionsKey, _sessions);
    if (widget.config.id == 'focus' || widget.config.id == 'meditation') {
      await ServiceEnergyLogger.instance.addServiceLog(
        sourceId: widget.config.id,
        activityId: widget.config.id == 'focus'
            ? 'focused_coding'
            : 'mindfulness_meditation',
        at: DateTime.now(),
        durationMinutes: minutes,
      );
      if (mounted) setState(() => _scoreRefreshToken++);
    }
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Done!', style: TextStyle(fontSize: 16)),
        content: Text('$minutes minutes logged. Nice work.'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  void _stopCountdown() {
    _ticker?.cancel();
    setState(() {
      _running = false;
      _remainingSeconds = 0;
    });
  }

  Future<void> _startFast() async {
    final start = DateTime.now();
    setState(() => _fastStart = start);
    await ServiceStore.saveMap(_stateKey, <String, dynamic>{
      'start': start.toIso8601String(),
      'target': widget.config.presets[_preset],
    });
    _startTicker();
  }

  Future<void> _endFast() async {
    final start = _fastStart;
    _ticker?.cancel();
    if (start != null) {
      final minutes = DateTime.now().difference(start).inMinutes;
      _sessions.insert(0, <String, dynamic>{
        't': DateTime.now().toIso8601String(),
        'minutes': minutes,
      });
      await ServiceStore.saveList(_sessionsKey, _sessions);
    }
    setState(() => _fastStart = null);
    await ServiceStore.saveMap(_stateKey, <String, dynamic>{});
  }

  String _fmt(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _stageLabel(int elapsedHours) {
    var label = '';
    for (final (h, text) in widget.config.stages) {
      if (elapsedHours >= h) label = text;
    }
    return label;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    final isUp = c.mode == TimerMode.countUp;
    final isRegain = c.id == 'focus';
    final active = isUp ? _fastStart != null : _running;
    final accent = isRegain ? AppColors.info : AppColors.primary;

    int elapsedSeconds = 0;
    double progress = 0;
    if (isUp && _fastStart != null) {
      elapsedSeconds = DateTime.now().difference(_fastStart!).inSeconds;
      progress = (elapsedSeconds / (c.presets[_preset] * 3600)).clamp(0.0, 1.0);
    } else if (!isUp && _running) {
      final total = c.presets[_preset] * 60;
      progress = 1 - (_remainingSeconds / total);
    }

    final weekTotal = _sessions.where((s) {
      final t = DateTime.tryParse(s['t'] as String? ?? '');
      return t != null &&
          t.isAfter(DateTime.now().subtract(const Duration(days: 7)));
    }).fold<int>(0, (sum, s) => sum + ((s['minutes'] as num?)?.toInt() ?? 0));

    return Scaffold(
      appBar: (c.id == 'focus' || c.id == 'meditation')
          ? ServiceEnergyScoreAppBar(
              title: c.title,
              refreshToken: _scoreRefreshToken,
            )
          : svcAppBar(c.title),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.large),
              children: <Widget>[
                if (c.note != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceTint.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(c.note!,
                        style: const TextStyle(
                            fontSize: 10.5,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textMuted)),
                  ),

                // Timer face
                WhiteCard(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: <Widget>[
                      if (isRegain) ...<Widget>[
                        const Text(
                          'Choose a regain block',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Pomodoro or longer focus, one clean run.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      SizedBox(
                        width: 170,
                        height: 170,
                        child: Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            SizedBox(
                              width: 170,
                              height: 170,
                              child: CircularProgressIndicator(
                                value: active ? progress : 0,
                                strokeWidth: 9,
                                strokeCap: StrokeCap.round,
                                color: accent,
                                backgroundColor:
                                    AppColors.surfaceTint.withOpacity(0.8),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  isUp
                                      ? (active ? _fmt(elapsedSeconds) : '0:00')
                                      : (active
                                          ? _fmt(_remainingSeconds)
                                          : '${c.presets[_preset]}:00'),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2A2E3B),
                                    fontFeatures: <FontFeature>[
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                                Text(
                                  isUp
                                      ? 'target ${c.presets[_preset]} h'
                                      : (active ? 'remaining' : 'ready'),
                                  style: const TextStyle(
                                      fontSize: 10, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (isUp && active) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          _stageLabel(elapsedSeconds ~/ 3600),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Preset picker (when idle)
                      if (!active)
                        _TimerPresetGrid(
                          presets: c.presets,
                          selectedIndex: _preset,
                          countUp: isUp,
                          regain: isRegain,
                          onSelected: (index) =>
                              setState(() => _preset = index),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: FilledButton(
                          onPressed: active
                              ? (isUp ? _endFast : _stopCountdown)
                              : (isUp ? _startFast : _startCountdown),
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                active ? const Color(0xFFC62828) : accent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            active
                                ? (isUp ? 'End fast' : 'Stop')
                                : (isRegain
                                    ? 'Start ${c.presets[_preset]} min'
                                    : c.startLabel),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                WhiteCard(
                  child: Row(
                    children: <Widget>[
                      Text(
                        isUp
                            ? '${(weekTotal / 60).toStringAsFixed(1)} h'
                            : '$weekTotal min',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Text(isRegain ? 'regained this week' : 'this week',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                if (_sessions.isNotEmpty) const SectionLabel('History'),
                for (final s in _sessions.take(15))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: WhiteCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              _sessionLabel(s),
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                          Text(
                            isUp
                                ? '${(((s['minutes'] as num?)?.toInt() ?? 0) / 60).toStringAsFixed(1)} h'
                                : '${s['minutes']} min',
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  String _sessionLabel(Map<String, dynamic> s) {
    final t = DateTime.tryParse(s['t'] as String? ?? '');
    if (t == null) return 'Session';
    return '${svcDayLabel(svcDay(t))} · ${svcClock(t)}';
  }
}

class _TimerPresetGrid extends StatelessWidget {
  const _TimerPresetGrid({
    required this.presets,
    required this.selectedIndex,
    required this.countUp,
    required this.regain,
    required this.onSelected,
  });

  final List<int> presets;
  final int selectedIndex;
  final bool countUp;
  final bool regain;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = regain ? AppColors.info : AppColors.primary;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (var i = 0; i < presets.length; i++)
          InkWell(
            onTap: () => onSelected(i),
            borderRadius: BorderRadius.circular(13),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 72,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: selectedIndex == i
                    ? accent.withOpacity(0.12)
                    : colors.surfaceContainerHighest.withOpacity(0.45),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: selectedIndex == i
                      ? accent.withOpacity(0.5)
                      : colors.outline.withOpacity(0.35),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    countUp ? '${presets[i]}h' : '${presets[i]}',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: selectedIndex == i ? accent : colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    countUp ? 'hours' : (presets[i] == 25 ? 'pomodoro' : 'min'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface.withOpacity(0.54),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
