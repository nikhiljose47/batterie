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

            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.large,
                    AppSpacing.large,
                    AppSpacing.large,
                    AppSpacing.xLarge,
                  ),
                  child: DecoratedBox(
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
                );
              },
            );
        }
      },
    );
  }
}
