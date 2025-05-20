import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/calorie_service.dart';
import '../services/exercise_service.dart'; 
import '../widgets/meal_section.dart';
import '../widgets/exercise_bar.dart';
import '../core/app_routes.dart';

class CalorieResultScreen extends StatefulWidget {
  final double height;
  final double weight;
  final double targetWeight;
  final double bmr;
  final DateTime startDate;
  final int durationInDays;

  const CalorieResultScreen({
    Key? key,
    required this.height,
    required this.weight,
    required this.targetWeight,
    required this.bmr,
    required this.startDate,
    required this.durationInDays,
  }) : super(key: key);

  @override
  State<CalorieResultScreen> createState() => _CalorieResultScreenState();
}

class _CalorieResultScreenState extends State<CalorieResultScreen> {
  // 계산된 데이터
  double _dailyCalorieIntake = 0;
  int _exerciseGoal = 0;
  double _weightDifference = 0;
  double _bmi = 0;
  String _bmiCategory = '';
  int _daysRequired = 0;
  DateTime _targetDate = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    _calculateValues();
    _saveCalorieTargets();
    _saveCalculationResults(); // 계산 결과 저장 추가
  }
  
  // 계산 결과를 SharedPreferences에 저장
  void _saveCalculationResults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 기본 신체 정보 및 계산 결과 저장
      await prefs.setDouble('last_calorie_calc_height', widget.height);
      await prefs.setDouble('last_calorie_calc_weight', widget.weight);
      await prefs.setDouble('last_calorie_calc_target_weight', widget.targetWeight);
      await prefs.setDouble('last_calorie_calc_bmr', widget.bmr);
      await prefs.setInt('last_calorie_calc_days', widget.durationInDays);
      
      // 계산된 결과 값들도 저장
      await prefs.setDouble('last_calorie_calc_daily_intake', _dailyCalorieIntake);
      await prefs.setInt('last_calorie_calc_exercise_goal', _exerciseGoal);
      await prefs.setDouble('last_calorie_calc_bmi', _bmi);
      await prefs.setString('last_calorie_calc_bmi_category', _bmiCategory);
      await prefs.setString('last_calorie_calc_date', DateTime.now().toIso8601String());
      
    } catch (e) {
      print('계산 결과 저장 오류: $e');
    }
  }
  
  // 계산된 모든 값들을 저장하기 위한 통합 메서드
  void _calculateValues() {
    // 키를 미터 단위로 변환
    final heightInMeters = widget.height / 100;

    // BMI 계산
    _bmi = widget.weight / (heightInMeters * heightInMeters);

    // BMI 카테고리 분류
    if (_bmi < 18.5) {
      _bmiCategory = '저체중';
    } else if (_bmi < 23) {
      _bmiCategory = '정상';
    } else if (_bmi < 25) {
      _bmiCategory = '과체중';
    } else if (_bmi < 30) {
      _bmiCategory = '비만';
    } else {
      _bmiCategory = '고도비만';
    }

    // 감량/증가해야 할 체중 계산
    _weightDifference = widget.weight - widget.targetWeight;

    // 활동 인자 (일반적인 활동량 가정)
    final activityFactor = 1.55;

    // TDEE (Total Daily Energy Expenditure) 계산
    final tdee = widget.bmr * activityFactor;

    // 일일 칼로리 섭취량 계산 (목표 기간 고려)
    if (_weightDifference > 0) { // 체중 감량이 목표인 경우
      // 목표 기간에 따라 일일 칼로리 적자 계산
      // 1kg = 7700kcal 가정, 목표 기간에 명시적으로 의존하도록 변경
      double totalDeficitNeeded = _weightDifference * 7700; // 총 필요 칼로리 적자
      double dailyDeficit = totalDeficitNeeded / widget.durationInDays; // 하루 필요 칼로리 적자
      
      // 하루 적자를 식사(70%)와 운동(30%)으로 분배
      double dietDeficit = dailyDeficit * 0.7;
      double exerciseDeficit = dailyDeficit * 0.3;
      
      // 최소 안전 섭취량 보장 (1200kcal)
      _dailyCalorieIntake = math.max(1200, tdee - dietDeficit);
      
      // 운동 목표 칼로리 업데이트
      _exerciseGoal = exerciseDeficit.toInt();
    } else if (_weightDifference < 0) { // 체중 증가가 목표인 경우
      // 체중 증가도 기간에 따라 조정
      double totalSurplusNeeded = _weightDifference.abs() * 7700;
      double dailySurplus = totalSurplusNeeded / widget.durationInDays;
      
      // 증가의 70%는 식사로, 30%는 근육 운동으로 연결
      _dailyCalorieIntake = tdee + (dailySurplus * 0.7).toInt();
      _exerciseGoal = math.max(300, (dailySurplus * 0.3).toInt()); // 최소 300kcal 운동 목표
    } else { // 체중 유지가 목표인 경우
      _dailyCalorieIntake = tdee;
      _exerciseGoal = 500; // 기본 500kcal 운동 권장
    }

    // 운동 목표는 이미 위에서 칼로리 섭취량 계산할 때 설정됨

    // 사용자가 설정한 목표 기간 사용
    _daysRequired = widget.durationInDays;
    
    // 사용자 설정 기간을 기본으로 사용

    // 목표 날짜 계산 (수정된 일수 기반)
    _targetDate = DateTime(widget.startDate.year, widget.startDate.month, widget.startDate.day +
        (_daysRequired > 0 ? _daysRequired : widget.durationInDays));
  }

  // 칼로리 및 운동 목표치 저장
  void _saveCalorieTargets() async {
    try {
      // 칼로리 섭취 목표량 저장 (식사 칼로리 70%만 저장)
      int mealCalorieTarget = (_dailyCalorieIntake * 0.7).toInt(); // 식사만 해당하는 70%만 저장
      await CalorieService.saveCalorieTargets(
        dailyCalorieIntake: mealCalorieTarget,
        exerciseCalorieTarget: _exerciseGoal,
      );

      // 운동 목표 칼로리 저장
      await ExerciseService.setExerciseGoal(_exerciseGoal);

      // 순차적으로 화면 업데이트를 위해 지연
      Timer(const Duration(milliseconds: 200), () {
        if (mounted) {
          // 칼로리 바 새로고침
          CalorieBar.refreshTargetCalorie();
          CalorieBar.updateKcal(0); // 초기에는 0으로 설정

          // 운동 바 새로고침
          ExerciseBar.refreshTargetKcal();
        }
      });
    } catch (e) {
      print('칼로리 목표치 저장 오류: $e');
    }
  }
  
  
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('칼로리 계산 결과', style: TextStyle(color: Colors.white, fontWeight: FontWeight.normal)),
        backgroundColor: const Color(0xFF3C4452),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BMI 정보 카드
            Card(
              elevation: 3,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                  color: Colors.grey.shade50,
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.monitor_weight_outlined,
                          color: Color(0xFFFFD600),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'BMI 결과',
                          style: TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF424242),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'BMI: ${_bmi.toStringAsFixed(1)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD600),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD600).withOpacity(0.3),
                                spreadRadius: 0,
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            _bmiCategory,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 칼로리 목표 카드
            Card(
              elevation: 3,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                  color: Colors.grey.shade50,
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department_outlined,
                          color: Color(0xFFFFD600),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '일일 식사 칼로리',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF424242),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${(_dailyCalorieIntake * 0.7).toInt()} kcal',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _weightDifference > 0 
                            ? '(${_weightDifference.toStringAsFixed(1)}kg 감량 목표)' 
                            : _weightDifference < 0 
                                ? '(${(-_weightDifference).toStringAsFixed(1)}kg 증량 목표)' 
                                : '(체중 유지)',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '식사: ${(_dailyCalorieIntake * 0.7).toInt()} kcal • 운동: ${_exerciseGoal} kcal',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 일정 정보 카드
            Card(
              elevation: 3,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                  color: Colors.grey.shade50,
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_outlined,
                          color: Color(0xFFFFD600),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '목표 일정',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF424242),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '시작 날짜',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.startDate.year}-${widget.startDate.month.toString().padLeft(2, '0')}-${widget.startDate.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              '목표 날짜',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_targetDate.year}-${_targetDate.month.toString().padLeft(2, '0')}-${_targetDate.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '예상 소요 기간: ${_daysRequired}일',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 28),
            
            // 홈으로 돌아가기 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  // 홈 화면으로 직접 이동 (이전 화면들을 모두 제거)
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.home,
                    (route) => false, // 모든 이전 화면 제거
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD600),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  shadowColor: const Color(0xFFFFD600).withOpacity(0.4),
                ),
                child: const Text(
                  '홈으로 돌아가기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  

}