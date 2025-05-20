import 'package:flutter/material.dart';
import '../services/openai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MealPlanningScreen extends StatefulWidget {

  @override
  State<MealPlanningScreen> createState() => _MealPlanningScreenState();
}

class _MealPlanningScreenState extends State<MealPlanningScreen> {
  final TextEditingController _controller = TextEditingController();
  // 식재료 리스트: [{emoji: "🍅", name: "토마토"}, ...]
  List<Map<String, String>> _ingredientList = [];
  static const String _prefsKey = 'ingredient_list_v1';
  String _ingredientInput = '';
  String? _goal;
  int _period = 7; // 추가: 식단 기간 기본값
  bool _loading = false;
  String? _recommendResult;

  // API 키 로딩
  String get _openAIApiKey => dotenv.env['OPENAI_API_KEY'] ?? '';

  bool _emojiLoading = false;

  Future<void> _addIngredient() async {
    final name = _ingredientInput.trim();
    if (name.isEmpty) return;
    setState(() => _emojiLoading = true);
    String emoji;
    try {
      final openai = OpenAIService(_openAIApiKey);
      emoji = await openai.getIngredientEmoji(name);
    } catch (_) {
      emoji = '🥕';
    }
    setState(() {
      _ingredientList.add({'emoji': (emoji.trim().isEmpty) ? '🥕' : emoji.trim(), 'name': name});
      _ingredientInput = '';
      _controller.clear();
      _emojiLoading = false;
    });
    print(_ingredientList);
    await _saveIngredients();
  }

  void _removeIngredient(int idx) async {
    setState(() {
      _ingredientList.removeAt(idx);
    });
    await _saveIngredients();
  }

  Future<void> _recommendMeal() async {
    setState(() { _loading = true; _recommendResult = null; });
    final openai = OpenAIService(_openAIApiKey);
    // ingredientList의 이름만 콤마로 합침
    final ingredientNames = _ingredientList.map((e) => e['name']).join(', ');
    final prompt = '''아래의 재료를 활용해서 $_goal 목적에 맞는 $_period일치 식단(각 날짜별 아침, 점심, 저녁)을 표로 구성해줘.\n각 날짜별로 음식 이름, 간단한 설명, 칼로리(대략), 단백질, 지방, 탄수화물 정보를 표로 정리해줘. 반드시 한국어로만 답변해줘.\n재료: $ingredientNames''';
    final res = await openai.analyzeMeal(prompt);
    setState(() { _recommendResult = res; _loading = false; });
  }

  Future<void> _saveIngredients() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _ingredientList.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList(_prefsKey, jsonList);
  }

  Future<void> _loadIngredients() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_prefsKey);
    if (jsonList != null) {
      setState(() {
        _ingredientList = jsonList.map((e) => jsonDecode(e)).toList();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadIngredients();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('식단 준비'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '식단 준비',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('내가 가진 식재료'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '식재료를 입력하세요 (예: 토마토)',
                    ),
                    onChanged: (value) => setState(() => _ingredientInput = value),
                    onSubmitted: (_) => _addIngredient(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _emojiLoading || _ingredientInput.trim().isEmpty ? null : _addIngredient,
                  child: _emojiLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('등록'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 식재료 카드 리스트
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _ingredientList.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
  
                  final item = _ingredientList[idx];
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(item['name'] ?? '', style: const TextStyle(fontSize: 16)),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => _removeIngredient(idx),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text('목표'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _goal,
              items: const [
                DropdownMenuItem(value: '감량', child: Text('감량(다이어트)')),
                DropdownMenuItem(value: '유지', child: Text('유지')),
                DropdownMenuItem(value: '증량', child: Text('증량(벌크업)')),
              ],
              onChanged: (value) => setState(() => _goal = value),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '목표를 선택하세요',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_ingredientList.isEmpty || _goal == null || _loading)
                    ? null
                    : _recommendMeal,
                child: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('식단 추천'),
              ),
            ),
            const SizedBox(height: 32),
            const Text('추천 식단 결과', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: _recommendResult == null
                  ? const Text('여기에 추천 식단 결과 표시 예정')
                  : Text(_recommendResult!),
            ),
          ],
        ),
      ),
    );
  }
}
