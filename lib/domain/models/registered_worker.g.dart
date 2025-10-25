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
      faceEmbeddings: (fields[1] as List)
          .map((dynamic e) => (e as List).cast<double>())
          .toList(),
      cedula: fields[3] as String,
      cargo: fields[4] as String,
      enabled: fields[5] as bool,
      id: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, RegisteredWorker obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.faceEmbeddings)
      ..writeByte(2)
      ..write(obj.id)
      ..writeByte(3)
      ..write(obj.cedula)
      ..writeByte(4)
      ..write(obj.cargo)
      ..writeByte(5)
      ..write(obj.enabled);
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
