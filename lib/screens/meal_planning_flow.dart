import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'meal_ingredient_input_screen.dart';
import 'meal_goal_and_period_screen.dart';
import 'meal_recommendation_result_screen.dart';
import '../services/meal_recommend_service.dart';

class MealPlanningFlow extends StatefulWidget {
  const MealPlanningFlow({Key? key}) : super(key: key);

  @override
  State<MealPlanningFlow> createState() => _MealPlanningFlowState();
}

class _MealPlanningFlowState extends State<MealPlanningFlow> {
  List<String> _ingredients = [];
  static const String _prefsKey = 'ingredient_list_v1';
  String? _goal;
  int? _period;
  double? _targetWeight;
  String? _allergy;
  int _meals = 3;
  String? _result;
  bool _loading = false;

  int _step = 0;

  void _goToStep(int step) {
    setState(() { _step = step; });
  }

  Future<void> _fetchRecommendation() async {
    setState(() { _loading = true; _result = null; });
    final mealService = MealRecommendService('http://localhost:8000'); // 실제 서버 주소로 변경
    try {
      // _goal은 이미 meal_goal_and_period_screen.dart에서 영어로 변환됨 (diet/bulk/maintain)
      final Map<String, dynamic> res = await mealService.recommendMeal(
        ingredients: _ingredients,
        weight: _targetWeight ?? 70.0,
        goal: _goal ?? 'maintain', // 이미 변환된 값 사용
        meals: _meals,
      );
      setState(() { _result = res['recommendation']?.toString() ?? '추천 결과 없음'; _loading = false; });
    } catch (e) {
      setState(() { _result = '추천 실패: $e'; _loading = false; });
    }
  }

  Future<void> _loadIngredients() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKey);
    if (json != null) {
      final List list = jsonDecode(json);
      setState(() {
        _ingredients = list.map<String>((e) => (e as Map<String, dynamic>)['name'].toString()).toList();
      });
    }
  }

  Future<void> _saveIngredients() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_ingredients));
  }

  @override
  void initState() {
    super.initState();
    _loadIngredients();
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 0) {
      return MealIngredientInputScreen(
        initialIngredients: _ingredients.map((e) => {'name': e}).toList(),
        onNext: (ingredients) {
          setState(() { _ingredients = ingredients.map((e) => e['name'].toString()).toList(); });
          _saveIngredients();
          _goToStep(1);
        },
      );
    } else if (_step == 1) {
      return MealGoalAndPeriodScreen(
        initialGoal: _goal,
        initialPeriod: _period,
        onPrev: () => _goToStep(0),
        onNext: ({required String goal, required int period, required double targetWeight, required String allergy, required int meals}) {
          setState(() {
            _goal = goal;
            _period = period;
            _targetWeight = targetWeight;
            _allergy = allergy;
            _meals = meals;
          });
          _goToStep(2);
          _fetchRecommendation();
        },
      );
    } else {
      return MealRecommendationResultScreen(
        ingredients: _ingredients,
        goal: _goal ?? '',
        meals: _meals ?? 3,
        weight: _targetWeight ?? 70.0,
        result: _result,
        loading: _loading,
        onRetry: _fetchRecommendation,
        onRestart: () {
          setState(() {
            _ingredients = [];
            _goal = null;
            _period = null;
            _result = null;
            _loading = false;
          });
          _saveIngredients();
          _goToStep(0);
        },
      );
    }
  }
}
