import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import '../../../engine/energy_score_engine.dart';
import '../../../models/day_template.dart';
import '../../../models/logged_activity.dart';

/// Quick-add palette shown inside the editor — a subset of engine activities
/// that cover the common day-shapes (movement, focus, recovery, admin).
const List<String> _paletteActivityIds = <String>[
  'brisk_walking',
  'running_easy_pace',
  'hiit_workout',
  'focused_coding',
  'video_meeting_for_work',
  'email_and_message_backlog',
  'cooking_light_meal',
  'meal_break_away_from_desk',
  'mindfulness_meditation',
  'power_nap_10_20_min',
  'slow_breathing_exercise',
  'deep_house_cleaning',
];

/// Build or customize a [DayTemplate]: add/edit/remove timed activities,
/// then save it as a reusable custom template and/or apply it to today.
class TemplateEditorSheet extends StatefulWidget {
  const TemplateEditorSheet({
    super.key,
    this.initial,
    required this.onSave,
    required this.onApply,
  });

  final DayTemplate? initial;
  final Future<void> Function(DayTemplate template) onSave;
  final void Function(List<TemplateActivity> items) onApply;

  @override
  State<TemplateEditorSheet> createState() => _TemplateEditorSheetState();
}

class _TemplateEditorSheetState extends State<TemplateEditorSheet> {
  static const EnergyScoreEngine _engine = EnergyScoreEngine();
  static const List<String> _emojiChoices = <String>[
    '🧭',
    '🏋️',
    '🌿',
    '💻',
    '⚡',
    '🌙',
    '🍃',
    '🎯',
  ];

  late final TextEditingController _nameController;
  late List<TemplateActivity> _items;
  late String _emoji;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(
      text: initial == null
          ? ''
          : (initial.isCustom ? initial.name : '${initial.name} (custom)'),
    );
    _items =
        List<TemplateActivity>.of(initial?.items ?? const <TemplateActivity>[]);
    _emoji = initial?.emoji ?? _emojiChoices.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  List<TemplateActivity> get _sortedItems => List<TemplateActivity>.of(_items)
    ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

  void _addActivity(String activityId) {
    final defaultDuration = _engine.activityById(activityId).referenceMinutes;
    final lastEnd = _items.isEmpty
        ? 8 * 60
        : (_sortedItems.last.startMinutes + _sortedItems.last.durationMinutes);
    setState(() {
      _items = <TemplateActivity>[
        ..._items,
        TemplateActivity(
          activityId: activityId,
          startMinutes: lastEnd.clamp(0, 1425),
          durationMinutes: defaultDuration.clamp(10, 240),
        ),
      ];
    });
  }

  void _editItem(TemplateActivity item) {
    var start = item.startMinutes.toDouble();
    var duration = item.durationMinutes.toDouble().clamp(10.0, 240.0);
    final activity = _engine.activityById(item.activityId);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xLarge,
            0,
            AppSpacing.xLarge,
            AppSpacing.xLarge,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${activityEmojis[item.activityId] ?? '⚡'} ${activity.name}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.large),
              Row(
                children: <Widget>[
                  const Expanded(child: Text('Start time')),
                  Text(formatMinutes(start.round()),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              Slider(
                value: start,
                min: 0,
                max: 1425,
                divisions: 95,
                onChanged: (v) => setSheetState(() => start = v),
              ),
              Row(
                children: <Widget>[
                  const Expanded(child: Text('Duration')),
                  Text('${duration.round()} min',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              Slider(
                value: duration,
                min: 10,
                max: 240,
                divisions: 23,
                onChanged: (v) => setSheetState(() => duration = v),
              ),
              const SizedBox(height: AppSpacing.medium),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() =>
                            _items = _items.where((i) => i != item).toList());
                        Navigator.of(sheetContext).pop();
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Remove'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.medium),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          final index = _items.indexOf(item);
                          if (index != -1) {
                            _items[index] = item.copyWith(
                              startMinutes: start.round(),
                              durationMinutes: duration.round(),
                            );
                          }
                        });
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    setState(() => _saving = true);
    try {
      final initial = widget.initial;
      final template = DayTemplate(
        id: (initial != null && initial.isCustom)
            ? initial.id
            : 'tpl_custom_${DateTime.now().microsecondsSinceEpoch}',
        name: name.isEmpty ? '$_emoji My plan' : name,
        emoji: _emoji,
        items: _sortedItems,
        isCustom: true,
      );
      await widget.onSave(template);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved "${template.name}"'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _apply() {
    if (_items.isEmpty) return;
    widget.onApply(_sortedItems);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.large,
              AppSpacing.small,
              AppSpacing.large,
              AppSpacing.xLarge,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Customize plan',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.small),
                Row(
                  children: <Widget>[
                    ..._emojiChoices.map(
                      (e) => Padding(
                        padding:
                            const EdgeInsets.only(right: AppSpacing.xSmall),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => setState(() => _emoji = e),
                          child: Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _emoji == e
                                  ? AppColors.surfaceTint
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: _emoji == e
                                    ? AppColors.primary
                                    : AppColors.outline,
                              ),
                            ),
                            child:
                                Text(e, style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.medium),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Template name',
                    hintText: 'e.g. "My Monday routine"',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.large),
                Text(
                  'PLAN (${_sortedItems.length})',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: AppSpacing.small),
                if (_sortedItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.small),
                    child: Text(
                      'No activities yet — add some from below.',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  )
                else
                  ..._sortedItems.map((item) {
                    final activity = _engine.activityById(item.activityId);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.small),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _editItem(item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceTint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: <Widget>[
                              Text(
                                activityEmojis[item.activityId] ?? '⚡',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      activity.name,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${formatMinutes(item.startMinutes)} · ${item.durationMinutes} min',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.edit_outlined,
                                  size: 16, color: AppColors.textMuted),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: AppSpacing.medium),
                const Text(
                  'ADD ACTIVITY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: AppSpacing.small),
                Wrap(
                  spacing: AppSpacing.small,
                  runSpacing: AppSpacing.small,
                  children: _paletteActivityIds.map((id) {
                    final activity = _engine.activityById(id);
                    return ActionChip(
                      avatar: Text(activityEmojis[id] ?? '⚡',
                          style: const TextStyle(fontSize: 13)),
                      label: Text(activity.name,
                          style: const TextStyle(fontSize: 12)),
                      onPressed: () => _addActivity(id),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: AppColors.outline),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.xLarge),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.bookmark_add_outlined, size: 18),
                        label: const Text('Save as template'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.medium),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _sortedItems.isEmpty ? null : _apply,
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Apply to today'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
