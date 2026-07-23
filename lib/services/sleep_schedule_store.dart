import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Storage keys ────────────────────────────────────────────────────────────
// schedule.wake.hour    — int, default 6
// schedule.wake.minute  — int, default 0
// schedule.sleep.hour   — int, default 22
// schedule.sleep.minute — int, default 0
//
// Supabase: add columns wake_hour, wake_minute, sleep_hour, sleep_minute
// to the profiles table (see remote_sync.dart).
// ─────────────────────────────────────────────────────────────────────────────

/// Stores the user's target wake and sleep times.
///
/// These drive the home-tab day tube (fill extent + endpoint animations)
/// and the planner's wake/sleep card highlighting.  Call [init] once at
/// startup; listen to [wakeTime] / [sleepTime] from any widget.
class SleepScheduleStore {
  SleepScheduleStore._();
  static final SleepScheduleStore instance = SleepScheduleStore._();

  static const _wakeHourKey  = 'schedule.wake.hour';
  static const _wakeMinKey   = 'schedule.wake.minute';
  static const _sleepHourKey = 'schedule.sleep.hour';
  static const _sleepMinKey  = 'schedule.sleep.minute';

  final ValueNotifier<TimeOfDay> wakeTime =
      ValueNotifier<TimeOfDay>(const TimeOfDay(hour: 6, minute: 0));
  final ValueNotifier<TimeOfDay> sleepTime =
      ValueNotifier<TimeOfDay>(const TimeOfDay(hour: 22, minute: 0));

  /// Minutes since midnight for the wake target.
  int get wakeMinutes => wakeTime.value.hour * 60 + wakeTime.value.minute;

  /// Minutes since midnight for the sleep target.
  int get sleepMinutes => sleepTime.value.hour * 60 + sleepTime.value.minute;

  /// Planned sleep duration in minutes (handles crossing midnight).
  int get plannedSleepMinutes {
    final w = wakeMinutes;
    final s = sleepMinutes;
    return w >= s ? w - s : 24 * 60 - s + w;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final wh = prefs.getInt(_wakeHourKey);
    final wm = prefs.getInt(_wakeMinKey);
    if (wh != null) wakeTime.value = TimeOfDay(hour: wh, minute: wm ?? 0);
    final sh = prefs.getInt(_sleepHourKey);
    final sm = prefs.getInt(_sleepMinKey);
    if (sh != null) sleepTime.value = TimeOfDay(hour: sh, minute: sm ?? 0);
  }

  Future<void> setWake(TimeOfDay t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_wakeHourKey, t.hour);
    await prefs.setInt(_wakeMinKey, t.minute);
    wakeTime.value = t;
  }

  Future<void> setSleep(TimeOfDay t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sleepHourKey, t.hour);
    await prefs.setInt(_sleepMinKey, t.minute);
    sleepTime.value = t;
  }
}
