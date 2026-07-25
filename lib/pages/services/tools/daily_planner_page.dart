import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import '../../../services/custom_mode_store.dart';
import '../../home_tab/data/mode_advice.dart' show customModeId, plannerSlots;
import '../../profile/profile_store.dart';
import 'toolkit.dart';

/// Editor for the user's **Custom** day mode.
///
/// Renders one row per entry in [plannerSlots] (09–11, 11–13, …) and lets
/// the user type in their own recommendation, coaching tip, and crowd
/// label. Everything persists via [CustomModeStore] so the home-tab
/// planner cards pick it up the moment the user hits back.
class DailyPlannerPage extends StatefulWidget {
  const DailyPlannerPage({super.key});

  @override
  State<DailyPlannerPage> createState() => _DailyPlannerPageState();
}

class _DailyPlannerPageState extends State<DailyPlannerPage> {
  late List<CustomSlot> _draft;
  late final List<TextEditingController> _recCtl;
  late final List<TextEditingController> _tipCtl;
  late final List<TextEditingController> _crowdCtl;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _draft = List<CustomSlot>.of(CustomModeStore.instance.slots.value);
    _recCtl = <TextEditingController>[
      for (final s in _draft) TextEditingController(text: s.recommendation)
    ];
    _tipCtl = <TextEditingController>[
      for (final s in _draft) TextEditingController(text: s.tip)
    ];
    _crowdCtl = <TextEditingController>[
      for (final s in _draft) TextEditingController(text: s.crowd)
    ];
  }

  @override
  void dispose() {
    for (final c in _recCtl) {
      c.dispose();
    }
    for (final c in _tipCtl) {
      c.dispose();
    }
    for (final c in _crowdCtl) {
      c.dispose();
    }
    super.dispose();
  }

  void _update(int i, {String? rec, String? tip, String? crowd}) {
    setState(() {
      _draft[i] = _draft[i].copyWith(
        recommendation: rec,
        tip: tip,
        crowd: crowd,
      );
      _dirty = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await CustomModeStore.instance.replaceAll(_draft);
    // Make sure the home tab shows the custom mode once the user has taken
    // the trouble to plan — this is the whole point of coming here.
    if (ProfileStore.instance.plannerMode.value != customModeId) {
      await ProfileStore.instance.setPlannerMode(customModeId);
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _dirty = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Custom plan saved'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _resetSlot(int i) async {
    _recCtl[i].clear();
    _tipCtl[i].clear();
    _crowdCtl[i].clear();
    _update(i, rec: '', tip: '', crowd: '');
  }

  String _slotLabel(int startHour, int endHour) {
    String fmt(int h) {
      final hr = h % 24;
      if (hr == 0) return '12 AM';
      if (hr == 12) return '12 PM';
      return hr < 12 ? '$hr AM' : '${hr - 12} PM';
    }
    return '${fmt(startHour)} — ${fmt(endHour)}';
  }

  String _slotEmoji(int startHour) {
    if (startHour < 11) return '🌅';
    if (startHour < 13) return '🍽';
    if (startHour < 15) return '☕';
    if (startHour < 17) return '💻';
    if (startHour < 19) return '🚶';
    if (startHour < 21) return '🌆';
    return '🌙';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: svcAppBar('🗓️ Daily Planner'),
      body: Column(
        children: <Widget>[
          _buildHeader(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.large,
                AppSpacing.small,
                AppSpacing.large,
                80,
              ),
              itemCount: plannerSlots.length,
              itemBuilder: (context, i) => _buildSlotCard(i),
            ),
          ),
        ],
      ),
      floatingActionButton: _dirty || _saving
          ? FloatingActionButton.extended(
              onPressed: _saving ? null : _save,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 20),
              label: Text(_saving ? 'Saving…' : 'Save plan'),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: AppColors.surfaceTint,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.large,
        AppSpacing.small,
        AppSpacing.large,
        AppSpacing.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Text('✨', style: TextStyle(fontSize: 18, height: 1)),
              SizedBox(width: 6),
              Text(
                'Plan your day, your way',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF141824),
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Fill any slot to override the built-in advice. Empty slots fall back to Normal mode.',
            style: TextStyle(
              fontSize: 10.5,
              color: AppColors.textMuted.withValues(alpha: 0.9),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotCard(int i) {
    final slot = plannerSlots[i];
    final label = _slotLabel(slot.startHour, slot.endHour);
    final emoji = _slotEmoji(slot.startHour);
    final hasContent = !_draft[i].isEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: WhiteCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(emoji, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF141824),
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                if (hasContent)
                  InkWell(
                    onTap: () => _resetSlot(i),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 15,
                        color: AppColors.textMuted.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _plainField(
              controller: _recCtl[i],
              hint: 'What matters this window?',
              maxLines: 2,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              onChanged: (v) => _update(i, rec: v),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: _plainField(
                    controller: _tipCtl[i],
                    hint: 'Coaching tip (💡 optional)',
                    fontSize: 11,
                    onChanged: (v) => _update(i, tip: v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _plainField(
                    controller: _crowdCtl[i],
                    hint: 'Vibe tag',
                    fontSize: 11,
                    onChanged: (v) => _update(i, crowd: v),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _plainField({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: const Color(0xFF141824),
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          color: AppColors.textMuted.withValues(alpha: 0.7),
        ),
        filled: true,
        fillColor: AppColors.scaffoldBackground.withValues(alpha: 0.7),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(
            color: AppColors.outline.withValues(alpha: 0.6),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(
            color: AppColors.outline.withValues(alpha: 0.6),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.2,
          ),
        ),
      ),
    );
  }
}
