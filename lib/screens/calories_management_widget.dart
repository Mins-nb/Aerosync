import 'package:flutter/material.dart';
import '../screens/calorie_result_screen.dart';
import '../screens/bmi_calculator_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 칼로리 관리 위젯
/// 홈 화면에서 분리하여 코드를 더 깔끔하게 관리
class CaloriesManagementWidget extends StatelessWidget {
  const CaloriesManagementWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // 헤더 영역
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Row(
                  children: [
                    Icon(Icons.fitness_center, color: Color(0xFFFFD600)),
                    SizedBox(width: 8),
                    Text(
                      '칼로리 관리',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 구분선
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          
          // 버튼 영역
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: Row(
              children: [
                // 칼로리 계산 버튼
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const BMICalculatorScreen()),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        children: const [
                          Icon(Icons.calculate_outlined, color: Color(0xFF3C4452), size: 28),
                          SizedBox(height: 8),
                          Text('칼로리 계산', style: TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // 구분선
                Container(height: 40, width: 1, color: Color(0xFFEEEEEE)),
                
                // 결과 확인 버튼
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      try {
                        // SharedPreferences에서 가장 최근 칼로리 계산 결과 정보 가져오기
                        final prefs = await SharedPreferences.getInstance();
                        final height = prefs.getDouble('last_calorie_calc_height');
                        final weight = prefs.getDouble('last_calorie_calc_weight');
                        final targetWeight = prefs.getDouble('last_calorie_calc_target_weight');
                        final bmr = prefs.getDouble('last_calorie_calc_bmr');
                        final days = prefs.getInt('last_calorie_calc_days') ?? 30;
                        final calcDate = prefs.getString('last_calorie_calc_date');
                        
                        // 저장된 날짜 형식이 유효한지 확인
                        DateTime startDate;
                        try {
                          startDate = calcDate != null ? DateTime.parse(calcDate) : DateTime.now();
                        } catch (e) {
                          startDate = DateTime.now();
                        }
                        
                        if (height != null && weight != null && targetWeight != null && bmr != null) {
                          // 저장된 데이터가 있으면 결과 화면으로 이동
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CalorieResultScreen(
                                height: height,
                                weight: weight,
                                targetWeight: targetWeight,
                                bmr: bmr,
                                startDate: startDate,
                                durationInDays: days,
                              ),
                            ),
                          );
                          
                          // 홈 화면 데이터 리프레시 알림
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('칼로리 계산 결과가 업데이트되었습니다.'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        } else {
                          // 저장된 데이터가 없으면 토스트 메시지
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('이전 칼로리 계산 결과가 없습니다. 먼저 칼로리 계산을 해보세요.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        print('결과 확인 오류: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('결과를 불러오는 중 오류가 발생했습니다.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        children: const [
                          Icon(Icons.bar_chart, color: Color(0xFF3C4452), size: 28),
                          SizedBox(height: 8),
                          Text('결과 확인', style: TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
