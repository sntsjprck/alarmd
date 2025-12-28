import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../models/alarm.dart';

typedef AlarmTriggerCallback = void Function(Alarm alarm);

class AlarmScheduler {
  Timer? _timer;
  List<Alarm> _alarms = [];
  // Track triggered alarms with timestamp to handle day rollover properly
  final Map<String, DateTime> _triggeredAlarms = {};
  AlarmTriggerCallback? onAlarmTriggered;
  DateTime? _lastCheckTime;

  // Grace period in seconds - if we check within this window, still trigger
  static const int _gracePeriodSeconds = 90;

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    developer.log('[$timestamp] AlarmScheduler: $message', name: 'Alarmd');
    // Also print to console for debugging
    debugPrint('[$timestamp] AlarmScheduler: $message');
  }

  void start() {
    _timer?.cancel();
    _lastCheckTime = null;
    _log('Scheduler started');
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    // Immediately perform a check on start
    _tick();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _log('Scheduler stopped');
  }

  void updateAlarms(List<Alarm> alarms) {
    _alarms = alarms;
    _log('Alarms updated: ${alarms.length} alarms, ${alarms.where((a) => a.enabled).length} enabled');
  }

  void _tick() {
    final now = DateTime.now();
    final currentMinute = now.hour * 60 + now.minute;

    // Detect if we missed time (app was suspended, system slept, etc.)
    if (_lastCheckTime != null) {
      final elapsed = now.difference(_lastCheckTime!).inSeconds;
      if (elapsed > 5) {
        _log('WARNING: Large gap detected - ${elapsed}s since last check. Performing catch-up.');
        _performCatchUp(_lastCheckTime!, now);
      }
    }

    // Clean up old triggered alarms (from previous days)
    _cleanupTriggeredAlarms(now);

    // Check for current minute matches
    final matchingAlarms = _findMatchingAlarms(now, currentMinute);

    // Trigger each matching alarm
    for (final alarm in matchingAlarms) {
      _log('TRIGGERING alarm: ${alarm.id} at ${alarm.hour}:${alarm.minute.toString().padLeft(2, '0')}');
      _triggeredAlarms[alarm.id] = now;
      onAlarmTriggered?.call(alarm);
    }

    _lastCheckTime = now;
  }

  /// Catch-up mechanism: check for any alarms that should have fired
  /// between lastCheck and now
  void _performCatchUp(DateTime from, DateTime to) {
    _log('Catch-up: checking alarms between $from and $to');

    for (final alarm in _alarms) {
      if (!alarm.enabled) continue;
      if (_wasTriggeredToday(alarm.id, to)) continue;

      // Create DateTime for alarm time today
      final alarmTime = DateTime(to.year, to.month, to.day, alarm.hour, alarm.minute);

      // Check if alarm time falls within the missed window
      if (alarmTime.isAfter(from) && alarmTime.isBefore(to.add(const Duration(seconds: 1)))) {
        _log('CATCH-UP: Triggering missed alarm ${alarm.id} scheduled for ${alarm.hour}:${alarm.minute.toString().padLeft(2, '0')}');
        _triggeredAlarms[alarm.id] = to;
        onAlarmTriggered?.call(alarm);
      }
    }
  }

  List<Alarm> _findMatchingAlarms(DateTime now, int currentMinute) {
    final matchingAlarms = <Alarm>[];

    for (final alarm in _alarms) {
      if (!alarm.enabled) continue;
      if (_wasTriggeredToday(alarm.id, now)) continue;

      final alarmMinute = alarm.hour * 60 + alarm.minute;

      // Check exact match OR within grace period (for catch-up)
      if (alarmMinute == currentMinute) {
        matchingAlarms.add(alarm);
      } else {
        // Check grace period: if alarm time was within last _gracePeriodSeconds
        final alarmTime = DateTime(now.year, now.month, now.day, alarm.hour, alarm.minute);
        final diff = now.difference(alarmTime).inSeconds;

        // Alarm is within grace period (just passed, within 90 seconds)
        if (diff > 0 && diff <= _gracePeriodSeconds) {
          _log('Grace period trigger for alarm ${alarm.id} ($diff seconds late)');
          matchingAlarms.add(alarm);
        }
      }
    }

    // Sort by time (earlier first) for queue processing
    matchingAlarms.sort((a, b) {
      final aMinutes = a.hour * 60 + a.minute;
      final bMinutes = b.hour * 60 + b.minute;
      return aMinutes.compareTo(bMinutes);
    });

    return matchingAlarms;
  }

  bool _wasTriggeredToday(String alarmId, DateTime now) {
    final triggeredTime = _triggeredAlarms[alarmId];
    if (triggeredTime == null) return false;

    // Check if triggered on the same day
    return triggeredTime.year == now.year &&
           triggeredTime.month == now.month &&
           triggeredTime.day == now.day;
  }

  void _cleanupTriggeredAlarms(DateTime now) {
    // Remove entries from previous days
    _triggeredAlarms.removeWhere((id, triggeredTime) {
      return triggeredTime.year != now.year ||
             triggeredTime.month != now.month ||
             triggeredTime.day != now.day;
    });
  }

  void scheduleSnooze(Alarm alarm, int minutes) {
    final now = DateTime.now();
    final snoozeTime = now.add(Duration(minutes: minutes));

    _log('Scheduling snooze for alarm ${alarm.id}: $minutes minutes (until ${snoozeTime.hour}:${snoozeTime.minute.toString().padLeft(2, '0')})');

    // Remove from triggered map so it can trigger again
    _triggeredAlarms.remove(alarm.id);

    // Create a one-shot timer for the snooze
    Timer(Duration(minutes: minutes), () {
      final currentTime = DateTime.now();

      // Allow a 60-second grace window for snooze trigger
      final diff = currentTime.difference(snoozeTime).inSeconds.abs();

      if (diff <= 60) {
        _log('Snooze triggered for alarm ${alarm.id}');
        _triggeredAlarms[alarm.id] = currentTime;
        onAlarmTriggered?.call(alarm);
      } else {
        _log('WARNING: Snooze timer expired outside grace window for alarm ${alarm.id} (diff: ${diff}s)');
        // Still trigger anyway - better late than never
        _triggeredAlarms[alarm.id] = currentTime;
        onAlarmTriggered?.call(alarm);
      }
    });
  }

  void markAsTriggered(String alarmId) {
    _triggeredAlarms[alarmId] = DateTime.now();
  }

  void clearTriggered(String alarmId) {
    _triggeredAlarms.remove(alarmId);
  }

  void dispose() {
    stop();
    _log('Scheduler disposed');
  }
}
