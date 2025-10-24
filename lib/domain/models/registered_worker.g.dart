// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'registered_worker.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RegisteredWorkerAdapter extends TypeAdapter<RegisteredWorker> {
  @override
  final int typeId = 1;

  @override
  RegisteredWorker read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RegisteredWorker(
      name: fields[0] as String,
      embedding: (fields[1] as List).cast<double>(),
    );
  }

  @override
  void write(BinaryWriter writer, RegisteredWorker obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.embedding);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegisteredWorkerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
