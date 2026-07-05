import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';
import '../../constants/app_strings.dart';
import '../../shared/widgets/empty_state_view.dart';
import '../../shared/widgets/error_state_view.dart';
import '../../shared/widgets/loading_state_view.dart';
import '../../state/async_view_state.dart';
import 'dashboard_controller.dart';
import 'widgets/battery_card.dart';
import 'widgets/body_status_card.dart';
import 'widgets/check_in_sheet.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DashboardController()..load();
  }

  @override
  void dispose() {
    _controller.dispose();
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
            final bodyStatus = state.bodyStatus;
            if (bodyStatus == null) {
              return ErrorStateView(
                message: AppStrings.genericError,
                onRetry: _controller.load,
              );
            }

            return Stack(
              children: <Widget>[
                LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.large,
                        AppSpacing.large,
                        AppSpacing.large,
                        AppSpacing.xLarge + 72,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (state.isAiPowered)
                            _AiPoweredBadge(
                              onRefresh: () => _showCheckInSheet(context),
                            ),
                          if (state.analysisError != null)
                            _AnalysisErrorBanner(
                              message: state.analysisError!,
                            ),
                          if (state.isAiPowered) const SizedBox(height: AppSpacing.medium),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceTint,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusMedium),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.medium),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight -
                                      (AppSpacing.xLarge + AppSpacing.xxLarge),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(
                                      flex: 7,
                                      child: BodyStatusCard(bodyStatus: bodyStatus),
                                    ),
                                    const SizedBox(width: AppSpacing.medium),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        children: state.batteries
                                            .map(
                                              (battery) => Padding(
                                                padding: EdgeInsets.only(
                                                  bottom:
                                                      battery == state.batteries.last
                                                          ? 0
                                                          : AppSpacing.medium,
                                                ),
                                                child: BatteryCard(status: battery),
                                              ),
                                            )
                                            .toList(),
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
                  },
                ),
                Positioned(
                  bottom: AppSpacing.xLarge,
                  left: AppSpacing.large,
                  right: AppSpacing.large,
                  child: state.isAnalyzing
                      ? const _AnalyzingBanner()
                      : _CheckInButton(
                          onTap: () => _showCheckInSheet(context),
                        ),
                ),
              ],
            );
        }
      },
    );
  }

  void _showCheckInSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CheckInSheet(
        onSubmit: _controller.analyzeCheckIn,
      ),
    );
  }
}

class _CheckInButton extends StatelessWidget {
  const _CheckInButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.self_improvement_outlined),
      label: const Text('Check in with AI'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        ),
      ),
    );
  }
}

class _AnalyzingBanner extends StatelessWidget {
  const _AnalyzingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.outline),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: AppSpacing.medium),
          Text('Analysing your energy levels…'),
        ],
      ),
    );
  }
}

class _AiPoweredBadge extends StatelessWidget {
  const _AiPoweredBadge({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.medium),
      child: Row(
        children: <Widget>[
          const Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xSmall),
          const Text(
            'AI-powered check-in',
            style: TextStyle(
              fontSize: 12,
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
                fontSize: 12,
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
      padding: const EdgeInsets.only(bottom: AppSpacing.medium),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.medium),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F0),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.error_outline, size: 16, color: AppColors.error),
            const SizedBox(width: AppSpacing.small),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
