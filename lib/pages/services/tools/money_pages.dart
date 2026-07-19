import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import 'toolkit.dart';

// Money mini-apps: Expense Tracker, Budget Planner (reads the same
// expense data), and Subscriptions / Bill Reminders (recurring items).

const List<String> expenseCategories = <String>[
  '🍔 Food',
  '🚌 Travel',
  '🛍️ Shopping',
  '💡 Utilities',
  '🎬 Fun',
  '🩺 Health',
  '🏠 Rent',
  '📦 Other',
];

const String _expensesKey = 'svc.expenses.entries';

String _monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

// ═══════════════════════════════════════════════════════════════════════
//  EXPENSE TRACKER
// ═══════════════════════════════════════════════════════════════════════

class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key});

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  List<Map<String, dynamic>> _entries = <Map<String, dynamic>>[];
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _category = expenseCategories.first;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    ServiceStore.loadList(_expensesKey).then((list) {
      if (!mounted) return;
      setState(() {
        _entries = list;
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) return;
    setState(() {
      _entries.insert(0, <String, dynamic>{
        't': DateTime.now().toIso8601String(),
        'amount': amount,
        'cat': _category,
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      });
      _amount.clear();
      _note.clear();
    });
    await ServiceStore.saveList(_expensesKey, _entries);
  }

  Future<void> _delete(Map<String, dynamic> e) async {
    setState(() => _entries.remove(e));
    await ServiceStore.saveList(_expensesKey, _entries);
  }

  List<Map<String, dynamic>> get _thisMonth {
    final month = _monthKey(DateTime.now());
    return _entries.where((e) {
      final t = DateTime.tryParse(e['t'] as String? ?? '');
      return t != null && _monthKey(t) == month;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final monthEntries = _thisMonth;
    final total = monthEntries.fold<double>(
        0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0));

    final byCat = <String, double>{};
    for (final e in monthEntries) {
      final cat = e['cat'] as String? ?? '📦 Other';
      byCat[cat] = (byCat[cat] ?? 0) + ((e['amount'] as num?)?.toDouble() ?? 0);
    }
    final sortedCats = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final groups = <String, List<Map<String, dynamic>>>{};
    for (final e in _entries.take(60)) {
      final t = DateTime.tryParse(e['t'] as String? ?? '');
      final key = t == null ? '?' : svcDay(t);
      groups.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(e);
    }

    return Scaffold(
      appBar: svcAppBar('🧾 Expense Tracker'),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.large),
              children: <Widget>[
                WhiteCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('₹${total.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w800)),
                      const Text('spent this month',
                          style: TextStyle(
                              fontSize: 10.5, color: AppColors.textMuted)),
                      if (sortedCats.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        for (final entry in sortedCats.take(5))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: <Widget>[
                                SizedBox(
                                  width: 92,
                                  child: Text(entry.key,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 10.5)),
                                ),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value:
                                          total == 0 ? 0 : entry.value / total,
                                      minHeight: 6,
                                      color: AppColors.primary,
                                      backgroundColor: AppColors.surfaceTint
                                          .withOpacity(0.7),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 58,
                                  child: Text(
                                    '₹${entry.value.toStringAsFixed(0)}',
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Add form
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: <Widget>[
                      for (final cat in expenseCategories)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: SvcChip(
                            label: cat,
                            selected: _category == cat,
                            onTap: () => setState(() => _category = cat),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                        flex: 2,
                        child: _MoneyField(
                            controller: _amount,
                            hint: '₹ Amount',
                            number: true)),
                    const SizedBox(width: 8),
                    Expanded(
                        flex: 3,
                        child: _MoneyField(
                            controller: _note, hint: 'Note (optional)')),
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
                const SizedBox(height: 6),

                if (_entries.isEmpty)
                  const EmptyHint('Log your first expense above.'),
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
                            Text(e['cat'] as String? ?? '📦 Other',
                                style: const TextStyle(fontSize: 11.5)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e['note'] as String? ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textMuted),
                              ),
                            ),
                            Text(
                              '₹${((e['amount'] as num?) ?? 0).toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _delete(e),
                              child: Icon(Icons.close_rounded,
                                  size: 15,
                                  color: AppColors.textMuted.withOpacity(0.6)),
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
}

// ═══════════════════════════════════════════════════════════════════════
//  BUDGET PLANNER — limits per category vs this month's expenses.
// ═══════════════════════════════════════════════════════════════════════

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  static const String limitsKey = 'svc.budget.limits';

  Map<String, dynamic> _limits = <String, dynamic>{};
  List<Map<String, dynamic>> _expenses = <Map<String, dynamic>>[];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final limits = await ServiceStore.loadMap(limitsKey);
    final expenses = await ServiceStore.loadList(_expensesKey);
    if (!mounted) return;
    setState(() {
      _limits = limits;
      _expenses = expenses;
      _loaded = true;
    });
  }

  double _spent(String cat) {
    final month = _monthKey(DateTime.now());
    return _expenses.where((e) {
      final t = DateTime.tryParse(e['t'] as String? ?? '');
      return t != null && _monthKey(t) == month && e['cat'] == cat;
    }).fold<double>(
        0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0));
  }

  Future<void> _editLimit(String cat) async {
    final controller = TextEditingController(
        text: ((_limits[cat] as num?)?.toDouble() ?? 0) == 0
            ? ''
            : '${(_limits[cat] as num).toInt()}');
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Budget for $cat', style: const TextStyle(fontSize: 15)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: '₹ '),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () =>
                  Navigator.pop(context, double.tryParse(controller.text)),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null) {
      setState(() => _limits[cat] = result);
      await ServiceStore.saveMap(limitsKey, _limits);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalLimit = expenseCategories.fold<double>(
        0, (sum, c) => sum + ((_limits[c] as num?)?.toDouble() ?? 0));
    final totalSpent =
        expenseCategories.fold<double>(0, (sum, c) => sum + _spent(c));
    final left = totalLimit - totalSpent;

    return Scaffold(
      appBar: svcAppBar('🎯 Budget Planner'),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.large),
              children: <Widget>[
                WhiteCard(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              totalLimit == 0
                                  ? 'Set budgets below'
                                  : '₹${left.toStringAsFixed(0)} left',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: left < 0
                                    ? const Color(0xFFC62828)
                                    : const Color(0xFF2E7D32),
                              ),
                            ),
                            Text(
                              '₹${totalSpent.toStringAsFixed(0)} of ₹${totalLimit.toStringAsFixed(0)} this month',
                              style: const TextStyle(
                                  fontSize: 10.5, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const SectionLabel('Category budgets — tap to edit'),
                for (final cat in expenseCategories)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => _editLimit(cat),
                      borderRadius: BorderRadius.circular(14),
                      child: WhiteCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Builder(builder: (context) {
                          final limit = (_limits[cat] as num?)?.toDouble() ?? 0;
                          final spent = _spent(cat);
                          final over = limit > 0 && spent > limit;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Text(cat,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                  const Spacer(),
                                  Text(
                                    limit == 0
                                        ? '₹${spent.toStringAsFixed(0)} · no budget'
                                        : '₹${spent.toStringAsFixed(0)} / ₹${limit.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: over
                                          ? const Color(0xFFC62828)
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              if (limit > 0) ...<Widget>[
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: (spent / limit).clamp(0.0, 1.0),
                                    minHeight: 6,
                                    color: over
                                        ? const Color(0xFFC62828)
                                        : AppColors.primary,
                                    backgroundColor:
                                        AppColors.surfaceTint.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                const Text(
                  'Spending comes from the Expense Tracker automatically.',
                  style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textMuted),
                ),
              ],
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  SUBSCRIPTIONS & BILLS — recurring monthly items.
// ═══════════════════════════════════════════════════════════════════════

class RecurringConfig {
  const RecurringConfig({
    required this.id,
    required this.title,
    required this.nameHint,
    required this.withPaidToggle,
  });

  final String id;
  final String title;
  final String nameHint;

  /// Bills: tick paid per month. Subs: renewal info only.
  final bool withPaidToggle;
}

const subsConfig = RecurringConfig(
  id: 'subscriptions',
  title: '🔁 Subscriptions',
  nameHint: 'Netflix, Spotify…',
  withPaidToggle: false,
);

const billsConfig = RecurringConfig(
  id: 'bills',
  title: '📅 Bill Reminders',
  nameHint: 'Electricity, rent…',
  withPaidToggle: true,
);

class RecurringPage extends StatefulWidget {
  const RecurringPage({super.key, required this.config});
  final RecurringConfig config;

  @override
  State<RecurringPage> createState() => _RecurringPageState();
}

class _RecurringPageState extends State<RecurringPage> {
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _day = TextEditingController();
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
    _name.dispose();
    _amount.dispose();
    _day.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    final amount = double.tryParse(_amount.text.trim());
    final day = int.tryParse(_day.text.trim());
    if (name.isEmpty || amount == null || day == null || day < 1 || day > 31) {
      return;
    }
    setState(() {
      _items.add(<String, dynamic>{
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'name': name,
        'amount': amount,
        'day': day,
        'paid': <String, dynamic>{},
      });
      _name.clear();
      _amount.clear();
      _day.clear();
    });
    await ServiceStore.saveList(_key, _items);
  }

  Future<void> _remove(String id) async {
    setState(() => _items.removeWhere((i) => i['id'] == id));
    await ServiceStore.saveList(_key, _items);
  }

  bool _isPaid(Map<String, dynamic> item) {
    final paid = item['paid'];
    if (paid is! Map) return false;
    return paid[_monthKey(DateTime.now())] == true;
  }

  Future<void> _togglePaid(Map<String, dynamic> item) async {
    final paid = Map<String, dynamic>.from((item['paid'] as Map?) ?? {});
    final key = _monthKey(DateTime.now());
    paid[key] = !(paid[key] == true);
    setState(() => item['paid'] = paid);
    await ServiceStore.saveList(_key, _items);
  }

  /// Days until this item's next due day-of-month.
  int _daysUntil(int dueDay) {
    final now = DateTime.now();
    final lastDayThisMonth = DateTime(now.year, now.month + 1, 0).day;
    var due = DateTime(now.year, now.month, dueDay.clamp(1, lastDayThisMonth));
    if (due.isBefore(DateTime(now.year, now.month, now.day))) {
      final lastDayNextMonth = DateTime(now.year, now.month + 2, 0).day;
      due =
          DateTime(now.year, now.month + 1, dueDay.clamp(1, lastDayNextMonth));
    }
    return due.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    final monthlyTotal = _items.fold<double>(
        0, (sum, i) => sum + ((i['amount'] as num?)?.toDouble() ?? 0));
    final sorted = _items.toList()
      ..sort((a, b) => _daysUntil((a['day'] as num?)?.toInt() ?? 1)
          .compareTo(_daysUntil((b['day'] as num?)?.toInt() ?? 1)));

    return Scaffold(
      appBar: svcAppBar(c.title),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.large),
              children: <Widget>[
                WhiteCard(
                  child: Row(
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('₹${monthlyTotal.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w800)),
                          Text(
                              'per month · ₹${(monthlyTotal * 12).toStringAsFixed(0)}/year',
                              style: const TextStyle(
                                  fontSize: 10.5, color: AppColors.textMuted)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                        flex: 3,
                        child:
                            _MoneyField(controller: _name, hint: c.nameHint)),
                    const SizedBox(width: 6),
                    Expanded(
                        flex: 2,
                        child: _MoneyField(
                            controller: _amount, hint: '₹', number: true)),
                    const SizedBox(width: 6),
                    Expanded(
                        flex: 2,
                        child: _MoneyField(
                            controller: _day,
                            hint: 'Day 1–31',
                            number: true)),
                    const SizedBox(width: 6),
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
                const SizedBox(height: 6),
                if (_items.isEmpty)
                  EmptyHint(c.withPaidToggle
                      ? 'Add bills with their due day — tick them off '
                          'each month.'
                      : 'Add every subscription — the yearly total is '
                          'usually a surprise.'),
                if (sorted.isNotEmpty)
                  SectionLabel(
                      c.withPaidToggle ? 'This month' : 'Next renewals'),
                for (final item in sorted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: WhiteCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: <Widget>[
                          if (c.withPaidToggle)
                            Checkbox(
                              value: _isPaid(item),
                              activeColor: AppColors.primary,
                              onChanged: (_) => _togglePaid(item),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(item['name'] as String,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      decoration:
                                          c.withPaidToggle && _isPaid(item)
                                              ? TextDecoration.lineThrough
                                              : null,
                                    )),
                                Builder(builder: (context) {
                                  final days = _daysUntil(
                                      (item['day'] as num?)?.toInt() ?? 1);
                                  final soon = days <= 3;
                                  final paid =
                                      c.withPaidToggle && _isPaid(item);
                                  return Text(
                                    paid
                                        ? 'Paid this month ✓'
                                        : days == 0
                                            ? 'Due today!'
                                            : 'Due in $days day${days == 1 ? '' : 's'} (day ${item['day']})',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: soon && !paid
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: paid
                                          ? const Color(0xFF2E7D32)
                                          : soon
                                              ? const Color(0xFFC62828)
                                              : AppColors.textMuted,
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                          Text(
                            '₹${((item['amount'] as num?) ?? 0).toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _remove(item['id'] as String),
                            child: Icon(Icons.close_rounded,
                                size: 15,
                                color: AppColors.textMuted.withOpacity(0.6)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _MoneyField extends StatelessWidget {
  const _MoneyField({
    required this.controller,
    required this.hint,
    this.number = false,
  });

  final TextEditingController controller;
  final String hint;
  final bool number;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        style: const TextStyle(fontSize: 12.5),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: TextStyle(
              fontSize: 11, color: AppColors.textMuted.withOpacity(0.8)),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.outline.withOpacity(0.9)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
          ),
        ),
      ),
    );
  }
}
