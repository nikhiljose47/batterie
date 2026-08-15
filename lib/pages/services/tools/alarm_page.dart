import 'package:flutter/material.dart';

import '../../../constants/app_spacing.dart';
import '../../../services/alarm_notification_service.dart';
import 'toolkit.dart';

class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key, this.initialAlarmMinutes});

  final int? initialAlarmMinutes;

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  static const String _key = 'svc.alarms.items';

  final TextEditingController _label = TextEditingController();
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  TimeOfDay _time = TimeOfDay.now();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAlarmMinutes;
    if (initial != null) {
      _time = TimeOfDay(hour: (initial ~/ 60) % 24, minute: initial % 60);
      _label.text = 'Planner alarm';
    }
    _load();
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await ServiceStore.loadList(_key);
    if (!mounted) return;
    setState(() {
      _items = list;
      _loaded = true;
    });
    if (widget.initialAlarmMinutes != null && !_hasTime(_time)) {
      await _add(autoSave: true);
    }
  }

  bool _hasTime(TimeOfDay time) {
    return _items.any((item) {
      return (item['hour'] as int? ?? -1) == time.hour &&
          (item['minute'] as int? ?? -1) == time.minute;
    });
  }

  Future<void> _save() => ServiceStore.saveList(_key, _items);

  DateTime _nextFire(TimeOfDay time) {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _add({bool autoSave = false}) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final title = _label.text.trim().isEmpty ? 'Alarm' : _label.text.trim();
    final item = <String, dynamic>{
      'id': id,
      'label': title,
      'hour': _time.hour,
      'minute': _time.minute,
      'enabled': true,
      'createdAt': DateTime.now().toIso8601String(),
    };

    setState(() {
      _items = <Map<String, dynamic>>[item, ..._items];
      if (!autoSave) _label.clear();
    });
    await _save();
    await AlarmNotificationService.instance.scheduleAlarm(
      id: id,
      when: _nextFire(_time),
      title: title,
      body: 'Alarm set for ${_formatTime(_time)}.',
    );
  }

  Future<void> _toggle(Map<String, dynamic> item, bool enabled) async {
    final id = item['id'] as String;
    setState(() {
      item['enabled'] = enabled;
    });
    await _save();
    if (enabled) {
      final time = TimeOfDay(
        hour: item['hour'] as int? ?? 9,
        minute: item['minute'] as int? ?? 0,
      );
      await AlarmNotificationService.instance.scheduleAlarm(
        id: id,
        when: _nextFire(time),
        title: item['label'] as String? ?? 'Alarm',
        body: 'Alarm set for ${_formatTime(time)}.',
      );
    } else {
      await AlarmNotificationService.instance.cancelAlarm(id);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final id = item['id'] as String;
    setState(() => _items.removeWhere((alarm) => alarm['id'] == id));
    await _save();
    await AlarmNotificationService.instance.cancelAlarm(id);
  }

  Future<void> _editTime(Map<String, dynamic> item) async {
    final current = TimeOfDay(
      hour: item['hour'] as int? ?? 9,
      minute: item['minute'] as int? ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;

    setState(() {
      item['hour'] = picked.hour;
      item['minute'] = picked.minute;
      item['enabled'] = true;
    });
    await _save();
    await AlarmNotificationService.instance.scheduleAlarm(
      id: item['id'] as String,
      when: _nextFire(picked),
      title: item['label'] as String? ?? 'Alarm',
      body: 'Alarm set for ${_formatTime(picked)}.',
    );
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: svcAppBar('Alarms'),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.large),
              children: <Widget>[
                WhiteCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              _formatTime(_time),
                              style: TextStyle(
                                fontSize: 34,
                                height: 1,
                                fontWeight: FontWeight.w900,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _pickTime,
                            icon: const Icon(Icons.schedule_rounded, size: 18),
                            label: const Text('Time'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _label,
                        maxLength: 42,
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: 'Alarm name',
                          filled: true,
                          fillColor: colors.surfaceTint.withOpacity(0.58),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: colors.outline.withOpacity(0.55),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: colors.outline.withOpacity(0.55),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: FilledButton.icon(
                          onPressed: _add,
                          icon: const Icon(Icons.alarm_add_rounded),
                          label: const Text('Set alarm'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_items.isEmpty)
                  const EmptyHint('No alarms yet. Add one for your next plan.')
                else
                  for (final item in _sortedItems()) _AlarmTile(
                    item: item,
                    timeLabel: _formatTime(
                      TimeOfDay(
                        hour: item['hour'] as int? ?? 9,
                        minute: item['minute'] as int? ?? 0,
                      ),
                    ),
                    onToggle: (value) => _toggle(item, value),
                    onEditTime: () => _editTime(item),
                    onDelete: () => _delete(item),
                  ),
              ],
            ),
    );
  }

  List<Map<String, dynamic>> _sortedItems() {
    final copy = _items.toList();
    copy.sort((a, b) {
      final aMinutes = (a['hour'] as int? ?? 0) * 60 + (a['minute'] as int? ?? 0);
      final bMinutes = (b['hour'] as int? ?? 0) * 60 + (b['minute'] as int? ?? 0);
      return aMinutes.compareTo(bMinutes);
    });
    return copy;
  }
}

class _AlarmTile extends StatelessWidget {
  const _AlarmTile({
    required this.item,
    required this.timeLabel,
    required this.onToggle,
    required this.onEditTime,
    required this.onDelete,
  });

  final Map<String, dynamic> item;
  final String timeLabel;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEditTime;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = item['enabled'] as bool? ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onEditTime,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: enabled
                    ? colors.primary.withOpacity(0.38)
                    : colors.outline.withOpacity(0.55),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        timeLabel,
                        style: TextStyle(
                          fontSize: 28,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          color: enabled
                              ? colors.onSurface
                              : colors.onSurface.withOpacity(0.45),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['label'] as String? ?? 'Alarm',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface.withOpacity(0.64),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Delete',
                ),
                Switch(value: enabled, onChanged: onToggle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
