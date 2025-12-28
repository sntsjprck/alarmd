import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/settings.dart';

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  static const String _boxName = 'settings';
  Box<AppSettings>? _box;

  SettingsNotifier() : super(AppSettings());

  static const List<String> _availableSounds = [
    'assets/sounds/beat.mp3',
    'assets/sounds/standard.mp3',
    'assets/sounds/chill.mp3',
  ];

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AppSettingsAdapter());
    }
    _box = await Hive.openBox<AppSettings>(_boxName);

    final stored = _box?.get('app_settings');
    if (stored != null) {
      // Always update availableSounds to match actual asset files
      state = stored.copyWith(availableSounds: _availableSounds);
      // Validate defaultSoundAsset exists, reset if not
      if (!_availableSounds.contains(state.defaultSoundAsset)) {
        state = state.copyWith(defaultSoundAsset: 'assets/sounds/standard.mp3');
      }
      await _save();
    } else {
      await _box?.put('app_settings', state);
    }
  }

  Future<void> setMaxSnoozeCount(int count) async {
    state = state.copyWith(maxSnoozeCount: count);
    await _save();
  }

  Future<void> setSnoozeIntervals(List<int> intervals) async {
    state = state.copyWith(snoozeIntervals: intervals);
    await _save();
  }

  Future<void> setDefaultSound(String soundAsset) async {
    state = state.copyWith(defaultSoundAsset: soundAsset);
    await _save();
  }

  Future<void> setVolume(double volume) async {
    state = state.copyWith(volume: volume.clamp(0.1, 1.25));
    await _save();
  }

  Future<void> setMinimizeToTray(bool value) async {
    state = state.copyWith(minimizeToTray: value);
    await _save();
  }

  Future<void> _save() async {
    await _box?.put('app_settings', state);
  }
}
