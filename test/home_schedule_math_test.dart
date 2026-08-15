import 'package:batterie/pages/home_tab/data/mode_advice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('home schedule math', () {
    test('sleep after midnight does not mark the whole day as sleep', () {
      const wake = 8 * 60;
      const sleep = 0;

      expect(
        isSleepWindowFor(12 * 60, wakeMinutes: wake, sleepMinutes: sleep),
        isFalse,
      );
      expect(
        isSleepWindowFor(23 * 60, wakeMinutes: wake, sleepMinutes: sleep),
        isFalse,
      );
      expect(
        isSleepWindowFor(1 * 60, wakeMinutes: wake, sleepMinutes: sleep),
        isTrue,
      );
      expect(
        isWakeWindowFor(8 * 60 + 30, wakeMinutes: wake),
        isTrue,
      );
    });

    test('planner slots can cross midnight', () {
      final slots = plannerSlotsFor(wakeMinutes: 8 * 60, sleepMinutes: 0);

      expect(slots, hasLength(kSlotCount));
      expect(slots.first.startMinutes, 10 * 60);
      expect(slots.last.endMinutes, kDayMinutes);
      expect(slots.any((slot) => slot.contains(23 * 60)), isTrue);
      expect(slots.any((slot) => slot.contains(1 * 60)), isFalse);
    });

    test('wrapped time slots contain after-midnight minutes', () {
      const slot = TimeSlot(startMinutes: 22 * 60, endMinutes: 25 * 60);

      expect(slot.contains(23 * 60), isTrue);
      expect(slot.contains(30), isTrue);
      expect(slot.contains(3 * 60), isFalse);
    });
  });
}
