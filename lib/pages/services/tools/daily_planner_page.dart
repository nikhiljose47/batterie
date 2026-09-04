import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/goal_plan_constants.dart';
import '../../../services/custom_mode_store.dart';
import '../../../services/sleep_schedule_store.dart';
import '../../home_tab/data/mode_advice.dart'
    show allDayModes, adviceForMode, dayPhases, plannerSlots, timeOfDayLabel;
import '../../profile/profile_store.dart';
import 'toolkit.dart';

class DailyPlannerPage extends StatefulWidget {
  const DailyPlannerPage({super.key, this.embedded = false, this.onSaved});

  final bool embedded;
  final VoidCallback? onSaved;

  @override
  State<DailyPlannerPage> createState() => _DailyPlannerPageState();
}

class _DailyPlannerPageState extends State<DailyPlannerPage> {
  static const int _headlineLimit = 88;
  static const int _detailLimit = 240;
  static const int _nameLimit = 22;

  late final TextEditingController _nameCtl;
  late final TextEditingController _headlineCtl;
  late final TextEditingController _detailCtl;

  late List<CustomSlot> _draftSlots;
  late String _tag;
  int _step = 0;
  bool _saving = false;

  int get _slotCount => plannerSlots.length;
  int get _saveStep => _slotCount + 1;
  bool get _isScheduleStep => _step == 0;
  bool get _isSaveStep => _step == _saveStep;
  int get _slotIndex => (_step - 1).clamp(0, _slotCount - 1);
  String get _phaseTitle {
    final phases = dayPhases;
    if (_slotIndex >= phases.length) return 'Day card';
    final phase = phases[_slotIndex];
    return '${phase.label} · ${phase.slot.rangeLabel}';
  }

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: _initialPlanName());
    _headlineCtl = TextEditingController();
    _detailCtl = TextEditingController();
    _draftSlots = _seedSlots();
    _tag = _initialPlanTag();
    _syncSlotControllers();
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

  String _initialPlanName() {
    final modeId = ProfileStore.instance.plannerMode.value;
    if (CustomModeStore.isCustomModeId(modeId)) {
      return CustomModeStore.instance.planForModeId(modeId).name;
    }
    final mode = allDayModes.firstWhere(
      (item) => item.id == modeId,
      orElse: () => allDayModes.first,
    );
    return '${mode.shortLabel} plan';
  }

  String _initialPlanTag() {
    final modeId = ProfileStore.instance.plannerMode.value;
    if (CustomModeStore.isCustomModeId(modeId)) {
      return CustomModeStore.instance.planForModeId(modeId).tag;
    }
    return GoalPlanConstants.defaultTag;
  }

  List<CustomSlot> _seedSlots() {
    final modeId = ProfileStore.instance.plannerMode.value;
    if (CustomModeStore.isCustomModeId(modeId)) {
      return List<CustomSlot>.of(
        CustomModeStore.normalizeSlots(
          CustomModeStore.instance.planForModeId(modeId).slots,
        ),
      );
    }
    final advice = adviceForMode(modeId);
    return List<CustomSlot>.of(CustomModeStore.normalizeSlots(<CustomSlot>[
      for (var i = 0; i < CustomModeStore.slotCount; i++)
        if (i < advice.length)
          CustomSlot(
            recommendation: advice[i].recommendation,
            tip: advice[i].tip,
            descriptions: advice[i].descriptions,
          )
        else
          const CustomSlot(),
    ]));
  }

  void _onScheduleChanged() {
    if (!mounted) return;
    setState(() {
      if (_step > _saveStep) _step = _saveStep;
    });
  }

  void _syncSlotControllers() {
    if (_isScheduleStep || _isSaveStep) return;
    final slot = _draftSlots[_slotIndex];
    _headlineCtl.text =
        slot.recommendation.isNotEmpty ? slot.recommendation : slot.tip;
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
        .toList(growable: false);
  }

  void _commitSlot() {
    if (_isScheduleStep || _isSaveStep) return;
    final headline = _headlineCtl.text.trim();
    _draftSlots[_slotIndex] = _draftSlots[_slotIndex].copyWith(
      recommendation: headline,
      tip: headline,
      descriptions: _detailLines(_detailCtl.text),
    );
  }

  void _goBack() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    _commitSlot();
    setState(() => _step--);
    _syncSlotControllers();
  }

  void _goNext() {
    if (_saving) return;
    _commitSlot();
    if (_isSaveStep) {
      _savePlan();
      return;
    }
    setState(() => _step++);
    _syncSlotControllers();
  }

  Future<void> _pickWakeTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: SleepScheduleStore.instance.wakeTime.value,
    );
    if (picked == null) return;
    await SleepScheduleStore.instance.setWake(picked);
  }

  Future<void> _pickSleepTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: SleepScheduleStore.instance.sleepTime.value,
    );
    if (picked == null) return;
    await SleepScheduleStore.instance.setSleep(picked);
  }

  Future<CustomPlan> _targetPlan() async {
    final modeId = ProfileStore.instance.plannerMode.value;
    if (CustomModeStore.isCustomModeId(modeId)) {
      return CustomModeStore.instance.planForModeId(modeId);
    }
    final added = await CustomModeStore.instance.addPlan();
    if (added != null) return added;
    final plans = CustomModeStore.instance.plans.value;
    return plans.isEmpty
        ? CustomPlan(
            id: CustomModeStore.defaultPlanId,
            name: 'My Plan',
            slots: List<CustomSlot>.filled(
              CustomModeStore.slotCount,
              const CustomSlot(),
            ),
          )
        : plans.first;
  }

  Future<void> _savePlan() async {
    if (_saving) return;
    _commitSlot();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save this plan?'),
        content: const Text('This will set it as your active day mode.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    final name =
        _nameCtl.text.trim().isEmpty ? 'My Plan' : _nameCtl.text.trim();
    final currentModeId = ProfileStore.instance.plannerMode.value;
    final currentPlanId =
        CustomModeStore.isCustomModeId(currentModeId) ? currentModeId : null;
    if (CustomModeStore.instance.hasPlanNamed(name, exceptId: currentPlanId)) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A plan with this name already exists')),
      );
      return;
    }
    final base = await _targetPlan();
    final plan = base.copyWith(
      name: name,
      slots: CustomModeStore.normalizeSlots(_draftSlots),
      tag: _tag,
    );
    await CustomModeStore.instance.savePlan(plan);
    await ProfileStore.instance.setPlannerMode(plan.id);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!widget.embedded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name saved and set as your day mode')),
      );
      Navigator.of(context).pop(true);
    } else {
      widget.onSaved?.call();
    }
  }

  String _stepTitle() {
    if (_isScheduleStep) return 'Confirm your day times';
    if (_isSaveStep) return 'Save your goal';
    return 'Card ${_slotIndex + 1} of $_slotCount';
  }

  String _stepSubtitle() {
    if (_isScheduleStep) {
      return 'First, make sure your wake-up and sleep time are right.';
    }
    if (_isSaveStep) {
      return 'Name the full plan and set it as your current goal.';
    }
    return plannerSlots[_slotIndex].rangeLabel;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = (_step + 1) / (_saveStep + 1);
    final content = Padding(
      padding: EdgeInsets.fromLTRB(14, widget.embedded ? 0 : 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _GuideHeader(
            title: _stepTitle(),
            subtitle: _stepSubtitle(),
            progress: progress,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _isScheduleStep
                  ? _ScheduleStepCard(
                      key: const ValueKey<String>('schedule'),
                      nameController: _nameCtl,
                      nameLimit: _nameLimit,
                      onWake: _pickWakeTime,
                      onSleep: _pickSleepTime,
                    )
                  : _isSaveStep
                      ? _SaveStepCard(
                          key: const ValueKey<String>('save'),
                          controller: _nameCtl,
                          nameLimit: _nameLimit,
                          tag: _tag,
                          onTagChanged: (value) => setState(() {
                            _tag = GoalPlanConstants.normalizeTag(value);
                          }),
                        )
                      : _TimeCardStep(
                          key: ValueKey<int>(_slotIndex),
                          slotLabel: _phaseTitle,
                          headlineController: _headlineCtl,
                          detailController: _detailCtl,
                          headlineLimit: _headlineLimit,
                          detailLimit: _detailLimit,
                        ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _goBack,
                  icon: Icon(
                    _step == 0
                        ? Icons.close_rounded
                        : Icons.chevron_left_rounded,
                  ),
                  label: Text(_step == 0 ? 'Cancel' : 'Back'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _goNext,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_isSaveStep
                          ? Icons.check_circle_rounded
                          : Icons.chevron_right_rounded),
                  label: Text(_isSaveStep
                      ? (_saving ? 'Saving...' : 'Save plan')
                      : 'Continue'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Step ${_step + 1} of ${_saveStep + 1}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface.withOpacity(0.46),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    if (widget.embedded) return content;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: svcAppBar('Change Mode'),
      body: SafeArea(child: content),
    );
  }
}

class _GuideHeader extends StatelessWidget {
  const _GuideHeader({
    required this.title,
    required this.subtitle,
    required this.progress,
  });

  final String title;
  final String subtitle;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outline.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface.withOpacity(0.58),
                        fontSize: 11.5,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: progress,
              backgroundColor: colors.surfaceTint,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleStepCard extends StatelessWidget {
  const _ScheduleStepCard({
    super.key,
    required this.nameController,
    required this.nameLimit,
    required this.onWake,
    required this.onSleep,
  });

  final TextEditingController nameController;
  final int nameLimit;
  final VoidCallback onWake;
  final VoidCallback onSleep;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TimeOfDay>(
      valueListenable: SleepScheduleStore.instance.wakeTime,
      builder: (context, wake, _) {
        return ValueListenableBuilder<TimeOfDay>(
          valueListenable: SleepScheduleStore.instance.sleepTime,
          builder: (context, sleep, _) {
            return _WizardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _FriendlyPrompt(
                    icon: Icons.bedtime_rounded,
                    title: 'Name and time your goal',
                    text: '',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    maxLength: nameLimit,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Goal name',
                      hintText: 'Exam focus',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TimePickRow(
                    icon: Icons.wb_sunny_rounded,
                    label: 'Wake up',
                    value: timeOfDayLabel(wake),
                    onTap: onWake,
                  ),
                  const SizedBox(height: 10),
                  _TimePickRow(
                    icon: Icons.nightlight_round,
                    label: 'Sleep',
                    value: timeOfDayLabel(sleep),
                    onTap: onSleep,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TimeCardStep extends StatelessWidget {
  const _TimeCardStep({
    super.key,
    required this.slotLabel,
    required this.headlineController,
    required this.detailController,
    required this.headlineLimit,
    required this.detailLimit,
  });

  final String slotLabel;
  final TextEditingController headlineController;
  final TextEditingController detailController;
  final int headlineLimit;
  final int detailLimit;

  @override
  Widget build(BuildContext context) {
    return _WizardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _FriendlyPrompt(
            icon: Icons.edit_note_rounded,
            title: 'Card text',
            text: '',
            trailing: slotLabel,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: headlineController,
            maxLength: headlineLimit,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Card text',
              hintText: 'Example: Study the hardest topic first',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: detailController,
              maxLength: detailLimit,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                labelText: 'Small notes',
                hintText: 'Add up to 3 short lines to support this card',
                counterText: '',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveStepCard extends StatelessWidget {
  const _SaveStepCard({
    super.key,
    required this.controller,
    required this.nameLimit,
    required this.tag,
    required this.onTagChanged,
  });

  final TextEditingController controller;
  final int nameLimit;
  final String tag;
  final ValueChanged<String> onTagChanged;

  @override
  Widget build(BuildContext context) {
    return _WizardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _FriendlyPrompt(
            icon: Icons.hotel_rounded,
            title: 'Save goal',
            text: '',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            maxLength: nameLimit,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Plan name',
              hintText: 'Example: Exam focus',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: tag,
            decoration: const InputDecoration(
              labelText: 'Plan tag',
              counterText: '',
            ),
            items: <DropdownMenuItem<String>>[
              for (final item in GoalPlanConstants.tags)
                DropdownMenuItem<String>(
                  value: item,
                  child: Text(GoalPlanConstants.labelFor(item)),
                ),
            ],
            onChanged: (value) {
              if (value != null) onTagChanged(value);
            },
          ),
        ],
      ),
    );
  }
}

class _WizardCard extends StatelessWidget {
  const _WizardCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withOpacity(0.18)),
      ),
      child: child,
    );
  }
}

class _FriendlyPrompt extends StatelessWidget {
  const _FriendlyPrompt({
    required this.icon,
    required this.title,
    required this.text,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (trailing != null) ...<Widget>[
                    const SizedBox(width: 8),
                    Text(
                      trailing!,
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
              if (text.isNotEmpty) ...<Widget>[
                const SizedBox(height: 5),
                Text(
                  text,
                  style: TextStyle(
                    color: colors.onSurface.withOpacity(0.58),
                    fontSize: 12,
                    height: 1.22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TimePickRow extends StatelessWidget {
  const _TimePickRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceTint.withOpacity(0.55),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 19, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: colors.onSurface.withOpacity(0.72),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.edit_rounded,
                size: 16,
                color: colors.onSurface.withOpacity(0.38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
