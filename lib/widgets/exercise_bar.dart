import 'package:flutter/material.dart';
import '../services/app_state_manager.dart';

class ExerciseBar extends StatefulWidget {
  const ExerciseBar({Key? key}) : super(key: key);

  // 정적 메서드는 이제 중앙 상태 관리자를 통해 동작
  static void updateKcal(int kcal) async {
    await appStateManager.updateExerciseKcal(kcal);
  }

  // 새로 계산된 목표 칼로리를 강제로 로드하는 메서드
  static void refreshTargetKcal() {
    appStateManager.refreshAllTargets();
  }

  @override
  State<ExerciseBar> createState() => ExerciseBarState();
}

class ExerciseBarState extends State<ExerciseBar> {
  @override
  void initState() {
    super.initState();
    // 앱 시작시 전체 데이터 로드 요청
    appStateManager.loadAllTargets();
  }
  
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: appStateManager.currentExerciseKcal,
      builder: (context, currentKcal, _) {
        return ValueListenableBuilder<int>(
          valueListenable: appStateManager.targetExerciseKcal,
          builder: (context, targetKcal, _) {
            // 비율 계산 및 초과 처리
            double ratio = targetKcal > 0 ? currentKcal / targetKcal : 0;
            ratio = ratio > 1.0 ? 1.0 : ratio;
            
            // 남은 칼로리 계산
            final remainingKcal = targetKcal - currentKcal;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Weekly Exercise Goal', 
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)
                    ),
                    Text('$targetKcal kcal', 
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)
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
                      Colors.grey[700]!
                    ),
                    minHeight: 12,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$currentKcal kcal done', 
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)
                      ),
                      Text('$remainingKcal kcal left', 
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)
                      ),
                    ],
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
