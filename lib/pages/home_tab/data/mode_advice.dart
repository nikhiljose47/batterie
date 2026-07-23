import '../../../services/sleep_schedule_store.dart';

// Short alias so the getters below read cleanly.
SleepScheduleStore get _scheduleStore => SleepScheduleStore.instance;

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

// ═════════════════════════════════════════════════════════════════════════
//                          Day-mode registry
// ═════════════════════════════════════════════════════════════════════════

class DayMode {
  const DayMode({
    required this.id,
    required this.emoji,
    required this.label,
    this.isPro = false,
  });

  final String id;
  final String emoji;
  final String label;

  /// Pro modes show a small PRO badge in the chip.
  final bool isPro;
}

/// Full ordered list of modes — base modes first, Student, then Pro variants.
/// Keys must match the `modeAdviceMap` entries at the bottom of this file.
const List<DayMode> allDayModes = <DayMode>[
  DayMode(id: 'normal',           emoji: '🙂', label: 'Normal'),
  DayMode(id: 'athletic',         emoji: '🏃', label: 'Athletic'),
  DayMode(id: 'gym',              emoji: '🏋️', label: 'Gym'),
  DayMode(id: 'office',           emoji: '💼', label: 'Office'),
  DayMode(id: 'nicotine_free',    emoji: '🚭', label: 'Nicotine Free'),
  DayMode(id: 'student',          emoji: '📚', label: 'Student'),
  DayMode(id: 'normal_pro',       emoji: '🙂', label: 'Normal Pro',       isPro: true),
  DayMode(id: 'athletic_pro',     emoji: '🏃', label: 'Athletic Pro',     isPro: true),
  DayMode(id: 'gym_pro',          emoji: '🏋️', label: 'Gym Pro',          isPro: true),
  DayMode(id: 'office_pro',       emoji: '💼', label: 'Office Pro',       isPro: true),
  DayMode(id: 'nicotine_free_pro',emoji: '🚭', label: 'Quit Pro',         isPro: true),
];

/// User's target wake time in minutes — driven by [SleepScheduleStore].
int get homeDayWakeMinutes => _scheduleStore.wakeMinutes;

/// User's target sleep time in minutes — driven by [SleepScheduleStore].
int get homeDaySleepMinutes => _scheduleStore.sleepMinutes;

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
  TimeSlot(startHour: 9, endHour: 11), // 0 · 09–11
  TimeSlot(startHour: 11, endHour: 13), // 1 · 11–13
  TimeSlot(startHour: 13, endHour: 15), // 2 · 13–15
  TimeSlot(startHour: 15, endHour: 17), // 3 · 15–17
  TimeSlot(startHour: 17, endHour: 19), // 4 · 17–19
  TimeSlot(startHour: 19, endHour: 21), // 5 · 19–21
  TimeSlot(startHour: 21, endHour: 22), // 6 · 21–22
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
//                             Mode: STUDENT
// ═════════════════════════════════════════════════════════════════════════

