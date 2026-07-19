import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import 'toolkit.dart';

// Women's health mini-apps: Period & Ovulation Tracker and Pregnancy
// Tracker. All math is standard calendar-method estimation and runs
// fully on-device.

// ═══════════════════════════════════════════════════════════════════════
//  PERIOD & OVULATION TRACKER
// ═══════════════════════════════════════════════════════════════════════

class CyclePage extends StatefulWidget {
  const CyclePage({super.key});

  @override
  State<CyclePage> createState() => _CyclePageState();
}

class _CyclePageState extends State<CyclePage> {
  static const String key = 'svc.period.settings';

  DateTime? _lastStart;
  int _cycleLen = 28;
  int _periodLen = 5;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    ServiceStore.loadMap(key).then((map) {
      if (!mounted) return;
      setState(() {
        _lastStart = DateTime.tryParse(map['lastStart'] as String? ?? '');
        _cycleLen = (map['cycleLen'] as num?)?.toInt() ?? 28;
        _periodLen = (map['periodLen'] as num?)?.toInt() ?? 5;
        _loaded = true;
      });
    });
  }

  Future<void> _save() async {
    await ServiceStore.saveMap(key, <String, dynamic>{
      if (_lastStart != null) 'lastStart': _lastStart!.toIso8601String(),
      'cycleLen': _cycleLen,
      'periodLen': _periodLen,
    });
  }

  Future<void> _pickLastStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastStart ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _lastStart = picked);
      await _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (!_loaded) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final last = _lastStart;
      DateTime? nextPeriod;
      DateTime? ovulation;
      int? dayOfCycle;
      if (last != null) {
        final today = DateTime.now();
        dayOfCycle = today.difference(last).inDays % _cycleLen + 1;
        var next = last;
        while (!next.isAfter(today)) {
          next = next.add(Duration(days: _cycleLen));
        }
        nextPeriod = next;
        ovulation = next.subtract(const Duration(days: 14));
        if (ovulation.isBefore(today)) {
          ovulation = ovulation.add(Duration(days: _cycleLen));
        }
      }

      body = ListView(
        padding: const EdgeInsets.all(AppSpacing.large),
        children: <Widget>[
          if (last == null)
            const WhiteCard(
              child: Text(
                'Set the first day of your last period below to see '
                'predictions.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            )
          else ...<Widget>[
            WhiteCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: <Widget>[
                  Text('Day $dayOfCycle',
                      style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFC2185B))),
                  const Text('of your cycle',
                      style: TextStyle(
                          fontSize: 10.5, color: AppColors.textMuted)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      _CycleStat(
                        emoji: '🌸',
                        label: 'Next period',
                        value:
                            'in ${nextPeriod!.difference(DateTime.now()).inDays + 1} d',
                        sub: svcDayLabel(svcDay(nextPeriod)),
                      ),
                      _CycleStat(
                        emoji: '🥚',
                        label: 'Ovulation ~',
                        value:
                            'in ${ovulation!.difference(DateTime.now()).inDays + 1} d',
                        sub: svcDayLabel(svcDay(ovulation)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCE4EC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Fertile window: '
                      '${svcDayLabel(svcDay(ovulation.subtract(const Duration(days: 4))))}'
                      ' → ${svcDayLabel(svcDay(ovulation.add(const Duration(days: 1))))}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFC2185B)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: FilledButton.icon(
              onPressed: () async {
                setState(() => _lastStart = DateTime.now());
                await _save();
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC2185B),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.water_drop_rounded, size: 16),
              label: const Text('My period started today',
                  style:
                      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 6),
          const SectionLabel('Settings'),
          WhiteCard(
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Text('Last period started',
                        style: TextStyle(fontSize: 12)),
                    const Spacer(),
                    SvcChip(
                      label: last == null
                          ? '📅 Pick date'
                          : '📅 ${svcDayLabel(svcDay(last))}',
                      selected: last != null,
                      onTap: _pickLastStart,
                    ),
                  ],
                ),
                _SettingSlider(
                  label: 'Cycle length',
                  value: _cycleLen,
                  min: 21,
                  max: 40,
                  unit: 'days',
                  onChanged: (v) {
                    setState(() => _cycleLen = v);
                    _save();
                  },
                ),
                _SettingSlider(
                  label: 'Period length',
                  value: _periodLen,
                  min: 2,
                  max: 10,
                  unit: 'days',
                  onChanged: (v) {
                    setState(() => _periodLen = v);
                    _save();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Calendar-method estimates only — not contraception advice. '
            'Cycles vary; talk to a doctor about anything unusual.',
            style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: AppColors.textMuted),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: svcAppBar("🌸 Women's Health"),
      body: body,
    );
  }
}

class _CycleStat extends StatelessWidget {
  const _CycleStat({
    required this.emoji,
    required this.label,
    required this.value,
    required this.sub,
  });

  final String emoji;
  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text('$emoji $value',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        Text(sub,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2A2E3B))),
      ],
    );
  }
}

