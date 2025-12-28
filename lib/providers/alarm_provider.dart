import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/alarm.dart';
import '../services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final alarmListProvider = StateNotifierProvider<AlarmNotifier, List<Alarm>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return AlarmNotifier(storage);
});

class AlarmNotifier extends StateNotifier<List<Alarm>> {
  final StorageService _storage;
  final Uuid _uuid = const Uuid();

  AlarmNotifier(this._storage) : super([]);

  Future<void> loadAlarms() async {
    state = _storage.getAllAlarms();
  }

  Future<void> addAlarm({
    required int hour,
    required int minute,
    String? label,
    String soundAsset = 'assets/sounds/standard.mp3',
  }) async {
    final alarm = Alarm(
      id: _uuid.v4(),
      hour: hour,
      minute: minute,
      label: label,
      soundAsset: soundAsset,
    );
    await _storage.addAlarm(alarm);
    state = _storage.getAllAlarms();
  }

  Future<void> addMultipleAlarms({
    required List<({int hour, int minute})> times,
    String? label,
    String soundAsset = 'assets/sounds/standard.mp3',
  }) async {
    for (final time in times) {
      final alarm = Alarm(
        id: _uuid.v4(),
        hour: time.hour,
        minute: time.minute,
        label: label,
        soundAsset: soundAsset,
      );
      await _storage.addAlarm(alarm);
    }
    state = _storage.getAllAlarms();
  }

  Future<void> toggleAlarm(String id, bool enabled) async {
    await _storage.toggleAlarm(id, enabled);
    state = _storage.getAllAlarms();
  }

  Future<void> deleteAlarm(String id) async {
    await _storage.deleteAlarm(id);
    state = _storage.getAllAlarms();
  }

  Future<void> updateAlarm(Alarm alarm) async {
    await _storage.updateAlarm(alarm);
    state = _storage.getAllAlarms();
  }

  Future<void> resetSnoozeCount(String id) async {
    await _storage.resetSnoozeCount(id);
    state = _storage.getAllAlarms();
  }

  Future<void> incrementSnoozeCount(String id) async {
    await _storage.incrementSnoozeCount(id);
    state = _storage.getAllAlarms();
  }

  Alarm? getAlarm(String id) {
    return _storage.getAlarm(id);
  }
}
