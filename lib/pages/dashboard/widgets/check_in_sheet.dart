import 'package:flutter/material.dart';

import '../../../constants/app_spacing.dart';
import '../../../engine/energy_score_engine.dart';
import '../../../models/energy_check_in.dart';

class CheckInSheet extends StatefulWidget {
  const CheckInSheet({super.key, required this.onSubmit});

  final Future<void> Function(EnergyCheckIn checkIn) onSubmit;

  @override
  State<CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<CheckInSheet> {
  final TextEditingController _notesController = TextEditingController();

  int _age = 28;
  double _sleepHours = 8.0;
  double _sleepQuality = 0.7;
  String _activityId = EnergyScoreEngine.activities.first.id;
  double _durationMinutes = 60;
  double _stressLevel = 0.3;
  double _illnessOrPain = 0.0;
  double _heatExposure = 0.0;
  double _fitnessLevel = 0.5;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final checkIn = EnergyCheckIn(
      age: _age,
      sleepHours: _sleepHours,
      sleepQuality: _sleepQuality,
      activityId: _activityId,
      durationMinutes: _durationMinutes.round(),
      stressLevel: _stressLevel,
      illnessOrPain: _illnessOrPain,
      heatExposure: _heatExposure,
      fitnessLevel: _fitnessLevel,
      notes: _notesController.text.trim(),
    );

    Navigator.of(context).pop();
    await widget.onSubmit(checkIn);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xLarge,
        0,
        AppSpacing.xLarge,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.xLarge,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Update your energy',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            'Answer a few quick signals. Batterie will estimate your physical and brain readiness without needing API credits.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: AppSpacing.large),
          Wrap(
            spacing: AppSpacing.small,
            runSpacing: AppSpacing.small,
            children: <Widget>[
              ActionChip(
                label: const Text('Rested focus'),
                onPressed: () => _applyPreset(_CheckInPreset.restedFocus),
              ),
              ActionChip(
                label: const Text('Bad sleep'),
                onPressed: () => _applyPreset(_CheckInPreset.badSleep),
              ),
              ActionChip(
                label: const Text('Workout'),
                onPressed: () => _applyPreset(_CheckInPreset.workout),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.large),
          _NumberSlider(
            label: 'Age',
            valueLabel: '$_age',
            value: _age.toDouble(),
            min: 13,
            max: 80,
            divisions: 67,
            onChanged: (value) => setState(() => _age = value.round()),
          ),
          _NumberSlider(
            label: 'Sleep last night',
            valueLabel: '${_sleepHours.toStringAsFixed(1)} h',
            value: _sleepHours,
            min: 3,
            max: 10,
            divisions: 14,
            onChanged: (value) => setState(() => _sleepHours = value),
          ),
          _NumberSlider(
            label: 'Sleep quality',
            valueLabel: _percentLabel(_sleepQuality),
            value: _sleepQuality,
            onChanged: (value) => setState(() => _sleepQuality = value),
          ),
          const SizedBox(height: AppSpacing.small),
          DropdownButtonFormField<String>(
            value: _activityId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'What have you mostly been doing?',
              border: OutlineInputBorder(),
            ),
            items: EnergyScoreEngine.activities
                .map(
                  (activity) => DropdownMenuItem<String>(
                    value: activity.id,
                    child: Text(activity.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _activityId = value);
            },
          ),
          const SizedBox(height: AppSpacing.medium),
          _NumberSlider(
            label: 'Activity duration',
            valueLabel: '${_durationMinutes.round()} min',
            value: _durationMinutes,
            min: 10,
            max: 240,
            divisions: 23,
            onChanged: (value) => setState(() => _durationMinutes = value),
          ),
          _NumberSlider(
            label: 'Stress right now',
            valueLabel: _percentLabel(_stressLevel),
            value: _stressLevel,
            onChanged: (value) => setState(() => _stressLevel = value),
          ),
          _NumberSlider(
            label: 'Illness or pain',
            valueLabel: _percentLabel(_illnessOrPain),
            value: _illnessOrPain,
            onChanged: (value) => setState(() => _illnessOrPain = value),
          ),
          _NumberSlider(
            label: 'Heat exposure',
            valueLabel: _percentLabel(_heatExposure),
            value: _heatExposure,
            onChanged: (value) => setState(() => _heatExposure = value),
          ),
          _NumberSlider(
            label: 'Fitness baseline',
            valueLabel: _percentLabel(_fitnessLevel),
            value: _fitnessLevel,
            onChanged: (value) => setState(() => _fitnessLevel = value),
          ),
          const SizedBox(height: AppSpacing.small),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Anything else?',
              hintText: 'e.g. headache, motivated, caffeine, heavy meal...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.large),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Update energy levels'),
          ),
        ],
      ),
    );
  }

  void _applyPreset(_CheckInPreset preset) {
    setState(() {
      switch (preset) {
        case _CheckInPreset.restedFocus:
          _sleepHours = 7.5;
          _sleepQuality = 0.85;
          _activityId = 'focused_coding';
          _durationMinutes = 60;
          _stressLevel = 0.25;
          _illnessOrPain = 0;
          _heatExposure = 0;
          _fitnessLevel = 0.55;
          _notesController.text = 'Feeling rested and ready to focus.';
        case _CheckInPreset.badSleep:
          _sleepHours = 5.5;
          _sleepQuality = 0.35;
          _activityId = 'email_and_message_backlog';
          _durationMinutes = 60;
          _stressLevel = 0.65;
          _illnessOrPain = 0.15;
          _heatExposure = 0;
          _fitnessLevel = 0.45;
          _notesController.text =
              'Tired after poor sleep and lower motivation.';
        case _CheckInPreset.workout:
          _sleepHours = 7;
          _sleepQuality = 0.7;
          _activityId = 'hiit_workout';
          _durationMinutes = 30;
          _stressLevel = 0.25;
          _illnessOrPain = 0;
          _heatExposure = 0.2;
          _fitnessLevel = 0.65;
          _notesController.text =
              'Worked out and feel alert, but physically spent.';
      }
    });
  }

  String _percentLabel(double value) => '${(value * 100).round()}%';
}

class _NumberSlider extends StatelessWidget {
  const _NumberSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions = 10,
  });

  final String label;
  final String valueLabel;
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final int divisions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Text(
                valueLabel,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

enum _CheckInPreset {
  restedFocus,
  badSleep,
  workout,
}
