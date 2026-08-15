import 'package:flutter/material.dart';

import '../../../data/coder/coder_advice.dart';
import '../../../services/custom_mode_store.dart';
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
//       3. Add `'studying': _studying,` to `modeAdviceSourceMap` at the bottom.
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
/// Keys must match the `modeAdviceSourceMap` entries at the bottom of this file.
const List<DayMode> allDayModes = <DayMode>[
  DayMode(id: 'healthy', emoji: '🙂', label: 'Healthy'),
  DayMode(id: 'athletic', emoji: '🏃', label: 'Athletic'),
  DayMode(id: 'gym', emoji: '🏋️', label: 'Gym'),
  DayMode(id: 'office', emoji: '💼', label: 'Office'),
  DayMode(id: 'nicotine_free', emoji: '🚭', label: 'Nicotine Free'),
  DayMode(id: 'student', emoji: '📚', label: 'Student'),
  DayMode(id: 'coder_pro', emoji: '</>', label: 'Coder Pro', isPro: true),
  DayMode(
      id: 'coder_super_plus',
      emoji: '++',
      label: 'Coder Super+',
      isPro: true),
  DayMode(id: 'healthy_pro', emoji: '🙂', label: 'Healthy Pro', isPro: true),
  DayMode(id: 'athletic_pro', emoji: '🏃', label: 'Athletic Pro', isPro: true),
  DayMode(id: 'gym_pro', emoji: '🏋️', label: 'Gym Pro', isPro: true),
  DayMode(id: 'office_pro', emoji: '💼', label: 'Office Pro', isPro: true),
  DayMode(id: 'nicotine_free_pro', emoji: '🚭', label: 'Quit Pro', isPro: true),
];

/// Legacy marker id. New saved plans use `custom_1` ... `custom_5`.
const String customModeId = 'custom';

List<DayMode> get customDayModes {
  return CustomModeStore.instance.plans.value
      .map((plan) => DayMode(id: plan.id, emoji: '✨', label: plan.name))
      .toList();
}

List<DayMode> get allSelectableDayModes =>
    <DayMode>[...allDayModes, ...customDayModes];

/// User's target wake time in minutes — driven by [SleepScheduleStore].
int get homeDayWakeMinutes => _scheduleStore.wakeMinutes;

/// User's target sleep time in minutes — driven by [SleepScheduleStore].
int get homeDaySleepMinutes => _scheduleStore.sleepMinutes;

/// A window in the waking day. Stored in minutes since midnight so the
/// slots can shift with the user's wake / sleep target without losing
/// precision at non-hour boundaries.
class TimeSlot {
  const TimeSlot({required this.startMinutes, required this.endMinutes});

  /// Convenience for legacy call sites that reason in whole hours.
  const TimeSlot.hours({required int startHour, required int endHour})
      : startMinutes = startHour * 60,
        endMinutes = endHour * 60;

  final int startMinutes;
  final int endMinutes;

  int get startHour => startMinutes ~/ 60;
  int get endHour => endMinutes ~/ 60;

  bool contains(int minutes) {
    var candidate = _normalizeMinuteOfDay(minutes);
    while (candidate < startMinutes) {
      candidate += kDayMinutes;
    }
    return candidate < endMinutes;
  }

  String get rangeLabel {
    String fmt(int m) {
      final hr24 = (m ~/ 60) % 24;
      final min = m % 60;
      final hr12 = hr24 == 0 ? 12 : (hr24 > 12 ? hr24 - 12 : hr24);
      final period = hr24 < 12 ? 'AM' : 'PM';
      if (min == 0) return '$hr12 $period';
      return '$hr12:${min.toString().padLeft(2, '0')} $period';
    }

    return '${fmt(startMinutes)} – ${fmt(endMinutes)}';
  }
}

/// What we tell the user about a single (mode, slot) pair.
class ModeAdvice {
  const ModeAdvice({
    required this.recommendation,
    required this.tip,
    this.descriptions = const <String>[],
  });

  /// Short phrase rendered as the card's main text.
  final String recommendation;

  /// Energy-aware coaching title for this window under this mode.
  final String tip;

  /// Short support bullets shown under the headline.
  final List<String> descriptions;
}

typedef AdviceMap = Map<String, Object>;

