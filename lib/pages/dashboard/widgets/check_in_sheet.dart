import 'package:flutter/material.dart';

import '../../../constants/app_spacing.dart';

class CheckInSheet extends StatefulWidget {
  const CheckInSheet({super.key, required this.onSubmit});

  final Future<void> Function(String input) onSubmit;

  @override
  State<CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<CheckInSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty) return;
    final input = _controller.text;
    Navigator.of(context).pop();
    await widget.onSubmit(input);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            'How are you feeling right now?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            'Describe your sleep, energy, mood, or anything on your mind. The AI will assess your physical and brain energy levels.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: AppSpacing.large),
          ..._prompts.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.small),
              child: ActionChip(
                label: Text(p, style: const TextStyle(fontSize: 12)),
                onPressed: () {
                  _controller.text = p;
                  _controller.selection = TextSelection.collapsed(
                    offset: _controller.text.length,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          TextField(
            controller: _controller,
            maxLines: 4,
            autofocus: true,
            decoration: const InputDecoration(
              hintText:
                  'e.g. Slept 6 hours, feeling a bit groggy but motivated...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.large),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Analyse my energy'),
          ),
        ],
      ),
    );
  }

  static const List<String> _prompts = <String>[
    'Slept 7 hours, feel well rested and focused',
    'Tired after bad sleep, low motivation today',
    'High energy, worked out this morning',
  ];
}
