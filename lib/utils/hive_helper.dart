import 'package:hive/hive.dart';
import '../models/user.dart';
import '../models/record.dart';

class HiveHelper {
  static Box<User> get userBox => Hive.box<User>('userBox');
  static Box<Record> get recordBox => Hive.box<Record>('recordBox');

  // 사용자 정보 저장
  static Future<void> saveUser(User user) async {
    await userBox.put('profile', user);
  }

  // 사용자 정보 불러오기
  static User? getUser() {
    return userBox.get('profile');
  }

  // 운동 기록 추가
  static Future<void> addRecord(Record record) async {
    await recordBox.add(record);
  }

  // 운동 기록 전체 불러오기
  static List<Record> getRecords() {
    return recordBox.values.toList();
  }

  // 운동 기록 삭제
  static Future<void> deleteRecord(int key) async {
    await recordBox.delete(key);
  }

  // 전체 기록 삭제
  static Future<void> clearRecords() async {
    await recordBox.clear();
  }
}
