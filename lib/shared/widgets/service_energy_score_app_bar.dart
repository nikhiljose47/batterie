import 'package:flutter/material.dart';

import '../../services/daily_progress_sync_service.dart';
import 'energy_score_pill.dart';

class ServiceEnergyScoreAppBar extends StatefulWidget
    implements PreferredSizeWidget {
  const ServiceEnergyScoreAppBar({
    super.key,
    required this.title,
    this.refreshToken = 0,
  });

  final String title;
  final int refreshToken;

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  State<ServiceEnergyScoreAppBar> createState() =>
      _ServiceEnergyScoreAppBarState();
}

class _ServiceEnergyScoreAppBarState extends State<ServiceEnergyScoreAppBar> {
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _loadScore();
  }

  @override
  void didUpdateWidget(covariant ServiceEnergyScoreAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadScore();
    }
  }

  Future<void> _loadScore() async {
    final record = await DailyProgressSyncService.instance.todayRecord();
    if (!mounted) return;
    setState(() => _score = record?.scorePercent ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 44,
      scrolledUnderElevation: 0,
      title: Text(
        widget.title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      actions: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Center(child: EnergyScorePill(score: _score, compact: true)),
        ),
      ],
    );
  }
}
