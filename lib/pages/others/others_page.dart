import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
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
  const OthersPage({super.key, this.refreshToken = 0});

  final int refreshToken;

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
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, auth) {
        final signedIn = auth.data != null;
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
                      padding:
                          EdgeInsets.symmetric(horizontal: AppSpacing.large),
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
                      height: signedIn ? 92 : 116,
                      child: signedIn
                          ? PersonStatusRail(people: state.people)
                          : const _LockedStatusRail(),
                    ),
                    const SizedBox(height: AppSpacing.small),
                    const Divider(height: 1, color: AppColors.outline),

                    // ── Your own detailed log, stats, and tips ─────────────────
                    Expanded(
                      child: DailyStatsPanel(
                        refreshToken: widget.refreshToken,
                        onOpenCoach: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const ChatPage()),
                        ),
                      ),
                    ),
                  ],
                );
            }
          },
        );
      },
    );
  }
}

class _LockedStatusRail extends StatelessWidget {
  const _LockedStatusRail();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.medium),
      itemBuilder: (context, index) {
        if (index == 0) {
          return const _StatusSignInCard();
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: 72,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.surface.withOpacity(0.46),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.outline.withOpacity(0.28)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.onSurface.withOpacity(0.08),
                      border: Border.all(
                        color: colors.primary.withOpacity(0.25),
                        width: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 42,
                    height: 7,
                    decoration: BoxDecoration(
                      color: colors.onSurface.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusSignInCard extends StatelessWidget {
  const _StatusSignInCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 210,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.76),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outline.withOpacity(0.34)),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 20,
            backgroundColor: colors.primary.withOpacity(0.12),
            child: Icon(
              Icons.lock_outline_rounded,
              size: 19,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppStrings.statusLockedTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.statusLockedMessage,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface.withOpacity(0.58),
                    fontSize: 10,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
