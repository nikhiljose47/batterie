import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../energy_outcome.dart';

/// Thin outlook strip above the batteries — one line telling the user how
/// their planned day is predicted to go, with a button to (re)plan it.
class EnergyOutcomeCard extends StatelessWidget {
  const EnergyOutcomeCard({
    super.key,
    required this.outcome,
    required this.onPlanDay,
  });

  final EnergyOutcome outcome;
  final VoidCallback onPlanDay;

  Color get _bg => switch (outcome.tone) {
        EnergyOutcomeTone.great => AppColors.energyBrainBg,
        EnergyOutcomeTone.ok => const Color(0xFFFFF3DC),
        EnergyOutcomeTone.low => const Color(0xFFFFEBEE),
        EnergyOutcomeTone.empty => AppColors.surfaceTint,
      };

  Color get _fg => switch (outcome.tone) {
        EnergyOutcomeTone.great => AppColors.energyBrainAccent,
        EnergyOutcomeTone.ok => const Color(0xFFB8860B),
        EnergyOutcomeTone.low => AppColors.error,
        EnergyOutcomeTone.empty => AppColors.textMuted,
      };

  IconData get _icon => switch (outcome.tone) {
        EnergyOutcomeTone.great => Icons.bolt_rounded,
        EnergyOutcomeTone.ok => Icons.trending_down_rounded,
        EnergyOutcomeTone.low => Icons.warning_amber_rounded,
        EnergyOutcomeTone.empty => Icons.event_note_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPlanDay,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: <Widget>[
              Icon(_icon, size: 16, color: _fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  outcome.headline,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _fg,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Plan day',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _fg,
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 16, color: _fg),
            ],
          ),
        ),
      ),
    );
  }
}
