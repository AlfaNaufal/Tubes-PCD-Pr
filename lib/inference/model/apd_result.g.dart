// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apd_result.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ApdResultAdapter extends TypeAdapter<ApdResult> {
  @override
  final int typeId = 1;

  @override
  ApdResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ApdResult(
      label: fields[0] as String,
      confidence: fields[1] as double,
      left: fields[2] as double,
      top: fields[3] as double,
      right: fields[4] as double,
      bottom: fields[5] as double,
    );
  }

  @override
  void write(BinaryWriter writer, ApdResult obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.label)
      ..writeByte(1)
      ..write(obj.confidence)
      ..writeByte(2)
      ..write(obj.left)
      ..writeByte(3)
      ..write(obj.top)
      ..writeByte(4)
      ..write(obj.right)
      ..writeByte(5)
      ..write(obj.bottom);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApdResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
