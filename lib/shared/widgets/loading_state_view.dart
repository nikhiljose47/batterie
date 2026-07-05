import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../constants/app_strings.dart';

class LoadingStateView extends StatelessWidget {
  const LoadingStateView({
    super.key,
    this.message = AppStrings.loadingMessage,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.large),
          Text(message),
        ],
      ),
    );
  }
}
