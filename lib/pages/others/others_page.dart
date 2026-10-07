import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';
import '../../constants/app_strings.dart';
import '../../models/person_status.dart';
import '../../shared/widgets/empty_state_view.dart';
import '../../shared/widgets/error_state_view.dart';
import '../../shared/widgets/loading_state_view.dart';
import '../../state/async_view_state.dart';
import '../chat/chat_page.dart';
import 'others_controller.dart';
import 'widgets/daily_stats_panel.dart';

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
                    const SizedBox(height: AppSpacing.small),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.large,
                      ),
                      child: signedIn
                          ? _StatusLeaderboard(people: state.people)
                          : const _LockedLeaderboard(),
                    ),
                    const SizedBox(height: AppSpacing.small),
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

class _StatusLeaderboard extends StatelessWidget {
  const _StatusLeaderboard({required this.people});

  final List<PersonStatus> people;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final leaders = people.take(20).toList(growable: false);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withOpacity(0.18)),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.military_tech_rounded,
                  size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Rank board',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${leaders.length} users',
                style: TextStyle(
                  color: colors.onSurface.withOpacity(0.48),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < leaders.length; i++) ...<Widget>[
            _LeaderboardRow(rank: i + 1, person: leaders[i]),
            if (i != leaders.length - 1)
              Divider(
                height: 10,
                color: colors.outline.withOpacity(0.1),
              ),
          ],
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.rank, required this.person});

  final int rank;
  final PersonStatus person;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final score = person.scorePercent ?? (person.energyPercent * 100).round();
    final accent = rank == 1
        ? const Color(0xFFE0A224)
        : rank == 2
            ? AppColors.primary
            : AppColors.success;
    return Row(
      children: <Widget>[
        SizedBox(
          width: 27,
          child: Text(
            '#$rank',
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        CircleAvatar(
          radius: 15,
          backgroundColor: accent.withOpacity(0.13),
          child: Text(
            person.name.trim().isEmpty
                ? 'U'
                : person.name.trim().substring(0, 1).toUpperCase(),
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                person.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Goal ${person.goalDoneCount ?? 0}/${person.goalTotalCount ?? 0} · App ${person.appUseMinutes ?? 0}m · Focus ${person.focusMinutes ?? 0}m',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurface.withOpacity(0.48),
                  fontSize: 9.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$score',
            style: TextStyle(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _LockedLeaderboard extends StatelessWidget {
  const _LockedLeaderboard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withOpacity(0.22)),
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
                  maxLines: 1,
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
