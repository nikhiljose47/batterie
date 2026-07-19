// ═════════════════════════════════════════════════════════════════════════
//                  Home tab planner — content data source
// ═════════════════════════════════════════════════════════════════════════
//
// Everything the planner shows lives in this file. To edit content you only
// touch the const blocks below — the widgets never need to change.
//
// Time model (8 hours of sleep):
//   • Wake  06:00  → begin the day
//   • Sleep 22:00  → 10 PM until 6 AM = 8 h of sleep
//
// How the planner reads this file:
//   1. It renders the wake card (see `wakeCardContent`) at the very top.
//   2. Then, one card per entry in `plannerSlots`, using the per-mode text
//      from the map for the currently selected mode.
//   3. Then the sleep card (see `sleepCardContent`) at the very bottom.
//
// ─── How to edit ─────────────────────────────────────────────────────────
//
//  • Tweak an existing (mode, slot) line:
//       Jump to the mode's const list (e.g. `_normal`), find the slot by
//       its `// 09–11` header, edit the fields.
//
//  • Add a new mode:
//       1. Copy `_normal` to a new const, e.g. `_studying`.
//       2. Rewrite each entry's text.
//       3. Add `'studying': _studying,` to `modeAdviceMap` at the bottom.
//       4. Add it to the mode dropdown in `home_tab_page.dart` (`_dayModes`).
//
//  • Add a new time slot:
//       1. Add a `TimeSlot(...)` entry to `plannerSlots`.
//       2. Append one `ModeAdvice(...)` to every mode's list — order must
//          match `plannerSlots`. Miss one and the analyzer will flag it
//          via a length mismatch when `debugAssertModeData()` runs.
//
//  • Adjust wake / sleep card copy: edit `wakeCardContent` / `sleepCardContent`.
//
// Nothing else in this file is worth touching by hand.

/// 6 AM — day starts.
const int homeDayWakeMinutes = 6 * 60;

/// 10 PM — day ends. 22 → 6 next morning = 8 h sleep.
const int homeDaySleepMinutes = 22 * 60;

/// A 1–2 hour window in the waking day.
class TimeSlot {
  const TimeSlot({required this.startHour, required this.endHour});

  final int startHour;
  final int endHour;

  bool contains(int minutes) =>
      minutes >= startHour * 60 && minutes < endHour * 60;

  String get rangeLabel {
    String h(int v) {
      final hr = v % 24;
      if (hr == 0) return '12 AM';
      if (hr == 12) return '12 PM';
      return hr < 12 ? '$hr AM' : '${hr - 12} PM';
    }

    return '${h(startHour)} – ${h(endHour)}';
  }
}

/// What we tell the user about a single (mode, slot) pair.
class ModeAdvice {
  const ModeAdvice({
    required this.recommendation,
    required this.attribution,
    required this.crowd,
    required this.tip,
    required this.history,
  });

  /// MacBook-keynote-style short phrase — rendered as the card's quote.
  final String recommendation;

  /// Sits under the recommendation as an author line
  /// (e.g. `— your athletic morning`).
  final String attribution;

  /// What most people are doing in this window.
  final String crowd;

  /// Energy-aware coaching tip for this window under this mode.
  final String tip;

  /// A world-history moment that happened around this time of day.
  final String history;
}

/// Special copy shown on the wake / sleep cards. These sit outside the
/// per-mode map because the wake–sleep frame is identical across modes;
/// if you ever want per-mode wake/sleep prose, swap the type here to
/// `Map<String, WakeSleepCopy>`.
class WakeSleepCopy {
  const WakeSleepCopy({
    required this.title,
    required this.headline,
    required this.sub,
    required this.tip,
  });

  final String title;
  final String headline;
  final String sub;
  final String tip;
}

const WakeSleepCopy wakeCardContent = WakeSleepCopy(
  title: '6:00 AM · Wake up',
  headline: 'Rise. Light on your face beats any coffee.',
  sub: 'Sunlight in the first 10 minutes anchors your day.',
  tip: '☀️ 10 min sun · 500 ml water · no phone',
);

const WakeSleepCopy sleepCardContent = WakeSleepCopy(
  title: '10:00 PM · Sleep',
  headline: 'Lights out. Tomorrow starts now.',
  sub: '8 hours — the version of you that shows up depends on this.',
  tip: '🌙 Cool room · no screens · same time daily',
);

// ═════════════════════════════════════════════════════════════════════════
//                              Time slots
// ═════════════════════════════════════════════════════════════════════════
//
// Order matters — every mode's advice list uses these indices.

