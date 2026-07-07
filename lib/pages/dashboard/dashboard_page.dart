import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';
import '../../constants/app_strings.dart';
import '../../engine/energy_score_engine.dart';
import '../../models/logged_activity.dart';
import '../../shared/widgets/empty_state_view.dart';
import '../../shared/widgets/error_state_view.dart';
import '../../shared/widgets/loading_state_view.dart';
import '../../state/async_view_state.dart';
import 'dashboard_controller.dart';
import 'dashboard_state.dart';
import 'widgets/activity_timeline_rail.dart';
import 'widgets/check_in_sheet.dart';
import 'widgets/energy_level_card.dart';

// Curated quick-log shortcuts; each maps straight to an engine activity.
typedef _QuickActivity = ({String activityId, String emoji, String label});

const List<_QuickActivity> _kQuickActivities = <_QuickActivity>[
  (activityId: 'brisk_walking', emoji: '🚶', label: 'Walk'),
  (activityId: 'running_easy_pace', emoji: '🏃', label: 'Run'),
  (activityId: 'hiit_workout', emoji: '🏋️', label: 'Gym'),
  (activityId: 'power_nap_10_20_min', emoji: '😴', label: 'Nap'),
  (activityId: 'mindfulness_meditation', emoji: '🧘', label: 'Meditate'),
  (activityId: 'focused_coding', emoji: '💻', label: 'Deep work'),
  (activityId: 'social_media_scrolling', emoji: '📱', label: 'Scrolling'),
  (activityId: 'meal_break_away_from_desk', emoji: '🍽️', label: 'Break'),
];

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardController _controller;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _controller = DashboardController()..load();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _textController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;

        switch (state.status) {
          case AsyncStatus.initial:
          case AsyncStatus.loading:
            return const LoadingStateView();
          case AsyncStatus.empty:
            return const EmptyStateView(message: AppStrings.emptyTitle);
          case AsyncStatus.error:
            return ErrorStateView(
              message: state.errorMessage ?? AppStrings.genericError,
              onRetry: _controller.load,
            );
          case AsyncStatus.success:
            return _buildBody(context, state);
        }
      },
    );
  }

  Widget _buildBody(BuildContext context, DashboardState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final topHeight = constraints.maxHeight * 0.38;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── Top — two energy batteries side by side ─────────────────
            SizedBox(
              height: topHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.large,
                  AppSpacing.medium,
                  AppSpacing.large,
                  0,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: EnergyLevelCard(
                        label: AppStrings.physicalEnergy,
                        percent: state.batteries.isNotEmpty
                            ? state.batteries[0].percent
                            : 0.72,
                        subtitle: state.batteries.isNotEmpty
                            ? state.batteries[0].subtitle
                            : '',
                        accentColor: AppColors.energyPhysicalAccent,
                        backgroundColor: AppColors.energyPhysicalBg,
                        icon: Icons.fitness_center_rounded,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.medium),
                    Expanded(
                      child: EnergyLevelCard(
                        label: AppStrings.brainEnergy,
                        percent: state.batteries.length > 1
                            ? state.batteries[1].percent
                            : 0.74,
                        subtitle: state.batteries.length > 1
                            ? state.batteries[1].subtitle
                            : '',
                        accentColor: AppColors.energyBrainAccent,
                        backgroundColor: AppColors.energyBrainBg,
                        icon: Icons.psychology_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Middle — scrollable: rail + quick log ────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.large,
                  AppSpacing.medium,
                  AppSpacing.large,
                  AppSpacing.small,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (state.analysisError != null)
                      _AnalysisErrorBanner(message: state.analysisError!),
                    ActivityTimelineRail(
                      activities: state.loggedActivities,
                      onDropActivity: (activityId, startMinutes) =>
                          _controller.logActivity(activityId,
                              startMinutes: startMinutes),
                      onEditRequest: _showEditActivitySheet,
                      onAdjustDuration: _adjustDuration,
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    _QuickLogSection(
                      isLoading: state.isAnalyzing,
                      searchController: _searchController,
                      searchQuery: _searchQuery,
                      onSelect: (activityId) =>
                          _controller.logActivity(activityId),
                      onAdvanced: () => _showCheckInSheet(context),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom — ChatGPT-style text input ────────────────────────
            _ActivityInputBar(
              controller: _textController,
              focusNode: _focusNode,
              isLoading: state.isAnalyzing,
              onSubmit: _submitText,
            ),
          ],
        );
      },
    );
  }

  void _submitText(String text) {
    if (text.trim().isEmpty) return;
    _controller.processActivityText(text);
    _textController.clear();
    _focusNode.unfocus();
  }

  void _adjustDuration(LoggedActivity logged, int deltaMinutes) {
    final newDuration =
        (logged.durationMinutes + deltaMinutes).clamp(10, 240);
    final activity =
        const EnergyScoreEngine().activityById(logged.activityId);

    if (newDuration == logged.durationMinutes) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
            deltaMinutes > 0
                ? '${activity.name} is already at the 240 min maximum'
                : '${activity.name} is already at the 10 min minimum',
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ));
      return;
    }

    _controller.updateLoggedActivity(logged.id,
        durationMinutes: newDuration);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          '${activity.name} ${deltaMinutes > 0 ? '+30' : '−30'} min → $newDuration min',
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _showCheckInSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CheckInSheet(onSubmit: _controller.analyzeCheckIn),
    );
  }

  void _showEditActivitySheet(LoggedActivity logged) {
    const engine = EnergyScoreEngine();
    final activity = engine.activityById(logged.activityId);
    var start = logged.startMinutes.toDouble();
    var duration = logged.durationMinutes.toDouble().clamp(10.0, 240.0);

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
                '${activityEmojis[logged.activityId] ?? '⚡'} ${activity.name}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.large),
              Row(
                children: <Widget>[
                  const Expanded(child: Text('Start time')),
                  Text(
                    formatMinutes(start.round()),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
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
                  Text(
                    '${duration.round()} min',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
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
                        _controller.removeLoggedActivity(logged.id);
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
                        _controller.updateLoggedActivity(
                          logged.id,
                          startMinutes: start.round(),
                          durationMinutes: duration.round(),
                        );
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
}

// ── Quick log: search + draggable chips ──────────────────────────────────────

class _QuickLogSection extends StatelessWidget {
  const _QuickLogSection({
    required this.isLoading,
    required this.searchController,
    required this.searchQuery,
    required this.onSelect,
    required this.onAdvanced,
  });

  final bool isLoading;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdvanced;

  List<({String activityId, String emoji, String label})> get _visibleChips {
    if (searchQuery.isEmpty) return _kQuickActivities;
    final q = searchQuery.toLowerCase();
    return EnergyScoreEngine.activities
        .where((a) => a.name.toLowerCase().contains(q))
        .map((a) => (
              activityId: a.id,
              emoji: activityEmojis[a.id] ?? '⚡',
              label: a.name,
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final chips = _visibleChips;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Row(
          children: <Widget>[
            Text(
              'QUICK LOG',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1.0,
              ),
            ),
            Spacer(),
            Text(
              'tap to log now · hold and drag to the rail',
              style: TextStyle(fontSize: 9, color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.small),
        SizedBox(
          height: 36,
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search activities…',
              hintStyle: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted.withValues(alpha: 0.6),
              ),
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 18, color: AppColors.textMuted),
              suffixIcon: searchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      color: AppColors.textMuted,
                      onPressed: searchController.clear,
                    ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppColors.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppColors.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1),
              ),
            ),
            style: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        if (chips.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.small),
            child: Text(
              'No matching activity — try the text box below, AI will estimate it.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: <Widget>[
                ...chips.map(
                  (chip) => Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.small),
                    child: _DraggableActivityChip(
                      activityId: chip.activityId,
                      emoji: chip.emoji,
                      label: chip.label,
                      enabled: !isLoading,
                      onTap: () => onSelect(chip.activityId),
                    ),
                  ),
                ),
                if (searchQuery.isEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.tune_rounded,
                        size: 14, color: AppColors.primary),
                    label: const Text('More'),
                    onPressed: isLoading ? null : onAdvanced,
                    backgroundColor: AppColors.surfaceTint,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(
                          color: AppColors.primary, width: 0.5),
                    ),
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xSmall),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Chip that logs on tap and can be long-pressed and dragged onto the rail.
class _DraggableActivityChip extends StatelessWidget {
  const _DraggableActivityChip({
    required this.activityId,
    required this.emoji,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String activityId;
  final String emoji;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  Widget _chip(BuildContext context, {bool dragging = false}) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: dragging ? AppColors.surfaceTint : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: dragging ? AppColors.primary : AppColors.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: dragging ? AppColors.primary : AppColors.textMuted,
                fontWeight: dragging ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) return Opacity(opacity: 0.5, child: _chip(context));

    return LongPressDraggable<String>(
      data: activityId,
      feedback: _chip(context, dragging: true),
      childWhenDragging: Opacity(opacity: 0.35, child: _chip(context)),
      child: GestureDetector(onTap: onTap, child: _chip(context)),
    );
  }
}

// ── Bottom activity input bar ─────────────────────────────────────────────────

class _ActivityInputBar extends StatelessWidget {
  const _ActivityInputBar({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
            top: BorderSide(color: AppColors.outline, width: 0.5)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.medium,
        AppSpacing.small,
        AppSpacing.medium,
        AppSpacing.small + bottomPad,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: !isLoading,
              decoration: InputDecoration(
                hintText: '"walked 30 min", "gym 1h", "took a nap"…',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: AppColors.scaffoldBackground,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.large, vertical: AppSpacing.small),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1),
                ),
              ),
              style: const TextStyle(fontSize: 14),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: onSubmit,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: AppSpacing.small),
          _SendButton(
            isLoading: isLoading,
            onTap: () => onSubmit(controller.text),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: isLoading
          ? const SizedBox(
              key: ValueKey<String>('loading'),
              width: 40,
              height: 40,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                ),
              ),
            )
          : Material(
              key: const ValueKey<String>('send'),
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onTap,
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.arrow_upward_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ),
    );
  }
}

class _AnalysisErrorBanner extends StatelessWidget {
  const _AnalysisErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.small),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.medium),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F0),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.error_outline,
                size: 15, color: AppColors.error),
            const SizedBox(width: AppSpacing.small),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 12, color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
