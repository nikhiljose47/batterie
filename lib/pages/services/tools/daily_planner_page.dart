import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../constants/app_colors.dart';
import '../../../services/custom_mode_store.dart';
import '../../../services/sleep_schedule_store.dart';
import '../../home_tab/data/mode_advice.dart'
    show
        DayMode,
        adviceForMode,
        allDayModes,
        allSelectableDayModes,
        minutesLabel,
        plannerSlots;
import '../../profile/profile_store.dart';
import 'sleep_page.dart';
import 'toolkit.dart';

class DailyPlannerPage extends StatefulWidget {
  const DailyPlannerPage({super.key});

  @override
  State<DailyPlannerPage> createState() => _DailyPlannerPageState();
}

class _DailyPlannerPageState extends State<DailyPlannerPage> {
  static const int _headlineLimit = 88;
  static const int _detailLimit = 240;
  static const int _nameLimit = 22;

  static const Color _accent = AppColors.primary;
  static const Color _accentDark = Color(0xFF0B7A37);
  late String _selectedModeId;
  late CustomPlan _draftPlan;
  late List<CustomSlot> _draftSlots;
  late final TextEditingController _nameCtl;
  late final TextEditingController _headlineCtl;
  late final TextEditingController _detailCtl;

  int _selectedSlot = 0;
  bool _dirty = false;
  bool _saving = false;

  bool get _isCustom => CustomModeStore.isCustomModeId(_selectedModeId);

  List<CustomSlot> get _visibleSlots {
    if (_isCustom) return _draftSlots;
    final advice = adviceForMode(_selectedModeId);
    return List<CustomSlot>.generate(plannerSlots.length, (index) {
      if (index >= advice.length) return const CustomSlot();
      final item = advice[index];
      return CustomSlot(
        recommendation: item.recommendation,
        tip: item.tip,
        descriptions: item.descriptions,
      );
    });
  }