const List<ModeAdvice> _student = <ModeAdvice>[
  // 09–11
  ModeAdvice(
    recommendation: 'Hardest subject first. Your brain is sharpest right now.',
    attribution: '— your study peak',
    crowd: '📖 Deep focus',
    tip: '🧠 Peak retention — shut all notifications',
    history: '1687 · Newton wrote Principia in total isolation',
  ),
  // 11–13
  ModeAdvice(
    recommendation: 'Teach it back. If you can\'t explain it, you don\'t know it.',
    attribution: '— your recall block',
    crowd: '✏️ Active recall',
    tip: '✏️ Active recall beats re-reading 3× over',
    history: '1905 · Einstein wrote 4 landmark papers in one year',
  ),
  // 13–15
  ModeAdvice(
    recommendation: 'Eat, walk, skim. Don\'t study hard during the post-lunch dip.',
    attribution: '— your recharge',
    crowd: '🍱 Lunch break',
    tip: '😴 20-min nap now — memory consolidates in sleep',
    history: '1453 · Gutenberg\'s press cut the cost of study',
  ),
  // 15–17
  ModeAdvice(
    recommendation: 'New material or group work. Fresh eyes handle complex ideas.',
    attribution: '— your afternoon block',
    crowd: '👥 Group study',
    tip: '📊 Interleave subjects — fights the forgetting curve',
    history: '1636 · Harvard founded to push new learning forward',
  ),
  // 17–19
  ModeAdvice(
    recommendation: 'Move your body. A 20-minute walk doubles afternoon retention.',
    attribution: '— your brain break',
    crowd: '🚶 Decompressing',
    tip: '🏃 Exercise before revision = +20% next-day recall',
    history: '1768 · First Encyclopaedia Britannica published',
  ),
  // 19–21
  ModeAdvice(
    recommendation: 'Spaced repetition. Tonight\'s review is tomorrow\'s memory.',
    attribution: '— your revision hour',
    crowd: '🃏 Flashcards',
    tip: '🗂 Review: 1h later, 1 day, 1 week — that\'s the curve',
    history: '1885 · Ebbinghaus first mapped the forgetting curve',
  ),
  // 21–22
  ModeAdvice(
    recommendation: 'Write tomorrow\'s first task. Then close the books for good.',
    attribution: '— your study close',
    crowd: '🌙 Wrap up',
    tip: '📒 Sleep cements today\'s learning — protect it',
    history: '1956 · Miller published "The Magical Number 7"',
  ),
];

// ═════════════════════════════════════════════════════════════════════════
//                           Mode: NORMAL PRO
// ═════════════════════════════════════════════════════════════════════════

const List<ModeAdvice> _normalPro = <ModeAdvice>[
  // 09–11
  ModeAdvice(
    recommendation: 'Cortisol peaks at 9 AM. Use the stress hormone — don\'t fight it.',
    attribution: '— your neuroscience morning',
    crowd: '🔬 Peak cortisol',
    tip: '⏰ Delay caffeine 90 min post-wake for best effect',
    history: '1958 · NASA designed peak-performance daily schedules',
  ),
  // 11–13
  ModeAdvice(
    recommendation: 'Decision fatigue starts now. Clear shallow work, not your mind.',
    attribution: '— your mid-morning',
    crowd: '🗣 Collaboration',
    tip: '🧠 Spend high willpower only on key decisions',
    history: '1995 · Baumeister first coined "decision fatigue"',
  ),
  // 13–15
  ModeAdvice(
    recommendation: 'Post-lunch dip is biology. A nap here beats two coffees.',
    attribution: '— your dip window',
    crowd: '😴 Recovery dip',
    tip: '🛌 10-min nap — set alarm to avoid sleep inertia',
    history: '500 BC · Aristotle napped holding a key over a bowl',
  ),
  // 15–17
  ModeAdvice(
    recommendation: 'Cognitive rebound. Use it for creative or deep analytical work.',
    attribution: '— your second peak',
    crowd: '💡 Creative work',
    tip: '🎨 Afternoon = right-brain mode is unlocked',
    history: '1935 · Graham Wallas mapped the four stages of creativity',
  ),
  // 17–19
  ModeAdvice(
    recommendation: 'Body temperature peaks. Reaction time is at its fastest now.',
    attribution: '— your physical peak',
    crowd: '🏃 Exercise',
    tip: '⚡ Personal-best attempts belong in this window',
    history: '1984 · USOC studied time-of-day performance gains',
  ),
  // 19–21
  ModeAdvice(
    recommendation: 'Parasympathetic mode on. Digest, connect, restore.',
    attribution: '— your recovery phase',
    crowd: '🏡 Family & rest',
    tip: '💬 Deep conversations measurably lower cortisol',
    history: '1970s · Cardiologists defined HRV as recovery marker',
  ),
  // 21–22
  ModeAdvice(
    recommendation: 'Melatonin rising. Blue light now costs 45 min of deep sleep.',
    attribution: '— your circadian prep',
    crowd: '🌙 Sleep onset',
    tip: '🕯 Dim lights + 18 °C room = faster sleep onset',
    history: '1980 · Lewy discovered the light–melatonin link',
  ),
];

