import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import 'toolkit.dart';

/// Task-list template. Powers To-Do (plain tasks), Reminders (date+time,
/// sorted by due, overdue highlighted) and Daily Planner (today-only
/// time blocks).
class TaskConfig {
  const TaskConfig({
    required this.id,
    required this.title,
    required this.addHint,
    this.withDate = false,
    this.withTime = false,
    this.todayOnly = false,
    this.note,
  });

  final String id;
  final String title;
  final String addHint;
  final bool withDate;
  final bool withTime;

  /// Planner mode: entries are pinned to today.
  final bool todayOnly;
  final String? note;
}

const todoConfig = TaskConfig(
  id: 'todo',
  title: '✅ To-Do List',
  addHint: 'Add a task…',
);

const remindersConfig = TaskConfig(
  id: 'reminders',
  title: '⏰ Reminders',
  addHint: 'Remind me to…',
  withDate: true,
  withTime: true,
  note: 'Reminders live in-app for now — open the app to check what\'s '
      'due. OS notifications can be added as a next step.',
);

const plannerConfig = TaskConfig(
  id: 'daily_planner',
  title: '🗓️ Daily Planner',
  addHint: 'Block — "Deep work", "Gym"…',
  withTime: true,
  todayOnly: true,
);

class TaskToolPage extends StatefulWidget {
  const TaskToolPage({super.key, required this.config});
  final TaskConfig config;

  @override
  State<TaskToolPage> createState() => _TaskToolPageState();
}

class _TaskToolPageState extends State<TaskToolPage> {
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  final TextEditingController _input = TextEditingController();
  DateTime? _pickedDate;
  TimeOfDay? _pickedTime;
  bool _loaded = false;

  String get _key => 'svc.${widget.config.id}.items';

  @override
  void initState() {
    super.initState();
    ServiceStore.loadList(_key).then((list) {
      if (!mounted) return;
      setState(() {
        _items = list;
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  DateTime? _dueOf(Map<String, dynamic> item) =>
      DateTime.tryParse(item['due'] as String? ?? '');

  Future<void> _add() async {
    final c = widget.config;
    final text = _input.text.trim();
    if (text.isEmpty) return;

    DateTime? due;
    if (c.todayOnly || c.withDate || c.withTime) {
      final base = c.todayOnly ? DateTime.now() : (_pickedDate ?? DateTime.now());
      final tod = _pickedTime;
      due = DateTime(base.year, base.month, base.day, tod?.hour ?? 9,
          tod?.minute ?? 0);
    }

    setState(() {
      _items.add(<String, dynamic>{
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'text': text,
        'done': false,
        if (due != null) 'due': due.toIso8601String(),
      });
      _input.clear();
      _pickedDate = null;
      _pickedTime = null;
    });
    await ServiceStore.saveList(_key, _items);
  }

  Future<void> _toggle(String id) async {
    setState(() {
      final item = _items.firstWhere((i) => i['id'] == id);
      item['done'] = !(item['done'] as bool? ?? false);
    });
    await ServiceStore.saveList(_key, _items);
  }

  Future<void> _remove(String id) async {
    setState(() => _items.removeWhere((i) => i['id'] == id));
    await ServiceStore.saveList(_key, _items);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    final today = svcDay(DateTime.now());

    var visible = _items.toList();
    if (c.todayOnly) {
      visible = visible.where((i) {
        final due = _dueOf(i);
        return due != null && svcDay(due) == today;
      }).toList();
    }
    // Sort: undone first, then by due time, then insertion.
    visible.sort((a, b) {
      final doneA = a['done'] as bool? ?? false;
      final doneB = b['done'] as bool? ?? false;
      if (doneA != doneB) return doneA ? 1 : -1;
      final dueA = _dueOf(a);
      final dueB = _dueOf(b);
      if (dueA != null && dueB != null) return dueA.compareTo(dueB);
      return 0;
    });

    final open = visible.where((i) => !(i['done'] as bool? ?? false));
    final done = visible.where((i) => i['done'] as bool? ?? false);

    return Scaffold(
      appBar: svcAppBar(c.title),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.large),
              children: <Widget>[
                if (c.note != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceTint.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(c.note!,
                        style: const TextStyle(
                            fontSize: 10.5,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textMuted)),
                  ),

                // Add row
                Row(
                  children: <Widget>[
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _input,
                          onSubmitted: (_) => _add(),
                          style: const TextStyle(fontSize: 12.5),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: c.addHint,
                            hintStyle: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textMuted
                                    .withValues(alpha: 0.8)),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: AppColors.outline
                                      .withValues(alpha: 0.9)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AppColors.primary, width: 1.2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _add,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 40,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
                if (c.withDate || c.withTime)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: <Widget>[
                        if (c.withDate)
                          SvcChip(
                            label: _pickedDate == null
                                ? '📅 Date'
                                : '📅 ${svcDayLabel(svcDay(_pickedDate!))}',
                            selected: _pickedDate != null,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now()
                                    .subtract(const Duration(days: 1)),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setState(() => _pickedDate = picked);
                              }
                            },
                          ),
                        if (c.withDate) const SizedBox(width: 6),
                        if (c.withTime)
                          SvcChip(
                            label: _pickedTime == null
                                ? '🕐 Time'
                                : '🕐 ${_pickedTime!.format(context)}',
                            selected: _pickedTime != null,
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (picked != null) {
                                setState(() => _pickedTime = picked);
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),

                if (open.isEmpty && done.isEmpty)
                  const EmptyHint('Nothing here yet — add the first one.'),
                if (open.isNotEmpty) ...<Widget>[
                  SectionLabel(c.todayOnly ? "Today's blocks" : 'Open'),
                  for (final item in open) _tile(item, false),
                ],
                if (done.isNotEmpty) ...<Widget>[
                  const SectionLabel('Done'),
                  for (final item in done) _tile(item, true),
                ],
              ],
            ),
    );
  }

  Widget _tile(Map<String, dynamic> item, bool done) {
    final due = _dueOf(item);
    final overdue = !done &&
        due != null &&
        widget.config.withDate &&
        due.isBefore(DateTime.now());

    String? dueLabel;
    if (due != null) {
      if (widget.config.withDate) {
        dueLabel = '${svcDayLabel(svcDay(due))} · ${svcClock(due)}';
      } else if (widget.config.withTime) {
        dueLabel = svcClock(due);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: WhiteCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: <Widget>[
            Checkbox(
              value: done,
              activeColor: AppColors.primary,
              onChanged: (_) => _toggle(item['id'] as String),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item['text'] as String,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done
                          ? AppColors.textMuted
                          : const Color(0xFF2A2E3B),
                    ),
                  ),
                  if (dueLabel != null)
                    Text(
                      overdue ? '⚠️ $dueLabel' : dueLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            overdue ? FontWeight.w700 : FontWeight.w500,
                        color: overdue
                            ? const Color(0xFFC62828)
                            : AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            InkWell(
              onTap: () => _remove(item['id'] as String),
              child: Icon(Icons.close_rounded,
                  size: 16,
                  color: AppColors.textMuted.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}
