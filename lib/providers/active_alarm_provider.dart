import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/alarm.dart';
import '../models/settings.dart';
import '../services/audio_service.dart';
import '../services/notification_service.dart';
import '../services/alarm_scheduler.dart';
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

final activeAlarmProvider = StateNotifierProvider<ActiveAlarmNotifier, ActiveAlarmState>((ref) {
  final audioService = ref.watch(audioServiceProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  final alarmScheduler = ref.watch(alarmSchedulerProvider);
  final alarmNotifier = ref.watch(alarmListProvider.notifier);
  final settings = ref.watch(settingsProvider);

  return ActiveAlarmNotifier(
    audioService: audioService,
    notificationService: notificationService,
    alarmScheduler: alarmScheduler,
    alarmNotifier: alarmNotifier,
    settings: settings,
  );
});

class ActiveAlarmState {
  final Queue<Alarm> alarmQueue;
  final Alarm? currentAlarm;
  final bool isRinging;

  const ActiveAlarmState({
    required this.alarmQueue,
    this.currentAlarm,
    this.isRinging = false,
  });

  ActiveAlarmState copyWith({
    Queue<Alarm>? alarmQueue,
    Alarm? currentAlarm,
    bool? isRinging,
    bool clearCurrentAlarm = false,
  }) {
    return ActiveAlarmState(
      alarmQueue: alarmQueue ?? this.alarmQueue,
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

  ActiveAlarmNotifier({
    required this.audioService,
    required this.notificationService,
    required this.alarmScheduler,
    required this.alarmNotifier,
    required this.settings,
  }) : super(ActiveAlarmState(alarmQueue: Queue<Alarm>())) {
    alarmScheduler.onAlarmTriggered = _onAlarmTriggered;
  }

  void _onAlarmTriggered(Alarm alarm) {
    state.alarmQueue.add(alarm);
    state = state.copyWith(alarmQueue: state.alarmQueue);
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (state.isRinging || state.alarmQueue.isEmpty) return;

    final alarm = state.alarmQueue.removeFirst();
    state = state.copyWith(
      alarmQueue: state.alarmQueue,
      currentAlarm: alarm,
      isRinging: true,
    );

    await audioService.playAlarm(alarm.soundAsset, volume: settings.volume);

    await notificationService.showAlarmNotification(
      title: 'Alarm',
      body: alarm.label ?? alarm.time12Formatted,
      onDismiss: () => dismiss(),
      onSnooze: () => snooze(5),
    );
  }

  Future<void> dismiss() async {
    if (!state.isRinging) return;

    await audioService.stop();

    if (state.currentAlarm != null) {
      await alarmNotifier.resetSnoozeCount(state.currentAlarm!.id);
    }

    state = state.copyWith(
      isRinging: false,
      clearCurrentAlarm: true,
    );

    _processQueue();
  }

  Future<void> snooze(int minutes) async {
    if (!state.isRinging || state.currentAlarm == null) return;

    final alarm = state.currentAlarm!;

    if (!alarm.canSnooze) {
      await dismiss();
      return;
    }

    await audioService.stop();
    await alarmNotifier.incrementSnoozeCount(alarm.id);

    final updatedAlarm = alarmNotifier.getAlarm(alarm.id);
    if (updatedAlarm != null) {
      alarmScheduler.scheduleSnooze(updatedAlarm, minutes);
    }

    state = state.copyWith(
      isRinging: false,
      clearCurrentAlarm: true,
    );

    _processQueue();
  }

  void startScheduler(List<Alarm> alarms) {
    alarmScheduler.updateAlarms(alarms);
    alarmScheduler.start();
  }

  void updateSchedulerAlarms(List<Alarm> alarms) {
    alarmScheduler.updateAlarms(alarms);
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
