import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../constants/app_strings.dart';
import '../../shared/widgets/empty_state_view.dart';
import '../../shared/widgets/error_state_view.dart';
import '../../shared/widgets/loading_state_view.dart';
import '../../state/async_view_state.dart';
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
                  return Row(
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
