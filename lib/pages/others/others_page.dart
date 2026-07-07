import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';
import '../../constants/app_strings.dart';
import '../../shared/widgets/empty_state_view.dart';
import '../../shared/widgets/error_state_view.dart';
import '../../shared/widgets/loading_state_view.dart';
import '../../state/async_view_state.dart';
import '../chat/chat_page.dart';
import 'others_controller.dart';
import 'widgets/daily_stats_panel.dart';
import 'widgets/person_status_rail.dart';

class OthersPage extends StatefulWidget {
  const OthersPage({super.key});

  @override
  State<OthersPage> createState() => _OthersPageState();
}

class _OthersPageState extends State<OthersPage> {
  late final OthersController _controller;

  @override
  void initState() {
    super.initState();
    _controller = OthersController()..load();
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
            return EmptyStateView(
              message: AppStrings.addPersonMessage,
              action: FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text(AppStrings.addPerson),
              ),
            );
          case AsyncStatus.error:
            return ErrorStateView(
              message: state.errorMessage ?? AppStrings.genericError,
              onRetry: _controller.load,
            );
          case AsyncStatus.success:
            return Column(
              children: <Widget>[
                // ── Others' status, WhatsApp-status-style rail ────────────
                const SizedBox(height: AppSpacing.small),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.large),
                  child: Row(
                    children: <Widget>[
                      Text(
                        'STATUS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.small),
                SizedBox(
                  height: 92,
                  child: PersonStatusRail(people: state.people),
                ),
                const SizedBox(height: AppSpacing.small),
                const Divider(height: 1, color: AppColors.outline),

                // ── Your own detailed log, stats, and tips ─────────────────
                Expanded(
                  child: DailyStatsPanel(
                    onOpenCoach: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const ChatPage()),
                    ),
                  ),
                ),
              ],
            );
        }
      },
    );
  }
}
