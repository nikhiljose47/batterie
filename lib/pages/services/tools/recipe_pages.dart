import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import 'toolkit.dart';

// Recipe Manager (your recipe box) and Meal Planner (7-day × 3-meal grid
// that suggests from your saved recipes).

const String _recipesKey = 'svc.recipes.items';

// ═══════════════════════════════════════════════════════════════════════
//  RECIPE MANAGER
// ═══════════════════════════════════════════════════════════════════════

class RecipePage extends StatefulWidget {
  const RecipePage({super.key});

  @override
  State<RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends State<RecipePage> {
  List<Map<String, dynamic>> _recipes = <Map<String, dynamic>>[];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    ServiceStore.loadList(_recipesKey).then((list) {
      if (!mounted) return;
      setState(() {
        _recipes = list;
        _loaded = true;
      });
    });
  }

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    final name = TextEditingController(
        text: existing?['name'] as String? ?? '');
    final ingredients = TextEditingController(
        text: existing?['ingredients'] as String? ?? '');
    final steps = TextEditingController(
        text: existing?['steps'] as String? ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.large, AppSpacing.large,
            AppSpacing.large,
            MediaQuery.of(context).viewInsets.bottom + AppSpacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(existing == null ? 'New recipe' : 'Edit recipe',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              style: const TextStyle(fontSize: 13),
              decoration:
                  const InputDecoration(labelText: 'Name — "Masala oats"'),
            ),
            TextField(
              controller: ingredients,
              maxLines: 3,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                  labelText: 'Ingredients (one per line)'),
            ),
            TextField(
              controller: steps,
              maxLines: 3,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(labelText: 'Steps'),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );

