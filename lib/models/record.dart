import 'package:hive/hive.dart';

// Record 모델을 수동으로 정의하여 Hive 어댑터 생성 없이 사용
@HiveType(typeId: 1)
class Record extends HiveObject {
  @HiveField(0)
  DateTime date;
  @HiveField(1)
  int duration; // seconds
  @HiveField(2)
  double distance; // km
  @HiveField(3)
  double pace; // min/km
  @HiveField(4)
  String? recordId; // 고유 식별자

  Record({
    required this.date,
    required this.duration,
    required this.distance,
    required this.pace,
    this.recordId,
  });
}

// Hive 어댑터 수동 구현
class RecordAdapter extends TypeAdapter<Record> {
  @override
  final int typeId = 1;

  @override
  Record read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      final value = reader.read();
      fields[key] = value;
    }
    return Record(
      date: fields[0] as DateTime,
      duration: fields[1] as int,
      distance: fields[2] as double,
      pace: fields[3] as double,
      recordId: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Record obj) {
    writer.writeByte(5);
    writer.writeByte(0);
    writer.write(obj.date);
    writer.writeByte(1);
    writer.write(obj.duration);
    writer.writeByte(2);
    writer.write(obj.distance);
    writer.writeByte(3);
    writer.write(obj.pace);
    writer.writeByte(4);
    writer.write(obj.recordId);
  }
}
