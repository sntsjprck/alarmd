import 'dart:async';
import 'package:flutter/material.dart';
import '../models/alarm.dart';

typedef AlarmTriggerCallback = void Function(Alarm alarm);

class AlarmScheduler {
  Timer? _timer;
  List<Alarm> _alarms = [];
  final Set<String> _triggeredToday = {};
  AlarmTriggerCallback? onAlarmTriggered;
  int _lastCheckedMinute = -1;

  void start() {
    _timer?.cancel();
    _lastCheckedMinute = -1;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void updateAlarms(List<Alarm> alarms) {
    _alarms = alarms;
  }

  void _tick() {
    final now = TimeOfDay.now();
    final currentMinute = now.hour * 60 + now.minute;

    // Only check once per minute (when minute changes)
    if (currentMinute == _lastCheckedMinute) return;
    _lastCheckedMinute = currentMinute;

    // Reset triggered set at midnight
    if (now.hour == 0 && now.minute == 0) {
      _triggeredToday.clear();
    }

    // Find alarms that match current time
    final matchingAlarms = _alarms.where((alarm) {
      if (!alarm.enabled) return false;
      if (_triggeredToday.contains(alarm.id)) return false;
      return alarm.hour == now.hour && alarm.minute == now.minute;
    }).toList();

    // Sort by time (earlier first) for queue processing
    matchingAlarms.sort((a, b) {
      final aMinutes = a.hour * 60 + a.minute;
      final bMinutes = b.hour * 60 + b.minute;
      return aMinutes.compareTo(bMinutes);
    });

    // Trigger each matching alarm
    for (final alarm in matchingAlarms) {
      _triggeredToday.add(alarm.id);
      onAlarmTriggered?.call(alarm);
    }
  }

  void scheduleSnooze(Alarm alarm, int minutes) {
    final now = DateTime.now();
    final snoozeTime = now.add(Duration(minutes: minutes));

    // Remove from triggered set so it can trigger again
    _triggeredToday.remove(alarm.id);

    // Create a one-shot timer for the snooze
    Timer(Duration(minutes: minutes), () {
      final currentTime = TimeOfDay.now();
      final snoozeHour = snoozeTime.hour;
      final snoozeMinute = snoozeTime.minute;

      // Only trigger if we're still within the snooze minute
      if (currentTime.hour == snoozeHour && currentTime.minute == snoozeMinute) {
        onAlarmTriggered?.call(alarm);
        _triggeredToday.add(alarm.id);
      }
    });
  }

  void markAsTriggered(String alarmId) {
    _triggeredToday.add(alarmId);
  }

  void clearTriggered(String alarmId) {
    _triggeredToday.remove(alarmId);
  }

  void dispose() {
    stop();
  }
}