// ═════════════════════════════════════════════════════════════════════════
//                          Mode: ATHLETIC PRO
// ═════════════════════════════════════════════════════════════════════════

const List<ModeAdvice> _athleticPro = <ModeAdvice>[
  // 09–11
  ModeAdvice(
    recommendation: 'Periodize, don\'t improvise. Know your training block for today.',
    attribution: '— your periodization',
    crowd: '📋 Block planning',
    tip: '🗓 Base → build → peak → taper — know your phase',
    history: '1952 · Matveyev formalised periodization theory',
  ),
  // 11–13
  ModeAdvice(
    recommendation: 'Zone 4–5 work. Push the VO₂ ceiling, not the floor.',
    attribution: '— your intensity block',
    crowd: '🔥 High intensity',
    tip: '❤️ 170–185 bpm is your Zone 4 territory',
    history: '1976 · Åstrand standardised VO₂ max measurement',
  ),
  // 13–15
  ModeAdvice(
    recommendation: 'Carb + protein within 30 minutes. The anabolic window is real.',
    attribution: '— your fueling window',
    crowd: '🍚 Precision refuel',
    tip: '📐 4:1 carb-to-protein ratio after high intensity',
    history: '1967 · Karlsson first mapped glycogen depletion rates',
  ),
  // 15–17
  ModeAdvice(
    recommendation: 'Technical skills need a fresher CNS than you might think.',
    attribution: '— your skill block',
    crowd: '🎯 Technical drills',
    tip: '🧠 Motor learning peaks ~6h after your warm-up',
    history: '1967 · Fitts\'s Law of motor skill acquisition',
  ),
  // 17–19
  ModeAdvice(
    recommendation: 'Zone 2 recovery run. Aerobic base compounds every single day.',
    attribution: '— your base build',
    crowd: '🏃 Zone 2',
    tip: '💓 Keep HR 120–145 bpm — you should be able to talk',
    history: '2007 · Iñigo San Millán popularised Zone 2 training',
  ),
  // 19–21
  ModeAdvice(
    recommendation: 'Cold, contrast, or compression. Choose one recovery tool.',
    attribution: '— your recovery stack',
    crowd: '🧊 Recovery',
    tip: '🌡 Cold 10 min → warm 10 min — repeat 3 rounds',
    history: '1978 · Jones published the first DOMS mechanisms paper',
  ),
  // 21–22
  ModeAdvice(
    recommendation: 'Log HRV. Low tomorrow = pull back. High = push hard.',
    attribution: '— your readiness check',
    crowd: '📊 HRV & sleep',
    tip: '📱 HRV drop > 10% = scheduled deload or full rest',
    history: '1973 · Ewing mapped HRV relationship with training load',
  ),
];

// ═════════════════════════════════════════════════════════════════════════
//                            Mode: GYM PRO
// ═════════════════════════════════════════════════════════════════════════

