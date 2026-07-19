import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import 'toolkit.dart';

/// Food log — powers Calorie Counter (kcal only) and Nutrition Tracker
/// (kcal + protein/carbs/fat). Both share the same entry list, so food
/// logged in one shows in the other. The daily kcal target can be set
/// here or pushed from the Calorie Calculator (TDEE) page.
class FoodLogPage extends StatefulWidget {
  const FoodLogPage({super.key, required this.showMacros});
  final bool showMacros;

  @override
  State<FoodLogPage> createState() => _FoodLogPageState();
}

class _FoodLogPageState extends State<FoodLogPage> {
  static const String entriesKey = 'svc.food.entries';
  static const String settingsKey = 'svc.food.settings';

  List<Map<String, dynamic>> _entries = <Map<String, dynamic>>[];
  int _targetKcal = 2000;
  bool _loaded = false;

  final _name = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await ServiceStore.loadList(entriesKey);
    final settings = await ServiceStore.loadMap(settingsKey);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _targetKcal = (settings['targetKcal'] as num?)?.toInt() ?? 2000;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _kcal.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    final kcal = int.tryParse(_kcal.text.trim());
    if (name.isEmpty || kcal == null) return;
    setState(() {
      _entries.insert(0, <String, dynamic>{
        't': DateTime.now().toIso8601String(),
        'name': name,
        'kcal': kcal,
        if (int.tryParse(_protein.text.trim()) != null)
          'p': int.parse(_protein.text.trim()),
        if (int.tryParse(_carbs.text.trim()) != null)
          'c': int.parse(_carbs.text.trim()),
        if (int.tryParse(_fat.text.trim()) != null)
          'f': int.parse(_fat.text.trim()),
      });
      _name.clear();
      _kcal.clear();
      _protein.clear();
      _carbs.clear();
      _fat.clear();
    });
    await ServiceStore.saveList(entriesKey, _entries);
  }

  Future<void> _delete(Map<String, dynamic> entry) async {
    setState(() => _entries.remove(entry));
    await ServiceStore.saveList(entriesKey, _entries);
  }

  Future<void> _editTarget() async {
    final controller = TextEditingController(text: '$_targetKcal');
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daily calorie target',
            style: TextStyle(fontSize: 15)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'kcal'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      setState(() => _targetKcal = result);
      await ServiceStore.saveMap(
          settingsKey, <String, dynamic>{'targetKcal': result});
    }
  }

  List<Map<String, dynamic>> get _todayEntries {
    final today = svcDay(DateTime.now());
    return _entries.where((e) {
      final t = DateTime.tryParse(e['t'] as String? ?? '');
      return t != null && svcDay(t) == today;
    }).toList();
  }

  int _sum(String field) => _todayEntries.fold(
      0, (total, e) => total + ((e[field] as num?)?.toInt() ?? 0));

  @override
  Widget build(BuildContext context) {
    final todayKcal = _sum('kcal');
    final progress = (_targetKcal == 0 ? 0.0 : todayKcal / _targetKcal)
        .clamp(0.0, 1.0)
        .toDouble();
    final over = todayKcal > _targetKcal;

    final groups = <String, List<Map<String, dynamic>>>{};
    for (final e in _entries) {
      final t = DateTime.tryParse(e['t'] as String? ?? '');
      final key = t == null ? '?' : svcDay(t);
      groups.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(e);
    }

    return Scaffold(
      appBar: svcAppBar(
          widget.showMacros ? '🥦 Nutrition Tracker' : '🍽️ Calorie Counter'),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.large),
              children: <Widget>[
                // Today summary
                WhiteCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            '$todayKcal',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: over
                                  ? const Color(0xFFC62828)
                                  : const Color(0xFF2A2E3B),
                            ),
                          ),
                          Text(
                            ' / $_targetKcal kcal today',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: _editTarget,
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.edit_rounded,
                                  size: 15, color: AppColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 7,
                          color: over
                              ? const Color(0xFFC62828)
                              : AppColors.primary,
                          backgroundColor:
                              AppColors.surfaceTint.withValues(alpha: 0.8),
                        ),
                      ),
                      if (widget.showMacros) ...<Widget>[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceAround,
                          children: <Widget>[
                            _MacroStat(
                                label: 'Protein',
                                value: _sum('p'),
                                color: const Color(0xFF2E7D32)),
                            _MacroStat(
                                label: 'Carbs',
                                value: _sum('c'),
                                color: const Color(0xFFEF6C00)),
                            _MacroStat(
                                label: 'Fat',
                                value: _sum('f'),
                                color: const Color(0xFF5E35B1)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Add form
                Row(
                  children: <Widget>[
                    Expanded(flex: 3, child: _field(_name, 'Food — "2 rotis + dal"')),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: _field(_kcal, 'kcal', number: true)),
                  ],
                ),
                if (widget.showMacros)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                            child:
                                _field(_protein, 'Protein g', number: true)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _field(_carbs, 'Carbs g', number: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _field(_fat, 'Fat g', number: true)),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: FilledButton.icon(
                    onPressed: _add,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Log food',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 6),

                if (_entries.isEmpty)
                  const EmptyHint(
                      'Log your first meal — search exact values in the '
                      'Food Calorie Check service.'),
                for (final day in groups.keys) ...<Widget>[
                  SectionLabel(svcDayLabel(day)),
                  for (final e in groups[day]!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: WhiteCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(e['name'] as String,
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600)),
                                  if (widget.showMacros &&
                                      (e['p'] != null ||
                                          e['c'] != null ||
                                          e['f'] != null))
                                    Text(
                                      'P ${e['p'] ?? '–'} · C ${e['c'] ?? '–'} · F ${e['f'] ?? '–'}',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textMuted),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              '${e['kcal']} kcal',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _delete(e),
                              child: Icon(Icons.close_rounded,
                                  size: 15,
                                  color: AppColors.textMuted
                                      .withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _field(TextEditingController controller, String hint,
      {bool number = false}) {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: controller,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontSize: 12.5),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted.withValues(alpha: 0.8)),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: AppColors.outline.withValues(alpha: 0.9)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.2),
          ),
        ),
      ),
    );
  }
}

class _MacroStat extends StatelessWidget {
  const _MacroStat(
      {required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text('${value}g',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        Text(label,
            style:
                const TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
      ],
    );
  }
}
