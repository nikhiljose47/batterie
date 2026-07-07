import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import '../../../models/day_template.dart';
import '../../../models/logged_activity.dart';
import '../dashboard_controller.dart';
import 'template_editor_sheet.dart';

/// "Plan your day" sheet — prefilled templates plus the user's saved custom
/// ones. Tap a card to apply it instantly, or tap Customize to tweak it
/// (and optionally save it as a new custom template) before applying.
class DayPlannerSheet extends StatefulWidget {
  const DayPlannerSheet({super.key, required this.controller});

  final DashboardController controller;

  @override
  State<DayPlannerSheet> createState() => _DayPlannerSheetState();
}

class _DayPlannerSheetState extends State<DayPlannerSheet> {
  List<DayTemplate> _custom = <DayTemplate>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.controller.loadCustomTemplates();
      if (mounted) setState(() => _custom = list);
    } catch (_) {
      // Keep going with just the prefilled templates.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyDirect(DayTemplate template) {
    widget.controller.applyTemplate(template);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied "${template.name}" to today'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openEditor(DayTemplate? template) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TemplateEditorSheet(
        initial: template,
        onSave: (t) async {
          await widget.controller.saveCustomTemplate(t);
          await _load();
        },
        onApply: (items) {
          widget.controller.applyTemplate(
            DayTemplate(
              id: 'adhoc',
              name: template?.name ?? 'Custom plan',
              emoji: template?.emoji ?? '⚡',
              items: items,
            ),
          );
          Navigator.of(context).pop(); // closes the editor sheet
          Navigator.of(context).pop(); // closes the planner sheet
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Applied to today\'s rail'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteCustom(DayTemplate template) async {
    await widget.controller.deleteCustomTemplate(template.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final templates = <DayTemplate>[...prefilledDayTemplates, ..._custom];

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: <Widget>[
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.large, AppSpacing.medium, AppSpacing.large, 0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Plan your day',
                            style: Theme.of(context).textTheme.titleLarge),
                        const Text(
                          'Pick a shape for today, then customize it.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.large,
                        AppSpacing.small,
                        AppSpacing.large,
                        AppSpacing.xLarge,
                      ),
                      itemCount: templates.length + 1,
                      itemBuilder: (context, index) {
                        if (index == templates.length) {
                          return Padding(
                            padding:
                                const EdgeInsets.only(top: AppSpacing.small),
                            child: OutlinedButton.icon(
                              onPressed: () => _openEditor(null),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('New custom template'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(44),
                              ),
                            ),
                          );
                        }
                        final template = templates[index];
                        return _TemplateCard(
                          template: template,
                          onApply: () => _applyDirect(template),
                          onCustomize: () => _openEditor(template),
                          onDelete: template.isCustom
                              ? () => _deleteCustom(template)
                              : null,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.onApply,
    required this.onCustomize,
    this.onDelete,
  });

  final DayTemplate template;
  final VoidCallback onApply;
  final VoidCallback onCustomize;
  final VoidCallback? onDelete;

  String get _timeRange {
    if (template.items.isEmpty) return 'No activities yet';
    final sorted = List.of(template.items)
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    final first = sorted.first;
    final last = sorted.last;
    return '${formatMinutes(first.startMinutes)} – ${formatMinutes(last.startMinutes + last.durationMinutes)} · ${template.items.length} activities';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.small),
      child: Material(
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onApply,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: <Widget>[
                Text(template.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              template.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (template.isCustom) ...<Widget>[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'CUSTOM',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _timeRange,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: AppColors.textMuted),
                    visualDensity: VisualDensity.compact,
                  ),
                TextButton(
                  onPressed: onCustomize,
                  child: const Text('Customize',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