const List<ModeAdvice> _gymPro = <ModeAdvice>[
  // 09–11
  ModeAdvice(
    recommendation: 'RPE 3 warm-up. Prime the CNS properly before you load the bar.',
    attribution: '— your CNS activation',
    crowd: '⚡ CNS priming',
    tip: '🔁 Potentiation set: 30% × 8 before your working sets',
    history: '1980 · Zatsiorsky defined maximum strength methods',
  ),
  // 11–13
  ModeAdvice(
    recommendation: 'Progressive overload is the only rule. One more rep or 2.5 kg.',
    attribution: '— your strength block',
    crowd: '🏋️ Working sets',
    tip: '📈 Linear: add 2.5 kg weekly on main compound lifts',
    history: '1945 · DeLorme published Progressive Resistance Exercise',
  ),
  // 13–15
  ModeAdvice(
    recommendation: 'Leucine triggers MPS. Get at least 3g in your post-workout meal.',
    attribution: '— your MPS window',
    crowd: '🍳 Muscle synthesis',
    tip: '🥩 Leucine threshold: 40g chicken or three whole eggs',
    history: '1998 · Norton established the leucine threshold model',
  ),
  // 15–17
  ModeAdvice(
    recommendation: '2 RIR on every set. Growth happens at the edge, not past it.',
    attribution: '— your volume block',
    crowd: '💪 Hypertrophy',
    tip: '📏 2 reps in reserve = optimal hypertrophy stimulus',
    history: '2001 · Krieger published the volume dose-response study',
  ),
  // 17–19
  ModeAdvice(
    recommendation: 'Zone 2 cardio protects the heart without stealing muscle.',
    attribution: '— your cardio boundary',
    crowd: '❤️ Conditioning',
    tip: '🚴 Low-intensity cardio: zero muscle interference at this dose',
    history: '1990 · Hickson studied interference effect limits',
  ),
  // 19–21
  ModeAdvice(
    recommendation: 'Myofascial release + protein. Two simultaneous repair signals.',
    attribution: '— your repair block',
    crowd: '🧘 Recovery',
    tip: '🫙 Casein shake + foam roll = the optimal repair combo',
    history: '1977 · Rolf Institute formalised myofascial release work',
  ),
  // 21–22
  ModeAdvice(
    recommendation: 'Growth hormone surges in slow-wave sleep. Earn the sleep.',
    attribution: '— your anabolic night',
    crowd: '💤 Anabolic sleep',
    tip: '😴 GH peaks ~1h after sleep onset — protect that window',
    history: '1963 · Takahashi documented the GH–sleep link',
  ),
];

// ═════════════════════════════════════════════════════════════════════════
//                           Mode: OFFICE PRO
// ═════════════════════════════════════════════════════════════════════════

const List<ModeAdvice> _officePro = <ModeAdvice>[
  // 09–11
  ModeAdvice(
    recommendation: 'Maker time. No meetings before noon — protect it fiercely.',
    attribution: '— your maker schedule',
    crowd: '🔕 Zero interrupts',
    tip: '🎧 Deep work: no Slack, one tab, one task',
    history: '2009 · Paul Graham wrote "Maker\'s Schedule, Manager\'s Schedule"',
  ),
  // 11–13
  ModeAdvice(
    recommendation: 'Batch your decisions here. Willpower is highest before lunch.',
    attribution: '— your decision peak',
    crowd: '⚖️ Key decisions',
    tip: '🧠 Save peak willpower for your two highest-stakes calls',
    history: '2011 · Danziger\'s judge study proved decision fatigue',
  ),
  // 13–15
  ModeAdvice(
    recommendation: 'Strategic lunch. A 10-minute walk gives you a 20% sharper 3 PM.',
    attribution: '— your tactical break',
    crowd: '🚶 Recovery walk',
    tip: '☀️ Outdoor lunch = melatonin reset + measurable mood lift',
    history: '1920 · Henry Ford introduced the 8-hour workday',
  ),
  // 15–17
  ModeAdvice(
    recommendation: 'Manager tasks now. Meetings, reviews, replies — none need peak brain.',
    attribution: '— your manager schedule',
    crowd: '📧 Admin mode',
    tip: '📬 Batch all emails twice a day — once right now',
    history: '1956 · Parkinson\'s Law published in The Economist',
  ),
  // 17–19
  ModeAdvice(
    recommendation: 'Shutdown ritual. Define "done", log the wins, set tomorrow\'s one thing.',
    attribution: '— your shutdown ritual',
    crowd: '🔒 Close-out',
    tip: '📋 3 wins + top task for tomorrow = zero morning drag',
    history: '1990 · Newport coined the "shutdown complete" ritual',
  ),
  // 19–21
  ModeAdvice(
    recommendation: 'Detach fully. The brain sorts unsolved problems during genuine downtime.',
    attribution: '— your incubation phase',
    crowd: '🏡 True rest',
    tip: '🧩 Hard problems often solve themselves in rest mode',
    history: '1926 · Wallas named incubation the third stage of creativity',
  ),
  // 21–22
  ModeAdvice(
    recommendation: 'Pre-mortem tomorrow. Name the one thing that must not fail.',
    attribution: '— your strategic wind-down',
    crowd: '📝 Pre-mortem',
    tip: '🎯 Clear top task → zero decision cost at tomorrow\'s start',
    history: '1989 · Klein developed the pre-mortem technique',
  ),
];

