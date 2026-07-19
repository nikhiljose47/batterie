import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import 'toolkit.dart';

/// Sleep Tracker — log bed & wake times per night, see duration,
/// 7-day average and sleep debt vs the 8-hour target the home planner
/// is built around.
class SleepPage extends StatefulWidget {
  const SleepPage({super.key});

  @override
  State<SleepPage> createState() => _SleepPageState();
}

class _SleepPageState extends State<SleepPage> {
  static const String key = 'svc.sleep.entries';
  static const int targetMinutes = 8 * 60;

  List<Map<String, dynamic>> _entries = <Map<String, dynamic>>[];
  TimeOfDay _bed = const TimeOfDay(hour: 22, minute: 30);
  TimeOfDay _wake = const TimeOfDay(hour: 6, minute: 30);
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    ServiceStore.loadList(key).then((list) {
      if (!mounted) return;
      setState(() {
        _entries = list;
        _loaded = true;
      });
    });
  }

  /// Minutes slept given bed & wake times; bed after midnight handled.
  int _duration(TimeOfDay bed, TimeOfDay wake) {
    final bedM = bed.hour * 60 + bed.minute;
    final wakeM = wake.hour * 60 + wake.minute;
    return wakeM >= bedM ? wakeM - bedM : 24 * 60 - bedM + wakeM;
  }

  Future<void> _log() async {
    final minutes = _duration(_bed, _wake);
    final day = svcDay(DateTime.now());
    setState(() {
      _entries.removeWhere((e) => e['day'] == day);
      _entries.insert(0, <String, dynamic>{
        'day': day,
        'bed': '${_bed.hour}:${_bed.minute.toString().padLeft(2, '0')}',
        'wake': '${_wake.hour}:${_wake.minute.toString().padLeft(2, '0')}',
        'minutes': minutes,
      });
    });
    await ServiceStore.saveList(key, _entries);
  }

  Future<void> _delete(Map<String, dynamic> e) async {
    setState(() => _entries.remove(e));
    await ServiceStore.saveList(key, _entries);
  }

  String _fmtH(int minutes) =>
      '${(minutes / 60).toStringAsFixed(1)} h';

  @override
  Widget build(BuildContext context) {
    final last7 = _entries.take(7).toList();
    final avg = last7.isEmpty
        ? 0
        : last7.fold<int>(
                0, (sum, e) => sum + ((e['minutes'] as num?)?.toInt() ?? 0)) ~/
            last7.length;
    final debt = last7.fold<int>(0, (sum, e) {
      final m = (e['minutes'] as num?)?.toInt() ?? 0;
      return sum + (targetMinutes - m > 0 ? targetMinutes - m : 0);
    });

    return Scaffold(
      appBar: svcAppBar('😴 Sleep Tracker'),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.large),
              children: <Widget>[
                // Stats
                Row(
                  children: <Widget>[
                    Expanded(
                      child: WhiteCard(
                        child: Column(
                          children: <Widget>[
                            Text(last7.isEmpty ? '—' : _fmtH(avg),
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800)),
                            const Text('7-day average',
                                style: TextStyle(
                                    fontSize: 9.5,
                                    color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: WhiteCard(
                        child: Column(
                          children: <Widget>[
                            Text(
                              debt == 0 ? '0 h' : '-${_fmtH(debt)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: debt > 120
                                    ? const Color(0xFFC62828)
                                    : const Color(0xFF2E7D32),
                              ),
                            ),
                            const Text('sleep debt vs 8 h',
                                style: TextStyle(
                                    fontSize: 9.5,
                                    color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Log last night
                WhiteCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('Log last night',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: SvcChip(
                              label:
                                  '🛏️ Bed ${_bed.format(context)}',
                              selected: true,
                              onTap: () async {
                                final picked = await showTimePicker(
                                    context: context, initialTime: _bed);
                                if (picked != null) {
                                  setState(() => _bed = picked);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SvcChip(
                              label:
                                  '⏰ Wake ${_wake.format(context)}',
                              selected: true,
                              onTap: () async {
                                final picked = await showTimePicker(
                                    context: context, initialTime: _wake);
                                if (picked != null) {
                                  setState(() => _wake = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Text(
                            '= ${_fmtH(_duration(_bed, _wake))}',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: _log,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10)),
                            ),
                            child: const Text('Log',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                if (_entries.isEmpty)
                  const EmptyHint(
                      'Log a night to start seeing your pattern.'),
                if (_entries.isNotEmpty) const SectionLabel('Nights'),
                for (final e in _entries.take(14))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: WhiteCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      child: Row(
                        children: <Widget>[
                          SizedBox(
                            width: 82,
                            child: Text(
                              svcDayLabel(e['day'] as String? ?? '?'),
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${e['bed']} → ${e['wake']}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted),
                            ),
                          ),
                          Text(
                            _fmtH((e['minutes'] as num?)?.toInt() ?? 0),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: ((e['minutes'] as num?)?.toInt() ??
                                          0) >=
                                      targetMinutes
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFEF6C00),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _delete(e),
                            child: Icon(Icons.close_rounded,
                                size: 15,
                                color: AppColors.textMuted
                                    .withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
