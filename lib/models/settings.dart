import 'package:hive/hive.dart';

part 'settings.g.dart';

@HiveType(typeId: 1)
class AppSettings extends HiveObject {
  @HiveField(0)
  int maxSnoozeCount;

  @HiveField(1)
  List<int> snoozeIntervals;

  @HiveField(2)
  String defaultSoundAsset;

  @HiveField(3)
  List<String> availableSounds;

  @HiveField(4)
  double volume;

  AppSettings({
    this.maxSnoozeCount = 3,
    List<int>? snoozeIntervals,
    this.defaultSoundAsset = 'assets/sounds/standard.mp3',
    List<String>? availableSounds,
    this.volume = 1.0,
  })  : snoozeIntervals = snoozeIntervals ?? [5, 10, 15],
        availableSounds = availableSounds ??
            [
              'assets/sounds/beat.mp3',
              'assets/sounds/standard.mp3',
              'assets/sounds/chill.mp3',
            ];

  AppSettings copyWith({
    int? maxSnoozeCount,
    List<int>? snoozeIntervals,
    String? defaultSoundAsset,
    List<String>? availableSounds,
    double? volume,
  }) {
    return AppSettings(
      maxSnoozeCount: maxSnoozeCount ?? this.maxSnoozeCount,
      snoozeIntervals: snoozeIntervals ?? this.snoozeIntervals,
      defaultSoundAsset: defaultSoundAsset ?? this.defaultSoundAsset,
      availableSounds: availableSounds ?? this.availableSounds,
      volume: volume ?? this.volume,
    );
  }

  String getSoundName(String path) {
    final filename = path.split('/').last.replaceAll('.mp3', '');
    return filename[0].toUpperCase() + filename.substring(1);
  }
}
