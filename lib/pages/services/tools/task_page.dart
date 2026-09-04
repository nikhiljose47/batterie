import 'package:flutter/material.dart';

import 'toolkit.dart';

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
  final bool todayOnly;
  final String? note;
}

const todoConfig = TaskConfig(
  id: 'todo',
  title: 'Today To-Do',
  addHint: 'What needs doing?',
  withTime: true,
  todayOnly: true,
  note: 'Tasks from planner cards open here with the time prefilled.',
);

const remindersConfig = TaskConfig(
  id: 'reminders',
  title: 'Reminders',
  addHint: 'What should be remembered?',
  withDate: true,
  withTime: true,
  note: 'Create a dated reminder and keep it visible in the app.',
);

class TaskToolPage extends StatefulWidget {
  const TaskToolPage({
    super.key,
    required this.config,
    this.initialDueMinutes,
  });

  final TaskConfig config;
  final int? initialDueMinutes;

  @override
  State<TaskToolPage> createState() => _TaskToolPageState();
}

class _TaskToolPageState extends State<TaskToolPage> {
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  bool _loaded = false;
  final Set<String> _selectedIds = <String>{};

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
    super.dispose();
  }

  DateTime? _dueOf(Map<String, dynamic> item) =>
      DateTime.tryParse(item['due'] as String? ?? '');

  String _itemTitle(Map<String, dynamic> item) {
    return (item['title'] as String?) ??
        (item['text'] as String?) ??
        'Untitled task';
  }

  String _itemDetails(Map<String, dynamic> item) {
    return item['details'] as String? ?? '';
  }

  Future<void> _saveItems() async {
    await ServiceStore.saveList(_key, _items);
  }

  Future<void> _openEditor([Map<String, dynamic>? item]) async {
    final result = await Navigator.of(context).push<_TaskEditResult>(
      MaterialPageRoute<_TaskEditResult>(
        builder: (context) => _TaskEditorPage(
          config: widget.config,
          item: item == null ? null : Map<String, dynamic>.from(item),
          initialDueMinutes: widget.initialDueMinutes,
        ),
      ),
    );
    if (result == null) return;

    if (result.deletedId != null) {
      setState(() => _items.removeWhere((i) => i['id'] == result.deletedId));
      await _saveItems();
      return;
    }

    final edited = result.item;
    if (edited == null) return;
    setState(() {
      final index = _items.indexWhere((i) => i['id'] == edited['id']);
      if (index == -1) {
        _items.insert(0, edited);
      } else {
        _items[index] = edited;
      }
    });
    await _saveItems();
  }

  Future<void> _toggle(String id) async {
    setState(() {
      final item = _items.firstWhere((i) => i['id'] == id);
      item['done'] = !(item['done'] as bool? ?? false);
    });
    await ServiceStore.saveList(_key, _items);
  }

  Future<void> _togglePinned(String id) async {
    setState(() {
      final item = _items.firstWhere((i) => i['id'] == id);
      item['pinned'] = !(item['pinned'] as bool? ?? false);
      item['updatedAt'] = DateTime.now().toIso8601String();
    });
    await _saveItems();
  }

  Future<void> _remove(String id) async {
    setState(() => _items.removeWhere((i) => i['id'] == id));
    await ServiceStore.saveList(_key, _items);
  }

  void _toggleSelected(String id) {
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  void _clearSelection() {
    if (_selectedIds.isEmpty) return;
    setState(_selectedIds.clear);
  }

  Future<void> _pinSelected() async {
    if (_selectedIds.isEmpty) return;
    setState(() {
      for (final item in _items) {
        if (_selectedIds.contains(item['id'])) {
          item['pinned'] = true;
          item['updatedAt'] = DateTime.now().toIso8601String();
        }
      }
      _selectedIds.clear();
    });
    await _saveItems();
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    setState(() {
      _items.removeWhere((i) => _selectedIds.contains(i['id']));
      _selectedIds.clear();
    });
    await _saveItems();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    final today = svcDay(DateTime.now());
    final colors = Theme.of(context).colorScheme;

    var visible = _items.toList();
    if (c.todayOnly) {
      visible = visible.where((i) {
        final due = _dueOf(i);
        return due != null && svcDay(due) == today;
      }).toList();
    }

    visible.sort((a, b) {
      final pinnedA = a['pinned'] as bool? ?? false;
      final pinnedB = b['pinned'] as bool? ?? false;
      if (pinnedA != pinnedB) return pinnedA ? -1 : 1;
      final doneA = a['done'] as bool? ?? false;
      final doneB = b['done'] as bool? ?? false;
      if (doneA != doneB) return doneA ? 1 : -1;
      final dueA = _dueOf(a);
      final dueB = _dueOf(b);
      if (dueA != null && dueB != null) return dueA.compareTo(dueB);
      return 0;
    });

    final pinned = visible
        .where((i) =>
            (i['pinned'] as bool? ?? false) && !(i['done'] as bool? ?? false))
        .toList();
    final open = visible
        .where((i) =>
            !(i['pinned'] as bool? ?? false) && !(i['done'] as bool? ?? false))
        .toList();
    final done = visible.where((i) => i['done'] as bool? ?? false).toList();

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: _selectedIds.isEmpty
          ? svcAppBar(c.title)
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _clearSelection,
              ),
              title: Text(_selectedIds.length.toString()),
              actions: <Widget>[
                IconButton(
                  tooltip: 'Pin',
                  onPressed: _pinSelected,
                  icon: const Icon(Icons.push_pin_outlined),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: _deleteSelected,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
                IconButton(
                  tooltip: 'More',
                  onPressed: _clearSelection,
                  icon: const Icon(Icons.more_vert_rounded),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 8,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: <Widget>[
                _TaskTopBar(
                  openCount: pinned.length + open.length,
                  doneCount: done.length,
                  onCreate: () => _openEditor(),
                ),
                const SizedBox(height: 14),
                if (pinned.isEmpty && open.isEmpty && done.isEmpty)
                  const EmptyHint('Nothing here yet. Tap New to create a card.')
                else ...<Widget>[
                  if (pinned.isNotEmpty) ...<Widget>[
                    const SectionLabel('Pinned'),
                    _TaskGrid(
                      items: pinned,
                      dueLabel: _dueLabel,
                      titleOf: _itemTitle,
                      detailsOf: _itemDetails,
                      onOpen: _openEditor,
                      selectedIds: _selectedIds,
                      onSelect: _toggleSelected,
                      onToggle: _toggle,
                      onPin: _togglePinned,
                      onRemove: _remove,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (open.isNotEmpty) ...<Widget>[
                    SectionLabel(c.todayOnly ? "Today's cards" : 'Others'),
                    _TaskGrid(
                      items: open,
                      dueLabel: _dueLabel,
                      titleOf: _itemTitle,
                      detailsOf: _itemDetails,
                      onOpen: _openEditor,
                      selectedIds: _selectedIds,
                      onSelect: _toggleSelected,
                      onToggle: _toggle,
                      onPin: _togglePinned,
                      onRemove: _remove,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (done.isNotEmpty) ...<Widget>[
                    const SectionLabel('Done'),
                    _TaskGrid(
                      items: done,
                      dueLabel: _dueLabel,
                      titleOf: _itemTitle,
                      detailsOf: _itemDetails,
                      onOpen: _openEditor,
                      selectedIds: _selectedIds,
                      onSelect: _toggleSelected,
                      onToggle: _toggle,
                      onPin: _togglePinned,
                      onRemove: _remove,
                    ),
                  ],
                ],
              ],
            ),
    );
  }

  String? _dueLabel(Map<String, dynamic> item) {
    final due = _dueOf(item);
    if (due == null) return null;
    if (widget.config.withDate) {
      return '${svcDayLabel(svcDay(due))} - ${svcClock(due)}';
    }
    if (widget.config.withTime) return svcClock(due);
    return null;
  }
}

class _TaskGrid extends StatelessWidget {
  const _TaskGrid({
    required this.items,
    required this.dueLabel,
    required this.titleOf,
    required this.detailsOf,
    required this.onOpen,
    required this.selectedIds,
    required this.onSelect,
    required this.onToggle,
    required this.onPin,
    required this.onRemove,
  });

  final List<Map<String, dynamic>> items;
  final String? Function(Map<String, dynamic>) dueLabel;
  final String Function(Map<String, dynamic>) titleOf;
  final String Function(Map<String, dynamic>) detailsOf;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final Set<String> selectedIds;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onPin;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 320;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            for (final item in items)
              SizedBox(
                width: twoColumns
                    ? (constraints.maxWidth - 10) / 2
                    : constraints.maxWidth,
                child: _TaskNoteCard(
                  item: item,
                  title: titleOf(item),
                  details: detailsOf(item),
                  dueLabel: dueLabel(item),
                  onOpen: () => onOpen(item),
                  selected: selectedIds.contains(item['id']),
                  selectionMode: selectedIds.isNotEmpty,
                  onSelect: () => onSelect(item['id'] as String),
                  onToggle: () => onToggle(item['id'] as String),
                  onPin: () => onPin(item['id'] as String),
                  onRemove: () => onRemove(item['id'] as String),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TaskNoteCard extends StatelessWidget {
  const _TaskNoteCard({
    required this.item,
    required this.title,
    required this.details,
    required this.dueLabel,
    required this.onOpen,
    required this.selected,
    required this.selectionMode,
    required this.onSelect,
    required this.onToggle,
    required this.onPin,
    required this.onRemove,
  });

  final Map<String, dynamic> item;
  final String title;
  final String details;
  final String? dueLabel;
  final VoidCallback onOpen;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onSelect;
  final VoidCallback onToggle;
  final VoidCallback onPin;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final done = item['done'] as bool? ?? false;
    final pinned = item['pinned'] as bool? ?? false;
    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: selectionMode ? onSelect : onOpen,
        onLongPress: onSelect,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  selected ? colors.primary : colors.outline.withOpacity(0.42),
              width: selected ? 2.2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.22,
                        fontWeight: FontWeight.w600,
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done
                            ? colors.onSurface.withOpacity(0.42)
                            : colors.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onToggle,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 30,
                      height: 30,
                    ),
                    tooltip: done ? 'Mark open' : 'Mark done',
                    icon: Icon(
                      done
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: done
                          ? colors.primary
                          : colors.onSurface.withOpacity(0.34),
                    ),
                  ),
                ],
              ),
              if (details.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  details,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.2,
                    height: 1.34,
                    fontWeight: FontWeight.w400,
                    color: colors.onSurface.withOpacity(done ? 0.38 : 0.62),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  if (dueLabel != null)
                    Expanded(
                      child: Text(
                        dueLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.2,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurface.withOpacity(0.58),
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  IconButton(
                    onPressed: onPin,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    icon: Icon(
                      pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                      size: 16,
                      color: pinned
                          ? colors.primary
                          : colors.onSurface.withOpacity(0.46),
                    ),
                    tooltip: pinned ? 'Unpin' : 'Pin',
                  ),
                  IconButton(
                    onPressed: onRemove,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 17,
                      color: colors.onSurface.withOpacity(0.48),
                    ),
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskTopBar extends StatelessWidget {
  const _TaskTopBar({
    required this.openCount,
    required this.doneCount,
    required this.onCreate,
  });

  final int openCount;
  final int doneCount;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onCreate,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 11, 10, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: colors.outline.withOpacity(0.28)),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.check_box_outlined,
                size: 17,
                color: colors.onSurface.withOpacity(0.46),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Take a note...',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface.withOpacity(0.52),
                  ),
                ),
              ),
              Text(
                '$openCount open',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface.withOpacity(0.48),
                ),
              ),
              if (doneCount > 0) ...<Widget>[
                const SizedBox(width: 8),
                Text(
                  '$doneCount done',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface.withOpacity(0.48),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskEditResult {
  const _TaskEditResult.save(this.item) : deletedId = null;
  const _TaskEditResult.delete(this.deletedId) : item = null;

  final Map<String, dynamic>? item;
  final String? deletedId;
}

class _TaskEditorPage extends StatefulWidget {
  const _TaskEditorPage({
    required this.config,
    required this.item,
    required this.initialDueMinutes,
  });

  final TaskConfig config;
  final Map<String, dynamic>? item;
  final int? initialDueMinutes;

  @override
  State<_TaskEditorPage> createState() => _TaskEditorPageState();
}

class _TaskEditorPageState extends State<_TaskEditorPage> {
  static const int _titleLimit = 72;
  static const int _detailsLimit = 180;

  late final TextEditingController _title;
  late final TextEditingController _details;
  late bool _done;
  late bool _pinned;
  DateTime? _pickedDate;
  TimeOfDay? _pickedTime;

  bool get _isNew => widget.item == null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _title = TextEditingController(
      text: (item?['title'] as String?) ?? (item?['text'] as String?) ?? '',
    );
    _details = TextEditingController(text: item?['details'] as String? ?? '');
    _done = item?['done'] as bool? ?? false;
    _pinned = item?['pinned'] as bool? ?? false;
    final due = DateTime.tryParse(item?['due'] as String? ?? '');
    if (due != null) {
      _pickedDate = due;
      _pickedTime = TimeOfDay(hour: due.hour, minute: due.minute);
    } else {
      final initial = widget.initialDueMinutes;
      if (initial != null &&
          (widget.config.withTime || widget.config.todayOnly)) {
        _pickedTime =
            TimeOfDay(hour: (initial ~/ 60) % 24, minute: initial % 60);
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    final details = _details.text.trim();
    if (title.isEmpty && details.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final now = DateTime.now();
    DateTime? due;
    if (widget.config.todayOnly ||
        widget.config.withDate ||
        widget.config.withTime) {
      final existingDue =
          DateTime.tryParse(widget.item?['due'] as String? ?? '');
      final base =
          widget.config.todayOnly ? now : (_pickedDate ?? existingDue ?? now);
      final tod = _pickedTime;
      due = DateTime(
        base.year,
        base.month,
        base.day,
        tod?.hour ?? 9,
        tod?.minute ?? 0,
      );
    }

    final existing = widget.item;
    final item = <String, dynamic>{
      ...?existing,
      'id': existing?['id'] as String? ?? now.microsecondsSinceEpoch.toString(),
      'title': title.isEmpty ? details : title,
      'text': title.isEmpty ? details : title,
      'details': details,
      'done': _done,
      'pinned': _pinned,
      'createdAt': existing?['createdAt'] as String? ?? now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      if (due != null) 'due': due.toIso8601String(),
    };
    if (due == null) item.remove('due');
    Navigator.of(context).pop(_TaskEditResult.save(item));
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _pickedDate = picked);
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _pickedTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _pickedTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(_isNew ? 'New card' : 'Edit card'),
        actions: <Widget>[
          IconButton(
            tooltip: _pinned ? 'Unpin' : 'Pin',
            onPressed: () => setState(() => _pinned = !_pinned),
            icon: Icon(
              _pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            ),
          ),
          IconButton(
            tooltip: _done ? 'Mark open' : 'Mark done',
            onPressed: () => setState(() => _done = !_done),
            icon: Icon(
              _done
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Save',
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: <Widget>[
          TextField(
            controller: _title,
            maxLength: _titleLimit,
            textInputAction: TextInputAction.next,
            style: TextStyle(
              fontSize: 22,
              height: 1.15,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
            decoration: const InputDecoration(
              hintText: 'Title',
              border: InputBorder.none,
            ),
          ),
          TextField(
            controller: _details,
            maxLength: _detailsLimit,
            minLines: 8,
            maxLines: 18,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w400,
              color: colors.onSurface.withOpacity(0.76),
            ),
            decoration: const InputDecoration(
              hintText: 'Note',
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (widget.config.withDate)
                SvcChip(
                  label: _pickedDate == null
                      ? 'Date'
                      : svcDayLabel(svcDay(_pickedDate!)),
                  selected: _pickedDate != null,
                  onTap: _selectDate,
                ),
              if (widget.config.withTime)
                SvcChip(
                  label: _pickedTime == null
                      ? 'Time'
                      : _pickedTime!.format(context),
                  selected: _pickedTime != null,
                  onTap: _selectTime,
                ),
              SvcChip(
                label: _pinned ? 'Pinned' : 'Pin',
                selected: _pinned,
                onTap: () => setState(() => _pinned = !_pinned),
              ),
              SvcChip(
                label: _done ? 'Done' : 'Open',
                selected: _done,
                onTap: () => setState(() => _done = !_done),
              ),
            ],
          ),
          if (!_isNew) ...<Widget>[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop(
                  _TaskEditResult.delete(widget.item!['id'] as String),
                );
              },
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete card'),
            ),
          ],
        ],
      ),
    );
  }
}
