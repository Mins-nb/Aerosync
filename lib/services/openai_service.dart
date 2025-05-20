import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OpenAIService {
  final String apiKey;
  OpenAIService(this.apiKey);

  Future<String?> analyzeMeal(String meal) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
    final body = jsonEncode({
      'model': 'gpt-4',
      'messages': [
        {
          'role': 'system',
          'content': '''You are a nutritionist. For the following meal, do the following:
1. If the user did not specify serving size or grams, first state what the default serving size (in grams) is for this food, and that the nutrition info is based on that.
2. Output the nutrition facts in this format, one per line:
칼로리 123
단백질 12g
지방 5g
탄수화물 30g
3. On a new line, output ONLY ONE representative emoji for this food. The emoji should be alone on its own line, and should be the most suitable emoji for the food (e.g. 닭고기→🍗, 피자→🍕, 밥→🍚, 고구마→🍠, 샐러드→🥗, 계란→🥚, 생선→🐟, 빵→🍞, 고기→🥩, 라면→🍜, 햄버거→🍔, 케이크→🍰, 과일→🍎, 커피→☕️, 우유→🥛, 치즈→🧀, 초콜릿→🍫, 아이스크림→🍦, 샌드위치→🥪 등). Do not add any explanation to the emoji, just the emoji itself on its own line.
Respond only in Korean.'''
        },
        {
          'role': 'user',
          'content': meal
        }
      ],
      'max_tokens': 4000
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final decoded = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decoded);
        final result = data['choices'][0]['message']['content'];
        return result;
      } else {
        return '분석 실패: ${response.statusCode}';
      }
    } catch (e) {
      return '분석 중 오류 발생: $e';
    }
  }

  Future<String> getIngredientEmoji(String ingredient) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
    final body = jsonEncode({
      'model': 'gpt-4',
      'messages': [
        {
          'role': 'system',
          'content': '''You are a nutritionist. For the following meal, do the following:
3. On a new line, output ONLY ONE representative emoji for this food. The emoji should be alone on its own line, and should be the most suitable emoji for the food (e.g. 닭고기→🍗, 피자→🍕, 밥→🍚, 고구마→🍠, 샐러드→🥗, 계란→🥚, 생선→🐟, 빵→🍞, 고기→🥩, 라면→🍜, 햄버거→🍔, 케이크→🍰, 과일→🍎, 커피→☕️, 우유→🥛, 치즈→🧀, 초콜릿→🍫, 아이스크림→🍦, 샌드위치→🥪 등). Do not add any explanation to the emoji, just the emoji itself on its own line.
Respond only in Korean.'''
        },
        {
          'role': 'user',
          'content': ingredient
        }
      ],
      'max_tokens': 8
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final decoded = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decoded);
        final result = data['choices'][0]['message']['content']?.trim();
        print('[OpenAI emoji raw result] $result');
        if (result != null && result.isNotEmpty) {
          final lines = result.trim().split('\n').where((l) => l.trim().isNotEmpty).toList();
          for (final line in lines) {
            final trimmed = line.trim();
            print('[OpenAI emoji line] "$trimmed"');
            if (trimmed.characters.isNotEmpty) {
              final firstChar = trimmed.characters.first;
              if (RegExp(r'^[\u{1F300}-\u{1FAFF}\u2600-\u27BF]', unicode: true).hasMatch(firstChar)) {
                return firstChar;
              }
            }
          }
        }
      }
      return '🥕'; // 실패 시 기본값
    } catch (e) {
      return '🥕';
    }
  }

  // 전체 식단 계획 분석
  Future<String?> analyzeDietPlan({
    required List<dynamic> meals,
    required List<String> ingredients,
    required double weight,
    required String goal,
    int? mealsPerDay,
  }) async {
    if (kDebugMode) {
      print('식단 분석 시작: ${meals.length} 항목');
    }
    
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
    
    // 식단 데이터를 포맷팅하여 GPT에게 전달
    String mealsDescription = '';
    int count = 0;
    for (var meal in meals) {
      if (count < 10) { // 토큰 제한을 고려하여 최대 10개 항목만 포함
        mealsDescription += "음식: ${meal['food_name'] ?? meal['name'] ?? '알 수 없음'}, ";
        mealsDescription += "양: ${meal['amount'] ?? 0}g, ";
        mealsDescription += "칼로리: ${meal['calories'] ?? 0}, ";
        mealsDescription += "탄수화물: ${meal['carbs'] ?? 0}g, ";
        mealsDescription += "단백질: ${meal['protein'] ?? 0}g, ";
        mealsDescription += "지방: ${meal['fat'] ?? 0}g\n";
        count++;
      }
    }
    
    final body = jsonEncode({
      'model': 'gpt-4-turbo-preview',
      'messages': [
        {
          'role': 'system',
          'content': '''당신은 영양학 전문가입니다. 사용자의 식단을 분석하고 맞춤형 조언을 제공해야 합니다.'''
        },
        {
          'role': 'user',
          'content': '''사용자 정보:
- 체중: ${weight}kg
- 목표: $goal
- 선호 재료: ${ingredients.join(', ')}
- 하루 식사 수: ${mealsPerDay ?? 3}회

다음은 추천된 식단입니다:
$mealsDescription

이 식단에 대한 분석을 다음 형식으로 제공해 주세요:

## 전체 영양 요약
(총 칼로리, 단백질, 탄수화물, 지방 등 전체 영양소 요약 및 균형 평가)

## 식단 평가
(선호 재료의 활용도, 식단 다양성, 목표 달성 가능성 등 평가)

## 식사 구성 제안
(식사 타이밍, 구성 개선 등에 대한 제안)

## 목표 달성을 위한 조언
(목표에 따른 조언: 다이어트, 근육 증가, 유지 등에 맞는 구체적 조언)

마크다운 형식으로 응답해 주세요. 전문가답게 설명하되 사용자가 이해하기 쉽도록 작성해 주세요.
'''
        }
      ],
      'max_tokens': 3000,
      'temperature': 0.7,
    });

    try {
      if (kDebugMode) {
        print('OpenAI API 요청 전송');
      }
      
      final response = await http.post(url, headers: headers, body: body);
      
      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('분석 응답 수신 성공');
        }
        
        final decoded = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decoded);
        final result = data['choices'][0]['message']['content'];
        return result;
      } else {
        if (kDebugMode) {
          print('분석 실패: ${response.statusCode}, 응답: ${response.body}');
        }
        return '식단 분석 실패: ${response.statusCode}';
      }
    } catch (e) {
      if (kDebugMode) {
        print('분석 중 오류 발생: $e');
      }
      return '분석 중 오류 발생: $e';
    }
  }
}