const List<TimeSlot> plannerSlots = <TimeSlot>[
  TimeSlot(startHour: 9, endHour: 11),   // 0 · 09–11
  TimeSlot(startHour: 11, endHour: 13),  // 1 · 11–13
  TimeSlot(startHour: 13, endHour: 15),  // 2 · 13–15
  TimeSlot(startHour: 15, endHour: 17),  // 3 · 15–17
  TimeSlot(startHour: 17, endHour: 19),  // 4 · 17–19
  TimeSlot(startHour: 19, endHour: 21),  // 5 · 19–21
  TimeSlot(startHour: 21, endHour: 22),  // 6 · 21–22
];

// ═════════════════════════════════════════════════════════════════════════
//                              Mode: NORMAL
// ═════════════════════════════════════════════════════════════════════════

const List<ModeAdvice> _normal = <ModeAdvice>[
  // 09–11
  ModeAdvice(
    recommendation: 'Do the one thing you\'ve been avoiding.',
    attribution: '— your morning peak',
    crowd: '💼 Deep work',
    tip: '🧠 Peak focus — hardest task first',
    history: '1969 · Apollo 11 cruised to the Moon',
  ),
  // 11–13
  ModeAdvice(
    recommendation: 'Reply, decide, then step away for lunch.',
    attribution: '— your late morning',
    crowd: '🗣 Meetings & calls',
    tip: '🥤 Hydrate — focus dips before lunch',
    history: '1889 · Eiffel Tower opened to crowds',
  ),
  // 13–15
  ModeAdvice(
    recommendation: 'Eat slow. A 10-minute walk beats caffeine.',
    attribution: '— your post-lunch dip',
    crowd: '🍽 Lunch & social',
    tip: '😴 Post-lunch dip — 10 min walk fixes it',
    history: '1903 · Wright brothers planned first flight',
  ),
  // 15–17
  ModeAdvice(
    recommendation: 'Batch the small wins while the second wind lasts.',
    attribution: '— your afternoon',
    crowd: '💻 Focused work',
    tip: '☕ Second wind — batch small wins',
    history: '1876 · Bell placed the first phone call',
  ),
  // 17–19
  ModeAdvice(
    recommendation: 'Move your body. Sunlight while you can.',
    attribution: '— your evening',
    crowd: '🚶 Out & commuting',
    tip: '🏃 Body peak — best time to exercise',
    history: '1776 · Independence declared by evening',
  ),
  // 19–21
  ModeAdvice(
    recommendation: 'Real conversations only. Dim the screens.',
    attribution: '— your wind down',
    crowd: '📱 Social & family',
    tip: '📵 Dim the screens — let the brain land',
    history: '1969 · "One small step" — 8:17 PM',
  ),
  // 21–22
  ModeAdvice(
    recommendation: 'Plan tomorrow in one line. Then close the loop.',
    attribution: '— your bedtime',
    crowd: '🌙 Winding down',
    tip: '🌙 Prep tomorrow, then lights out',
    history: '1938 · War of the Worlds aired at night',
  ),
];

// ═════════════════════════════════════════════════════════════════════════
//                             Mode: ATHLETIC
// ═════════════════════════════════════════════════════════════════════════

const List<ModeAdvice> _athletic = <ModeAdvice>[
  // 09–11
  ModeAdvice(
    recommendation: 'Fuel first. Mobility, then your hardest session.',
    attribution: '— your athletic morning',
    crowd: '🥣 Fuel & mobility',
    tip: '🍳 Protein + carbs before you push',
    history: '1896 · First modern Olympics opened in Athens',
  ),
  // 11–13
  ModeAdvice(
    recommendation: 'Push through the peak. Don\'t save it for later.',
    attribution: '— your athletic prime',
    crowd: '🏋️ Peak training',
    tip: '⚡ VO2 max window — hit intervals now',
    history: '1954 · Bannister ran the 4-min mile at 6 PM',
  ),
  // 13–15
  ModeAdvice(
    recommendation: 'Refuel, then rest. Recovery is training too.',
    attribution: '— your recovery',
    crowd: '🍚 Refuel',
    tip: '🥛 Protein window — eat within 45 min',
    history: '1936 · Jesse Owens ran his 4th gold',
  ),
  // 15–17
  ModeAdvice(
    recommendation: 'Skills, not intensity. Sharpen the movement.',
    attribution: '— your technique block',
    crowd: '🎯 Skill drills',
    tip: '🧠 Learning peak — practice fine motor',
    history: '1968 · Fosbury Flop debuted in Mexico',
  ),
  // 17–19
  ModeAdvice(
    recommendation: 'Second session, lighter load. Move for joy.',
    attribution: '— your second wind',
    crowd: '🚴 Easy cardio',
    tip: '🏃 Body temp peak — run feels effortless',
    history: '1954 · Diane Leather broke 5-min mile',
  ),
  // 19–21
  ModeAdvice(
    recommendation: 'Cool it down. Long stretch, quiet meal.',
    attribution: '— your cooldown',
    crowd: '🧘 Stretch & eat',
    tip: '🧘 Parasympathetic on — foam roll now',
    history: '1968 · Beamon\'s long jump: 8.90 m',
  ),
  // 21–22
  ModeAdvice(
    recommendation: 'Prep tomorrow\'s kit. Sleep is your best supplement.',
    attribution: '— your recovery block',
    crowd: '😴 Sleep prep',
    tip: '💤 GH surge in deep sleep — protect it',
    history: '1980 · Miracle on Ice ended near 10 PM',
  ),
];

