import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/energy_log_record.dart';
import '../../models/planner_session_log.dart';
import '../../services/custom_mode_store.dart';
import '../../services/energy_log_store.dart';
import '../../services/remote_sync.dart';
import '../../services/sleep_schedule_store.dart';
import '../home_tab/data/mode_advice.dart';
import '../profile/profile_store.dart';
import '../services/tools/daily_planner_page.dart';
import '../services/tools/toolkit.dart';

class ComparePage extends StatefulWidget {
  const ComparePage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  List<PlannerSessionLog> _sessionLogs = const <PlannerSessionLog>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ProfileStore.instance.plannerMode.addListener(_reloadForMode);
    _loadLogs();
  }

  @override
  void dispose() {
    ProfileStore.instance.plannerMode.removeListener(_reloadForMode);
    super.dispose();
  }

  void _reloadForMode() {
    if (mounted) setState(() {});
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    try {
      final userId = ProfileStore.instance.userId.value;
      final store = SqliteEnergyLogStore.instance;
      await store.claimPlannerSessionLogsForUser(userId);
      final logs = await store.plannerSessionLogsForDate(
        dateKey(DateTime.now()),
        userId: userId,
      );
      if (!mounted) return;
      setState(() {
        _sessionLogs = logs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sessionLogs = const <PlannerSessionLog>[];
        _loading = false;
      });
    }
  }

  Future<void> _openChangeMode() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DailyPlannerPage()),
    );
    if (!mounted) return;
    await _loadLogs();
    setState(() {});
  }

  Future<void> _selectCustomPlan(String id) async {
    await CustomModeStore.instance.setActivePlan(id);
    await ProfileStore.instance.setPlannerMode(id);
    if (!mounted) return;
    await _loadLogs();
    setState(() {});
  }

  Future<void> _selectBuiltInMode(String id) async {
    await ProfileStore.instance.setPlannerMode(id);
    if (!mounted) return;
    await _loadLogs();
    setState(() {});
  }

  Future<void> _createCustomPlan() async {
    final plan = await CustomModeStore.instance.addPlan();
    if (plan == null) return;
    await ProfileStore.instance.setPlannerMode(plan.id);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DailyPlannerPage()),
    );
    if (!mounted) return;
    await _loadLogs();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final modeId = ProfileStore.instance.plannerMode.value;
    final selectedMode = allSelectableDayModes.firstWhere(
      (mode) => mode.id == modeId,
      orElse: () => allSelectableDayModes.first,
    );
    final slots = plannerSlotsFor(
      wakeMinutes: SleepScheduleStore.instance.wakeMinutes,
      sleepMinutes: SleepScheduleStore.instance.sleepMinutes,
    );
    final advice = adviceForMode(modeId);
    final now = DateTime.now();
    final nowMinutes = _adjustedMinuteForToday(
      now.hour * 60 + now.minute,
      wakeMinutes: SleepScheduleStore.instance.wakeMinutes,
    );
    final rows = <_CompareRow>[
      for (var i = 0; i < slots.length; i++)
        _CompareRow(
          sessionId: 'slot_$i',
          time: slots[i].rangeLabel,
          startMinutes: slots[i].startMinutes,
          endMinutes: slots[i].endMinutes,
          planTitle: advice[i].tip,
          planBody: advice[i].recommendation,
          userText: _userTextFor('slot_$i'),
          status: _statusFor('slot_$i'),
          canMark: slots[i].startMinutes <= nowMinutes,
        ),
    ];

    final content = Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _DayModeHeader(
            modeLabel: selectedMode.label,
            loading: _loading,
            onChange: _openChangeMode,
            onBuiltInSelected: _selectBuiltInMode,
            onCustomSelected: _selectCustomPlan,
            onCreatePlan: _createCustomPlan,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _JoinedCompareColumns(
              modeLabel: selectedMode.shortLabel,
              rows: rows,
              onStatusChanged: _setSessionStatus,
            ),
          ),
        ],
      ),
    );
    if (widget.embedded) return content;
    return Scaffold(
      appBar: svcAppBar('Day Mode'),
      body: content,
    );
  }

  int _adjustedMinuteForToday(int minutes, {required int wakeMinutes}) {
    var adjusted = minutes % kDayMinutes;
    while (adjusted < wakeMinutes) {
      adjusted += kDayMinutes;
    }
    return adjusted;
  }

  String _statusFor(String sessionId) {
    final log = _logFor(sessionId);
    return log?.status ?? PlannerSessionStatus.notDone;
  }

  String _userTextFor(String sessionId) {
    final log = _logFor(sessionId);
    if (log == null) return '';
    if (log.status == PlannerSessionStatus.partial) return 'Partially done';
    if (log.status == PlannerSessionStatus.notDone) return 'Not done';
    return log.title.trim().isEmpty ? 'Marked done' : log.title.trim();
  }

  PlannerSessionLog? _logFor(String sessionId) {
    for (final item in _sessionLogs) {
      if (item.sessionId == sessionId) return item;
    }
    return null;
  }

  Future<void> _setSessionStatus(_CompareRow row, String status) async {
    if (!row.canMark) return;
    final today = dateKey(DateTime.now());
    final userId = ProfileStore.instance.userId.value;
    final isDone = status == PlannerSessionStatus.done;
    final title = switch (status) {
      PlannerSessionStatus.done => row.planTitle,
      PlannerSessionStatus.partial => 'Partially done',
      _ => 'Not done',
    };
    final log = PlannerSessionLog(
      id: 'planner_${userId}_${today}_${row.sessionId}',
      userId: userId,
      date: today,
      sessionId: row.sessionId,
      startMinutes: row.startMinutes,
      endMinutes: row.endMinutes,
      title: title,
      isDone: isDone,
      status: status,
    );

    setState(() {
      _sessionLogs = <PlannerSessionLog>[
        for (final item in _sessionLogs)
          if (item.sessionId != row.sessionId) item,
        log,
      ]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    });

    try {
      await SqliteEnergyLogStore.instance.savePlannerSessionLog(log);
      await RemoteSync.instance.upsertPlannerSessionLog(log, userId: userId);
    } catch (_) {}
  }
}