    if (saved == true && name.text.trim().isNotEmpty) {
      setState(() {
        if (existing != null) {
          existing['name'] = name.text.trim();
          existing['ingredients'] = ingredients.text.trim();
          existing['steps'] = steps.text.trim();
        } else {
          _recipes.insert(0, <String, dynamic>{
            'id': DateTime.now().microsecondsSinceEpoch.toString(),
            'name': name.text.trim(),
            'ingredients': ingredients.text.trim(),
            'steps': steps.text.trim(),
          });
        }
      });
      await ServiceStore.saveList(_recipesKey, _recipes);
    }
    name.dispose();
    ingredients.dispose();
    steps.dispose();
  }

  Future<void> _delete(Map<String, dynamic> recipe) async {
    setState(() => _recipes.remove(recipe));
    await ServiceStore.saveList(_recipesKey, _recipes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: svcAppBar('🍳 Recipe Manager'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _recipes.isEmpty
              ? const EmptyHint(
                  'Your recipe box is empty — tap + to save the first '
                  'one.')
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.large),
                  children: <Widget>[
                    for (final r in _recipes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: WhiteCard(
                          padding: EdgeInsets.zero,
                          child: Theme(
                            data: Theme.of(context).copyWith(
                                dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(
                                  horizontal: 14),
                              title: Text(r['name'] as String,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      14, 0, 14, 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      if ((r['ingredients'] as String?)
                                              ?.isNotEmpty ==
                                          true) ...<Widget>[
                                        const Text('INGREDIENTS',
                                            style: TextStyle(
                                                fontSize: 9,
                                                fontWeight:
                                                    FontWeight.w800,
                                                letterSpacing: 0.8,
                                                color: AppColors
                                                    .textMuted)),
                                        const SizedBox(height: 3),
                                        Text(r['ingredients'] as String,
                                            style: const TextStyle(
                                                fontSize: 11.5,
                                                height: 1.5)),
                                        const SizedBox(height: 8),
                                      ],
                                      if ((r['steps'] as String?)
                                              ?.isNotEmpty ==
                                          true) ...<Widget>[
                                        const Text('STEPS',
                                            style: TextStyle(
                                                fontSize: 9,
                                                fontWeight:
                                                    FontWeight.w800,
                                                letterSpacing: 0.8,
                                                color: AppColors
                                                    .textMuted)),
                                        const SizedBox(height: 3),
                                        Text(r['steps'] as String,
                                            style: const TextStyle(
                                                fontSize: 11.5,
                                                height: 1.5)),
                                        const SizedBox(height: 8),
                                      ],
                                      Row(
                                        children: <Widget>[
                                          TextButton.icon(
                                            onPressed: () => _edit(r),
                                            icon: const Icon(
                                                Icons.edit_rounded,
                                                size: 14),
                                            label: const Text('Edit',
                                                style: TextStyle(
                                                    fontSize: 11)),
                                          ),
                                          TextButton.icon(
                                            onPressed: () => _delete(r),
                                            icon: const Icon(
                                                Icons
                                                    .delete_outline_rounded,
                                                size: 14),
                                            label: const Text('Delete',
                                                style: TextStyle(
                                                    fontSize: 11)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  MEAL PLANNER
// ═══════════════════════════════════════════════════════════════════════

class MealPlanPage extends StatefulWidget {
  const MealPlanPage({super.key});

  @override
  State<MealPlanPage> createState() => _MealPlanPageState();
}

class _MealPlanPageState extends State<MealPlanPage> {
  static const String key = 'svc.mealplan.grid';
  static const List<String> _days = <String>[
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];
  static const List<String> _meals = <String>[
    '🌅 Breakfast', '☀️ Lunch', '🌙 Dinner'
  ];

  Map<String, dynamic> _grid = <String, dynamic>{};
  List<Map<String, dynamic>> _recipes = <Map<String, dynamic>>[];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final grid = await ServiceStore.loadMap(key);
    final recipes = await ServiceStore.loadList(_recipesKey);
    if (!mounted) return;
    setState(() {
      _grid = grid;
      _recipes = recipes;
      _loaded = true;
    });
  }

  Future<void> _editCell(String day, String meal) async {
    final cellKey = '$day.$meal';
    final controller =
        TextEditingController(text: _grid[cellKey] as String? ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$meal · $day', style: const TextStyle(fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration:
                  const InputDecoration(hintText: 'What\'s cooking?'),
            ),
            if (_recipes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              const Text('From your recipe box:',
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textMuted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final r in _recipes.take(6))
                    InkWell(
                      onTap: () =>
                          controller.text = r['name'] as String? ?? '',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceTint,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(r['name'] as String? ?? '',
                            style: const TextStyle(fontSize: 10.5)),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null) {
      setState(() {
        if (result.trim().isEmpty) {
          _grid.remove(cellKey);
        } else {
          _grid[cellKey] = result.trim();
        }
      });
      await ServiceStore.saveMap(key, _grid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayIndex = DateTime.now().weekday - 1;

    return Scaffold(
      appBar: svcAppBar('📋 Meal Planner'),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.large),
              children: <Widget>[
                for (var d = 0; d < _days.length; d++) ...<Widget>[
                  SectionLabel(
                      d == todayIndex ? '${_days[d]} — today' : _days[d]),
                  WhiteCard(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      children: <Widget>[
                        for (final meal in _meals)
                          InkWell(
                            onTap: () => _editCell(_days[d], meal),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 7),
                              child: Row(
                                children: <Widget>[
                                  SizedBox(
                                    width: 100,
                                    child: Text(meal,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textMuted)),
                                  ),
                                  Expanded(
                                    child: Text(
                                      _grid['${_days[d]}.$meal']
                                              as String? ??
                                          'Tap to plan…',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: _grid[
                                                    '${_days[d]}.$meal'] ==
                                                null
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                        color: _grid['${_days[d]}.$meal'] ==
                                                null
                                            ? AppColors.textMuted
                                                .withValues(alpha: 0.6)
                                            : const Color(0xFF2A2E3B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ],
            ),
    );
  }
}
