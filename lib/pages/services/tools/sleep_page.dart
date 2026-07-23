import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import '../../../services/sleep_schedule_store.dart';
import 'toolkit.dart';

/// Sleep Tracker — two concerns in one place:
///
/// 1. **My Schedule** — the user's daily wake/sleep target.  Persisted via
///    [SleepScheduleStore] and reflected immediately on the home-tab tube and
///    planner card highlighting.
///
/// 2. **Sleep log** — per-night bed/wake records with 7-day stats.
class SleepPage extends StatefulWidget {
  const SleepPage({super.key});

  @override
  State<SleepPage> createState() => _SleepPageState();
}

class _SleepPageState extends State<SleepPage> {
  static const String _logKey = 'svc.sleep.entries';
  static const int _targetMinutes = 8 * 60;

  List<Map<String, dynamic>> _entries = <Map<String, dynamic>>[];
  late TimeOfDay _logBed;
  late TimeOfDay _logWake;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    // Sensible log defaults come from the schedule
    _logBed = SleepScheduleStore.instance.sleepTime.value;
    _logWake = SleepScheduleStore.instance.wakeTime.value;

    ServiceStore.loadList(_logKey).then((list) {
      if (!mounted) return;
      setState(() {
        _entries = list;
        _loaded = true;
        if (list.isNotEmpty) {
          final wStr = list.first['wake'] as String?;
          if (wStr != null) {
            final p = wStr.split(':');
            if (p.length == 2) {
              _logWake = TimeOfDay(
                  hour: int.tryParse(p[0]) ?? _logWake.hour,
                  minute: int.tryParse(p[1]) ?? _logWake.minute);
            }
          }
        }
      });
    });
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  int _duration(TimeOfDay bed, TimeOfDay wake) {
    final b = bed.hour * 60 + bed.minute;
    final w = wake.hour * 60 + wake.minute;
    return w >= b ? w - b : 24 * 60 - b + w;
  }

