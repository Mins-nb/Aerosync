import 'package:flutter/foundation.dart';
import 'calorie_service.dart';
import 'exercise_service.dart';

/// Global state manager to prevent dependency issues from static references to widget states
/// This acts as a central hub for state that needs to be shared across widgets
class AppStateManager {
  // Singleton pattern
  static final AppStateManager _instance = AppStateManager._internal();
  factory AppStateManager() => _instance;
  AppStateManager._internal();

  // Calorie state
  final ValueNotifier<int> currentCalorieIntake = ValueNotifier<int>(0);
  final ValueNotifier<int> targetCalorieIntake = ValueNotifier<int>(3000);

  // Exercise state
  final ValueNotifier<int> currentExerciseCalories = ValueNotifier<int>(0);
  final ValueNotifier<int> targetExerciseCalories = ValueNotifier<int>(500);
  
  // Exercise bar state
  final ValueNotifier<int> currentExerciseKcal = ValueNotifier<int>(0);
  final ValueNotifier<int> targetExerciseKcal = ValueNotifier<int>(300);
  
  // Load all target values
  Future<void> loadAllTargets() async {
    try {
      // Load calorie targets from services
      final calorieTargets = await CalorieService.getCalorieTargets();
      final exerciseTargets = await ExerciseService.getExerciseTargets();
      
      // Update notifiers
      targetCalorieIntake.value = calorieTargets['calorieIntake'] ?? 3000;
      targetExerciseCalories.value = calorieTargets['exerciseCalorie'] ?? 500;
      targetExerciseKcal.value = exerciseTargets['exerciseGoal'] ?? 300;
      
      // Load current exercise calories
      final calculatedCalories = await ExerciseService.calculateTotalExerciseCalories();
      currentExerciseKcal.value = calculatedCalories;
    } catch (e) {
      print('Error loading targets in AppStateManager: $e');
    }
  }
  
  // Update calorie intake
  void updateCalorieIntake(int calories) {
    currentCalorieIntake.value = calories;
  }
  
  // Update exercise calories
  void updateExerciseCalories(int calories) {
    currentExerciseCalories.value = calories;
  }
  
  // Update exercise kcal with service call
  Future<void> updateExerciseKcal(int kcal) async {
    currentExerciseKcal.value = kcal;
    await ExerciseService.updateExerciseDone(kcal);
  }
  
  // Refresh all target values
  Future<void> refreshAllTargets() async {
    await loadAllTargets();
  }
}

// Global instance for easy access
final appStateManager = AppStateManager();
