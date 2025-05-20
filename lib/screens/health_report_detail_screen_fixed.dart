import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/user.dart';
import '../services/openai_service.dart';

class HealthReportDetailScreenFixed extends StatefulWidget {
  final String reportId;
  
  const HealthReportDetailScreenFixed({
    Key? key, 
    required this.reportId,
  }) : super(key: key);

  @override
  State<HealthReportDetailScreenFixed> createState() => _HealthReportDetailScreenFixedState();
}

class _HealthReportDetailScreenFixedState extends State<HealthReportDetailScreenFixed> {
  final userBox = Hive.box<User>('userBox');
  User? _user;
  
  String _healthReport = "";
  bool _isLoading = false;
  bool _hasReport = false;
  
  // 보고서 생성 날짜
  DateTime? _reportDate;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    
    if (widget.reportId.isNotEmpty) {
      _loadReport(widget.reportId);
    }
  }

  // 사용자 데이터 가져오기
  void _loadUserData() {
    if (mounted) {
      setState(() {
        _user = userBox.get('profile');
      });
    }
  }

  // 특정 보고서 로드
  Future<void> _loadReport(String reportId) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? reportJson = prefs.getString('health_report_$reportId');
      
      if (reportJson != null && mounted) {
        final reportData = json.decode(reportJson);
        setState(() {
          _healthReport = reportData['content'] ?? "";
          _reportDate = DateTime.parse(reportData['date'] ?? DateTime.now().toIso8601String());
          _hasReport = _healthReport.isNotEmpty;
        });
      }
    } catch (e) {
      print('보고서 로드 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('보고서를 불러오는 중 오류가 발생했습니다.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 보고서 생성 및 저장
  Future<void> _generateReport() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _healthReport = "";
    });

    try {
      // 사용자 데이터 수집
      final userData = await _collectUserData();
      
      // OpenAI API를 사용한 보고서 생성
      final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        throw Exception('API 키가 설정되지 않았습니다');
      }
      
      final OpenAIService openAIService = OpenAIService(apiKey);
      final prompt = _createPrompt(userData);
      
      print("보고서 생성 프롬프트: $prompt");
      
      // OpenAI 서비스를 사용하여 임시 응답 생성 (실제로는 analyzeMeal 메서드를 사용)
      final response = await openAIService.analyzeMeal(
        '건강 보고서 생성: \n\n$prompt'
      ) ?? '데이터 분석 중 오류가 발생했습니다.';
      
      // 결과 저장
      if (response.isNotEmpty) {
        final now = DateTime.now();
        final reportId = '${now.millisecondsSinceEpoch}';
        
        // 보고서 내용 저장
        final reportData = {
          'id': reportId,
          'content': response,
          'date': now.toIso8601String(),
        };
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('health_report_$reportId', json.encode(reportData));
        
        // 보고서 목록 업데이트
        String? reportListRaw = prefs.getString('health_report_list');
        List<Map<String, dynamic>> reportList = [];
        
        if (reportListRaw != null) {
          final List<dynamic> existingList = json.decode(reportListRaw);
          reportList = existingList.map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item)).toList();
        }
        
        // 보고서 목록에 추가
        reportList.add({
          'id': reportId,
          'date': now.toIso8601String(),
          'title': '오늘의 건강 보고서 (${now.year}년 ${now.month}월 ${now.day}일)',
        });
        
        await prefs.setString('health_report_list', json.encode(reportList));
        
        // 위젯이 여전히 화면에 있는지 확인
        if (mounted) {
          setState(() {
            _healthReport = response;
            _reportDate = now;
            _hasReport = true;
          });
        }
      }
    } catch (e) {
      print('보고서 생성 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('보고서 생성 중 오류가 발생했습니다. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 사용자 데이터 수집
  Future<Map<String, dynamic>> _collectUserData() async {
    final userData = <String, dynamic>{};
    
    // 사용자 기본 정보
    if (_user != null) {
      userData['name'] = _user!.name;
      userData['gender'] = _user!.gender;
      userData['age'] = _user!.age;
      userData['height'] = _user!.height;
      userData['weight'] = _user!.weight;
      
      // BMI 계산
      if (_user!.height != null && _user!.weight != null && _user!.height! > 0 && _user!.weight! > 0) {
        double heightInMeter = _user!.height! / 100;
        double bmi = _user!.weight! / (heightInMeter * heightInMeter);
        userData['bmi'] = bmi.toStringAsFixed(1);
      }
    }
    
    // 식단 데이터 수집
    userData['meals'] = await _collectMealData();
    
    // 운동 데이터 수집
    userData['running'] = await _collectRunningData();
    
    // 테스트 결과 수집
    userData['tests'] = await _collectTestData();
    
    return userData;
  }

  // 식단 데이터 수집
  Future<List<Map<String, dynamic>>> _collectMealData() async {
    final meals = <Map<String, dynamic>>[];
    final prefs = await SharedPreferences.getInstance();
    
    // 기록 탭에서 관리하는 식단 데이터 조회 (삭제된 식단은 포함되지 않음)
    final String? mealRecordsRaw = prefs.getString('meal_records_v1');
    
    if (mealRecordsRaw != null) {
      try {
        final List<dynamic> mealRecords = json.decode(mealRecordsRaw);
        print('식단 기록 데이터 판별: ${mealRecords.length}개 검색');
        
        // 오늘 날짜의 식단 데이터만 필터링
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        // 식사 유형별 그룹화
        final typeMeals = <String, List<Map<String, dynamic>>>{
          'Breakfast': [],
          'Lunch': [],
          'Dinner': [],
        };
        
        for (final record in mealRecords) {
          // 오늘 날짜의 식단만 포함
          final recordDate = DateTime.parse(record['date'] as String);
          final recordDay = DateTime(recordDate.year, recordDate.month, recordDate.day);
          
          if (recordDay.isAtSameMomentAs(today)) {
            final mealType = record['mealType'] as String? ?? 'Other';
            if (typeMeals.containsKey(mealType)) {
              typeMeals[mealType]!.add(Map<String, dynamic>.from(record));
            }
          }
        }
        
        // 각 식사 유형별 요약 정보 생성
        for (final entry in typeMeals.entries) {
          if (entry.value.isEmpty) continue;
          
          final items = entry.value;
          final foodItems = <String>[];
          int totalCalories = 0;
          final nutrientSummary = <String, String>{};
          
          for (final item in items) {
            if (item['mealName'] != null) {
              foodItems.add(item['mealName'] as String);
              
              // 칼로리 계산
              if (item.containsKey('nutrients') && item['nutrients'] != null) {
                final nutrients = item['nutrients'] as Map<String, dynamic>;
                final calStr = nutrients['\uce7c\ub85c\ub9ac']?.toString().replaceAll(RegExp(r'[^0-9]'), '');
                if (calStr != null && calStr.isNotEmpty) {
                  totalCalories += int.tryParse(calStr) ?? 0;
                }
                
                // 영양소 정보 처리
                for (final key in nutrients.keys) {
                  nutrientSummary[key.toString()] = nutrients[key].toString();
                }
              }
            }
          }
          
          // 한국어 식사 타입으로 변환
          String koreanMealType = '아침';
          if (entry.key == 'Lunch') koreanMealType = '점심';
          if (entry.key == 'Dinner') koreanMealType = '저녁';
          
          // 그룹화된 식단 정보 추가
          if (foodItems.isNotEmpty) {
            meals.add({
              'type': koreanMealType,
              'items': foodItems,
              'calories': totalCalories,
              'nutrients': nutrientSummary,
            });
          }
        }
      } catch (e) {
        print('식단 데이터 파싱 오류: $e');
      }
    } else {
      print('기록 탭에 저장된 식단 기록이 없습니다.');
    }
    
    return meals;
  }

  // 운동 데이터 수집
  Future<List<Map<String, dynamic>>> _collectRunningData() async {
    final runningData = <Map<String, dynamic>>[];
    final prefs = await SharedPreferences.getInstance();
    
    // 오늘 날짜 가져오기
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final formattedToday = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    print('현재 날짜: $formattedToday');
    
    // SharedPreferences에 저장된 모든 키 출력 (디버깅용)
    final allKeys = prefs.getKeys();
    print('운동 관련 키 확인:');
    for (final key in allKeys) {
      if (key.contains('run') || key.contains('test')) {
        print('- $key');
      }
    }
    
    // 자유 달리기 기록 조회
    final String? freeRunRecordsJson = prefs.getString('free_run_records_v1');
    if (freeRunRecordsJson != null) {
      try {
        print('자유 달리기 기록 발견: ${freeRunRecordsJson.substring(0, math.min(100, freeRunRecordsJson.length))}...');
        final List<dynamic> records = json.decode(freeRunRecordsJson);
        print('총 ${records.length}개의 자유 달리기 기록 발견');
        
        for (final record in records) {
          final recordDate = DateTime.parse(record['date']);
          final recordDay = DateTime(recordDate.year, recordDate.month, recordDate.day);
          final formattedRecordDay = '${recordDay.year}-${recordDay.month.toString().padLeft(2, '0')}-${recordDay.day.toString().padLeft(2, '0')}';
          
          print('기록 날짜 $formattedRecordDay vs 오늘 $formattedToday');
          
          // 오늘 날짜의 기록만 포함
          if (formattedRecordDay == formattedToday) {
            final distance = double.parse(record['distance'].toString());
            final durationInSeconds = int.parse(record['duration'].toString());
            // 대략적인 칼로리 계산 (1km당 60kcal로 가정)
            final calories = (distance * 60).round();
            
            final runData = {
              'date': record['date'],
              'distance': distance,
              'duration': (durationInSeconds / 60).round(), // 분 단위로 변환
              'calories': calories,
              'type': '자유 달리기'
            };
            
            runningData.add(runData);
            print('오늘의 자유 달리기 기록 추가: ${distance.toStringAsFixed(2)}km, 기록: $runData');
          }
        }
      } catch (e) {
        print('자유 달리기 기록 파싱 오류: $e');
      }
    } else {
      print('자유 달리기 기록이 없습니다');
    }
    
    // 테스트 기록 조회
    final String? testRecordsJson = prefs.getString('test_records_v1');
    if (testRecordsJson != null) {
      try {
        print('테스트 기록 발견: ${testRecordsJson.substring(0, math.min(100, testRecordsJson.length))}...');
        final List<dynamic> records = json.decode(testRecordsJson);
        print('총 ${records.length}개의 테스트 기록 발견');
        
        for (final record in records) {
          final recordDate = DateTime.parse(record['date'] as String);
          final recordDay = DateTime(recordDate.year, recordDate.month, recordDate.day);
          final formattedRecordDay = '${recordDay.year}-${recordDay.month.toString().padLeft(2, '0')}-${recordDay.day.toString().padLeft(2, '0')}';
          
          print('테스트 기록 날짜 $formattedRecordDay vs 오늘 $formattedToday');
          
          // 오늘 날짜의 기록만 포함
          if (formattedRecordDay == formattedToday) {
            final distance = double.parse(record['distance'].toString());
            final durationInSeconds = int.parse(record['duration'].toString());
            // 대략적인 칼로리 계산 (1km당 60kcal로 가정)
            final calories = (distance * 60).round();
            
            // 테스트 유형 확인
            String testType = '테스트 달리기';
            final testTypeIndex = int.parse(record['testType'].toString());
            if (testTypeIndex == 0) testType = '1마일 걷기';
            else if (testTypeIndex == 1) testType = '1.5마일 달리기';
            else if (testTypeIndex == 2) testType = '5분 달리기';
            else if (testTypeIndex == 3) testType = '12분 달리기';
            
            // VO2max 포함
            var vo2max = 0.0;
            if (record.containsKey('vo2max')) {
              vo2max = double.parse(record['vo2max'].toString());
            }
            
            final testData = {
              'date': record['date'],
              'distance': distance,
              'duration': (durationInSeconds / 60).round(), // 분 단위로 변환
              'calories': calories,
              'type': testType,
              'vo2max': vo2max
            };
            
            runningData.add(testData);
            print('오늘의 테스트 기록 추가: $testType - ${distance.toStringAsFixed(2)}km, VO2max: ${vo2max.toStringAsFixed(1)}, 기록: $testData');
          }
        }
      } catch (e) {
        print('테스트 기록 파싱 오류: $e');
      }
    } else {
      print('테스트 기록이 없습니다');
    }
    
    // 날짜 기준 내림차순 정렬
    runningData.sort((a, b) => 
      DateTime.parse(b['date'] as String).compareTo(DateTime.parse(a['date'] as String)));
    
    print('오늘의 운동 기록 총: ${runningData.length}개');
    return runningData;
  }

  // 테스트 결과 수집
  Future<Map<String, dynamic>> _collectTestData() async {
    final resultData = <String, dynamic>{};
    final prefs = await SharedPreferences.getInstance();
    
    // 오늘 날짜 가져오기
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // 테스트 기록 조회
    final String? testRecordsJson = prefs.getString('test_records_v1');
    if (testRecordsJson != null) {
      try {
        final List<dynamic> records = json.decode(testRecordsJson);
        
        // 오늘 날짜의 테스트 기록 필터링
        final todaysTests = <Map<String, dynamic>>[];
        for (final record in records) {
          final recordDate = DateTime.parse(record['date'] as String);
          final recordDay = DateTime(recordDate.year, recordDate.month, recordDate.day);
          
          if (recordDay.isAtSameMomentAs(today)) {
            todaysTests.add(Map<String, dynamic>.from(record));
          }
        }
        
        // 오늘 테스트 기록이 있는 경우
        if (todaysTests.isNotEmpty) {
          // 가장 최근 테스트 선택 (날짜 내림차순 정렬)
          todaysTests.sort((a, b) => 
            DateTime.parse(b['date'] as String).compareTo(DateTime.parse(a['date'] as String)));
          
          final latestTest = todaysTests.first;
          if (latestTest.containsKey('vo2max')) {
            resultData['vo2max'] = latestTest['vo2max'] as double;
            resultData['testDate'] = latestTest['date'];
            
            // 테스트 유형 확인
            String testType = '테스트';
            final testTypeIndex = latestTest['testType'] as int;
            if (testTypeIndex == 0) testType = '1마일 걷기';
            else if (testTypeIndex == 1) testType = '1.5마일 달리기';
            else if (testTypeIndex == 2) testType = '5분 달리기';
            else if (testTypeIndex == 3) testType = '12분 달리기';
            
            resultData['testType'] = testType;
            
            print('오늘의 테스트 결과: $testType, VO2max: ${(latestTest['vo2max'] as double).toStringAsFixed(1)}');
          }
        } else {
          print('오늘 실시한 테스트 기록이 없습니다.');
        }
      } catch (e) {
        print('테스트 결과 파싱 오류: $e');
      }
    }
    
    // 기본값 제공 (기록이 없는 경우)
    if (!resultData.containsKey('vo2max')) {
      resultData['vo2max'] = 0.0;  // 기록 없음을 나타내는 값
      resultData['testDate'] = '';
      resultData['testType'] = '';
    }
    
    return resultData;
  }

  // OpenAI 프롬프트 생성
  String _createPrompt(Map<String, dynamic> userData) {
    final prompt = StringBuffer();
    
    prompt.writeln('【오늘의 건강 보고서 작성 요청】');
    prompt.writeln();
    prompt.writeln('아래 사용자 데이터를 기반으로 오늘 하루의 건강 상태를 분석하고 상세한 건강 보고서를 마크다운 형식으로 작성해주세요.');
    prompt.writeln('이 보고서는 오직 오늘 하루동안의 식단과 운동 데이터만을 기반으로 합니다. 각 섹션에서 구체적이고 실제적인 조언을 제공해 주십시오.');
    
    // 기본 정보
    prompt.writeln('### 사용자 정보');
    if (userData['name'] != null) prompt.writeln('- 이름: ${userData['name']}');
    if (userData['gender'] != null) prompt.writeln('- 성별: ${userData['gender']}');
    if (userData['age'] != null) prompt.writeln('- 나이: ${userData['age']}');
    if (userData['height'] != null) prompt.writeln('- 키: ${userData['height']}cm');
    if (userData['weight'] != null) prompt.writeln('- 몸무게: ${userData['weight']}kg');
    if (userData['bmi'] != null) prompt.writeln('- BMI: ${userData['bmi']}');
    prompt.writeln();
    
    // 식단 정보
    prompt.writeln('### 오늘의 식단 정보');
    if (userData['meals'] != null && (userData['meals'] as List).isNotEmpty) {
      for (final meal in userData['meals']) {
        prompt.writeln('- ${meal['type']}: ${meal['calories']}kcal');
        if ((meal['items'] as List).isNotEmpty) {
          prompt.writeln('  - 음식 항목: ${meal['items'].join(', ')}');
        }
        // 영양소 정보 추가
        if (meal['nutrients'] != null && (meal['nutrients'] as Map).isNotEmpty) {
          prompt.writeln('  - 영양소:');
          final nutrients = meal['nutrients'] as Map<String, String>;
          for (final entry in nutrients.entries) {
            prompt.writeln('    - ${entry.key}: ${entry.value}');
          }
        }
      }
    } else {
      prompt.writeln('- 오늘의 식단 데이터 없음');
    }
    prompt.writeln();
    
    // 운동 정보
    prompt.writeln('### 오늘의 운동 정보');
    if (userData['running'] != null && (userData['running'] as List).isNotEmpty) {
      for (final run in userData['running']) {
        prompt.writeln('- 운동 유형: ${run['type']}');
        prompt.writeln('  - 거리: ${run['distance']}km');
        prompt.writeln('  - 시간: ${run['duration']}분');
        prompt.writeln('  - 소모 칼로리: ${run['calories']}kcal');
        if (run.containsKey('vo2max') && run['vo2max'] != null && (run['vo2max'] as double) > 0) {
          prompt.writeln('  - VO2max: ${run['vo2max']}');
        }
      }
    } else {
      prompt.writeln('- 오늘의 운동 데이터 없음');
    }
    prompt.writeln();
    
    // 테스트 결과
    prompt.writeln('### 오늘의 테스트 결과');
    if (userData['tests'] != null && userData['tests']['vo2max'] != null && (userData['tests']['vo2max'] as double) > 0) {
      prompt.writeln('- 테스트 유형: ${userData['tests']['testType']}');
      prompt.writeln('- VO2 Max: ${userData['tests']['vo2max']}');
      prompt.writeln('- 테스트 날짜: ${userData['tests']['testDate']}');
    } else {
      prompt.writeln('- 오늘의 테스트 결과 없음');
    }
    prompt.writeln();
    
    prompt.writeln('### 요청사항');
    prompt.writeln('1. **오늘의 건강 상태 종합 분석**: 모든 데이터를 기반으로 사용자의 현재 건강 상태를 분석해주세요.');
    prompt.writeln('2. **오늘의 식단 평가 및 제안**: 영양 발란에 대한 구체적인 평가와 실정적인 개선 방안을 제시해주세요.');
    prompt.writeln('3. **오늘의 운동 평가 및 제안**: 운동 성과와 개선 방안을 구체적으로 제시해주세요.');
    prompt.writeln('4. **오늘의 건강 점수 (100점 만점)**: 종합적인 건강 점수와 간단한 이유를 설명해주세요.');
    prompt.writeln('5. **내일을 위한 구체적 건강 향상 제안**: 1-3가지의 실천할 수 있는 구체적인 건강 습관 개선안을 제시해주세요.');
    prompt.writeln();
    prompt.writeln('★ 우선순위: 가장 중요한 필요사항부터 순서대로 제시해주세요.');
    prompt.writeln('★ 형식: 각 섹션은 #, ##, ### 형태의 마크다운 헤더를 사용하여 분립해서 작성해주세요.');  
    prompt.writeln('★ 이해하기 쉽고 실행 가능한 형태로 작성해주세요: 전문용어 적절히 혹합, 읽기 쉽고 실행 가능한 조언을 제공해주세요.');
    
    return prompt.toString();
  }

  // 보고서 내용을 마크다운 형식의 섹션으로 분할
  List<Map<String, dynamic>> _parseReportSections(String report) {
    final sections = <Map<String, dynamic>>[];
    final lines = report.split('\n');
    
    String currentTitle = '';
    StringBuffer currentContent = StringBuffer();
    
    for (final line in lines) {
      if (line.startsWith('##') || line.startsWith('# ')) {
        // 새 섹션을 시작할 때 이전 섹션 저장
        if (currentTitle.isNotEmpty) {
          sections.add({
            'title': currentTitle,
            'content': currentContent.toString().trim(),
          });
          currentContent = StringBuffer();
        }
        currentTitle = line.replaceAll(RegExp(r'^#+\s*'), '').trim();
      } else {
        currentContent.writeln(line);
      }
    }
    
    // 마지막 섹션 저장
    if (currentTitle.isNotEmpty) {
      sections.add({
        'title': currentTitle,
        'content': currentContent.toString().trim(),
      });
    }
    
    // 보고서가 섹션 구분 없이 작성된 경우
    if (sections.isEmpty && report.trim().isNotEmpty) {
      sections.add({
        'title': '건강 보고서',
        'content': report.trim(),
      });
    }
    
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final reportSections = _healthReport.isNotEmpty ? _parseReportSections(_healthReport) : [];
    // 미리 Colors 객체 생성
    final greyColor = Colors.grey;
    final blueColor = Colors.blue;
    
    return Scaffold(
      backgroundColor: greyColor[50],
      appBar: AppBar(
        title: const Text(
          '건강 보고서',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasReport
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_reportDate != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            '생성일: ${_reportDate!.year}년 ${_reportDate!.month}월 ${_reportDate!.day}일',
                            style: TextStyle(color: greyColor[600], fontSize: 14),
                          ),
                        ),
                      
                      // 보고서 섹션 표시
                      for (final section in reportSections)
                        Column(
                          key: UniqueKey(), // Hero 태그 중복 문제 해결
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: blueColor[700],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                section['title'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color.fromRGBO(0, 0, 0, 0.05),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                section['content'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                    ],
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assessment_outlined,
                        size: 80,
                        color: greyColor[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '건강 보고서가 없습니다',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: greyColor[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '아래 버튼을 눌러 건강 보고서를 생성하세요',
                        style: TextStyle(
                          fontSize: 14,
                          color: greyColor[600],
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _generateReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blueColor[700],
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '보고서 생성하기',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}