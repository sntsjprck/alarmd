// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alarm.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AlarmAdapter extends TypeAdapter<Alarm> {
  @override
  final int typeId = 0;

  @override
  Alarm read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Alarm(
      id: fields[0] as String,
      hour: fields[1] as int,
      minute: fields[2] as int,
      enabled: fields[3] as bool,
      label: fields[4] as String?,
      snoozeCount: fields[5] as int,
      maxSnooze: fields[6] as int,
      soundAsset: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Alarm obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.hour)
      ..writeByte(2)
      ..write(obj.minute)
      ..writeByte(3)
      ..write(obj.enabled)
      ..writeByte(4)
      ..write(obj.label)
      ..writeByte(5)
      ..write(obj.snoozeCount)
      ..writeByte(6)
      ..write(obj.maxSnooze)
      ..writeByte(7)
      ..write(obj.soundAsset);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlarmAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
