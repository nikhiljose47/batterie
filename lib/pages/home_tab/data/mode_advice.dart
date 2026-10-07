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
//   1. Wake and sleep time define the user's active day.
//   2. `plannerSlots` divides that active day into seven editable phases.
//   3. Each phase uses the per-mode text from the map for the selected goal.
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
//       3. Add it to `presetGoalContentLibrary` below.
//       4. Add it to the mode dropdown in `home_tab_page.dart` (`_dayModes`).
//
//  • Add a new time slot:
//       1. Add a `TimeSlot(...)` entry to `plannerSlots`.
//       2. Append one `ModeAdvice(...)` to every mode's list — order must
//          match `plannerSlots`. Miss one and the analyzer will flag it
//          via a length mismatch when `debugAssertModeData()` runs.
//
//  • Adjust phase names: edit `kDayPhaseBlueprints`.
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
    required this.shortLabel,
    this.isPro = false,
  });

  final String id;
  final String emoji;
  final String label;
  final String shortLabel;

  /// Pro modes show a small PRO badge in the chip.
  final bool isPro;
}

/// Full ordered list of goal-based modes shown to the user.
/// Keys must match the preset content entries at the bottom of this file.
const List<DayMode> allDayModes = <DayMode>[
  DayMode(
    id: 'student',
    emoji: '📚',
    label: 'I need to Prepare for Exam',
    shortLabel: 'Exam',
  ),
  DayMode(
    id: 'office',
    emoji: '🎯',
    label: 'I need a better office workday',
    shortLabel: 'Office',
  ),
  DayMode(
    id: 'gym',
    emoji: '🏋️',
    label: 'Track and get me muscles',
    shortLabel: 'Muscles',
  ),
  DayMode(
    id: 'nicotine_free',
    emoji: '🚭',
    label: 'Reduce my Nicotine / Cigarettes',
    shortLabel: 'Nicotine',
  ),
  DayMode(
    id: 'language',
    emoji: '🗣️',
    label: 'Learn a new Language',
    shortLabel: 'Language',
  ),
  DayMode(
    id: 'healthy',
    emoji: '🙂',
    label: 'Stay Balanced',
    shortLabel: 'Balanced',
  ),
];

/// Legacy marker id. New saved plans use `custom_1` ... `custom_5`.
const String customModeId = 'custom';