  String _fmtH(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  String _fmtTod(TimeOfDay t) {
    final h = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  // ── actions ──────────────────────────────────────────────────────────────

  Future<void> _pickScheduleWake() async {
    final t = await showTimePicker(
        context: context,
        initialTime: SleepScheduleStore.instance.wakeTime.value);
    if (t != null) {
      await SleepScheduleStore.instance.setWake(t);
      if (mounted) setState(() {});
    }
  }

  Future<void> _pickScheduleSleep() async {
    final t = await showTimePicker(
        context: context,
        initialTime: SleepScheduleStore.instance.sleepTime.value);
    if (t != null) {
      await SleepScheduleStore.instance.setSleep(t);
      if (mounted) setState(() {});
    }
  }

  Future<void> _log() async {
    final minutes = _duration(_logBed, _logWake);
    final day = svcDay(DateTime.now());
    setState(() {
      _entries.removeWhere((e) => e['day'] == day);
      _entries.insert(0, <String, dynamic>{
        'day': day,
        'bed': '${_logBed.hour}:${_logBed.minute.toString().padLeft(2, '0')}',
        'wake': '${_logWake.hour}:${_logWake.minute.toString().padLeft(2, '0')}',
        'minutes': minutes,
      });
    });
    await ServiceStore.saveList(_logKey, _entries);
  }

  Future<void> _delete(Map<String, dynamic> e) async {
    setState(() => _entries.remove(e));
    await ServiceStore.saveList(_logKey, _entries);
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final last7 = _entries.take(7).toList();
    final avg = last7.isEmpty
        ? 0
        : last7.fold<int>(
                0, (s, e) => s + ((e['minutes'] as num?)?.toInt() ?? 0)) ~/
            last7.length;
    final debt = last7.fold<int>(0, (s, e) {
      final m = (e['minutes'] as num?)?.toInt() ?? 0;
      return s + (m < _targetMinutes ? _targetMinutes - m : 0);
    });

    return Scaffold(
      appBar: svcAppBar('😴 Sleep Tracker'),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.large),
              children: <Widget>[
                _buildScheduleCard(),
                const SizedBox(height: 12),
                _buildStatsRow(avg, debt),
                const SizedBox(height: 12),
                _buildLogCard(),
                const SizedBox(height: 12),
                if (_entries.isEmpty)
                  const EmptyHint('Log a night to start seeing your pattern.')
                else ...<Widget>[
                  const SectionLabel('Nights'),
                  for (final e in _entries.take(14))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _buildNightRow(e),
                    ),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  // ── schedule card ─────────────────────────────────────────────────────────

  Widget _buildScheduleCard() {
    return ValueListenableBuilder<TimeOfDay>(
      valueListenable: SleepScheduleStore.instance.wakeTime,
      builder: (_, wake, __) => ValueListenableBuilder<TimeOfDay>(
        valueListenable: SleepScheduleStore.instance.sleepTime,
        builder: (_, sleep, __) {
          final planned = SleepScheduleStore.instance.plannedSleepMinutes;
          return Container(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFF1B1E4A),
                  Color(0xFF2E2F6E),
                  Color(0xFF3D3E85),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Header row
                Row(
                  children: <Widget>[
                    const Text(
                      'MY DAILY SCHEDULE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3,
                        color: Color(0xFFB5B8FF),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'affects home tab',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'Sets your day tube & planner timing',
                  style: TextStyle(fontSize: 11, color: Colors.white54),
                ),
                const SizedBox(height: 22),

                // Time selectors row
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Wake
                      Expanded(child: _scheduleTimeTile(
                        emoji: '🌅',
                        label: 'WAKE UP',
                        labelColor: const Color(0xFF66BB6A),
                        time: wake,
                        onTap: _pickScheduleWake,
                      )),
                      // Centre — planned duration
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Text('↔',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.white30)),
                            const SizedBox(height: 4),
                            Text(
                              _fmtH(planned),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              'sleep',
                              style:
                                  TextStyle(fontSize: 8, color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                      // Sleep
                      Expanded(child: _scheduleTimeTile(
                        emoji: '🌙',
                        label: 'BEDTIME',
                        labelColor: const Color(0xFFB5B8FF),
                        time: sleep,
                        onTap: _pickScheduleSleep,
                      )),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _scheduleTimeTile({
    required String emoji,
    required String label,
    required Color labelColor,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.18), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _fmtTod(time),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            const Row(
              children: <Widget>[
                Icon(Icons.edit_rounded, size: 10, color: Colors.white38),
                SizedBox(width: 3),
                Text('Tap to change',
                    style: TextStyle(fontSize: 9, color: Colors.white38)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── stats row ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow(int avg, int debt) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatCard(
            value: avg == 0 ? '—' : _fmtH(avg),
            label: '7-day average',
            color: avg >= _targetMinutes
                ? const Color(0xFF2E7D32)
                : AppColors.textMuted,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: debt == 0 ? '0h' : '-${_fmtH(debt)}',
            label: 'sleep debt',
            color: debt == 0
                ? const Color(0xFF2E7D32)
                : debt > 120
                    ? const Color(0xFFC62828)
                    : const Color(0xFFEF6C00),
          ),
        ),
      ],
    );
  }

  // ── log card ──────────────────────────────────────────────────────────────

  Widget _buildLogCard() {
    final dur = _duration(_logBed, _logWake);
    final ok = dur >= _targetMinutes;
    return WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text(
                'LOG LAST NIGHT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              Text(
                _fmtH(dur),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: ok
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFEF6C00),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: SvcChip(
                  label: '🛏️ Bed  ${_fmtTod(_logBed)}',
                  selected: true,
                  onTap: () async {
                    final t = await showTimePicker(
                        context: context, initialTime: _logBed);
                    if (t != null) setState(() => _logBed = t);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SvcChip(
                  label: '⏰ Wake ${_fmtTod(_logWake)}',
                  selected: true,
                  onTap: () async {
                    final t = await showTimePicker(
                        context: context, initialTime: _logWake);
                    if (t != null) setState(() => _logWake = t);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _log,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Log this night',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── night row ─────────────────────────────────────────────────────────────

  Widget _buildNightRow(Map<String, dynamic> e) {
    final minutes = (e['minutes'] as num?)?.toInt() ?? 0;
    final ok = minutes >= _targetMinutes;
    final accent = ok ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00);
    final bedStr = e['bed'] as String? ?? '?';
    final wakeStr = e['wake'] as String? ?? '?';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.outline.withValues(alpha: 0.8), width: 0.8),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          // Colour bar
          Container(
            width: 4,
            height: 56,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Date
          SizedBox(
            width: 76,
            child: Text(
              svcDayLabel(e['day'] as String? ?? '?'),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          // Times + bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$bedStr → $wakeStr',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (minutes / _targetMinutes).clamp(0.0, 1.2),
                    backgroundColor:
                        AppColors.outline.withValues(alpha: 0.25),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _fmtH(minutes),
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: accent),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _delete(e),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.close_rounded,
                  size: 15,
                  color: AppColors.textMuted.withValues(alpha: 0.5)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── stat card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.8)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(
                  fontSize: 9.5, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
