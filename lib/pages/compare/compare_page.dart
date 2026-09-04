import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/energy_log_record.dart';
import '../../models/planner_session_log.dart';
import '../../services/custom_mode_store.dart';
import '../../services/daily_progress_sync_service.dart';
import '../../services/energy_log_store.dart';
import '../../services/remote_sync.dart';
import '../../services/shared_goal_plan_service.dart';
import '../../services/sleep_schedule_store.dart';
import '../home_tab/data/mode_advice.dart';
import '../profile/profile_store.dart';
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
  int? _usingNowCount;

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
    if (mounted) {
      setState(() {});
      _loadUsingNowCount();
    }
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    _loadUsingNowCount();
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

  Future<void> _loadUsingNowCount() async {
    final modeId = ProfileStore.instance.plannerMode.value;
    final selectedMode = allSelectableDayModes.firstWhere(
      (mode) => mode.id == modeId,
      orElse: () => allSelectableDayModes.first,
    );
    final currentPlan = CustomModeStore.isCustomModeId(modeId)
        ? CustomModeStore.instance.planForModeId(modeId)
        : null;
    try {
      final plans = await SharedGoalPlanService.instance.trendingPlans(
        limit: 50,
      );
      SharedGoalPlan? matched;
      for (final plan in plans) {
        if (plan.id.endsWith('_$modeId') ||
            plan.name.trim().toLowerCase() ==
                selectedMode.label.trim().toLowerCase() ||
            plan.name.trim().toLowerCase() ==
                currentPlan?.name.trim().toLowerCase()) {
          matched = plan;
          break;
        }
      }
      if (!mounted) return;
      setState(() => _usingNowCount = matched?.displayUsedCount ?? 0);
    } catch (_) {
      if (!mounted) return;
      setState(() => _usingNowCount = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final modeId = ProfileStore.instance.plannerMode.value;
    final selectedMode = allSelectableDayModes.firstWhere(
      (mode) => mode.id == modeId,
      orElse: () => allSelectableDayModes.first,
    );
    final phases = dayPhasesFor(
      wakeMinutes: SleepScheduleStore.instance.wakeMinutes,
      sleepMinutes: SleepScheduleStore.instance.sleepMinutes,
    );
    final slots = phases.map((phase) => phase.slot).toList(growable: false);
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
          phaseLabel: phases[i].label,
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
            usingNowCount: _usingNowCount,
          ),
          const SizedBox(height: 7),
          Expanded(
            child: _JoinedCompareColumns(
              modeLabel: selectedMode.label,
              rows: rows,
              onStatusChanged: _setSessionStatus,
            ),
          ),
        ],
      ),
    );
    if (widget.embedded) return content;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: svcAppBar('Track Goal'),
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
      await DailyProgressSyncService.instance.syncToday();
    } catch (_) {}
  }
}

class _DayModeHeader extends StatelessWidget {
  const _DayModeHeader({
    required this.modeLabel,
    required this.usingNowCount,
  });

  final String modeLabel;
  final int? usingNowCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ValueListenableBuilder<List<CustomPlan>>(
      valueListenable: CustomModeStore.instance.plans,
      builder: (context, plans, _) {
        return Container(
          padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.success.withOpacity(0.22)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  size: 13,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  modeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 12,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.success.withOpacity(0.2)),
                ),
                child: Text(
                  usingNowCount == null
                      ? 'Loading'
                      : '$usingNowCount using now',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
    required this.phaseLabel,
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
  final String phaseLabel;
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
                    flex: 4,
                    child: _PlanCell(row: row),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
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
          '${row.phaseLabel} · ${row.time}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.onSurface.withOpacity(0.45),
            fontSize: 10,
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
            fontSize: 11.5,
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
            fontSize: 10.2,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          statusTitle,
          maxLines: 1,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: statusColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Column(
          children: <Widget>[
            _StatusChoiceChip(
              icon: Icons.check_rounded,
              color: AppColors.success,
              selected: row.status == PlannerSessionStatus.done,
              enabled: row.canMark,
              onTap: () => onStatusChanged(row, PlannerSessionStatus.done),
            ),
            const SizedBox(height: 5),
            _StatusChoiceChip(
              icon: Icons.remove_rounded,
              color: const Color(0xFFE0A224),
              selected: row.status == PlannerSessionStatus.partial,
              enabled: row.canMark,
              onTap: () => onStatusChanged(row, PlannerSessionStatus.partial),
            ),
            const SizedBox(height: 5),
            _StatusChoiceChip(
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
    required this.icon,
    required this.color,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

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
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 25,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.13) : colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? color.withOpacity(0.55)
                  : colors.outline.withOpacity(0.22),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 14,
                color: enabled ? color : colors.onSurface.withOpacity(0.28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
