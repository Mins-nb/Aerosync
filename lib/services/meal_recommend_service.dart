import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class MealRecommendService {
  final String apiUrl;

  MealRecommendService(this.apiUrl);

  Future<Map<String, dynamic>> recommendMeal({
    required List<String> ingredients,
    required double weight,
    required String goal,
    required int meals,
  }) async {
    try {
      if (kDebugMode) {
        print('서버 요청 시작: ingredients=$ingredients, weight=$weight, goal=$goal, meals=$meals');
      }
      
      final response = await http.post(
        Uri.parse('$apiUrl/recommend'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'ingredients': ingredients,
          'weight': weight,
          'goal': goal,
          'meals': meals,
        }),
      );

      if (kDebugMode) {
        print('서버 응답 코드: ${response.statusCode}');
      }
      
      if (response.statusCode == 200) {
        // 응답 디코딩 - UTF-8 지정
        final String decodedBody = utf8.decode(response.bodyBytes);
        
        try {
          // JSON 파싱 시도
          final jsonData = jsonDecode(decodedBody) as Map<String, dynamic>;
          
          if (kDebugMode) {
            print('서버 응답 옵션: ${jsonData.keys.toList()}');
          }
          
          // 새로운 API 응답 형식 처리 (구조화된 meals 데이터 사용)
          if (jsonData.containsKey('success') && jsonData.containsKey('meals')) {
            // 개선된 서버 응답 추출
            final success = jsonData['success'] as bool;
            final rawMarkdown = jsonData['rawMarkdown'];
            
            if (success) {
              List<dynamic> mealsData = jsonData['meals'] as List<dynamic>;
              
              if (kDebugMode) {
                print('개선된 서버 응답: ${mealsData.length} 개 식단 항목');
              }
              
              return {
                'success': true,
                'meals': mealsData,
                'rawMarkdown': rawMarkdown,
              };
            } else {
              final errorMessage = jsonData['errorMessage'] ?? '알 수 없는 오류';
              return {
                'success': false,
                'errorMessage': errorMessage,
                'rawResponse': decodedBody,
              };
            }
          }
          // 이전 버전 호환성 - 마크다운 기반 응답
          else if (jsonData.containsKey('recommendation')) {
            final recommendationText = jsonData['recommendation'] as String;
            
            // 테이블 데이터 추출
            final parsedMeals = extractMealsFromMarkdown(recommendationText);
            
            if (kDebugMode) {
              print('마크다운 파싱 성공: ${parsedMeals.length} 개 항목 추출');
            }
            
            return {
              'success': true,
              'meals': parsedMeals,
              'rawMarkdown': recommendationText,
            };
          } else {
            return {
              'success': false,
              'errorMessage': '서버 응답에 필요한 데이터가 없습니다',
              'rawResponse': decodedBody,
            };
          }
        } catch (e) {
          if (kDebugMode) {
            print('JSON 파싱 오류: $e');
          }
          return {
            'success': false,
            'errorMessage': 'JSON 파싱 오류: $e',
            'rawResponse': decodedBody,
          };
        }
      } else {
        throw Exception('서버 오류 (코드: ${response.statusCode}): ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('API 호출 실패: $e');
      }
      rethrow;
    }
  }
  
  // 마크다운에서 식단 정보 추출
  List<Map<String, dynamic>> extractMealsFromMarkdown(String markdown) {
    List<Map<String, dynamic>> result = [];
    try {
      // 라인별로 분석
      final lines = markdown.split('\n');
      
      // 테이블 데이터 행만 추출 (헤더와 구분자 제외)
      final dataRows = lines.where((line) => 
          line.startsWith('| ') && 
          line.contains(' | ') && 
          !line.contains(':---:') &&
          !line.contains('헤더')
      ).toList();
      
      if (kDebugMode) {
        print('추출된 테이블 행 수: ${dataRows.length}');
      }
      
      // 식사 번호와 타입 매핑
      final mealTypes = {1: '아침', 2: '점심', 3: '저녁', 4: '간식'};
      
      // 각 행 파싱
      for (var row in dataRows) {
        // | 기호로 구분하여 각 열 추출
        final columns = row.split('|')
            .map((col) => col.trim())
            .where((col) => col.isNotEmpty)
            .toList();
        
        // 형식에 맞게 추출되었는지 확인
        if (columns.length >= 7) {
          final mealNumber = int.tryParse(columns[0]) ?? 1;
          final mealType = mealTypes[mealNumber] ?? '식사 $mealNumber';
          
          final amount = _parseDoubleFromText(columns[2]);
          final calories = _parseDoubleFromText(columns[3]);
          final carbs = _parseDoubleFromText(columns[4]);
          final protein = _parseDoubleFromText(columns[5]);
          final fat = _parseDoubleFromText(columns[6]);
          
          // 결과에 추가
          result.add({
            'number': mealNumber,
            'type': mealType,
            'name': columns[1],
            'amount': amount,
            'calories': calories,
            'carbs': carbs,
            'protein': protein,
            'fat': fat,
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('마크다운 파싱 오류: $e');
      }
    }
    
    return result;
  }
  
  // 문자열에서 실수 파싱
  double _parseDoubleFromText(String text) {
    try {
      final cleanText = text.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(cleanText) ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }
}