class _SettingSlider extends StatelessWidget {
  const _SettingSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Text(label, style: const TextStyle(fontSize: 12)),
            const Spacer(),
            Text('$value $unit',
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
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.surfaceTint,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  PREGNANCY TRACKER
// ═══════════════════════════════════════════════════════════════════════

/// Baby size per week (subset; nearest match is shown).
const Map<int, String> _babySizes = <int, String>{
  4: '🌱 poppy seed',
  6: '🫛 pea',
  8: '🫐 raspberry',
  10: '🍓 strawberry',
  12: '🍋 lime',
  14: '🍋 lemon',
  16: '🥑 avocado',
  18: '🫑 bell pepper',
  20: '🍌 banana',
  22: '🥥 coconut',
  24: '🌽 corn cob',
  26: '🥬 lettuce',
  28: '🍆 eggplant',
  30: '🥦 big broccoli',
  32: '🎃 squash',
  34: '🍈 cantaloupe',
  36: '🍍 pineapple',
  38: '🍉 small watermelon',
  40: '👶 ready to meet you',
};

class PregnancyPage extends StatefulWidget {
  const PregnancyPage({super.key});

  @override
  State<PregnancyPage> createState() => _PregnancyPageState();
}

class _PregnancyPageState extends State<PregnancyPage> {
  static const String key = 'svc.pregnancy.settings';

  DateTime? _due;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    ServiceStore.loadMap(key).then((map) {
      if (!mounted) return;
      setState(() {
        _due = DateTime.tryParse(map['due'] as String? ?? '');
        _loaded = true;
      });
    });
  }

  Future<void> _setDue(DateTime due) async {
    setState(() => _due = due);
    await ServiceStore.saveMap(
        key, <String, dynamic>{'due': due.toIso8601String()});
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? DateTime.now().add(const Duration(days: 120)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 290)),
    );
    if (picked != null) await _setDue(picked);
  }

  Future<void> _pickLmp() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 60)),
      firstDate: DateTime.now().subtract(const Duration(days: 290)),
      lastDate: DateTime.now(),
      helpText: 'First day of last period',
    );
    if (picked != null) {
      await _setDue(picked.add(const Duration(days: 280)));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (!_loaded) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_due == null) {
      body = ListView(
        padding: const EdgeInsets.all(AppSpacing.large),
        children: <Widget>[
          const WhiteCard(
            child: Text(
              'Set your due date (from your doctor) or the first day of '
              'your last period, and the tracker takes it from there.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: FilledButton(
              onPressed: _pickDueDate,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC2185B),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('I know my due date',
                  style:
                      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: OutlinedButton(
              onPressed: _pickLmp,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Calculate from last period',
                  style:
                      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      );
    } else {
      final daysLeft = _due!.difference(DateTime.now()).inDays;
      final week = ((280 - daysLeft) / 7).floor().clamp(1, 42);
      final trimester = week <= 13 ? 1 : (week <= 27 ? 2 : 3);
      final sizeWeek = _babySizes.keys
          .where((w) => w <= week)
          .fold(4, (best, w) => w > best ? w : best);

      body = ListView(
        padding: const EdgeInsets.all(AppSpacing.large),
        children: <Widget>[
          WhiteCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: <Widget>[
                Text('Week $week',
                    style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFC2185B))),
                Text('Trimester $trimester',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (week / 40).clamp(0.0, 1.0),
                    minHeight: 8,
                    color: const Color(0xFFC2185B),
                    backgroundColor: const Color(0xFFFCE4EC),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Baby is about the size of a ${_babySizes[sizeWeek]}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  daysLeft > 0
                      ? '$daysLeft days to go · due ${svcDayLabel(svcDay(_due!))}'
                      : 'Due date reached — any day now! 💕',
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickDueDate,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Change due date',
                      style: TextStyle(fontSize: 11.5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'General guidance only — always follow your doctor\'s advice.',
            style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: AppColors.textMuted),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: svcAppBar('🤰 Pregnancy Tracker'),
      body: body,
    );
  }
}
