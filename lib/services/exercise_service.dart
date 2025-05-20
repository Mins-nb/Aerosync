import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:hive/hive.dart';
import '../models/record.dart';

class ExerciseService {
  // 운동 목표 및 달성량 관련 키 정의
  static const String _exerciseGoalKey = 'exercise_goal';
  static const String _exerciseDoneKey = 'exercise_done';
  static const String _freeRunRecordsKey = 'free_run_records_v1';
  static const String _testRecordsKey = 'test_records_v1';
  
  // 주간 운동 목표 칼로리를 가져오는 메서드
  static Future<Map<String, int>> getExerciseTargets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 저장된 목표값이 있으면 사용, 없으면 기본값
      final exerciseGoal = prefs.getInt(_exerciseGoalKey) ?? 300; // 기본 300kcal
      
      // 실제 운동 기록에서 칼로리 합계 계산
      final exerciseDone = await calculateTotalExerciseCalories();
      
      return {
        'exerciseGoal': exerciseGoal,
        'exerciseDone': exerciseDone,
      };
    } catch (e) {
      print('운동 목표값 로딩 오류: $e');
      // 오류 발생시 기본값 반환
      return {
        'exerciseGoal': 300,
        'exerciseDone': 0,
      };
    }
  }
  
  // 운동 기록에서 소모된 칼로리 합계를 계산하는 메서드
  static Future<int> calculateTotalExerciseCalories() async {
    try {
      int totalCalories = 0;
      final prefs = await SharedPreferences.getInstance();
      final recordBox = Hive.box<Record>('recordBox');
      
      print('=========== 운동 칼로리 계산 시작 ===========');
      
      // Hive에서 기록 가져오기
      final records = recordBox.values.toList();
      print('총 기록 수: ${records.length}');
      
      // 이번 주에 해당하는 기록 필터링
      final now = DateTime.now();
      print('현재 날짜: ${now.toString()}');
      
      // 이번 주의 시작은 일요일부터 (weekday: 1=월, 2=화, ... 7=일)
      final startOfWeek = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      print('이번 주 시작일: ${startOfWeek.toString()}');
      
      // 자유 러닝 기록에서 칼로리 정보 확인
      List<Map<String, dynamic>> freeRunRecords = [];
      String? freeRunRecordsJson = prefs.getString(_freeRunRecordsKey);
      
      if (freeRunRecordsJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(freeRunRecordsJson) as List<dynamic>;
          freeRunRecords = List<Map<String, dynamic>>.from(decoded);
          print('자유 러닝 기록 수: ${freeRunRecords.length}');
        } catch (e) {
          print('자유 러닝 기록 업데이트 오류: $e');
          freeRunRecords = [];
        }
      } else {
        print('자유 러닝 기록이 없습니다.');
      }
      
      // 테스트 기록에서 칼로리 정보 확인
      List<Map<String, dynamic>> testRunRecords = [];
      String? testRunRecordsJson = prefs.getString(_testRecordsKey);
      
      if (testRunRecordsJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(testRunRecordsJson) as List<dynamic>;
          testRunRecords = List<Map<String, dynamic>>.from(decoded);
          print('테스트 러닝 기록 수: ${testRunRecords.length}');
        } catch (e) {
          print('테스트 러닝 기록 업데이트 오류: $e');
          testRunRecords = [];
        }
      } else {
        print('테스트 러닝 기록이 없습니다.');
      }
      
      // 모든 자유 러닝 기록에서 이번 주 기록 추출
      for (final recordData in freeRunRecords) {
        try {
          final recordDate = DateTime.parse(recordData['date'] as String);
          
          // 이번 주 기록인지 확인
          if (recordDate.isAfter(startOfWeek) || recordDate.isAtSameMomentAs(startOfWeek)) {
            final calories = recordData['calories'];
            if (calories != null) {
              final caloriesInt = calories is int ? calories : int.tryParse(calories.toString()) ?? 0;
              totalCalories += caloriesInt;
              print('자유 러닝 - 이번 주 기록 발견: 날짜=${recordData['date']}, 칼로리=$caloriesInt');
            }
          }
        } catch (e) {
          print('자유 러닝 데이터 파싱 오류: $e');
        }
      }
      
      // 모든 테스트 러닝 기록에서 이번 주 기록 추출
      for (final recordData in testRunRecords) {
        try {
          final recordDate = DateTime.parse(recordData['date'] as String);
          
          // 이번 주 기록인지 확인
          if (recordDate.isAfter(startOfWeek) || recordDate.isAtSameMomentAs(startOfWeek)) {
            final calories = recordData['calories'];
            if (calories != null) {
              final caloriesInt = calories is int ? calories : int.tryParse(calories.toString()) ?? 0;
              totalCalories += caloriesInt;
              print('테스트 러닝 - 이번 주 기록 발견: 날짜=${recordData['date']}, 칼로리=$caloriesInt');
            }
          }
        } catch (e) {
          print('테스트 러닝 데이터 파싱 오류: $e');
        }
      }
      
      // 계산된 합계 저장
      await prefs.setInt(_exerciseDoneKey, totalCalories);
      
      print('이번 주 운동 칼로리 합계: $totalCalories');
      print('=========== 운동 칼로리 계산 완료 ===========');
      return totalCalories;
    } catch (e) {
      print('운동 칼로리 계산 오류: $e');
      return 0;
    }
  }
  
  // 운동 목표 칼로리를 설정하는 메서드
  static Future<bool> setExerciseGoal(int goal) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_exerciseGoalKey, goal);
      return true;
    } catch (e) {
      print('운동 목표값 저장 오류: $e');
      return false;
    }
  }
  
  // 운동 달성 칼로리를 업데이트하는 메서드
  static Future<bool> updateExerciseDone(int done) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_exerciseDoneKey, done);
      return true;
    } catch (e) {
      print('운동 달성값 저장 오류: $e');
      return false;
    }
  }
  
  // 운동 달성량을 추가하는 메서드 (기존 값에 추가)
  static Future<bool> addExerciseDone(int additional) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_exerciseDoneKey) ?? 0;
      await prefs.setInt(_exerciseDoneKey, current + additional);
      return true;
    } catch (e) {
      print('운동 달성값 업데이트 오류: $e');
      return false;
    }
  }
  
  // 주간 운동 데이터를 초기화하는 메서드 (새로운 주가 시작될 때 호출)
  static Future<bool> resetWeeklyExercise() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_exerciseDoneKey, 0);
      return true;
    } catch (e) {
      print('주간 운동 데이터 초기화 오류: $e');
      return false;
    }
  }
}
