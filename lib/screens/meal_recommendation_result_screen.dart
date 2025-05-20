import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import '../services/openai_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MealRecommendationResultScreen extends StatefulWidget {
  final List<String> ingredients;
  final String goal;
  final int meals;
  final double weight;
  final dynamic result; // String 또는 Map<String, dynamic> 둘 다 처리할 수 있게 dynamic으로 변경
  final bool loading;
  final VoidCallback onRetry;
  final VoidCallback onRestart;

  const MealRecommendationResultScreen({
    required this.ingredients,
    required this.goal,
    required this.meals,
    required this.weight,
    this.result,
    required this.loading,
    required this.onRestart,
    required this.onRetry,
    Key? key,
  }) : super(key: key);
  
  @override
  State<MealRecommendationResultScreen> createState() => _MealRecommendationResultScreenState();
}

class _MealRecommendationResultScreenState extends State<MealRecommendationResultScreen> {
  String? _analysisResult;
  bool _isAnalyzing = false;
  
  @override
  void initState() {
    super.initState();
    
    // 위젯이 처음 로드될 때 분석 시작
    if (!widget.loading && widget.result != null) {
      _startAnalysis();
    }
  }
  
  @override
  void didUpdateWidget(MealRecommendationResultScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 데이터가 새로 업데이트되었다면 분석 다시 시작
    if (!widget.loading && widget.result != null && widget.result != oldWidget.result) {
      _startAnalysis();
    }
  }
  
  @override
  void dispose() {
    super.dispose();
  }
  
  void _startAnalysis() async {
    if (_isAnalyzing) return;
    
    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
    });
    
    try {
      // API 키 가져오기
      final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        throw Exception('잘못된 API 키: $apiKey');
      }
      final openAIService = OpenAIService(apiKey);
      
      // FastAPI에서 받은 식단 데이터가 있는지 로그
      if (kDebugMode) {
        print('FastAPI 데이터 분석 시작');
        print('결과 타입: ${widget.result.runtimeType}');
      }
      
      // 식단 데이터 추출 - 어떠한 형태로 오든 FastAPI에서 받은 데이터 사용
      List<dynamic> meals = [];
      if (widget.result != null) {
        if (widget.result is Map && (widget.result as Map).containsKey('meals')) {
          meals = (widget.result as Map)['meals'];
          if (kDebugMode) {
            print('식단 데이터 형식: ${meals.runtimeType}, 개수: ${meals.length}');
          }
        } else {
          // 기본 데이터를 사용하여 식단 생성
          if (kDebugMode) {
            print('식단 데이터 경로를 찾지 못함. 기본 데이터 사용');
          }
        }
      }
      
      final analysis = await openAIService.analyzeDietPlan(
        meals: meals,
        ingredients: widget.ingredients,
        weight: widget.weight,
        goal: widget.goal,
        mealsPerDay: widget.meals,
      );
      
      if (mounted) {
        setState(() {
          _analysisResult = analysis;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('분석 오류: $e');
      }

      if (mounted) {
        setState(() {
          _analysisResult = '식단 분석 중 오류가 발생했습니다: $e';
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('개인 맞춤 식단 분석'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '입력한 식재료: ${widget.ingredients.join(", ")}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text('목표: ${widget.goal}, 식사: ${widget.meals}회', style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 16),
            Expanded(
              child: _isAnalyzing 
                ? const Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('AI가 개인 맞춤 식단을 분석 중입니다...', style: TextStyle(fontSize: 16)),
                    ],
                  ))
                : _analysisResult != null
                    ? _buildAnalysisView()
                    : !widget.loading && widget.result != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _startAnalysis,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                  child: const Text('영양 분석 시작하기'),
                                ),
                              ],
                            ),
                          )
                        : const Center(child: Text('식단 데이터가 없습니다')),
            ),
            const SizedBox(height: 24),
            if (widget.loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  '※ 식단은 참고용이며, 건강 상태에 따라 전문가 상담을 권장합니다.',
                  style: TextStyle(fontSize: 14, color: Colors.deepPurple),
                  textAlign: TextAlign.center,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                      ),
                      onPressed: widget.onRetry,
                      child: const Text('다시 추천'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                      ),
                      onPressed: widget.onRestart,
                      child: const Text('처음으로'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 오류 발생 시 표시할 메시지 위젯
  Widget _buildErrorMessage(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.red),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: widget.onRetry,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
  
  // 숫자를 정해진 형식으로 보여주는 함수
  String _formatNumber(dynamic value) {
    if (value == null) return '-';
    if (value is num) {
      return value.toStringAsFixed(1);
    }
    return value.toString();
  }
  
  // GPT 분석 결과 뷰
  Widget _buildAnalysisView() {
    // 분석 중이면 로딩 표시
    if (_isAnalyzing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('식단 분석 중...', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('GPT-4 Turbo로 영양학적 분석을 진행 중입니다', style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      );
    }
    // 분석 결과가 없으면 추천 버튼 표시
    if (_analysisResult == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('식단 분석을 시작해보세요!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('식단의 영양학적 평가와 개선 제안을 받아보세요', style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.analytics),
              label: const Text('GPT로 분석하기'),
              onPressed: () => _startAnalysis(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }
    // 분석 결과 표시
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '사용자 식재료에 따른 영양 가이드',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: MarkdownBody(
              data: _analysisResult!,
              styleSheet: MarkdownStyleSheet(
                h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                p: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('다시 분석하기'),
              onPressed: () => _startAnalysis(),
            ),
          ),
        ],
      ),
    );
  }
}
