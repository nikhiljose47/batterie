import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import 'toolkit.dart';

/// Mental Health — a daily wellbeing check-in (1–10) with history,
/// a coping-technique toolkit, and helplines.
class MentalHealthPage extends StatefulWidget {
  const MentalHealthPage({super.key});

  @override
  State<MentalHealthPage> createState() => _MentalHealthPageState();
}

class _MentalHealthPageState extends State<MentalHealthPage> {
  static const String key = 'svc.mental.checkins';

  Map<String, dynamic> _checkins = <String, dynamic>{};
  double _slider = 5;
  bool _loaded = false;

  static const List<(String, String)> _techniques = <(String, String)>[
    (
      '🖐️ 5-4-3-2-1 grounding',
      'Name 5 things you see, 4 you can touch, 3 you hear, 2 you '
          'smell, 1 you taste. Pulls a racing mind back to the room.'
    ),
    (
      '🌬️ Longer exhale',
      'Breathe in for 4, out for 6-8. A longer exhale activates the '
          'calm branch of your nervous system. (Breathing Exercises '
          'service has a guided version.)'
    ),
    (
      '📝 Brain dump',
      'Set a 5-minute timer and write everything worrying you, '
          'unfiltered. Worries on paper take less RAM in your head.'
    ),
    (
      '🚶 10-minute walk',
      'Movement + change of scenery is one of the most reliable '
          'quick mood shifts there is. No pace requirement.'
    ),
    (
      '☎️ Say it out loud',
      'Text or call one person you trust. Saying "today is rough" '
          'out loud is already treatment, not weakness.'
    ),
  ];

  @override
  void initState() {
    super.initState();
    ServiceStore.loadMap(key).then((map) {
      if (!mounted) return;
      setState(() {
        _checkins = map;
        final today = (map[svcDay(DateTime.now())] as num?)?.toDouble();
        if (today != null) _slider = today;
        _loaded = true;
      });
    });
  }

  Future<void> _saveCheckin() async {
    setState(() => _checkins[svcDay(DateTime.now())] = _slider);
    await ServiceStore.saveMap(key, _checkins);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Check-in saved 💙'),
          duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasToday = _checkins.containsKey(svcDay(DateTime.now()));

    return Scaffold(
      appBar: svcAppBar('🫶 Mental Health'),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.large),
              children: <Widget>[
                // Check-in
                WhiteCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        hasToday
                            ? 'Today\'s check-in (update anytime)'
                            : 'How are you, really? (1 = rough, 10 = great)',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 9),
                              ),
                              child: Slider(
                                value: _slider,
                                min: 1,
                                max: 10,
                                divisions: 9,
                                activeColor: AppColors.primary,
                                inactiveColor: AppColors.surfaceTint,
                                onChanged: (v) =>
                                    setState(() => _slider = v),
                              ),
                            ),
                          ),
                          Text('${_slider.round()}',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary)),
                        ],
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: FilledButton(
                          onPressed: _saveCheckin,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(hasToday ? 'Update' : 'Check in',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // 14-day mini history
                if (_checkins.isNotEmpty) ...<Widget>[
                  const SectionLabel('Last 2 weeks'),
                  WhiteCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        for (var back = 13; back >= 0; back--)
                          Builder(builder: (context) {
                            final day = DateTime.now()
                                .subtract(Duration(days: back));
                            final v = (_checkins[svcDay(day)] as num?)
                                ?.toDouble();
                            return Container(
                              width: 14,
                              height: 8 + (v ?? 0) * 4.4,
                              decoration: BoxDecoration(
                                color: v == null
                                    ? AppColors.surfaceTint
                                    : v >= 7
                                        ? const Color(0xFF2E7D32)
                                            .withValues(alpha: 0.75)
                                        : v >= 4
                                            ? const Color(0xFFF9A825)
                                                .withValues(alpha: 0.8)
                                            : const Color(0xFFC62828)
                                                .withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],

                const SectionLabel('When it\'s heavy — toolkit'),
                for (final (title, body) in _techniques)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: WhiteCard(
                      padding: EdgeInsets.zero,
                      child: Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                              horizontal: 14),
                          title: Text(title,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700)),
                          children: <Widget>[
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 0, 14, 12),
                              child: Text(body,
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      height: 1.5,
                                      color: AppColors.textMuted)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                const SectionLabel('Talk to someone'),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE7F6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color:
                            const Color(0xFF5E35B1).withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    '🧠 Tele-MANAS (govt, free, 24×7): 14416\n'
                    '☎️ iCall: 9152987821 (Mon–Sat, 10am–8pm)\n'
                    '🚨 Any emergency: 112\n\n'
                    'If things feel unsafe right now, please reach a '
                    'helpline or someone near you — this app is a '
                    'companion, not a substitute for care.',
                    style: TextStyle(fontSize: 11.5, height: 1.6),
                  ),
                ),
              ],
            ),
    );
  }
}