ModeAdvice _modeAdviceFromMap(AdviceMap source) {
  final descriptions =
      (source['descriptions'] as List<Object>? ?? const <Object>[])
          .whereType<String>()
          .where((text) => text.trim().isNotEmpty)
          .map((text) => text.trim())
          .toList();
  return ModeAdvice(
    recommendation: (source['recommendation'] as String?) ?? '',
    tip: (source['tip'] as String?) ?? '',
    descriptions: descriptions,
  );
}

ModeAdvice _customAdviceFromSlot({
  required CustomSlot slot,
  required ModeAdvice fallback,
}) {
  return ModeAdvice(
    recommendation: slot.recommendation.isNotEmpty
        ? slot.recommendation
        : fallback.recommendation,
    tip: slot.tip.isNotEmpty ? slot.tip : fallback.tip,
    descriptions: slot.descriptions.isNotEmpty
        ? slot.descriptions
        : fallback.descriptions,
  );
}

const List<String> modeAdviceHistory = <String>[
  '1969 - Apollo 11 cruised toward the Moon',
  '1889 - The Eiffel Tower opened to visitors',
  '1876 - Bell made the first clear telephone call',
  '1903 - The Wright brothers prepared for first flight',
  '1985 - The first .com domain was registered',
  '1776 - Independence was approved in Philadelphia',
  '1938 - War of the Worlds aired on radio',
];

String historyForPlannerSlot(int slotIndex) {
  return modeAdviceHistory[slotIndex % modeAdviceHistory.length];
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
// Order matters — every mode's advice list uses these indices. The list is
// computed on demand from the user's wake / sleep window so shifting either
// end re-labels every planner card, the daily-planner editor, and the home
// scrollbar together.

/// Number of slots in the day. Kept as a compile-time constant so the
/// per-mode advice lists (which are `const`) stay in sync with the layout.
const int kSlotCount = 7;
const int kDayMinutes = 24 * 60;

/// Minutes reserved after wake for the "wake" card (breakfast, sunlight,
/// morning routine). The first planner slot begins at [wake + this].
const int kWakeBufferMinutes = 120;

/// True when [nowMinutes] falls inside the wake-card window
/// (right after wake, before the first planner slot).
bool isWakeWindow(num nowMinutes) {
  return isWakeWindowFor(nowMinutes, wakeMinutes: homeDayWakeMinutes);
}

bool isWakeWindowFor(num nowMinutes, {required int wakeMinutes}) {
  return TimeSlot(
    startMinutes: wakeMinutes,
    endMinutes: wakeMinutes + kWakeBufferMinutes,
  ).contains(nowMinutes.floor());
}

/// True when [nowMinutes] is either before wake (previous night still
/// carrying over) or at/after sleep — i.e. the sleep card is current.
bool isSleepWindow(num nowMinutes) {
  return isSleepWindowFor(
    nowMinutes,
    wakeMinutes: homeDayWakeMinutes,
    sleepMinutes: homeDaySleepMinutes,
  );
}

bool isSleepWindowFor(
  num nowMinutes, {
  required int wakeMinutes,
  required int sleepMinutes,
}) {
  final sleepEnd = _sleepEndForDay(
    wakeMinutes: wakeMinutes,
    sleepMinutes: sleepMinutes,
  );
  var candidate = _normalizeMinuteOfDay(nowMinutes.floor());
  while (candidate < wakeMinutes) {
    candidate += kDayMinutes;
  }
  return candidate >= sleepEnd;
}

/// Live-computed planner slots — divides the current
/// [wake + kWakeBufferMinutes → sleep] window evenly into [kSlotCount]
/// pieces, rounded to 15-minute boundaries so labels stay tidy. The last
/// slot absorbs any rounding remainder so it always ends exactly at sleep.
List<TimeSlot> get plannerSlots => plannerSlotsFor(
      wakeMinutes: homeDayWakeMinutes,
      sleepMinutes: homeDaySleepMinutes,
    );

List<TimeSlot> plannerSlotsFor({
  required int wakeMinutes,
  required int sleepMinutes,
}) {
  final wake = _normalizeMinuteOfDay(wakeMinutes);
  final sleep = _sleepEndForDay(
    wakeMinutes: wake,
    sleepMinutes: sleepMinutes,
  );
  final start = wake + kWakeBufferMinutes;
  final total = sleep > start ? sleep - start : 60 * 12; // sane fallback
  const step = 15;
  final rawSlot = total ~/ kSlotCount;
  final slotMinutes = (rawSlot ~/ step) * step;
  final base = slotMinutes < step ? step : slotMinutes;

  final slots = <TimeSlot>[];
  var cursor = start;
  for (var i = 0; i < kSlotCount - 1; i++) {
    slots.add(TimeSlot(
      startMinutes: cursor,
      endMinutes: cursor + base,
    ));
    cursor += base;
  }
  slots.add(TimeSlot(startMinutes: cursor, endMinutes: sleep));
  return slots;
}

int _normalizeMinuteOfDay(num minutes) {
  final value = minutes.floor() % kDayMinutes;
  return value < 0 ? value + kDayMinutes : value;
}

int _sleepEndForDay({
  required int wakeMinutes,
  required int sleepMinutes,
}) {
  final wake = _normalizeMinuteOfDay(wakeMinutes);
  var sleep = _normalizeMinuteOfDay(sleepMinutes);
  if (sleep <= wake) sleep += kDayMinutes;
  return sleep;
}

/// Formatted "6:00 AM" for the current wake target.
String get wakeTimeLabel {
  final t = _scheduleStore.wakeTime.value;
  return timeOfDayLabel(t);
}

/// Formatted "10:00 PM" for the current sleep target.
String get sleepTimeLabel {
  final t = _scheduleStore.sleepTime.value;
  return timeOfDayLabel(t);
}

String minutesLabel(int minutes) {
  final normalized = minutes % (24 * 60);
  return timeOfDayLabel(
    TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60),
  );
}