// ═════════════════════════════════════════════════════════════════════════
//                               Mode: GYM
// ═════════════════════════════════════════════════════════════════════════

const List<ModeAdvice> _gym = <ModeAdvice>[
  // 09–11
  ModeAdvice(
    recommendation: 'Warm up properly. Your joints will thank you at 60.',
    attribution: '— your gym morning',
    crowd: '🔥 Warm-up',
    tip: '🩸 Circulate first — dynamic stretch',
    history: '1893 · First bodybuilding show, London',
  ),
  // 11–13
  ModeAdvice(
    recommendation: 'Heavy compounds. Squat, press, pull — earn it.',
    attribution: '— your lift block',
    crowd: '🏋️ Heavy sets',
    tip: '💪 Strength peak — go for PRs',
    history: '1972 · Alexeev cleaned 230 kg',
  ),
  // 13–15
  ModeAdvice(
    recommendation: 'Refuel with real food. Rest between sessions.',
    attribution: '— your gym recovery',
    crowd: '🍗 Refuel',
    tip: '🥩 40g protein — muscle repair window',
    history: '1977 · "Pumping Iron" hit theaters',
  ),
  // 15–17
  ModeAdvice(
    recommendation: 'Accessories, isolation. Chase the pump, not the ego.',
    attribution: '— your volume block',
    crowd: '💪 Hypertrophy',
    tip: '📈 Volume window — 8-12 rep range',
    history: '1968 · Arnold\'s first Mr. Olympia',
  ),
  // 17–19
  ModeAdvice(
    recommendation: 'Conditioning. Sled, sprint, or 20 min zone 2.',
    attribution: '— your metcon',
    crowd: '🔥 Conditioning',
    tip: '❤️ Cardio + strength = longevity',
    history: '2001 · CrossFit went online',
  ),
  // 19–21
  ModeAdvice(
    recommendation: 'Stretch the tight spots. Log the session.',
    attribution: '— your cooldown',
    crowd: '📓 Log & stretch',
    tip: '📉 Cortisol dropping — mobility now',
    history: '1965 · Gold\'s Gym opened in Venice',
  ),
  // 21–22
  ModeAdvice(
    recommendation: 'Casein, foam roll, lights out. Grow while you sleep.',
    attribution: '— your night lift',
    crowd: '😴 Recovery',
    tip: '💤 Testosterone rises in deep sleep',
    history: '1930 · Steve Reeves born',
  ),
];

// ═════════════════════════════════════════════════════════════════════════
//                              Mode: OFFICE
// ═════════════════════════════════════════════════════════════════════════

const List<ModeAdvice> _office = <ModeAdvice>[
  // 09–11
  ModeAdvice(
    recommendation: 'Close your inbox. One deep-work block, no meetings.',
    attribution: '— your office morning',
    crowd: '💻 Deep work',
    tip: '🧠 Prefrontal peak — hardest task now',
    history: '1985 · Excel 1.0 shipped for Mac',
  ),
  // 11–13
  ModeAdvice(
    recommendation: 'Batch the meetings. Stand up between calls.',
    attribution: '— your meeting block',
    crowd: '🗣 Meetings',
    tip: '🚶 Move 2 min between calls',
    history: '1990 · Web servers went live at CERN',
  ),
  // 13–15
  ModeAdvice(
    recommendation: 'Walk to lunch. Screens off, actual food.',
    attribution: '— your break',
    crowd: '🍱 Lunch',
    tip: '☀️ 10 min sunlight = sharper 3 PM',
    history: '1876 · First typewriter shipped',
  ),
  // 15–17
  ModeAdvice(
    recommendation: 'Reply, review, ship. Small closures build momentum.',
    attribution: '— your afternoon',
    crowd: '📧 Reply & review',
    tip: '☕ Second focus wave — batch replies',
    history: '1969 · ARPANET first packet at 10:30 PM',
  ),
  // 17–19
  ModeAdvice(
    recommendation: 'Shut it down cleanly. Write tomorrow\'s top three.',
    attribution: '— your close-out',
    crowd: '📝 Wrap up',
    tip: '🧾 Log wins — future you will read them',
    history: '1985 · First .com registered',
  ),
  // 19–21
  ModeAdvice(
    recommendation: 'Off screens. Family, walks, or a real book.',
    attribution: '— your unplug',
    crowd: '📱 Family time',
    tip: '📵 Screens dim mind — real light in',
    history: '1928 · First TV broadcast (WGY)',
  ),
  // 21–22
  ModeAdvice(
    recommendation: 'No inbox. No Slack. Set tomorrow\'s intent.',
    attribution: '— your close',
    crowd: '🌙 Wind down',
    tip: '🌙 Blue light off — melatonin rises',
    history: '1997 · Deep Blue beat Kasparov',
  ),
];