List<DayMode> get customDayModes {
  return CustomModeStore.instance.plans.value
      .map((plan) => DayMode(
            id: plan.id,
            emoji: '✨',
            label: plan.longName ?? plan.name,
            shortLabel: plan.shortName ?? plan.name,
          ))
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

class DayPhase {
  const DayPhase({
    required this.id,
    required this.label,
    required this.energyLabel,
    required this.foundationLabel,
    required this.slot,
  });

  final String id;
  final String label;
  final String energyLabel;
  final String foundationLabel;
  final TimeSlot slot;
}

class DayPhaseBlueprint {
  const DayPhaseBlueprint({
    required this.id,
    required this.label,
    required this.energyLabel,
    required this.weight,
  });

  final String id;
  final String label;
  final String energyLabel;
  final double weight;
}

const List<DayPhaseBlueprint> kDayPhaseBlueprints = <DayPhaseBlueprint>[
  DayPhaseBlueprint(
    id: 'wake_activate',
    label: 'Wake & Activate',
    energyLabel: 'Gentle start',
    weight: 0.11,
  ),
  DayPhaseBlueprint(
    id: 'focus_window',
    label: 'Focus Window',
    energyLabel: 'Best clarity',
    weight: 0.19,
  ),
  DayPhaseBlueprint(
    id: 'maintain',
    label: 'Maintain',
    energyLabel: 'Steady work',
    weight: 0.15,
  ),
  DayPhaseBlueprint(
    id: 'recovery',
    label: 'Recovery',
    energyLabel: 'Reset energy',
    weight: 0.13,
  ),
  DayPhaseBlueprint(
    id: 'flexible',
    label: 'Flexible',
    energyLabel: 'Useful buffer',
    weight: 0.16,
  ),
  DayPhaseBlueprint(
    id: 'downshift',
    label: 'Downshift',
    energyLabel: 'Lower friction',
    weight: 0.13,
  ),
  DayPhaseBlueprint(
    id: 'wind_down',
    label: 'Wind Down',
    energyLabel: 'Protect sleep',
    weight: 0.13,
  ),
];

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

class PresetGoalContent {
  const PresetGoalContent({
    required this.modeId,
    required this.cards,
  });

  final String modeId;
  final List<AdviceMap> cards;
}

const List<PresetGoalContent> presetGoalContentLibrary = <PresetGoalContent>[
  PresetGoalContent(modeId: 'healthy', cards: _normal),
  PresetGoalContent(modeId: 'athletic', cards: _athletic),
  PresetGoalContent(modeId: 'gym', cards: _gym),
  PresetGoalContent(modeId: 'office', cards: _office),
  PresetGoalContent(modeId: 'nicotine_free', cards: _nicotineFree),
  PresetGoalContent(modeId: 'student', cards: _student),
  PresetGoalContent(modeId: 'language', cards: _language),
  PresetGoalContent(modeId: 'coder_pro', cards: coderProAdvice),
  PresetGoalContent(modeId: 'coder_super_plus', cards: coderSuperPlusAdvice),
  PresetGoalContent(modeId: 'healthy_pro', cards: _normalPro),
  PresetGoalContent(modeId: 'athletic_pro', cards: _athleticPro),
  PresetGoalContent(modeId: 'gym_pro', cards: _gymPro),
  PresetGoalContent(modeId: 'office_pro', cards: _officePro),
  PresetGoalContent(modeId: 'nicotine_free_pro', cards: _nicotineFreePro),
];

List<AdviceMap> presetGoalCardsFor(String modeId) {
  final normalizedModeId = switch (modeId) {
    'normal' => 'healthy',
    'normal_pro' => 'healthy_pro',
    _ => modeId,
  };
  return presetGoalContentLibrary
      .firstWhere(
        (preset) => preset.modeId == normalizedModeId,
        orElse: () => presetGoalContentLibrary.first,
      )
      .cards;
}

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
}) {
  return ModeAdvice(
    recommendation: slot.recommendation,
    tip: slot.tip,
    descriptions: slot.descriptions,
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

/// Legacy duration kept for older code paths. New phase generation uses the
/// full wake-to-sleep window instead of a fixed wake buffer.
const int kWakeBufferMinutes = 120;

/// True when [nowMinutes] falls inside the wake-card window
/// (right after wake, before the first planner slot).
bool isWakeWindow(num nowMinutes) {
  return isWakeWindowFor(nowMinutes, wakeMinutes: homeDayWakeMinutes);
}

bool isWakeWindowFor(num nowMinutes, {required int wakeMinutes}) {
  final phases = dayPhasesFor(
    wakeMinutes: wakeMinutes,
    sleepMinutes: homeDaySleepMinutes,
  );
  return phases.isNotEmpty && phases.first.slot.contains(nowMinutes.floor());
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
  final phases = dayPhasesFor(
    wakeMinutes: wakeMinutes,
    sleepMinutes: sleepMinutes,
  );
  var candidate = _normalizeMinuteOfDay(nowMinutes.floor());
  while (candidate < wakeMinutes) {
    candidate += kDayMinutes;
  }
  if (phases.isEmpty) return false;
  final last = phases.last.slot;
  return last.contains(candidate) || candidate >= last.endMinutes;
}

/// Live-computed planner slots — the user's wake-to-sleep day split into
/// science-informed phases. The split is deliberately heuristic: it reflects
/// common sleep-wake rhythm patterns, not a medical or diagnostic claim.
List<TimeSlot> get plannerSlots => plannerSlotsFor(
      wakeMinutes: homeDayWakeMinutes,
      sleepMinutes: homeDaySleepMinutes,
    );

List<TimeSlot> plannerSlotsFor({
  required int wakeMinutes,
  required int sleepMinutes,
}) {
  return dayPhasesFor(
    wakeMinutes: wakeMinutes,
    sleepMinutes: sleepMinutes,
  ).map((phase) => phase.slot).toList(growable: false);
}

List<DayPhase> get dayPhases => dayPhasesFor(
      wakeMinutes: homeDayWakeMinutes,
      sleepMinutes: homeDaySleepMinutes,
    );

List<TimeSlot> plannerSlotsForMode(
  String modeId, {
  required int wakeMinutes,
  required int sleepMinutes,
}) {
  if (CustomModeStore.isCustomModeId(modeId)) {
    final cards = CustomModeStore.instance.planForModeId(modeId).planCards;
    if (cards.isNotEmpty) {
      return cards
          .map((card) => TimeSlot(
                startMinutes: wakeMinutes + card.startOffsetMinutes,
                endMinutes: wakeMinutes + card.endOffsetMinutes,
              ))
          .toList(growable: false);
    }
  }
  return plannerSlotsFor(wakeMinutes: wakeMinutes, sleepMinutes: sleepMinutes);
}

List<DayPhase> dayPhasesForMode(
  String modeId, {
  required int wakeMinutes,
  required int sleepMinutes,
}) {
  if (CustomModeStore.isCustomModeId(modeId)) {
    final slots = plannerSlotsForMode(
      modeId,
      wakeMinutes: wakeMinutes,
      sleepMinutes: sleepMinutes,
    );
    if (slots.isNotEmpty) {
      return List<DayPhase>.generate(slots.length, (index) {
        final blueprint =
            kDayPhaseBlueprints[index % kDayPhaseBlueprints.length];
        return DayPhase(
          id: blueprint.id,
          label: blueprint.label,
          energyLabel: blueprint.energyLabel,
          foundationLabel: 'Wake-time offset plan',
          slot: slots[index],
        );
      });
    }
  }
  return dayPhasesFor(wakeMinutes: wakeMinutes, sleepMinutes: sleepMinutes);
}

List<DayPhase> dayPhasesFor({
  required int wakeMinutes,
  required int sleepMinutes,
}) {
  final wake = _normalizeMinuteOfDay(wakeMinutes);
  final sleep = _sleepEndForDay(
    wakeMinutes: wake,
    sleepMinutes: sleepMinutes,
  );
  final total = sleep > wake ? sleep - wake : 60 * 16;
  const step = 15;
  final phases = <DayPhase>[];
  var cursor = wake;
  var used = 0;
  for (var i = 0; i < kDayPhaseBlueprints.length; i++) {
    final blueprint = kDayPhaseBlueprints[i];
    final isLast = i == kDayPhaseBlueprints.length - 1;
    final raw = isLast ? total - used : (total * blueprint.weight).round();
    final rounded = isLast ? raw : ((raw / step).round() * step);
    final duration = rounded < step ? step : rounded;
    final end = isLast ? sleep : cursor + duration;
    used += end - cursor;
    phases.add(DayPhase(
      id: blueprint.id,
      label: blueprint.label,
      energyLabel: blueprint.energyLabel,
      foundationLabel: 'Sleep-wake rhythm informed',
      slot: TimeSlot(
        startMinutes: cursor,
        endMinutes: end,
      ),
    ));
    cursor = end;
  }
  return phases;
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
  <String, Object>{
    'tip': 'Don’t try to fix your whole life in one morning.',
    'recommendation': 'Pick one useful thing and start with 10 minutes.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Doing five things together usually means doing none properly.',
    'recommendation': 'Choose one task, finish a small part, then move on.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Messages and calls don’t need your attention all day.',
    'recommendation': 'Keep one fixed time to clear them together.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'A small break is better than sitting tired for hours.',
    'recommendation': 'Eat, drink water, walk a bit, and come back fresh.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Small pending things create unnecessary stress.',
    'recommendation': 'Close one or two easy tasks before the day ends.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Not every free minute needs to become work time.',
    'recommendation':
        'Keep some time for family, friends, rest, or just doing nothing.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Tomorrow doesn’t need a full timetable tonight.',
    'recommendation':
        'Decide the first thing you’ll do tomorrow, then switch off.',
    'descriptions': <String>[],
  },
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
  <String, Object>{
    'tip': 'Don’t wait for the perfect workout mood.',
    'recommendation': 'Change clothes, warm up, and just start.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'You don’t need to destroy yourself in every workout.',
    'recommendation': 'Train properly, but keep enough energy to recover.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Muscle needs food also, not only workouts.',
    'recommendation': 'Have a proper meal with enough protein after training.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Don’t randomly change your workout every day.',
    'recommendation':
        'Follow the same basic plan and track your reps or weights.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Missed one workout? Don’t make it a full week.',
    'recommendation': 'Do a shorter workout today and continue normally.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Recovery is part of getting stronger.',
    'recommendation':
        'Stretch a bit, drink water, eat properly, and get enough sleep.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Small progress still counts.',
    'recommendation':
        'Note today’s workout and try to improve one small thing next time.',
    'descriptions': <String>[],
  },
];

const List<AdviceMap> _office = <AdviceMap>[
  <String, Object>{
    'tip': 'Don’t start your day with notifications.',
    'recommendation': 'Mute them and finish one important task first.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Replying every five minutes will eat your full day.',
    'recommendation': 'Check messages together at one fixed time.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Feeling tired? Don’t directly start scrolling.',
    'recommendation': 'Drink water, eat something, and walk for 5–10 minutes.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Too many open tasks make your brain more tired.',
    'recommendation': 'Finish one small pending task before starting another.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'You don’t need to finish everything today.',
    'recommendation': 'Pick the top 2–3 things and complete those properly.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'If you keep pushing, focus will only get worse.',
    'recommendation': 'Take one proper break without work or calls.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Don’t carry today’s mess into tomorrow.',
    'recommendation': 'Note tomorrow’s first task and close work for the day.',
    'descriptions': <String>[],
  },
];

const List<AdviceMap> _nicotineFree = <AdviceMap>[
  <String, Object>{
    'tip': 'Don’t automatically smoke the moment you feel the urge.',
    'recommendation':
        'Wait a few minutes. Drink water, walk, or message someone.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Notice when you usually reach for a cigarette.',
    'recommendation':
        'Check if it happens with chai, stress, work breaks, or boredom.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'One craving doesn’t mean you have to act on it.',
    'recommendation':
        'Change what you’re doing for 5–10 minutes and let the urge pass.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Make smoking a little less convenient.',
    'recommendation':
        'Keep cigarettes away from your desk, bed, or usual sitting place.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Don’t think only about quitting everything at once.',
    'recommendation': 'Focus on skipping or delaying the next cigarette first.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'If you smoked more today, don’t give up on the full plan.',
    'recommendation':
        'Notice what triggered it and start reducing again from the next one.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Keep track without judging yourself too much.',
    'recommendation':
        'Note how many you had today and aim for a little better tomorrow.',
    'descriptions': <String>[],
  },
];

const List<AdviceMap> _student = <AdviceMap>[
  <String, Object>{
    'tip': 'Don’t wait for full motivation. Just start somehow.',
    'recommendation': 'Pick one topic and study for 10–15 minutes. Bas, start.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'One proper session is better than wasting the full day.',
    'recommendation':
        'Set a 25–30 minute timer. Start with the topic you keep avoiding.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Take a break, but don’t make it too long.',
    'recommendation':
        'Eat, drink water, check your phone a bit, then come back at a fixed time.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Small-small work can take your whole day.',
    'recommendation':
        'Finish calls, messages, and small tasks together. Then study again.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'If your brain is not working, don’t keep forcing it.',
    'recommendation':
        'Walk a bit, stretch, have chai or coffee, then start with an easy topic.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Too tired to learn something new? Revise instead.',
    'recommendation':
        'Go through formulas, key points, definitions, or old questions.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'No need to make a big plan before sleeping.',
    'recommendation':
        'Decide tomorrow’s first topic, keep your books ready, and sleep.',
    'descriptions': <String>[],
  },
];

const List<AdviceMap> _language = <AdviceMap>[
  <String, Object>{
    'tip': 'Don’t try to learn 50 new words in one sitting.',
    'recommendation': 'Learn 5–10 useful words and actually use them.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Reading only is not enough. Say things out loud.',
    'recommendation': 'Speak a few simple sentences using what you learnt.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Ten minutes daily is better than two hours once a week.',
    'recommendation': 'Keep one small daily language session.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Don’t stop every time you forget one word.',
    'recommendation': 'Say the sentence in an easier way and keep going.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Use content you already enjoy.',
    'recommendation':
        'Watch a short video, reel, or show clip in that language.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Revision works better than reading the same page again.',
    'recommendation': 'Try remembering old words before checking the answer.',
    'descriptions': <String>[],
  },
  <String, Object>{
    'tip': 'Keep tomorrow’s practice easy to start.',
    'recommendation': 'Pick one small lesson or topic before you sleep.',
    'descriptions': <String>[],
  },
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
  if (CustomModeStore.isCustomModeId(modeId)) {
    final plan = CustomModeStore.instance.planForModeId(modeId);
    final slots = CustomModeStore.slotsFromCards(plan.planCards);
    return List<ModeAdvice>.generate(slots.length, (i) {
      return _customAdviceFromSlot(slot: slots[i]);
    });
  }
  final source = presetGoalCardsFor(normalizedModeId);
  return source.map(_modeAdviceFromMap).toList();
}

/// Optional runtime sanity check — call from `main.dart` during dev to
/// catch a mode list that got out of sync with `plannerSlots`.
bool debugAssertModeData() {
  final expected = plannerSlots.length;
  for (final entry in presetGoalContentLibrary) {
    assert(
      entry.cards.length == expected,
      'Mode "${entry.modeId}" has ${entry.cards.length} entries, '
      'expected $expected (one per slot in plannerSlots).',
    );
  }
  return true;
}
