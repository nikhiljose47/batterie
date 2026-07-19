import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import 'toolkit.dart';

/// Timestamped-entry log template. One page powers Notes, Journal,
/// Symptom Tracker, Hobby Tracker, Mood Tracker and Screen Time —
/// each config decides which inputs show: tag chips, free text,
/// and/or a number field.
class QuickLogConfig {
  const QuickLogConfig({
    required this.id,
    required this.title,
    this.prompt,
    this.textHint,
    this.chips = const <String>[],
    this.chipRequired = false,
    this.numberLabel,
    this.numberUnit,
    this.emptyHint = 'Nothing logged yet.',
  });

  final String id;
  final String title;

  /// Optional banner above the input (journal prompt etc.).
  final String? prompt;

  /// null → no text field.
  final String? textHint;

  /// Quick tag chips ("🤕 Headache"…). Selected chip is saved with entry.
  final List<String> chips;
  final bool chipRequired;

  /// null → no number field. e.g. "Minutes".
  final String? numberLabel;
  final String? numberUnit;
  final String emptyHint;
}

const notesLogConfig = QuickLogConfig(
  id: 'notes',
  title: '📝 Notes',
  textHint: 'Write a quick note…',
  emptyHint: 'Your notes will appear here.',
);

const journalLogConfig = QuickLogConfig(
  id: 'journal',
  title: '📓 Journal',
  prompt: 'What made today good? What drained you?',
  textHint: 'Dear diary…',
  emptyHint: 'Your first entry is one thought away.',
);

const symptomLogConfig = QuickLogConfig(
  id: 'symptoms',
  title: '🤒 Symptom Tracker',
  chips: <String>[
    '🤕 Headache',
    '🤒 Fever',
    '🤧 Cold',
    '😖 Pain',
    '🤢 Nausea',
    '😮‍💨 Fatigue',
    '😵 Dizzy',
    '🫁 Cough',
  ],
  chipRequired: true,
  textHint: 'Details (optional) — where, how bad…',
  emptyHint: 'Log symptoms as they happen — patterns show up over time.',
);

const hobbyLogConfig = QuickLogConfig(
  id: 'hobby',
  title: '🎨 Hobby Tracker',
  chips: <String>[
    '🎸 Music',
    '🎨 Art',
    '📚 Reading',
    '🧵 Craft',
    '🎮 Gaming',
    '🌱 Garden',
    '📷 Photo',
    '🍳 Cooking',
  ],
  chipRequired: true,
  numberLabel: 'Minutes',
  numberUnit: 'min',
  emptyHint: 'Log time on what you love — see where your week goes.',
);

const moodLogConfig = QuickLogConfig(
  id: 'mood',
  title: '🙂 Mood Tracker',
  chips: <String>[
    '😞 Low',
    '😕 Meh',
    '🙂 Okay',
    '😀 Good',
    '🤩 Great'
  ],
  chipRequired: true,
  textHint: 'Why? (optional)',
  emptyHint: 'One tap a day builds your mood picture.',
);

const screenTimeLogConfig = QuickLogConfig(
  id: 'screen_time',
  title: '📱 Screen Time',
  prompt: 'Check Settings → Digital Wellbeing for the exact number, '
      'then log it here to track the trend.',
  numberLabel: 'Minutes on screen',
  numberUnit: 'min',
  emptyHint: 'Log daily minutes to see your trend.',
);

class QuickLogPage extends StatefulWidget {
  const QuickLogPage({super.key, required this.config});
  final QuickLogConfig config;

  @override
  State<QuickLogPage> createState() => _QuickLogPageState();
}

class _QuickLogPageState extends State<QuickLogPage> {
  List<Map<String, dynamic>> _entries = <Map<String, dynamic>>[];
  final TextEditingController _text = TextEditingController();
  final TextEditingController _number = TextEditingController();
  String? _chip;
  bool _loaded = false;

  String get _key => 'svc.${widget.config.id}.entries';