  String get _selectedModeName {
    if (_isCustom) return _draftPlan.name;
    return allDayModes
        .firstWhere((mode) => mode.id == _selectedModeId,
            orElse: () => allDayModes.first)
        .label;
  }

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController();
    _headlineCtl = TextEditingController();
    _detailCtl = TextEditingController();
    _selectedModeId = ProfileStore.instance.plannerMode.value;
    final plan = CustomModeStore.instance.planForModeId(_selectedModeId);
    _selectedModeId = CustomModeStore.isCustomModeId(_selectedModeId)
        ? plan.id
        : _selectedModeId;
    _loadDraft(plan);
    SleepScheduleStore.instance.wakeTime.addListener(_onScheduleChanged);
    SleepScheduleStore.instance.sleepTime.addListener(_onScheduleChanged);
  }

  @override
  void dispose() {
    SleepScheduleStore.instance.wakeTime.removeListener(_onScheduleChanged);
    SleepScheduleStore.instance.sleepTime.removeListener(_onScheduleChanged);
    _nameCtl.dispose();
    _headlineCtl.dispose();
    _detailCtl.dispose();
    super.dispose();
  }

  void _onScheduleChanged() {
    if (!mounted) return;
    final maxIndex = plannerSlots.length - 1;
    setState(() {
      if (_selectedSlot > maxIndex) _selectedSlot = maxIndex;
    });
  }

  void _loadDraft(CustomPlan plan) {
    _draftPlan = plan;
    _draftSlots = List<CustomSlot>.of(
      CustomModeStore.normalizeSlots(plan.slots),
    );
    _nameCtl.text = plan.name;
    _syncSlotControllers();
    _dirty = false;
  }

  void _syncSlotControllers() {
    final slot = _draftSlots[_selectedSlot];
    _headlineCtl.text = slot.recommendation;
    _detailCtl.text = slot.descriptions.join('\n');
  }

  List<String> _detailLines(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const <String>[];
    return trimmed
        .split('\n')
        .map((line) => line.replaceFirst(RegExp(r'^[-•]\s*'), '').trim())
        .where((line) => line.isNotEmpty)
        .take(3)
        .toList();
  }

  void _markDirty() {
    if (_isCustom) setState(() => _dirty = true);
  }

  void _updateSelectedSlot({String? headline, String? detail}) {
    if (!_isCustom) return;
    final nextHeadline = headline ?? _headlineCtl.text;
    final nextDetail = detail ?? _detailCtl.text;
    _draftSlots[_selectedSlot] = _draftSlots[_selectedSlot].copyWith(
      recommendation: nextHeadline.trim(),
      tip: nextHeadline.trim(),
      descriptions: _detailLines(nextDetail),
    );
    _markDirty();
  }

  Future<void> _saveIfNeeded() async {
    if (_dirty) await _save(showMessage: false);
  }

  Future<void> _save({bool showMessage = true}) async {
    if (_saving || !_isCustom) return;
    _updateSelectedSlot();
    setState(() => _saving = true);
    final name =
        _nameCtl.text.trim().isEmpty ? 'My Plan' : _nameCtl.text.trim();
    final plan = _draftPlan.copyWith(name: name, slots: _draftSlots);
    await CustomModeStore.instance.savePlan(plan);
    await ProfileStore.instance.setPlannerMode(plan.id);
    if (!mounted) return;
    setState(() {
      _selectedModeId = plan.id;
      _draftPlan = plan;
      _saving = false;
      _dirty = false;
    });
    if (showMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name saved'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _selectBuiltIn(DayMode mode) async {
    await _saveIfNeeded();
    await ProfileStore.instance.setPlannerMode(mode.id);
    if (!mounted) return;
    setState(() {
      _selectedModeId = mode.id;
      _dirty = false;
    });
  }

  Future<void> _selectCustomPlan(CustomPlan plan) async {
    await _saveIfNeeded();
    await CustomModeStore.instance.setActivePlan(plan.id);
    await ProfileStore.instance.setPlannerMode(plan.id);
    if (!mounted) return;
    setState(() {
      _selectedModeId = plan.id;
      _selectedSlot = 0;
      _loadDraft(plan);
    });
  }

  Future<void> _addPlan() async {
    await _saveIfNeeded();
    final plan = await CustomModeStore.instance.addPlan();
    if (!mounted) return;
    if (plan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can keep up to 5 custom plans')),
      );
      return;
    }
    await ProfileStore.instance.setPlannerMode(plan.id);
    if (!mounted) return;
    setState(() {
      _selectedModeId = plan.id;
      _selectedSlot = 0;
      _loadDraft(plan);
    });
  }

  Future<void> _deletePlan() async {
    if (!_isCustom || CustomModeStore.instance.plans.value.length <= 1) return;
    await CustomModeStore.instance.deletePlan(_draftPlan.id);
    final next = CustomModeStore.instance.plans.value.first;
    await ProfileStore.instance.setPlannerMode(next.id);
    if (!mounted) return;
    setState(() {
      _selectedModeId = next.id;
      _selectedSlot = 0;
      _loadDraft(next);
    });
  }

  Future<void> _openSleepEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SleepPage()),
    );
    if (!mounted) return;
    _onScheduleChanged();
  }

  void _selectSlot(int index) {
    if (index == _selectedSlot) return;
    _updateSelectedSlot();
    setState(() {
      _selectedSlot = index;
      _syncSlotControllers();
    });
  }

  void _shiftSlot(int delta) {
    final next = (_selectedSlot + delta) % plannerSlots.length;
    _selectSlot(next < 0 ? next + plannerSlots.length : next);
  }

  Future<void> _copyFromMode() async {
    if (!_isCustom) return;
    _updateSelectedSlot();

    final sources = allSelectableDayModes
        .where((mode) => mode.id != _selectedModeId)
        .toList(growable: false);
    final selected = await showModalBottomSheet<DayMode>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _CopyModeSheet(sources: sources),
    );
    if (selected == null || !mounted) return;

    final advice = adviceForMode(selected.id);
    final copied = List<CustomSlot>.generate(plannerSlots.length, (index) {
      if (index >= advice.length) return const CustomSlot();
      final item = advice[index];
      final details = <String>[
        item.recommendation,
        ...item.descriptions,
      ].where((line) => line.trim().isNotEmpty).take(3).toList();
      return CustomSlot(
        recommendation: item.tip,
        tip: item.tip,
        descriptions: details,
      );
    });

    setState(() {
      _draftSlots = copied;
      _syncSlotControllers();
      _dirty = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${selected.label} into this plan')),
    );
  }

  String _slotTitle(int index) {
    final slot = plannerSlots[index];
    return '${minutesLabel(slot.startMinutes)} - ${minutesLabel(slot.endMinutes)}';
  }

  String _headlineHint() {
    final advice = adviceForMode(_selectedModeId);
    if (_selectedSlot < advice.length) {
      return advice[_selectedSlot].recommendation;
    }
    final hour = (plannerSlots[_selectedSlot].startMinutes ~/ 60) % 24;
    if (hour < 10) return 'Start with one clear win';
    if (hour < 13) return 'Finish, reply, decide';
    if (hour < 16) return 'Use the quieter task';
    if (hour < 19) return 'Move, reset, wrap up';
    return 'Make tomorrow easier';
  }

  String _detailHint() {
    final advice = adviceForMode(_selectedModeId);
    if (_selectedSlot < advice.length &&
        advice[_selectedSlot].descriptions.isNotEmpty) {
      return advice[_selectedSlot].descriptions.take(3).join('\n');
    }
    final hour = (plannerSlots[_selectedSlot].startMinutes ~/ 60) % 24;
    if (hour < 10) return 'Pick one task\nSet a small timer\nKeep it simple';
    if (hour < 13) return 'Batch messages\nClose tiny loops\nTake a break';
    if (hour < 16) return 'Eat, hydrate\nWalk for 10 min\nReturn gently';
    if (hour < 19) return 'Move your body\nHandle one errand\nSlow the pace';
    return 'Dim screens\nPrep one thing\nLet the day end';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: svcAppBar('Daily Planner'),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _ModeGallerySection(
              selectedModeId: _selectedModeId,
              onBuiltInSelected: _selectBuiltIn,
              onCustomSelected: _selectCustomPlan,
              onAddCustom: _addPlan,
            ),
            _PlanControlSection(
              isCustom: _isCustom,
              selectedName: _selectedModeName,
              nameController: _nameCtl,
              dirty: _dirty,
              saving: _saving,
              onNameChanged: (_) => _markDirty(),
              onSave: _save,
              onDelete: _deletePlan,
              onSleep: _openSleepEditor,
            ),
            _SlotNavigatorSection(
              selectedIndex: _selectedSlot,
              draftSlots: _visibleSlots,
              slotLabel: _slotTitle(_selectedSlot),
              onPrevious: () => _shiftSlot(-1),
              onNext: () => _shiftSlot(1),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                child: _PlanFormCard(
                  enabled: _isCustom,
                  slotLabel: _slotTitle(_selectedSlot),
                  headlineController: _headlineCtl,
                  detailController: _detailCtl,
                  headlineLimit: _headlineLimit,
                  detailLimit: _detailLimit,
                  headlineHint: _headlineHint(),
                  detailHint: _detailHint(),
                  onHeadlineChanged: (value) =>
                      _updateSelectedSlot(headline: value),
                  onDetailChanged: (value) =>
                      _updateSelectedSlot(detail: value),
                  onCopyFromMode: _copyFromMode,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _dirty || _saving
          ? FloatingActionButton.extended(
              onPressed: _saving ? null : _save,
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 20),
              label: Text(_saving ? 'Saving...' : 'Save'),
            )
          : null,
    );
  }
}

