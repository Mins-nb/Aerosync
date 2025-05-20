import 'package:flutter/material.dart';
import '../services/app_state_manager.dart';

class ExerciseCalorieBar extends StatefulWidget {
  const ExerciseCalorieBar({Key? key}) : super(key: key);

  // 정적 메서드는 이제 중앙 상태 관리자를 통해 동작
  static void updateCalories(int calories) {
    appStateManager.updateExerciseCalories(calories);
  }

  @override
  State<ExerciseCalorieBar> createState() => ExerciseCalorieBarState();
}

class ExerciseCalorieBarState extends State<ExerciseCalorieBar> {
  @override
  void initState() {
    super.initState();
    // 앱 시작시 전체 데이터 로드 요청
    appStateManager.loadAllTargets();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: appStateManager.currentExerciseCalories,
      builder: (context, currentCalories, _) {
        return ValueListenableBuilder<int>(
          valueListenable: appStateManager.targetExerciseCalories,
          builder: (context, targetCalories, _) {
            // 운동 칼로리는 목표보다 높을수록 좋음
            double ratio = targetCalories > 0 ? currentCalories / targetCalories : 0;
            ratio = ratio > 1.0 ? 1.0 : ratio;
            final isReached = currentCalories >= targetCalories;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Exercise Calories', 
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)
                    ),
                    Text(
                      '$currentCalories / $targetCalories kcal', 
                      style: TextStyle(
                        fontWeight: FontWeight.w600, 
                        color: isReached ? const Color(0xFF4CAF50) : Colors.black87
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: ratio,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isReached ? const Color(0xFF4CAF50) : const Color(0xFF00BCD4)
                    ),
                    minHeight: 12,
                  ),
                ),
                if (isReached)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('목표 달성!', 
                      style: TextStyle(
                        color: Color(0xFF4CAF50), 
                        fontWeight: FontWeight.bold
                      )
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
