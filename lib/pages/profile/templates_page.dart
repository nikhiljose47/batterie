import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/widgets/day_planner_sheet.dart';

class TemplatesPage extends StatelessWidget {
  const TemplatesPage({
    super.key,
    required this.controller,
  });

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(title: const Text('Templates')),
      body: DayPlannerSheet(
        controller: controller,
        asPage: true,
      ),
    );
  }
}
