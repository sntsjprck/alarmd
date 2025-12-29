import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/alarm.dart';

class StorageService {
  static const String _boxName = 'alarms';
  static const String _appDataFolder = 'alarmd';
  late Box<Alarm> _box;

  Future<void> init() async {
    // Use ~/.local/share/alarmd/ for app data (XDG compliant)
    final home = Platform.environment['HOME'] ?? '/home';
    final dataDir = Directory('$home/.local/share/$_appDataFolder');
    await dataDir.create(recursive: true);

    Hive.init(dataDir.path);
    Hive.registerAdapter(AlarmAdapter());
    _box = await Hive.openBox<Alarm>(_boxName);
  }

  List<Alarm> getAllAlarms() {
    return _box.values.toList()
      ..sort((a, b) {
        final aMinutes = a.hour * 60 + a.minute;
        final bMinutes = b.hour * 60 + b.minute;
        return aMinutes.compareTo(bMinutes);
      });
  }

  Future<void> addAlarm(Alarm alarm) async {
    await _box.put(alarm.id, alarm);
  }

  Future<void> updateAlarm(Alarm alarm) async {
    await _box.put(alarm.id, alarm);
  }

  Future<void> deleteAlarm(String id) async {
    await _box.delete(id);
  }

  Alarm? getAlarm(String id) {
    return _box.get(id);
  }

  Future<void> toggleAlarm(String id, bool enabled) async {
    final alarm = _box.get(id);
    if (alarm != null) {
      alarm.enabled = enabled;
      await alarm.save();
    }
  }

  Future<void> resetSnoozeCount(String id) async {
    final alarm = _box.get(id);
    if (alarm != null) {
      alarm.snoozeCount = 0;
      await alarm.save();
    }
  }

  Future<void> incrementSnoozeCount(String id) async {
    final alarm = _box.get(id);
    if (alarm != null) {
      alarm.snoozeCount++;
      await alarm.save();
    }
  }

  Future<void> close() async {
    await _box.close();
  }
}
