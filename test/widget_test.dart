import 'package:flutter_test/flutter_test.dart';
import 'package:alarmd/models/alarm.dart';

void main() {
  group('Alarm Model', () {
    test('creates alarm with correct time format', () {
      final alarm = Alarm(
        id: 'test-id',
        hour: 14,
        minute: 30,
      );

      expect(alarm.timeFormatted, '14:30');
      expect(alarm.time12Formatted, '2:30 PM');
    });

    test('canSnooze returns true when snoozeCount < maxSnooze', () {
      final alarm = Alarm(
        id: 'test-id',
        hour: 8,
        minute: 0,
        snoozeCount: 1,
        maxSnooze: 3,
      );

      expect(alarm.canSnooze, true);
    });

    test('canSnooze returns false when snoozeCount >= maxSnooze', () {
      final alarm = Alarm(
        id: 'test-id',
        hour: 8,
        minute: 0,
        snoozeCount: 3,
        maxSnooze: 3,
      );

      expect(alarm.canSnooze, false);
    });

    test('copyWith creates new alarm with updated values', () {
      final alarm = Alarm(
        id: 'test-id',
        hour: 8,
        minute: 0,
        label: 'Wake up',
      );

      final updated = alarm.copyWith(hour: 9, label: 'New label');

      expect(updated.hour, 9);
      expect(updated.minute, 0);
      expect(updated.label, 'New label');
      expect(updated.id, 'test-id');
    });
  });
}