// ═════════════════════════════════════════════════════════════════════════
//                        Mode: NICOTINE FREE PRO
// ═════════════════════════════════════════════════════════════════════════

const List<ModeAdvice> _nicotineFreePro = <ModeAdvice>[
  // 09–11
  ModeAdvice(
    recommendation: 'HALT check — Hungry, Angry, Lonely, Tired? Fix the real need first.',
    attribution: '— your craving root',
    crowd: '🛡 HALT check',
    tip: '🔎 A craving = an unmet need. Name it precisely.',
    history: '1970 · HALT model emerged from addiction counselling',
  ),
  // 11–13
  ModeAdvice(
    recommendation: 'Urge surfing: ride the wave, don\'t wrestle it. Peak lasts 3 minutes.',
    attribution: '— your urge window',
    crowd: '🌊 Urge surf',
    tip: '⏱ Peak craving = 3 min max — breathe through the whole thing',
    history: '1994 · Marlatt and colleagues developed urge surfing',
  ),
  // 13–15
  ModeAdvice(
    recommendation: 'Stable blood sugar is your secret weapon. Spikes mimic nicotine cues.',
    attribution: '— your metabolic anchor',
    crowd: '🍎 Stable glucose',
    tip: '🥗 Low-GI lunch → fewer false craving signals this afternoon',
    history: '1977 · Hughes first linked nicotine and blood glucose',
  ),
  // 15–17
  ModeAdvice(
    recommendation: 'Reward the milestone. Your quit bank grows every waking hour.',
    attribution: '— your reward anchor',
    crowd: '🏆 Reward',
    tip: '💰 Calculate money saved and keep it visible today',
    history: '2003 · NRT studies doubled 12-month quit rates',
  ),
  // 17–19
  ModeAdvice(
    recommendation: 'Dopamine reset: exercise fires the same pathways nicotine hijacked.',
    attribution: '— your dopamine repair',
    crowd: '🏃 Dopamine run',
    tip: '🧬 20-min run = nicotine-equivalent dopamine release',
    history: '2002 · Volkow mapped dopamine pathways in addiction',
  ),
  // 19–21
  ModeAdvice(
    recommendation: 'Social triggers are set-ups. Sit differently. Hold your drink. Leave briefly.',
    attribution: '— your trigger shield',
    crowd: '🛡 Social shield',
    tip: '🔄 Cue → routine → reward. Break the routine first.',
    history: '2012 · Duhigg\'s The Power of Habit published',
  ),
  // 21–22
  ModeAdvice(
    recommendation: 'Another day banked. Sleep cements the quit-behaviour pathways.',
    attribution: '— your daily win',
    crowd: '💤 Win banked',
    tip: '😴 Sleep quality = top predictor of next-day quit success',
    history: '2014 · Sleep quality was linked to quit success rates',
  ),
];

// ═════════════════════════════════════════════════════════════════════════
//                       Register all modes here
// ═════════════════════════════════════════════════════════════════════════
//
// One line per mode. Keys must match DayMode.id values in `allDayModes`.

const Map<String, List<ModeAdvice>> modeAdviceMap =
    <String, List<ModeAdvice>>{
  'normal':            _normal,
  'athletic':          _athletic,
  'gym':               _gym,
  'office':            _office,
  'nicotine_free':     _nicotineFree,
  'student':           _student,
  'normal_pro':        _normalPro,
  'athletic_pro':      _athleticPro,
  'gym_pro':           _gymPro,
  'office_pro':        _officePro,
  'nicotine_free_pro': _nicotineFreePro,
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