// ═════════════════════════════════════════════════════════════════════════
//                           Mode: NICOTINE FREE
// ═════════════════════════════════════════════════════════════════════════

const List<ModeAdvice> _nicotineFree = <ModeAdvice>[
  // 09–11
  ModeAdvice(
    recommendation: 'Cold water on your face. Breathe. Urge peaks in 3 min.',
    attribution: '— your quit morning',
    crowd: '🌊 Cravings peak',
    tip: '💨 Box breathe 4-4-4-4 through cravings',
    history: '1964 · Surgeon General linked smoking to cancer',
  ),
  // 11–13
  ModeAdvice(
    recommendation: 'Chew ice, sip water, walk. Ride the wave.',
    attribution: '— your late morning',
    crowd: '🥤 Hydrate hard',
    tip: '🧊 Chew ice — replaces the hand ritual',
    history: '1971 · Cigarette ads banned on US TV',
  ),
  // 13–15
  ModeAdvice(
    recommendation: 'Eat real food. Sugar spikes make cravings worse.',
    attribution: '— your lunch',
    crowd: '🍎 Fresh food',
    tip: '🍏 Fiber + protein — steady glucose',
    history: '2003 · Ireland went smoke-free',
  ),
  // 15–17
  ModeAdvice(
    recommendation: 'Walk after coffee. Break the old chain.',
    attribution: '— your afternoon',
    crowd: '🚶 New rituals',
    tip: '🚶 Replace smoke break with 5 min walk',
    history: '2007 · UK indoor smoking ban',
  ),
  // 17–19
  ModeAdvice(
    recommendation: 'Move. Sweat clears the receptors faster.',
    attribution: '— your evening',
    crowd: '🏃 Sweat it out',
    tip: '🏃 20 min cardio — dopamine reset',
    history: '1998 · US Tobacco Settlement Agreement',
  ),
  // 19–21
  ModeAdvice(
    recommendation: 'Change the scene. Not the couch, not the porch.',
    attribution: '— your trigger hour',
    crowd: '🏡 Reset the space',
    tip: '🪟 Fresh air — 10 min outside',
    history: '2019 · India banned e-cigs',
  ),
  // 21–22
  ModeAdvice(
    recommendation: 'Sleep early — cravings fall with rest.',
    attribution: '— your recovery',
    crowd: '😴 Rest deep',
    tip: '💤 Sleep = strongest craving defense',
    history: '2008 · US raised tobacco tax by \$0.61',
  ),
];

// ═════════════════════════════════════════════════════════════════════════
//                       Register all modes here
// ═════════════════════════════════════════════════════════════════════════
//
// One line per mode. Keys must match the mode ids in `home_tab_page.dart`'s
// `_dayModes` list. Add a mode → add one line. Remove a mode → remove one.

const Map<String, List<ModeAdvice>> modeAdviceMap =
    <String, List<ModeAdvice>>{
  'normal': _normal,
  'athletic': _athletic,
  'gym': _gym,
  'office': _office,
  'nicotine_free': _nicotineFree,
};

/// Safe lookup: falls back to 'normal' if a mode id has no curated data
/// yet, so a new dropdown entry can never crash the planner.
List<ModeAdvice> adviceForMode(String modeId) {
  return modeAdviceMap[modeId] ?? modeAdviceMap['normal']!;
}

/// Optional runtime sanity check — call from `main.dart` during dev to
/// catch a mode list that got out of sync with `plannerSlots`.
bool debugAssertModeData() {
  final expected = plannerSlots.length;
  for (final entry in modeAdviceMap.entries) {
    assert(
      entry.value.length == expected,
      'Mode "${entry.key}" has ${entry.value.length} entries, '
      'expected $expected (one per slot in plannerSlots).',
    );
  }
  return true;
}
