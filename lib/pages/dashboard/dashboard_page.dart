import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';
import '../../constants/app_strings.dart';
import '../../shared/widgets/empty_state_view.dart';
import '../../shared/widgets/error_state_view.dart';
import '../../shared/widgets/loading_state_view.dart';
import '../../state/async_view_state.dart';
import 'dashboard_controller.dart';
import 'dashboard_state.dart';
import 'widgets/check_in_sheet.dart';
import 'widgets/energy_level_card.dart';

// Quick-log shortcut chips shown below the energy cards.
typedef _QuickActivity = ({String emoji, String label, String hint});

const List<_QuickActivity> _kQuickActivities = <_QuickActivity>[
  (emoji: '🚶', label: 'Walk',      hint: 'I walked for 30 minutes'),
  (emoji: '🏃', label: 'Run',       hint: 'I jogged for 30 minutes'),
  (emoji: '🏋️', label: 'Gym',       hint: 'gym workout 30 minutes'),
  (emoji: '😴', label: 'Nap',       hint: 'I took a 20 minute nap'),
  (emoji: '🧘', label: 'Meditate',  hint: 'I meditated for 15 minutes'),
  (emoji: '💻', label: 'Deep work', hint: 'focused coding work 60 minutes'),
  (emoji: '📱', label: 'Scrolling', hint: 'I was scrolling social media 30 minutes'),
  (emoji: '🍽️', label: 'Break',     hint: 'I took a meal break away from my desk'),
];

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardController _controller;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = DashboardController()..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _textController.dispose();
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
        final topHeight = constraints.maxHeight * 0.40;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── Top 40 % — two energy level cards side by side ──────────
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

            // ── Status badges ────────────────────────────────────────────
            if (state.hasCheckInEstimate || state.analysisError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.large,
                  AppSpacing.medium,
                  AppSpacing.large,
                  0,
                ),
                child: Column(
                  children: <Widget>[
                    if (state.hasCheckInEstimate)
                      _AiPoweredBadge(
                        onRefresh: () => _showCheckInSheet(context),
                      ),
                    if (state.analysisError != null)
                      _AnalysisErrorBanner(message: state.analysisError!),
                  ],
                ),
              ),

            // ── Quick activity chips ─────────────────────────────────────
            _QuickActivitiesRow(
              isLoading: state.isAnalyzing,
              onSelect: _submitText,
              onAdvanced: () => _showCheckInSheet(context),
            ),

            const Spacer(),

            // ── Bottom text input (ChatGPT / Claude style) ───────────────
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

  void _showCheckInSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CheckInSheet(onSubmit: _controller.analyzeCheckIn),
    );
  }
}

// ── Quick-log chip row ────────────────────────────────────────────────────────

class _QuickActivitiesRow extends StatelessWidget {
  const _QuickActivitiesRow({
    required this.isLoading,
    required this.onSelect,
    required this.onAdvanced,
  });

  final bool isLoading;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdvanced;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.large,
        AppSpacing.medium,
        AppSpacing.large,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'QUICK LOG',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: <Widget>[
                ..._kQuickActivities.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.small),
                    child: ActionChip(
                      avatar: Text(a.emoji,
                          style: const TextStyle(fontSize: 14)),
                      label: Text(a.label),
                      onPressed: isLoading ? null : () => onSelect(a.hint),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: AppColors.outline),
                      ),
                      labelStyle: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xSmall),
                    ),
                  ),
                ),
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
      ),
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

// ── Status badges (reused from old layout) ────────────────────────────────────

class _AiPoweredBadge extends StatelessWidget {
  const _AiPoweredBadge({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.small),
      child: Row(
        children: <Widget>[
          const Icon(Icons.auto_awesome, size: 13, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xSmall),
          const Text(
            'Latest check-in estimate',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onRefresh,
            child: const Text(
              'Update',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
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