String timeOfDayLabel(TimeOfDay t) {
  final h12 = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
  final m = t.minute.toString().padLeft(2, '0');
  return '$h12:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

// ═════════════════════════════════════════════════════════════════════════
//                              Mode: NORMAL
// ═════════════════════════════════════════════════════════════════════════

// Broad, accessible mode advice. Each list has one item per planner slot.
const AdviceMap _steadyStart = <String, Object>{
  'recommendation': 'Pick one useful task and make the first step small.',
  'tip': 'Start with 10 focused minutes',
  'descriptions': <String>[
    'Choose one outcome for this session.',
    'Write the first tiny step before starting.',
    'Keep distractions outside the first 10 minutes.',
  ],
};

const AdviceMap _focusedProgress = <String, Object>{
  'recommendation':
      'Use this block for the work that needs your clearest mind.',
  'tip': 'One task, one timer, fewer tabs',
  'descriptions': <String>[
    'Use this for work that needs a clear mind.',
    'Keep only the needed app or notebook open.',
    'Pause notifications until the block ends.',
  ],
};

const AdviceMap _replyAndDecide = <String, Object>{
  'recommendation':
      'Answer messages, make small decisions, then take a real break.',
  'tip': 'Batch messages so they do not take the whole day',
  'descriptions': <String>[
    'Reply to important people first.',
    'Make small decisions in one batch.',
    'Close the loop before taking a break.',
  ],
};

const AdviceMap _recharge = <String, Object>{
  'recommendation': 'Eat, hydrate, and step away long enough to feel reset.',
  'tip': 'A short walk helps more than scrolling',
  'descriptions': <String>[
    'Eat something steady and drink water.',
    'Step away from the same screen or seat.',
    'Return with one simple next action.',
  ],
};

const AdviceMap _secondWind = <String, Object>{
  'recommendation': 'Close a few small loops while your momentum is back.',
  'tip': 'Finish, file, reply, or clean up one thing',
  'descriptions': <String>[
    'Pick low-friction tasks that still matter.',
    'Clear loose ends while energy is returning.',
    'Save deep thinking for a better window.',
  ],
};

const AdviceMap _moveAndReset = <String, Object>{
  'recommendation': 'Move your body a little before the evening gets full.',
  'tip': 'Ten minutes outside can change the tone of the night',
  'descriptions': <String>[
    'Move, stretch, or take a short walk.',
    'Handle one errand before settling in.',
    'Let the day shift out of work mode.',
  ],
};

const AdviceMap _closeTheDay = <String, Object>{
  'recommendation': 'Give attention to people, home, or quiet recovery.',
  'tip': 'Dim screens and make the room easier to sleep in',
  'descriptions': <String>[
    'Give attention to people or home.',
    'Choose calmer light and quieter inputs.',
    'Avoid starting anything hard to stop.',
  ],
};

const AdviceMap _bedtimePrep = <String, Object>{
  'recommendation': 'Write tomorrow\'s first step, then let today be done.',
  'tip': 'Set clothes, charger, and one priority before bed',
  'descriptions': <String>[
    'Write tomorrow\'s first step.',
    'Put essentials where morning-you can see them.',
    'Let the day be complete enough.',
  ],
};

const AdviceMap _activeStart = <String, Object>{
  'recommendation':
      'Check your energy, warm up gently, and choose a realistic pace.',
  'tip': 'Easy movement first; intensity is optional',
  'descriptions': <String>[
    'Check how your body feels today.',
    'Warm up before asking for intensity.',
    'Choose a pace you can recover from.',
  ],
};

const AdviceMap _trainingBlock = <String, Object>{
  'recommendation':
      'Train the plan you can recover from, not the plan your ego likes.',
  'tip': 'Leave a little energy for the rest of life',
  'descriptions': <String>[
    'Train the plan, not the mood.',
    'Stop before form starts falling apart.',
    'Recovery counts as part of the session.',
  ],
};

const AdviceMap _mobilityReset = <String, Object>{
  'recommendation': 'Stretch what feels tight and log what helped today.',
  'tip': 'Two calm minutes are better than skipping recovery',
  'descriptions': <String>[
    'Stretch the area that feels tightest.',
    'Log one thing that helped.',
    'Keep it light enough to repeat tomorrow.',
  ],
};

const AdviceMap _officeStart = <String, Object>{
  'recommendation': 'Protect a quiet block before the day fills with requests.',
  'tip': 'Mute notifications for the first important task',
  'descriptions': <String>[
    'Protect one quiet work block.',
    'Start before messages set the agenda.',
    'Keep the output small and shippable.',
  ],
};

const AdviceMap _officeClose = <String, Object>{
  'recommendation':
      'Define done, note tomorrow\'s priority, and leave work at work.',
  'tip': 'A clean stop makes tomorrow easier',
  'descriptions': <String>[
    'Define what is done for today.',
    'Note tomorrow\'s first priority.',
    'Leave work with a clean handoff.',
  ],
};

const AdviceMap _habitReset = <String, Object>{
  'recommendation':
      'Notice the urge, name the need, and choose one replacement action.',
  'tip': 'Water, breath, walk, or message someone',
  'descriptions': <String>[
    'Name the urge without judging it.',
    'Meet the real need with a small action.',
    'Change location if the cue is strong.',
  ],
};

const AdviceMap _triggerPlan = <String, Object>{
  'recommendation':
      'Change the scene before an old routine starts automatically.',
  'tip': 'Move seats, hold water, step outside, or call a friend',
  'descriptions': <String>[
    'Spot the cue before it runs the routine.',
    'Swap in a replacement action quickly.',
    'Make the old pattern slightly harder.',
  ],
};

const AdviceMap _studyStart = <String, Object>{
  'recommendation':
      'Study the hardest idea first while attention is still fresh.',
  'tip': 'Explain the idea out loud after reading it',
  'descriptions': <String>[
    'Start with the hardest concept.',
    'Turn reading into recall.',
    'Keep study blocks short enough to repeat.',
  ],
};

const AdviceMap _studyReview = <String, Object>{
  'recommendation':
      'Review what matters, then stop before your brain gets noisy.',
  'tip': 'Short recall beats long rereading',
  'descriptions': <String>[
    'Review the material that fades fastest.',
    'Use recall before checking notes.',
    'Stop while your brain can still settle.',
  ],
};

const AdviceMap _proPlan = <String, Object>{
  'recommendation':
      'Choose the highest-value outcome and remove one friction point.',
  'tip': 'Make the next action visible and specific',
  'descriptions': <String>[
    'Choose the highest-value outcome.',
    'Remove one friction point before starting.',
    'Measure energy as well as output.',
  ],
};

const AdviceMap _proReview = <String, Object>{
  'recommendation':
      'Review signals, adjust the plan, and keep the standard humane.',
  'tip': 'Track energy, not only output',
  'descriptions': <String>[
    'Review what helped and what drained you.',
    'Adjust the next block instead of forcing it.',
    'Keep the standard useful and humane.',
  ],
};

const List<AdviceMap> _normal = <AdviceMap>[
  _steadyStart,
  _focusedProgress,
  _replyAndDecide,
  _recharge,
  _secondWind,
  _moveAndReset,
  _bedtimePrep,
];

const List<AdviceMap> _athletic = <AdviceMap>[
  _activeStart,
  _trainingBlock,
  _recharge,
  _mobilityReset,
  _moveAndReset,
  _closeTheDay,
  _bedtimePrep,
];

const List<AdviceMap> _gym = <AdviceMap>[
  _activeStart,
  _trainingBlock,
  _recharge,
  _focusedProgress,
  _moveAndReset,
  _mobilityReset,
  _bedtimePrep,
];

const List<AdviceMap> _office = <AdviceMap>[
  _officeStart,
  _replyAndDecide,
  _recharge,
  _secondWind,
  _officeClose,
  _closeTheDay,
  _bedtimePrep,
];

const List<AdviceMap> _nicotineFree = <AdviceMap>[
  _habitReset,
  _focusedProgress,
  _recharge,
  _triggerPlan,
  _moveAndReset,
  _closeTheDay,
  _bedtimePrep,
];

const List<AdviceMap> _student = <AdviceMap>[
  _studyStart,
  _focusedProgress,
  _recharge,
  _replyAndDecide,
  _moveAndReset,
  _studyReview,
  _bedtimePrep,
];

const List<AdviceMap> _normalPro = <AdviceMap>[
  _proPlan,
  _focusedProgress,
  _replyAndDecide,
  _recharge,
  _secondWind,
  _proReview,
  _bedtimePrep,
];

const List<AdviceMap> _athleticPro = <AdviceMap>[
  _proPlan,
  _trainingBlock,
  _recharge,
  _mobilityReset,
  _moveAndReset,
  _proReview,
  _bedtimePrep,
];

const List<AdviceMap> _gymPro = <AdviceMap>[
  _proPlan,
  _trainingBlock,
  _recharge,
  _focusedProgress,
  _moveAndReset,
  _proReview,
  _bedtimePrep,
];

const List<AdviceMap> _officePro = <AdviceMap>[
  _proPlan,
  _officeStart,
  _replyAndDecide,
  _recharge,
  _officeClose,
  _proReview,
  _bedtimePrep,
];

const List<AdviceMap> _nicotineFreePro = <AdviceMap>[
  _proPlan,
  _habitReset,
  _recharge,
  _triggerPlan,
  _moveAndReset,
  _proReview,
  _bedtimePrep,
];
//                       Register all modes here
// ═════════════════════════════════════════════════════════════════════════
//
// One line per mode. Keys must match DayMode.id values in `allDayModes`.

const Map<String, List<AdviceMap>> modeAdviceSourceMap =
    <String, List<AdviceMap>>{
  'healthy': _normal,
  'athletic': _athletic,
  'gym': _gym,
  'office': _office,
  'nicotine_free': _nicotineFree,
  'student': _student,
  'coder_pro': coderProAdvice,
  'coder_super_plus': coderSuperPlusAdvice,
  'healthy_pro': _normalPro,
  'athletic_pro': _athleticPro,
  'gym_pro': _gymPro,
  'office_pro': _officePro,
  'nicotine_free_pro': _nicotineFreePro,
};

/// Safe lookup: falls back to 'healthy' if a mode id has no curated data
/// yet, so a new dropdown entry can never crash the planner.
/// For the special [customModeId], reads live from [CustomModeStore] and
/// falls back per-slot to the healthy advice for any blank entries.
List<ModeAdvice> adviceForMode(String modeId) {
  final normalizedModeId = switch (modeId) {
    'normal' => 'healthy',
    'normal_pro' => 'healthy_pro',
    _ => modeId,
  };
  final healthy =
      modeAdviceSourceMap['healthy']!.map(_modeAdviceFromMap).toList();
  if (CustomModeStore.isCustomModeId(modeId)) {
    final plan = CustomModeStore.instance.planForModeId(modeId);
    final slots = plan.slots;
    return List<ModeAdvice>.generate(healthy.length, (i) {
      final s = i < slots.length ? slots[i] : const CustomSlot();
      return _customAdviceFromSlot(
        slot: s,
        fallback: healthy[i],
      );
    });
  }
  final source =
      modeAdviceSourceMap[normalizedModeId] ?? modeAdviceSourceMap['healthy']!;
  return source.map(_modeAdviceFromMap).toList();
}

/// Optional runtime sanity check — call from `main.dart` during dev to
/// catch a mode list that got out of sync with `plannerSlots`.
bool debugAssertModeData() {
  final expected = plannerSlots.length;
  for (final entry in modeAdviceSourceMap.entries) {
    assert(
      entry.value.length == expected,
      'Mode "${entry.key}" has ${entry.value.length} entries, '
      'expected $expected (one per slot in plannerSlots).',
    );
  }
  return true;
}
