import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/alarm.dart';
import '../models/settings.dart';
import '../services/audio_service.dart';
import '../services/notification_service.dart';
import '../services/alarm_scheduler.dart';
import '../services/keep_alive_service.dart';
import '../services/systemd_timer_service.dart';
import 'alarm_provider.dart';
import 'settings_provider.dart';

final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final alarmSchedulerProvider = Provider<AlarmScheduler>((ref) {
  return AlarmScheduler();
});

final keepAliveServiceProvider = Provider<KeepAliveService>((ref) {
  return KeepAliveService();
});

final systemdTimerServiceProvider = Provider<SystemdTimerService>((ref) {
  return SystemdTimerService();
});

final activeAlarmProvider = StateNotifierProvider<ActiveAlarmNotifier, ActiveAlarmState>((ref) {
  final audioService = ref.watch(audioServiceProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  final alarmScheduler = ref.watch(alarmSchedulerProvider);
  final alarmNotifier = ref.watch(alarmListProvider.notifier);
  final settings = ref.watch(settingsProvider);
  final keepAliveService = ref.watch(keepAliveServiceProvider);
  final systemdTimerService = ref.watch(systemdTimerServiceProvider);

  return ActiveAlarmNotifier(
    audioService: audioService,
    notificationService: notificationService,
    alarmScheduler: alarmScheduler,
    alarmNotifier: alarmNotifier,
    settings: settings,
    keepAliveService: keepAliveService,
    systemdTimerService: systemdTimerService,
  );
});

class ActiveAlarmState {
  final Alarm? currentAlarm;
  final bool isRinging;

  const ActiveAlarmState({
    this.currentAlarm,
    this.isRinging = false,
  });

  ActiveAlarmState copyWith({
    Alarm? currentAlarm,
    bool? isRinging,
    bool clearCurrentAlarm = false,
  }) {
    return ActiveAlarmState(
      currentAlarm: clearCurrentAlarm ? null : (currentAlarm ?? this.currentAlarm),
      isRinging: isRinging ?? this.isRinging,
    );
  }
}

class ActiveAlarmNotifier extends StateNotifier<ActiveAlarmState> {
  final AudioService audioService;
  final NotificationService notificationService;
  final AlarmScheduler alarmScheduler;
  final AlarmNotifier alarmNotifier;
  final AppSettings settings;
  final KeepAliveService keepAliveService;
  final SystemdTimerService systemdTimerService;

  ActiveAlarmNotifier({
    required this.audioService,
    required this.notificationService,
    required this.alarmScheduler,
    required this.alarmNotifier,
    required this.settings,
    required this.keepAliveService,
    required this.systemdTimerService,
  }) : super(const ActiveAlarmState()) {
    alarmScheduler.onAlarmTriggered = _onAlarmTriggered;
  }

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    developer.log('[$timestamp] ActiveAlarmNotifier: $message', name: 'Alarmd');
    debugPrint('[$timestamp] ActiveAlarmNotifier: $message');
  }

  /// When a new alarm triggers, it REPLACES any currently ringing alarm.
  /// No stacking - latest alarm wins.
  void _onAlarmTriggered(Alarm alarm) {
    _log('Alarm triggered: ${alarm.id} (${alarm.hour}:${alarm.minute.toString().padLeft(2, '0')})');

    if (state.isRinging && state.currentAlarm != null) {
      _log('Replacing current alarm ${state.currentAlarm!.id} with new alarm ${alarm.id}');
      // Reset snooze count for the alarm being replaced (it's effectively dismissed)
      alarmNotifier.resetSnoozeCount(state.currentAlarm!.id);
    }

    // Start the new alarm immediately (replaces current)
    _startAlarm(alarm);
  }

  Future<void> _startAlarm(Alarm alarm) async {
    _log('Starting alarm: ${alarm.id}');

    state = state.copyWith(
      currentAlarm: alarm,
      isRinging: true,
    );

    // Start system inhibit to prevent sleep during alarm
    try {
      await keepAliveService.startInhibit();
    } catch (e) {
      _log('WARNING: Failed to start system inhibit: $e');
    }

    try {
      await audioService.playAlarm(alarm.soundAsset, volume: settings.volume);
      _log('Audio started for alarm ${alarm.id}');
    } catch (e) {
      _log('ERROR: Failed to play audio for alarm ${alarm.id}: $e');
    }

    try {
      await notificationService.showAlarmNotification(
        title: 'Alarm',
        body: alarm.label ?? alarm.time12Formatted,
        onDismiss: () => dismiss(),
        onSnooze: () => snooze(settings.snoozeIntervals.isNotEmpty ? settings.snoozeIntervals.first : 5),
      );
      _log('Notification shown for alarm ${alarm.id}');
    } catch (e) {
      _log('ERROR: Failed to show notification for alarm ${alarm.id}: $e');
    }
  }

  Future<void> dismiss() async {
    if (!state.isRinging) {
      _log('Dismiss called but not ringing - ignoring');
      return;
    }

    _log('Dismissing alarm: ${state.currentAlarm?.id}');

    await audioService.stop();

    // Stop system inhibit
    try {
      await keepAliveService.stopInhibit();
    } catch (e) {
      _log('WARNING: Failed to stop system inhibit: $e');
    }

    if (state.currentAlarm != null) {
      await alarmNotifier.resetSnoozeCount(state.currentAlarm!.id);
    }

    state = state.copyWith(
      isRinging: false,
      clearCurrentAlarm: true,
    );

    _log('Alarm dismissed');
  }

  Future<void> snooze(int minutes) async {
    if (!state.isRinging || state.currentAlarm == null) {
      _log('Snooze called but not ringing or no current alarm - ignoring');
      return;
    }

    final alarm = state.currentAlarm!;
    _log('Snoozing alarm ${alarm.id} for $minutes minutes');

    if (!alarm.canSnooze) {
      _log('Alarm ${alarm.id} has reached max snooze count - dismissing instead');
      await dismiss();
      return;
    }

    await audioService.stop();

    // Stop system inhibit while snoozed
    try {
      await keepAliveService.stopInhibit();
    } catch (e) {
      _log('WARNING: Failed to stop system inhibit: $e');
    }

    await alarmNotifier.incrementSnoozeCount(alarm.id);

    final updatedAlarm = alarmNotifier.getAlarm(alarm.id);
    if (updatedAlarm != null) {
      alarmScheduler.scheduleSnooze(updatedAlarm, minutes);

      // Also schedule a systemd wake as backup in case app is suspended
      final snoozeTime = DateTime.now().add(Duration(minutes: minutes));
      await systemdTimerService.scheduleSnoozeWake(snoozeTime);

      _log('Snooze scheduled for alarm ${alarm.id}');
    }

    state = state.copyWith(
      isRinging: false,
      clearCurrentAlarm: true,
    );
  }

  Future<void> startScheduler(List<Alarm> alarms) async {
    _log('Starting scheduler with ${alarms.length} alarms');
    alarmScheduler.updateAlarms(alarms);
    alarmScheduler.start();

    // Initialize and sync systemd timer for reliable background wake
    await systemdTimerService.init();
    await systemdTimerService.syncAlarms(alarms);
  }

  Future<void> updateSchedulerAlarms(List<Alarm> alarms) async {
    alarmScheduler.updateAlarms(alarms);

    // Sync to systemd timer for reliable background wake
    await systemdTimerService.syncAlarms(alarms);
  }

  void stopScheduler() {
    alarmScheduler.stop();
  }

  @override
  void dispose() {
    alarmScheduler.dispose();
    audioService.dispose();
    super.dispose();
  }
}
