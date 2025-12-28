// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 1;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      maxSnoozeCount: fields[0] as int,
      snoozeIntervals: (fields[1] as List?)?.cast<int>(),
      defaultSoundAsset: fields[2] as String,
      availableSounds: (fields[3] as List?)?.cast<String>(),
      volume: fields[4] as double,
      minimizeToTray: fields[5] == null ? true : fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.maxSnoozeCount)
      ..writeByte(1)
      ..write(obj.snoozeIntervals)
      ..writeByte(2)
      ..write(obj.defaultSoundAsset)
      ..writeByte(3)
      ..write(obj.availableSounds)
      ..writeByte(4)
      ..write(obj.volume)
      ..writeByte(5)
      ..write(obj.minimizeToTray);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
