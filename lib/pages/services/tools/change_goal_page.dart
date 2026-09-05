import 'dart:async';

import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/goal_plan_constants.dart';
import '../../../services/custom_mode_store.dart';
import '../../../services/shared_goal_plan_service.dart';
import '../../home_tab/data/mode_advice.dart';
import '../../profile/profile_store.dart';
import 'daily_planner_page.dart';
import 'toolkit.dart';

enum _GoalEntryKind { shared, ready, custom }

class ChangeGoalPage extends StatefulWidget {
  const ChangeGoalPage({super.key});

  @override
  State<ChangeGoalPage> createState() => _ChangeGoalPageState();
}

class _ChangeGoalPageState extends State<ChangeGoalPage> {
  static const String _ratingsKey = 'svc.goals.ratings';

  late Future<List<SharedGoalPlan>> _sharedPlans;
  final TextEditingController _searchCtl = TextEditingController();
  Map<String, double> _ratings = const <String, double>{};
  Timer? _ratingWriteTimer;

  @override
  void initState() {
    super.initState();
    _sharedPlans = SharedGoalPlanService.instance.trendingPlans();
    _searchCtl.addListener(() => setState(() {}));
    _loadRatings();
  }

  @override
  void dispose() {
    _ratingWriteTimer?.cancel();
    unawaited(_persistRatings());
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _loadRatings() async {
    final stored = await ServiceStore.loadMap(_ratingsKey);
    if (!mounted) return;
    setState(() {
      _ratings = <String, double>{
        for (final entry in stored.entries)
          if (entry.value is num) entry.key: (entry.value as num).toDouble(),
      };
    });
  }

  Future<void> _persistRatings() {
    return ServiceStore.saveMap(_ratingsKey, <String, dynamic>{
      for (final entry in _ratings.entries) entry.key: entry.value,
    });
  }

  void _rateGoal(_GoalEntry entry, double rating) {
    setState(() {
      _ratings = <String, double>{
        ..._ratings,
        entry.ratingKey: rating.clamp(1, 5).toDouble(),
      };
    });
    _ratingWriteTimer?.cancel();
    _ratingWriteTimer = Timer(
      const Duration(milliseconds: 650),
      () => unawaited(_persistRatings()),
    );
  }

  double _displayRating(_GoalEntry entry) =>
      _ratings[entry.ratingKey] ?? entry.rating;

  Future<void> _selectGoal(String id) async {
    if (CustomModeStore.isCustomModeId(id)) {
      await CustomModeStore.instance.setActivePlan(id);
    }
    await ProfileStore.instance.setPlannerMode(id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _createPlan() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const DailyPlannerPage()),
    );
    if (!mounted) return;
    if (changed == true) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {});
  }

  Future<void> _editPlan(CustomPlan plan) async {
    await CustomModeStore.instance.setActivePlan(plan.id);
    await ProfileStore.instance.setPlannerMode(plan.id);
    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const DailyPlannerPage()),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _deletePlan(CustomPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this plan?'),
        content: Text('This removes "${plan.name}" from your plans.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await CustomModeStore.instance.deletePlan(plan.id);
    if (ProfileStore.instance.plannerMode.value == plan.id) {
      final customPlans = CustomModeStore.instance.plans.value;
      final fallback = customPlans.isEmpty
          ? allDayModes[
                  DateTime.now().millisecondsSinceEpoch % allDayModes.length]
              .id
          : CustomModeStore.instance.activePlanId.value;
      await ProfileStore.instance.setPlannerMode(fallback);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    setState(() {});
  }

  Future<void> _publishPlan(CustomPlan plan) async {
    await SharedGoalPlanService.instance.publishPlan(plan);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Plan shared')),
    );
  }

  Future<void> _toggleLike(SharedGoalPlan plan) async {
    await SharedGoalPlanService.instance.toggleLike(plan);
    if (!mounted) return;
    setState(() {
      _sharedPlans = _sharedPlans.then((plans) {
        return <SharedGoalPlan>[
          for (final item in plans)
            if (item.id == plan.id)
              item.copyWith(
                likedByMe: !plan.likedByMe,
                likesCount: (plan.likesCount + (plan.likedByMe ? -1 : 1))
                    .clamp(0, 999999)
                    .toInt(),
              )
            else
              item,
        ];
      });
    });
  }

  Future<void> _useSharedPlan(SharedGoalPlan plan) async {
    final imported = await SharedGoalPlanService.instance.usePlan(plan);
    if (imported == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan already exists or limit reached')),
      );
      return;
    }
    await ProfileStore.instance.setPlannerMode(imported.id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  List<_GoalEntry> _entries({
    required List<SharedGoalPlan> sharedPlans,
    required List<CustomPlan> customPlans,
  }) {
    return <_GoalEntry>[
      for (var i = 0; i < sharedPlans.length; i++)
        _GoalEntry.shared(sharedPlans[i], trending: i < 4),
      for (var i = 0; i < allDayModes.length; i++)
        _GoalEntry.ready(allDayModes[i], index: i),
      for (final plan in customPlans) _GoalEntry.custom(plan),
    ];
  }

  List<_GoalEntry> _filterEntries(List<_GoalEntry> entries) {
    final query = _searchCtl.text.trim().toLowerCase();
    if (query.isEmpty) return entries;
    return entries.where((entry) {
      return entry.title.toLowerCase().contains(query) ||
          entry.description.toLowerCase().contains(query) ||
          entry.author.toLowerCase().contains(query) ||
          entry.tag.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  Future<void> _openDetails(_GoalEntry entry) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _GoalDetailPage(
          entry: entry,
          rating: _displayRating(entry),
          selected: entry.modeId == ProfileStore.instance.plannerMode.value,
          onUse: () {
            if (entry.sharedPlan != null) {
              _useSharedPlan(entry.sharedPlan!);
            } else {
              _selectGoal(entry.modeId);
            }
          },
          onLike: entry.sharedPlan == null
              ? null
              : () => _toggleLike(entry.sharedPlan!),
          onEdit: entry.customPlan == null
              ? null
              : () => _editPlan(entry.customPlan!),
          onShare: entry.customPlan == null
              ? null
              : () => _publishPlan(entry.customPlan!),
          onDelete: entry.customPlan == null
              ? null
              : () => _deletePlan(entry.customPlan!),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: svcAppBar('Change Goal'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createPlan,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create plan'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _PlanSearchBar(controller: _searchCtl),
                const SizedBox(height: 7),
                Text(
                  'Community, ready-made, and your plans.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface.withOpacity(0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<CustomPlan>>(
              valueListenable: CustomModeStore.instance.plans,
              builder: (context, customPlans, _) {
                return FutureBuilder<List<SharedGoalPlan>>(
                  future: _sharedPlans,
                  builder: (context, snapshot) {
                    final entries = _filterEntries(
                      _entries(
                        sharedPlans: snapshot.data ?? const <SharedGoalPlan>[],
                        customPlans: customPlans,
                      ),
                    );
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 92),
                      children: <Widget>[
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else if (entries.isEmpty)
                          const EmptyHint('No plans found.')
                        else
                          for (final entry in entries)
                            _GoalFeedCard(
                              entry: entry,
                              rating: _displayRating(entry),
                              selected: entry.modeId ==
                                  ProfileStore.instance.plannerMode.value,
                              onTap: () => _openDetails(entry),
                              onRate: (rating) => _rateGoal(entry, rating),
                              onFeedback: entry.sharedPlan == null
                                  ? null
                                  : () => _toggleLike(entry.sharedPlan!),
                            ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalEntry {
  const _GoalEntry({
    required this.kind,
    required this.modeId,
    required this.title,
    required this.description,
    required this.author,
    required this.tag,
    required this.users,
    required this.rating,
    required this.icon,
    required this.accent,
    required this.slots,
    this.trending = false,
    this.sharedPlan,
    this.customPlan,
  });

  factory _GoalEntry.shared(SharedGoalPlan plan, {required bool trending}) {
    return _GoalEntry(
      kind: _GoalEntryKind.shared,
      modeId: plan.id,
      title: plan.shortName ?? plan.name,
      description: plan.description.trim().isEmpty
          ? _slotDescription(plan.slots)
          : plan.description,
      author: plan.ownerName,
      tag: plan.tag,
      users: plan.displayUsedCount,
      rating: plan.rating,
      icon: Icons.public_rounded,
      accent: AppColors.info,
      slots: plan.slots,
      trending: trending,
      sharedPlan: plan,
    );
  }

  factory _GoalEntry.ready(DayMode mode, {required int index}) {
    final advice = adviceForMode(mode.id);
    return _GoalEntry(
      kind: _GoalEntryKind.ready,
      modeId: mode.id,
      title: mode.shortLabel,
      description: mode.label,
      author: 'Batterie',
      tag: _tagForMode(mode.id),
      users: 2 + (index * 5),
      rating: 4.4 + ((index % 4) * 0.1),
      icon: Icons.auto_awesome_rounded,
      accent: _goalTint(mode.id),
      slots: <CustomSlot>[
        for (final item in advice)
          CustomSlot(
            recommendation: item.recommendation,
            tip: item.tip,
            descriptions: item.descriptions,
          ),
      ],
    );
  }

  factory _GoalEntry.custom(CustomPlan plan) {
    return _GoalEntry(
      kind: _GoalEntryKind.custom,
      modeId: plan.id,
      title: plan.shortName ?? plan.name,
      description: plan.description.trim().isEmpty
          ? _slotDescription(plan.slots)
          : plan.description,
      author: 'You',
      tag: plan.tag,
      users: 2,
      rating: 4.5,
      icon: Icons.edit_note_rounded,
      accent: AppColors.primary,
      slots: plan.slots,
      customPlan: plan,
    );
  }

  final _GoalEntryKind kind;
  final String modeId;
  final String title;
  final String description;
  final String author;
  final String tag;
  final int users;
  final double rating;
  final IconData icon;
  final Color accent;
  final List<CustomSlot> slots;
  final bool trending;
  final SharedGoalPlan? sharedPlan;
  final CustomPlan? customPlan;

  String get ratingKey => switch (kind) {
        _GoalEntryKind.shared => 'shared:$modeId',
        _GoalEntryKind.ready => 'ready:$modeId',
        _GoalEntryKind.custom => 'custom:$modeId',
      };

  String get typeLabel => switch (kind) {
        _GoalEntryKind.shared => trending ? 'Trending' : 'Community',
        _GoalEntryKind.ready => 'Ready-made',
        _GoalEntryKind.custom => 'Your plan',
      };

  static String _slotDescription(List<CustomSlot> slots) {
    for (final slot in slots) {
      if (slot.recommendation.trim().isNotEmpty) {
        return _shortText(slot.recommendation);
      }
      if (slot.tip.trim().isNotEmpty) return _shortText(slot.tip);
    }
    return 'A personal day plan from wake time to sleep time.';
  }

  static String _shortText(String value) {
    final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.length <= 78) return text;
    return '${text.substring(0, 75).trimRight()}...';
  }

  static String _tagForMode(String id) {
    return switch (id) {
      'student' => 'exam',
      'office' => 'focus',
      'gym' || 'athletic' => 'fitness',
      'nicotine_free' => 'nicotine',
      'language' => 'language',
      _ => GoalPlanConstants.defaultTag,
    };
  }

  static Color _goalTint(String id) {
    return switch (id) {
      'student' => const Color(0xFF4F7FE5),
      'office' => const Color(0xFF168A5A),
      'gym' => const Color(0xFFE16A3D),
      'nicotine_free' => const Color(0xFF6D5BD0),
      'language' => const Color(0xFF2E9DA6),
      'athletic' => const Color(0xFFD49B25),
      _ => AppColors.primary,
    };
  }
}

class _GoalFeedCard extends StatelessWidget {
  const _GoalFeedCard({
    required this.entry,
    required this.rating,
    required this.selected,
    required this.onTap,
    required this.onRate,
    this.onFeedback,
  });

  final _GoalEntry entry;
  final double rating;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<double> onRate;
  final VoidCallback? onFeedback;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final sharedPlan = entry.sharedPlan;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? entry.accent.withOpacity(0.06) : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: colors.outline.withOpacity(0.26)),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 20),
        child: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: entry.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(entry.icon, size: 18, color: entry.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (selected)
                        Icon(
                          Icons.check_circle_rounded,
                          size: 15,
                          color: entry.accent,
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entry.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface.withOpacity(0.52),
                      fontSize: 11.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${entry.typeLabel} - ${entry.author}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface.withOpacity(0.43),
                      fontSize: 10.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _RatingBadge(rating: rating, onRate: onRate),
                const SizedBox(height: 5),
                _UsersBadge(users: entry.users),
              ],
            ),
            if (onFeedback != null) ...<Widget>[
              const SizedBox(width: 2),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 34,
                  height: 34,
                ),
                onPressed: onFeedback,
                icon: Icon(
                  sharedPlan?.likedByMe == true
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 18,
                  color: sharedPlan?.likedByMe == true
                      ? AppColors.error
                      : colors.onSurface.withOpacity(0.38),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({
    required this.rating,
    required this.onRate,
  });

  final double rating;
  final ValueChanged<double> onRate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopupMenuButton<double>(
      tooltip: 'Rate goal',
      onSelected: onRate,
      padding: EdgeInsets.zero,
      itemBuilder: (context) => <PopupMenuEntry<double>>[
        for (var i = 1; i <= 5; i++)
          PopupMenuItem<double>(
            value: i.toDouble(),
            height: 36,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var star = 1; star <= 5; star++)
                  Icon(
                    star <= i ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 16,
                    color: const Color(0xFFE2A72E),
                  ),
              ],
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.star_rounded,
            size: 13,
            color: Color(0xFFE2A72E),
          ),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              color: colors.onSurface.withOpacity(0.6),
              fontSize: 10.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsersBadge extends StatelessWidget {
  const _UsersBadge({required this.users});

  final int users;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 86),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withOpacity(0.58),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.outline.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.group_rounded,
            size: 11,
            color: colors.onSurface.withOpacity(0.42),
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              '$users using',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurface.withOpacity(0.52),
                fontSize: 9.6,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalDetailPage extends StatelessWidget {
  const _GoalDetailPage({
    required this.entry,
    required this.rating,
    required this.selected,
    required this.onUse,
    this.onLike,
    this.onEdit,
    this.onShare,
    this.onDelete,
  });

  final _GoalEntry entry;
  final double rating;
  final bool selected;
  final VoidCallback onUse;
  final VoidCallback? onLike;
  final VoidCallback? onEdit;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final sharedPlan = entry.sharedPlan;
    return Scaffold(
      appBar: svcAppBar('Goal details'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: entry.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.surface.withOpacity(0.78),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(entry.icon, color: entry.accent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            entry.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 20,
                              height: 1.05,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${entry.typeLabel} - ${entry.author}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurface.withOpacity(0.52),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  entry.description,
                  style: TextStyle(
                    color: colors.onSurface.withOpacity(0.72),
                    fontSize: 13,
                    height: 1.28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    _DetailMetric(
                      icon: Icons.star_rounded,
                      label: rating.toStringAsFixed(1),
                    ),
                    const SizedBox(width: 8),
                    _DetailMetric(
                      icon: Icons.sell_outlined,
                      label: GoalPlanConstants.labelFor(entry.tag),
                    ),
                    if (sharedPlan != null) ...<Widget>[
                      const SizedBox(width: 8),
                      _DetailMetric(
                        icon: Icons.favorite_rounded,
                        label: '${sharedPlan.likesCount}',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: selected ? null : onUse,
                icon: Icon(
                  selected
                      ? Icons.check_rounded
                      : Icons.playlist_add_check_rounded,
                  size: 17,
                ),
                label: Text(selected ? 'Selected' : 'Use goal'),
              ),
              if (onEdit != null)
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_note_rounded, size: 17),
                  label: const Text('Edit'),
                ),
              if (onShare != null)
                OutlinedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.cloud_upload_outlined, size: 17),
                  label: const Text('Share'),
                ),
              if (onLike != null)
                OutlinedButton.icon(
                  onPressed: onLike,
                  icon: Icon(
                    sharedPlan?.likedByMe == true
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 17,
                  ),
                  label: Text(sharedPlan?.likedByMe == true ? 'Liked' : 'Like'),
                ),
              if (onDelete != null)
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 17),
                  label: const Text('Delete'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const SectionLabel('Plan cards'),
          for (var i = 0; i < entry.slots.length; i++)
            _GoalSlotPreview(index: i, slot: entry.slots[i]),
        ],
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.74),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: AppColors.info),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: colors.onSurface.withOpacity(0.66),
              fontSize: 10.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalSlotPreview extends StatelessWidget {
  const _GoalSlotPreview({required this.index, required this.slot});

  final int index;
  final CustomSlot slot;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = slot.tip.trim().isEmpty ? 'Card ${index + 1}' : slot.tip;
    final body = slot.recommendation.trim().isEmpty
        ? 'Set what should happen in this time block.'
        : slot.recommendation;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outline.withOpacity(0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSurface.withOpacity(0.58),
              fontSize: 11.4,
              height: 1.22,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanSearchBar extends StatelessWidget {
  const _PlanSearchBar({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search goals, tags, authors',
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: controller.clear,
                icon: const Icon(Icons.close_rounded, size: 17),
              ),
        filled: true,
        fillColor: colors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.outline.withOpacity(0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.outline.withOpacity(0.25)),
        ),
      ),
    );
  }
}
