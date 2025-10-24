// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_api_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AdminApiConfigAdapter extends TypeAdapter<AdminApiConfig> {
  @override
  final int typeId = 2;

  @override
  AdminApiConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AdminApiConfig(
      endpointUrl: fields[0] as String,
      apiKey: fields[1] as String?,
      customHeader: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AdminApiConfig obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.endpointUrl)
      ..writeByte(1)
      ..write(obj.apiKey)
      ..writeByte(2)
      ..write(obj.customHeader);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminApiConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
