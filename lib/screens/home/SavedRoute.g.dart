// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'SavedRoute.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SavedRouteAdapter extends TypeAdapter<SavedRoute> {
  @override
  final int typeId = 1;

  @override
  SavedRoute read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavedRoute(
      name: fields[0] as String,
      points: (fields[1] as List).cast<LatLngPoint>(),
      dateTime: fields[2] as DateTime,
      distance: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, SavedRoute obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.points)
      ..writeByte(2)
      ..write(obj.dateTime)
      ..writeByte(3)
      ..write(obj.distance);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedRouteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