class _PlanControlSection extends StatelessWidget {
  const _PlanControlSection({
    required this.isCustom,
    required this.selectedName,
    required this.nameController,
    required this.dirty,
    required this.saving,
    required this.onNameChanged,
    required this.onSave,
    required this.onDelete,
    required this.onSleep,
  });

  final bool isCustom;
  final String selectedName;
  final TextEditingController nameController;
  final bool dirty;
  final bool saving;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onSave;
  final VoidCallback onDelete;
  final VoidCallback onSleep;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool canSave = isCustom && dirty && !saving;
    final textColor = colors.onSurface;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colors.outline.withOpacity(0.55)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Plan name
          Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.softAccent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  isCustom ? Icons.edit_note_rounded : Icons.event_note_rounded,
                  size: 18,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 9),

              // Expanded fixes the TextField render issue.
              Expanded(
                child: isCustom
                    ? TextField(
                        controller: nameController,
                        maxLength: _DailyPlannerPageState._nameLimit,
                        maxLines: 1,
                        textInputAction: TextInputAction.done,
                        inputFormatters: <TextInputFormatter>[
                          LengthLimitingTextInputFormatter(
                            _DailyPlannerPageState._nameLimit,
                          ),
                        ],
                        onChanged: onNameChanged,
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: 'Enter plan name',
                          isDense: true,
                          filled: true,
                          fillColor: colors.surfaceTint.withOpacity(0.55),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: colors.outline.withOpacity(0.55),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: colors.outline.withOpacity(0.55),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: colors.primary,
                              width: 1.3,
                            ),
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      )
                    : Text(
                        selectedName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
              ),

              if (isCustom && dirty && !saving) ...<Widget>[
                const SizedBox(width: 7),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 9),

          // Compact actions
          Row(
            children: <Widget>[
              Expanded(
                child: _CompactPlanButton(
                  icon: Icons.bedtime_outlined,
                  label: 'Sleep schedule',
                  tooltip: 'Set wake-up and bedtime',
                  onPressed: onSleep,
                  foregroundColor: _DailyPlannerPageState._accentDark,
                  backgroundColor: colors.surfaceTint.withOpacity(0.72),
                ),
              ),
              if (isCustom) ...<Widget>[
                const SizedBox(width: 7),
                Expanded(
                  child: _CompactPlanButton(
                    icon: saving ? null : Icons.check_circle_outline_rounded,
                    label: saving ? 'Saving...' : 'Save changes',
                    tooltip: 'Save changes to this plan',
                    onPressed: canSave ? onSave : null,
                    foregroundColor: Colors.white,
                    backgroundColor: _DailyPlannerPageState._accent,
                    loading: saving,
                  ),
                ),
                const SizedBox(width: 7),
                _CompactDeleteButton(
                  onPressed: saving ? null : onDelete,
                  errorColor: colors.error,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactPlanButton extends StatelessWidget {
  const _CompactPlanButton({
    required this.label,
    required this.tooltip,
    required this.onPressed,
    required this.foregroundColor,
    required this.backgroundColor,
    this.icon,
    this.loading = false,
  });

  final IconData? icon;
  final String label;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color foregroundColor;
  final Color backgroundColor;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        height: 36,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            disabledBackgroundColor: backgroundColor.withOpacity(0.45),
            disabledForegroundColor: foregroundColor.withOpacity(0.65),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (loading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foregroundColor,
                  ),
                )
              else if (icon != null)
                Icon(icon, size: 16),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactDeleteButton extends StatelessWidget {
  const _CompactDeleteButton({
    required this.onPressed,
    required this.errorColor,
  });

  final VoidCallback? onPressed;
  final Color errorColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Delete this custom plan',
      child: SizedBox(
        width: 38,
        height: 36,
        child: IconButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          iconSize: 18,
          style: IconButton.styleFrom(
            foregroundColor: errorColor,
            backgroundColor: errorColor.withOpacity(0.08),
            disabledForegroundColor: errorColor.withOpacity(0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: errorColor.withOpacity(0.22),
              ),
            ),
          ),
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ),
    );
  }
}

class _ModeGallerySection extends StatelessWidget {
  const _ModeGallerySection({
    required this.selectedModeId,
    required this.onBuiltInSelected,
    required this.onCustomSelected,
    required this.onAddCustom,
  });

  final String selectedModeId;
  final ValueChanged<DayMode> onBuiltInSelected;
  final ValueChanged<CustomPlan> onCustomSelected;
  final VoidCallback onAddCustom;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: ValueListenableBuilder<List<CustomPlan>>(
        valueListenable: CustomModeStore.instance.plans,
        builder: (context, plans, _) {
          final cards = <Widget>[
            for (var i = 0; i < allDayModes.length; i++)
              _ModeCard(
                title: allDayModes[i].label,
                icon: allDayModes[i].emoji,
                selected: selectedModeId == allDayModes[i].id,
                color: _palette(i),
                onTap: () => onBuiltInSelected(allDayModes[i]),
              ),
            for (var i = 0; i < CustomModeStore.maxPlans; i++)
              i < plans.length
                  ? _CustomPlanCard(
                      plan: plans[i],
                      selected: selectedModeId == plans[i].id,
                      color: _palette(i + allDayModes.length),
                      onTap: () => onCustomSelected(plans[i]),
                    )
                  : _EmptyCustomCard(
                      number: i + 1,
                      enabled: plans.length < CustomModeStore.maxPlans,
                      onTap: onAddCustom,
                    ),
          ];
          return LayoutBuilder(
            builder: (context, constraints) {
              const columns = 8;
              const gap = 5.0;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: 6,
                children: cards
                    .map((card) => SizedBox(width: width, child: card))
                    .toList(),
              );
            },
          );
        },
      ),
    );
  }

  static Color _palette(int index) {
    const colors = <Color>[
      _DailyPlannerPageState._accent,
      _DailyPlannerPageState._accentDark,
      Color(0xFF22C55E),
      Color(0xFF38BDF8),
      Color(0xFF8B5CF6),
    ];
    return colors[index % colors.length];
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textColor = colors.onSurface;
    return _PlannerPickCard(
      selected: selected,
      color: color,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(child: Text(icon, style: const TextStyle(fontSize: 15))),
          const Spacer(),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 7.6,
              height: 1.08,
              fontWeight: FontWeight.w900,
              color: selected ? Colors.white : textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomPlanCard extends StatelessWidget {
  const _CustomPlanCard({
    required this.plan,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final CustomPlan plan;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textColor = colors.onSurface;
    return _PlannerPickCard(
      selected: selected,
      color: color,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.edit_note_rounded,
            color: selected ? Colors.white : color,
            size: 16,
          ),
          const Spacer(),
          Text(
            plan.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 7.6,
              height: 1.08,
              fontWeight: FontWeight.w900,
              color: selected ? Colors.white : textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCustomCard extends StatelessWidget {
  const _EmptyCustomCard({
    required this.number,
    required this.enabled,
    required this.onTap,
  });

  final int number;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _PlannerPickCard(
      selected: false,
      color: AppColors.textMuted,
      onTap: enabled ? onTap : null,
      dashed: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.add_rounded,
            color: enabled
                ? colors.onSurface.withOpacity(0.58)
                : colors.outline.withOpacity(0.7),
            size: 16,
          ),
          const Spacer(),
          Text(
            'Custom $number',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 7.4,
              fontWeight: FontWeight.w900,
              color: enabled
                  ? colors.onSurface.withOpacity(0.58)
                  : colors.outline.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlannerPickCard extends StatelessWidget {
  const _PlannerPickCard({
    required this.selected,
    required this.color,
    required this.child,
    this.onTap,
    this.dashed = false,
  });

  final bool selected;
  final bool dashed;
  final Color color;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 56,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: selected ? color : colors.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected
                ? color
                : dashed
                    ? colors.outline.withOpacity(0.55)
                    : color.withOpacity(0.32),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: color.withOpacity(0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: child,
      ),
    );
  }
}

class _SlotNavigatorSection extends StatelessWidget {
  const _SlotNavigatorSection({
    required this.selectedIndex,
    required this.draftSlots,
    required this.slotLabel,
    required this.onPrevious,
    required this.onNext,
  });

  final int selectedIndex;
  final List<CustomSlot> draftSlots;
  final String slotLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textColor = colors.onSurface;
    final mutedColor = colors.onSurface.withOpacity(0.58);
    final completed = draftSlots.where((slot) => !slot.isEmpty).length;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outline.withOpacity(0.55)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          _ArrowButton(
            icon: Icons.chevron_left_rounded,
            onTap: onPrevious,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _SlotCircleRail(
                  selectedIndex: selectedIndex,
                  draftSlots: draftSlots,
                  total: plannerSlots.length,
                ),
                const SizedBox(height: 8),
                Text(
                  slotLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$completed of ${plannerSlots.length} cards filled',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: mutedColor,
                  ),
                ),
              ],
            ),
          ),
          _ArrowButton(
            icon: Icons.chevron_right_rounded,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class _SlotCircleRail extends StatelessWidget {
  const _SlotCircleRail({
    required this.selectedIndex,
    required this.draftSlots,
    required this.total,
  });

  final int selectedIndex;
  final List<CustomSlot> draftSlots;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 18,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (var i = 0; i < total; i++) ...<Widget>[
            _SlotCircle(
              selected: i == selectedIndex,
              filled: i < draftSlots.length && !draftSlots[i].isEmpty,
            ),
            if (i != total - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i < draftSlots.length - 1 &&
                            !draftSlots[i].isEmpty &&
                            !draftSlots[i + 1].isEmpty
                        ? colors.primary
                        : colors.outline.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SlotCircle extends StatelessWidget {
  const _SlotCircle({
    required this.selected,
    required this.filled,
  });

  final bool selected;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = selected
        ? colors.primary
        : filled
            ? colors.secondary
            : colors.outline.withOpacity(0.72);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: selected ? 18 : 11,
      height: selected ? 18 : 11,
      decoration: BoxDecoration(
        color: selected || filled ? color : colors.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: color,
          width: selected ? 2 : 1.3,
        ),
        boxShadow: selected
            ? <BoxShadow>[
                BoxShadow(
                  color: _DailyPlannerPageState._accent.withOpacity(0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: selected
          ? const Icon(
              Icons.check_rounded,
              size: 12,
              color: Colors.white,
            )
          : null,
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: colors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: colors.outline.withOpacity(0.55)),
        ),
        child: Icon(
          icon,
          size: 24,
          color: colors.primary,
        ),
      ),
    );
  }
}

class _PlanFormCard extends StatelessWidget {
  const _PlanFormCard({
    required this.enabled,
    required this.slotLabel,
    required this.headlineController,
    required this.detailController,
    required this.headlineLimit,
    required this.detailLimit,
    required this.headlineHint,
    required this.detailHint,
    required this.onHeadlineChanged,
    required this.onDetailChanged,
    required this.onCopyFromMode,
  });

  final bool enabled;
  final String slotLabel;
  final TextEditingController headlineController;
  final TextEditingController detailController;
  final int headlineLimit;
  final int detailLimit;
  final String headlineHint;
  final String detailHint;
  final ValueChanged<String> onHeadlineChanged;
  final ValueChanged<String> onDetailChanged;
  final VoidCallback onCopyFromMode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textColor = colors.onSurface;
    final mutedColor = colors.onSurface.withOpacity(0.58);
    return WhiteCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Card content',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      enabled ? 'Editing $slotLabel' : 'Previewing $slotLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: enabled ? onCopyFromMode : null,
                icon: const Icon(Icons.content_copy_rounded, size: 16),
                label: const Text('Copy mode'),
                style: TextButton.styleFrom(
                  foregroundColor: colors.primary,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!enabled)
            Expanded(
              child: _BuiltInPreviewCard(
                headline: headlineHint,
                detail: detailHint,
              ),
            )
          else ...<Widget>[
            _LimitedField(
              controller: headlineController,
              label: 'Headline',
              hint: headlineHint,
              maxLength: headlineLimit,
              maxLines: 2,
              expands: false,
              onChanged: onHeadlineChanged,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _LimitedField(
                controller: detailController,
                label: 'Details',
                hint: detailHint,
                maxLength: detailLimit,
                maxLines: null,
                expands: true,
                onChanged: onDetailChanged,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BuiltInPreviewCard extends StatelessWidget {
  const _BuiltInPreviewCard({
    required this.headline,
    required this.detail,
  });

  final String headline;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final lines = detail
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(3)
        .toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceTint.withOpacity(0.52),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outline.withOpacity(0.52)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            headline,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 19,
              height: 1.2,
              fontWeight: FontWeight.w900,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 7),
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.75),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface.withOpacity(0.68),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Spacer(),
          Text(
            'Create or select a custom plan to edit this content.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: colors.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyModeSheet extends StatelessWidget {
  const _CopyModeSheet({required this.sources});

  final List<DayMode> sources;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textColor = colors.onSurface;
    final mutedColor = colors.onSurface.withOpacity(0.58);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Copy from mode',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This fills all 7 cards. You can edit them after copying.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: mutedColor,
              ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: sources.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final mode = sources[index];
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(mode),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceTint.withOpacity(0.58),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: colors.outline.withOpacity(0.55)),
                      ),
                      child: Row(
                        children: <Widget>[
                          Text(
                            mode.emoji,
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              mode.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: mutedColor,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LimitedField extends StatelessWidget {
  const _LimitedField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.maxLength,
    required this.maxLines,
    required this.expands,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLength;
  final int? maxLines;
  final bool expands;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      expands: expands,
      textAlignVertical: expands ? TextAlignVertical.top : null,
      inputFormatters: <TextInputFormatter>[
        LengthLimitingTextInputFormatter(maxLength),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: hint,
        hintMaxLines: expands ? 4 : 2,
        alignLabelWithHint: true,
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: colors.primary,
        ),
        hintStyle: TextStyle(
          fontSize: 13,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: colors.onSurface.withOpacity(0.44),
        ),
        counterStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: colors.onSurface.withOpacity(0.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.outline.withOpacity(0.55)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.outline.withOpacity(0.55)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colors.primary,
            width: 1.4,
          ),
        ),
      ),
      style: TextStyle(
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: colors.onSurface,
      ),
    );
  }
}