  @override
  void initState() {
    super.initState();
    ServiceStore.loadList(_key).then((list) {
      if (!mounted) return;
      setState(() {
        _entries = list;
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final c = widget.config;
    final text = _text.text.trim();
    final num = int.tryParse(_number.text.trim());
    if (c.chipRequired && _chip == null) return;
    if (c.textHint != null &&
        c.chips.isEmpty &&
        c.numberLabel == null &&
        text.isEmpty) {
      return;
    }
    if (c.numberLabel != null &&
        c.chips.isEmpty &&
        c.textHint == null &&
        num == null) {
      return;
    }
    setState(() {
      _entries.insert(0, <String, dynamic>{
        't': DateTime.now().toIso8601String(),
        if (text.isNotEmpty) 'text': text,
        if (_chip != null) 'tag': _chip,
        if (num != null) 'num': num,
      });
      _text.clear();
      _number.clear();
      _chip = null;
    });
    await ServiceStore.saveList(_key, _entries);
  }

  Future<void> _delete(int index) async {
    setState(() => _entries.removeAt(index));
    await ServiceStore.saveList(_key, _entries);
  }

  int get _todayNumberTotal {
    final today = svcDay(DateTime.now());
    var total = 0;
    for (final e in _entries) {
      final t = DateTime.tryParse(e['t'] as String? ?? '');
      if (t != null && svcDay(t) == today) {
        total += (e['num'] as num?)?.toInt() ?? 0;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;

    // Group entries by day for display.
    final groups = <String, List<(int, Map<String, dynamic>)>>{};
    for (var i = 0; i < _entries.length; i++) {
      final t = DateTime.tryParse(_entries[i]['t'] as String? ?? '');
      final key = t == null ? '?' : svcDay(t);
      groups.putIfAbsent(key, () => <(int, Map<String, dynamic>)>[]);
      groups[key]!.add((i, _entries[i]));
    }

    return Scaffold(
      appBar: svcAppBar(c.title),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: <Widget>[
                // ── Input area ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.large, AppSpacing.medium, AppSpacing.large, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (c.prompt != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceTint.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            c.prompt!,
                            style: const TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: AppColors.textMuted),
                          ),
                        ),
                      if (c.chips.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: <Widget>[
                            for (final chip in c.chips)
                              SvcChip(
                                label: chip,
                                selected: _chip == chip,
                                onTap: () => setState(
                                    () => _chip = _chip == chip ? null : chip),
                              ),
                          ],
                        ),
                      if (c.chips.isNotEmpty) const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          if (c.textHint != null)
                            Expanded(
                              flex: 3,
                              child: _input(_text, c.textHint!),
                            ),
                          if (c.textHint != null && c.numberLabel != null)
                            const SizedBox(width: 8),
                          if (c.numberLabel != null)
                            Expanded(
                              flex: 2,
                              child:
                                  _input(_number, c.numberLabel!, number: true),
                            ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _add,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 40,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.add_rounded,
                                  color: Colors.white, size: 22),
                            ),
                          ),
                        ],
                      ),
                      if (c.numberLabel != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Today: $_todayNumberTotal ${c.numberUnit ?? ''}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // ── Entries ────────────────────────────────────────────
                Expanded(
                  child: _entries.isEmpty
                      ? EmptyHint(c.emptyHint)
                      : ListView(
                          padding: const EdgeInsets.all(AppSpacing.large),
                          children: <Widget>[
                            for (final day in groups.keys) ...<Widget>[
                              SectionLabel(svcDayLabel(day)),
                              for (final (index, e) in groups[day]!)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: WhiteCard(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    child: Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Row(
                                                children: <Widget>[
                                                  if (e['tag'] != null)
                                                    Text(
                                                      e['tag'] as String,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  if (e['num'] != null) ...[
                                                    if (e['tag'] != null)
                                                      const SizedBox(width: 6),
                                                    Text(
                                                      '${e['num']} ${c.numberUnit ?? ''}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            AppColors.primary,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              if (e['text'] != null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 2),
                                                  child: Text(
                                                    e['text'] as String,
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        height: 1.35),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: <Widget>[
                                            Text(
                                              _clockOf(e),
                                              style: const TextStyle(
                                                  fontSize: 9,
                                                  color: AppColors.textMuted),
                                            ),
                                            InkWell(
                                              onTap: () => _delete(index),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(4),
                                                child: Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 15,
                                                  color: AppColors.textMuted
                                                      .withOpacity(0.6),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  String _clockOf(Map<String, dynamic> e) {
    final t = DateTime.tryParse(e['t'] as String? ?? '');
    return t == null ? '' : svcClock(t);
  }

  Widget _input(TextEditingController controller, String hint,
      {bool number = false}) {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: controller,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontSize: 12.5),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: TextStyle(
              fontSize: 11.5, color: AppColors.textMuted.withOpacity(0.8)),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.outline.withOpacity(0.9)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
          ),
        ),
      ),
    );
  }
}