class _DayModeHeader extends StatelessWidget {
  const _DayModeHeader({
    required this.modeLabel,
    required this.loading,
    required this.onChange,
    required this.onBuiltInSelected,
    required this.onCustomSelected,
    required this.onCreatePlan,
  });

  final String modeLabel;
  final bool loading;
  final VoidCallback onChange;
  final ValueChanged<String> onBuiltInSelected;
  final ValueChanged<String> onCustomSelected;
  final VoidCallback onCreatePlan;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ValueListenableBuilder<List<CustomPlan>>(
      valueListenable: CustomModeStore.instance.plans,
      builder: (context, plans, _) {
        final activeMode = ProfileStore.instance.plannerMode.value;
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.success.withOpacity(0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.view_timeline_rounded,
                      size: 18,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Day mode',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface.withOpacity(0.5),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          modeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (loading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    FilledButton.tonalIcon(
                      onPressed: onChange,
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text('Change'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: <Widget>[
                  for (final mode in allDayModes)
                    ChoiceChip(
                      selected: activeMode == mode.id,
                      label: Text(mode.shortLabel),
                      onSelected: (_) => onBuiltInSelected(mode.id),
                    ),
                  for (final plan in plans)
                    ChoiceChip(
                      selected: activeMode == plan.id,
                      label: Text(plan.name),
                      onSelected: (_) => onCustomSelected(plan.id),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('New plan'),
                    onPressed: onCreatePlan,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompareRow {
  const _CompareRow({
    required this.sessionId,
    required this.time,
    required this.startMinutes,
    required this.endMinutes,
    required this.planTitle,
    required this.planBody,
    required this.userText,
    required this.status,
    required this.canMark,
  });

  final String sessionId;
  final String time;
  final int startMinutes;
  final int endMinutes;
  final String planTitle;
  final String planBody;
  final String userText;
  final String status;
  final bool canMark;

  bool get done => status == PlannerSessionStatus.done;
  bool get partial => status == PlannerSessionStatus.partial;
}

class _JoinedCompareColumns extends StatelessWidget {
  const _JoinedCompareColumns({
    required this.modeLabel,
    required this.rows,
    required this.onStatusChanged,
  });

  final String modeLabel;
  final List<_CompareRow> rows;
  final void Function(_CompareRow row, String status) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline.withOpacity(0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _CompareHeader(modeLabel: modeLabel),
                Divider(height: 1, color: colors.outline.withOpacity(0.22)),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _CompareAlignedRow(
                      row: rows[index],
                      first: index == 0,
                      last: index == rows.length - 1,
                      onStatusChanged: onStatusChanged,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareHeader extends StatelessWidget {
  const _CompareHeader({required this.modeLabel});

  final String modeLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _HeaderCell(
              title: 'Mode plan',
              subtitle: modeLabel,
              icon: Icons.route_rounded,
              color: AppColors.primary,
            ),
          ),
          Container(
            width: 1,
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: colors.outline.withOpacity(0.2),
          ),
          const Expanded(
            child: _HeaderCell(
              title: 'Your result',
              subtitle: 'Done / partial / not done',
              icon: Icons.fact_check_rounded,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurface.withOpacity(0.48),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompareAlignedRow extends StatelessWidget {
  const _CompareAlignedRow({
    required this.row,
    required this.first,
    required this.last,
    required this.onStatusChanged,
  });

  final _CompareRow row;
  final bool first;
  final bool last;
  final void Function(_CompareRow row, String status) onStatusChanged;

  Color _statusColor(ColorScheme colors) {
    return switch (row.status) {
      PlannerSessionStatus.done => AppColors.success,
      PlannerSessionStatus.partial => const Color(0xFFE0A224),
      _ => row.canMark
          ? colors.onSurface.withOpacity(0.44)
          : colors.outline.withOpacity(0.7),
    };
  }

  String get _statusTitle {
    return switch (row.status) {
      PlannerSessionStatus.done => 'Done',
      PlannerSessionStatus.partial => 'Partly done',
      _ => row.canMark ? 'Not done' : 'Upcoming',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = _statusColor(colors);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 22,
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Container(
                    width: 2,
                    color: first
                        ? Colors.transparent
                        : colors.outline.withOpacity(0.24),
                  ),
                ),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: last
                        ? Colors.transparent
                        : colors.outline.withOpacity(0.24),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 9),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colors.outline.withOpacity(0.14)),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _PlanCell(row: row),
                  ),
                  Container(
                    width: 1,
                    height: 86,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: colors.outline.withOpacity(0.18),
                  ),
                  Expanded(
                    child: _UserStatusCell(
                      row: row,
                      statusColor: statusColor,
                      statusTitle: _statusTitle,
                      onStatusChanged: onStatusChanged,
                    ),
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

class _PlanCell extends StatelessWidget {
  const _PlanCell({required this.row});

  final _CompareRow row;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          row.time,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.onSurface.withOpacity(0.45),
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          row.planTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.onSurface.withOpacity(0.9),
            fontSize: 11,
            height: 1.14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          row.planBody,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.onSurface.withOpacity(0.58),
            fontSize: 9.8,
            height: 1.16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _UserStatusCell extends StatelessWidget {
  const _UserStatusCell({
    required this.row,
    required this.statusColor,
    required this.statusTitle,
    required this.onStatusChanged,
  });

  final _CompareRow row;
  final Color statusColor;
  final String statusTitle;
  final void Function(_CompareRow row, String status) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = row.userText.isEmpty ? 'No result yet' : row.userText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              row.done
                  ? Icons.check_circle_rounded
                  : row.partial
                      ? Icons.adjust_rounded
                      : Icons.radio_button_unchecked_rounded,
              size: 14,
              color: statusColor,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                statusTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          row.canMark ? text : 'Can mark when this block starts',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.onSurface.withOpacity(row.canMark ? 0.58 : 0.38),
            fontSize: 9.8,
            height: 1.16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: <Widget>[
            _StatusChoiceChip(
              label: 'Done',
              icon: Icons.check_rounded,
              color: AppColors.success,
              selected: row.status == PlannerSessionStatus.done,
              enabled: row.canMark,
              onTap: () => onStatusChanged(row, PlannerSessionStatus.done),
            ),
            _StatusChoiceChip(
              label: 'Partial',
              icon: Icons.remove_rounded,
              color: const Color(0xFFE0A224),
              selected: row.status == PlannerSessionStatus.partial,
              enabled: row.canMark,
              onTap: () => onStatusChanged(row, PlannerSessionStatus.partial),
            ),
            _StatusChoiceChip(
              label: 'Not',
              icon: Icons.close_rounded,
              color: colors.onSurface.withOpacity(0.48),
              selected: row.status == PlannerSessionStatus.notDone,
              enabled: row.canMark,
              onTap: () => onStatusChanged(row, PlannerSessionStatus.notDone),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusChoiceChip extends StatelessWidget {
  const _StatusChoiceChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.13) : colors.surfaceTint,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? color.withOpacity(0.55)
                  : colors.outline.withOpacity(0.22),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 12,
                color: enabled ? color : colors.onSurface.withOpacity(0.28),
              ),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  color: enabled
                      ? selected
                          ? color
                          : colors.onSurface.withOpacity(0.58)
                      : colors.onSurface.withOpacity(0.28),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
