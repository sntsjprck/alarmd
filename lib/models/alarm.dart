import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'alarm.g.dart';

@HiveType(typeId: 0)
class Alarm extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int hour;

  @HiveField(2)
  final int minute;

  @HiveField(3)
  bool enabled;

  @HiveField(4)
  String? label;

  @HiveField(5)
  int snoozeCount;

  @HiveField(6)
  final int maxSnooze;

  @HiveField(7)
  final String soundAsset;

  Alarm({
    required this.id,
    required this.hour,
    required this.minute,
    this.enabled = true,
    this.label,
    this.snoozeCount = 0,
    this.maxSnooze = 3,
    this.soundAsset = 'assets/sounds/standard.mp3',
  });

  TimeOfDay get time => TimeOfDay(hour: hour, minute: minute);

  String get timeFormatted {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get time12Formatted {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  bool get canSnooze => snoozeCount < maxSnooze;

  Alarm copyWith({
    String? id,
    int? hour,
    int? minute,
    bool? enabled,
    String? label,
    int? snoozeCount,
    int? maxSnooze,
    String? soundAsset,
  }) {
    return Alarm(
      id: id ?? this.id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      enabled: enabled ?? this.enabled,
      label: label ?? this.label,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      maxSnooze: maxSnooze ?? this.maxSnooze,
      soundAsset: soundAsset ?? this.soundAsset,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Alarm && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
