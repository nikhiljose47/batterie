import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import 'toolkit.dart';

/// Recurring daily check-off template: a persistent item list plus a tick
/// per item per day, with streaks. Powers Habit Tracker and Medication
/// Reminder (tick a med when taken).
class HabitConfig {
  const HabitConfig({
    required this.id,
    required this.title,
    required this.addHint,
    required this.itemNoun,
    this.note,
  });

  final String id;
  final String title;
  final String addHint;
  final String itemNoun;
  final String? note;
}

const habitsConfig = HabitConfig(
  id: 'habits',
  title: '🔥 Habit Tracker',
  addHint: 'New habit — "Read 10 pages"…',
  itemNoun: 'habit',
);

const medsConfig = HabitConfig(
  id: 'medication',
  title: '💊 Medication',
  addHint: 'Medicine + dose — "Vitamin D 1000 IU, morning"…',
  itemNoun: 'medicine',
  note: 'Tick each medicine when you take it. For OS alarm '
      'notifications, ask to enable the notifications module.',
);

class HabitToolPage extends StatefulWidget {
  const HabitToolPage({super.key, required this.config});
  final HabitConfig config;

  @override
  State<HabitToolPage> createState() => _HabitToolPageState();
}

class _HabitToolPageState extends State<HabitToolPage> {
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  Map<String, dynamic> _ticks = <String, dynamic>{};
  final TextEditingController _input = TextEditingController();
  bool _loaded = false;

  String get _itemsKey => 'svc.${widget.config.id}.items';
  String get _ticksKey => 'svc.${widget.config.id}.ticks';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await ServiceStore.loadList(_itemsKey);
    final ticks = await ServiceStore.loadMap(_ticksKey);
    if (!mounted) return;
    setState(() {
      _items = items;
      _ticks = ticks;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  List<String> _tickedOn(String day) =>
      ((_ticks[day] as List<dynamic>?) ?? <dynamic>[]).cast<String>();

  bool _isTicked(String itemId) =>
      _tickedOn(svcDay(DateTime.now())).contains(itemId);

  Future<void> _toggle(String itemId) async {
    final day = svcDay(DateTime.now());
    final ticked = _tickedOn(day).toList();
    if (ticked.contains(itemId)) {
      ticked.remove(itemId);
    } else {
      ticked.add(itemId);
    }
    setState(() => _ticks[day] = ticked);
    await ServiceStore.saveMap(_ticksKey, _ticks);
  }

  Future<void> _add() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _items.add(<String, dynamic>{
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'name': text,
      });
      _input.clear();
    });
    await ServiceStore.saveList(_itemsKey, _items);
  }

  Future<void> _remove(String itemId) async {
    setState(() => _items.removeWhere((i) => i['id'] == itemId));
    await ServiceStore.saveList(_itemsKey, _items);
  }

  /// Consecutive days ticked, ending today (today counts once ticked).
  int _streak(String itemId) {
    var streak = 0;
    var day = DateTime.now();
    if (!_tickedOn(svcDay(day)).contains(itemId)) {
      day = day.subtract(const Duration(days: 1));
    }
    while (_tickedOn(svcDay(day)).contains(itemId)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
      if (streak > 999) break;
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    final doneToday =
        _items.where((i) => _isTicked(i['id'] as String)).length;

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

                // Progress summary
                WhiteCard(
                  child: Row(
                    children: <Widget>[
                      Text(
                        _items.isEmpty
                            ? '—'
                            : '$doneToday / ${_items.length}',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _items.isEmpty
                              ? 'Add your first ${c.itemNoun} below.'
                              : doneToday == _items.length
                                  ? '🎉 All done today!'
                                  : 'done today — keep going.',
                          style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const SectionLabel('Today'),
                for (final item in _items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: WhiteCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Row(
                        children: <Widget>[
                          Checkbox(
                            value: _isTicked(item['id'] as String),
                            activeColor: AppColors.primary,
                            onChanged: (_) =>
                                _toggle(item['id'] as String),
                          ),
                          Expanded(
                            child: Text(
                              item['name'] as String,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                decoration:
                                    _isTicked(item['id'] as String)
                                        ? TextDecoration.lineThrough
                                        : null,
                                color: _isTicked(item['id'] as String)
                                    ? AppColors.textMuted
                                    : const Color(0xFF2A2E3B),
                              ),
                            ),
                          ),
                          Text(
                            '🔥${_streak(item['id'] as String)}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => _remove(item['id'] as String),
                            child: Icon(Icons.close_rounded,
                                size: 16,
                                color: AppColors.textMuted
                                    .withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_items.isEmpty)
                  EmptyHint('No ${c.itemNoun}s yet — add one below.'),
                const SizedBox(height: 4),

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
              ],
            ),
    );
  }
}
