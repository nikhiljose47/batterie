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
import 'widgets/person_status_card.dart';

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
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.large),
              itemCount: state.people.length + 1,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.medium),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              AppStrings.othersTitle,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text(AppStrings.addPerson),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      _AiChatBanner(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ChatPage(),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return PersonStatusCard(person: state.people[index - 1]);
              },
            );
        }
      },
    );
  }
}

class _AiChatBanner extends StatelessWidget {
  const _AiChatBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.large),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[AppColors.primary, Color(0xFF7B88FF)],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        ),
        child: Row(
          children: <Widget>[
            const CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white24,
              child: Icon(Icons.bolt, color: Colors.white),
            ),
            const SizedBox(width: AppSpacing.medium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'AI Energy Coach',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Chat about sleep, focus, recovery, and more.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
