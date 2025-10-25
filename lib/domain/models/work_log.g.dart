// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'work_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkLogAdapter extends TypeAdapter<WorkLog> {
  @override
  final int typeId = 0;

  @override
  WorkLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkLog(
      workerId: fields[0] as String,
      timestamp: fields[1] as DateTime,
      isEntry: fields[2] as bool,
      isSynced: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, WorkLog obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.workerId)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.isEntry)
      ..writeByte(3)
      ..write(obj.isSynced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
