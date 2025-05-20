import 'package:shared_preferences/shared_preferences.dart';

class CalorieService {
  // SharedPreferences 키 상수
  static const String _targetCalorieIntakeKey = 'target_calorie_intake';
  static const String _targetExerciseCalorieKey = 'target_exercise_calorie';
  static const String _dailyCalorieIntakeKey = 'daily_calorie_intake';
  static const String _dailyExerciseCalorieKey = 'daily_exercise_calorie';
  static const String _dateFormatKey = 'yyyy-MM-dd';

  // 목표 칼로리 설정
  static Future<void> saveCalorieTargets({
    required int dailyCalorieIntake,
    required int exerciseCalorieTarget,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_targetCalorieIntakeKey, dailyCalorieIntake);
    await prefs.setInt(_targetExerciseCalorieKey, exerciseCalorieTarget);
  }

  // 목표 칼로리 불러오기
  static Future<Map<String, int>> getCalorieTargets() async {
    final prefs = await SharedPreferences.getInstance();
    final calorieIntake = prefs.getInt(_targetCalorieIntakeKey) ?? 3000; // 기본값
    final exerciseCalorie = prefs.getInt(_targetExerciseCalorieKey) ?? 500; // 기본값
    
    return {
      'calorieIntake': calorieIntake,
      'exerciseCalorie': exerciseCalorie,
    };
  }

  // 특정 날짜의 실제 섭취 칼로리 저장
  static Future<void> saveDailyCalorieIntake(DateTime date, int calories) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = '${_dailyCalorieIntakeKey}_${_formatDate(date)}';
    await prefs.setInt(dateKey, calories);
  }

  // 특정 날짜의 실제 운동 칼로리 저장
  static Future<void> saveDailyExerciseCalorie(DateTime date, int calories) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = '${_dailyExerciseCalorieKey}_${_formatDate(date)}';
    await prefs.setInt(dateKey, calories);
  }

  // 특정 날짜의 실제 섭취 칼로리 불러오기
  static Future<int> getDailyCalorieIntake(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = '${_dailyCalorieIntakeKey}_${_formatDate(date)}';
    return prefs.getInt(dateKey) ?? 0;
  }

  // 특정 날짜의 실제 운동 칼로리 불러오기
  static Future<int> getDailyExerciseCalorie(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = '${_dailyExerciseCalorieKey}_${_formatDate(date)}';
    return prefs.getInt(dateKey) ?? 0;
  }

  // 특정 날짜의 칼로리 목표 달성 여부 (식이)
  static Future<bool> isCalorieIntakeGoalAchieved(DateTime date) async {
    final target = await getCalorieTargets();
    final actual = await getDailyCalorieIntake(date);
    
    // 칼로리 섭취는 목표치 이하여야 성공
    return actual <= target['calorieIntake']!;
  }

  // 특정 날짜의 운동 목표 달성 여부
  static Future<bool> isExerciseGoalAchieved(DateTime date) async {
    final target = await getCalorieTargets();
    final actual = await getDailyExerciseCalorie(date);
    
    // 운동 칼로리는 목표치 이상이어야 성공
    return actual >= target['exerciseCalorie']!;
  }

  // 특정 날짜의 전체 목표 달성 여부
  static Future<bool> isDailyGoalAchieved(DateTime date) async {
    final calorieGoalAchieved = await isCalorieIntakeGoalAchieved(date);
    final exerciseGoalAchieved = await isExerciseGoalAchieved(date);
    
    // 둘 다 성공해야 전체 성공
    return calorieGoalAchieved && exerciseGoalAchieved;
  }

  // 날짜 포맷 헬퍼 함수
  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
