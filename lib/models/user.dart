import 'package:hive/hive.dart';

// User 모델을 수동으로 정의하여 Hive 어댑터 생성 없이 사용
@HiveType(typeId: 0)
class User extends HiveObject {
  @HiveField(0)
  String? name;
  @HiveField(1)
  int? age;
  @HiveField(2)
  String? gender;
  @HiveField(3)
  double? height;
  @HiveField(4)
  double? weight;
  @HiveField(5)
  String? profileImagePath;
  @HiveField(6)
  String? uuid; // 사용자 고유 식별자

  User({
    this.name,
    this.age,
    this.gender,
    this.height,
    this.weight,
    this.profileImagePath,
    this.uuid,
  });
}

// Hive 어댑터 수동 구현
class UserAdapter extends TypeAdapter<User> {
  @override
  final int typeId = 0;

  @override
  User read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      final value = reader.read();
      fields[key] = value;
    }
    return User(
      name: fields[0] as String?,
      age: fields[1] as int?,
      gender: fields[2] as String?,
      height: fields[3] as double?,
      weight: fields[4] as double?,
      profileImagePath: fields[5] as String?,
      uuid: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer.writeByte(7);
    writer.writeByte(0);
    writer.write(obj.name);
    writer.writeByte(1);
    writer.write(obj.age);
    writer.writeByte(2);
    writer.write(obj.gender);
    writer.writeByte(3);
    writer.write(obj.height);
    writer.writeByte(4);
    writer.write(obj.weight);
    writer.writeByte(5);
    writer.write(obj.profileImagePath);
    writer.writeByte(6);
    writer.write(obj.uuid);
  }
}
