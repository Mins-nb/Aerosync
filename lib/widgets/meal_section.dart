import 'package:flutter/material.dart';
import '../screens/meal_planning_flow.dart';
import '../screens/meal_input_screen.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/calorie_service.dart';
import 'package:intl/intl.dart';
import '../services/app_state_manager.dart';

// 앱 라이프사이클 변화를 감지하는 Observer 클래스
class LifecycleChangeObserver extends WidgetsBindingObserver {
  final VoidCallback? onAppResume;
  
  LifecycleChangeObserver({this.onAppResume});
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onAppResume?.call();
    }
  }
}

class CalorieBar extends StatefulWidget {
  const CalorieBar({Key? key}) : super(key: key);

  // 정적 메서드는 이제 중앙 상태 관리자를 통해 동작
  static void updateKcal(int kcal) {
    appStateManager.updateCalorieIntake(kcal);
  }
  
  // 새로 계산된 목표 칼로리를 강제로 로드하는 메서드
  static void refreshTargetCalorie() {
    print('목표 칼로리 값 새로고침 요청');
    appStateManager.refreshAllTargets();
  }

  @override
  State<CalorieBar> createState() => CalorieBarState();
}

class CalorieBarState extends State<CalorieBar> {
  @override
  void initState() {
    super.initState();
    // 앱 시작시 전체 데이터 로드 요청
    appStateManager.loadAllTargets();
  }
  
  // 그래프 바로 표시하는 원래 디자인으로 복원
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: appStateManager.currentCalorieIntake,
      builder: (context, currentKcal, _) {
        return ValueListenableBuilder<int>(
          valueListenable: appStateManager.targetCalorieIntake,
          builder: (context, targetCalorie, _) {
            // 비율 계산 및 초과 처리
            double ratio = targetCalorie > 0 ? currentKcal / targetCalorie : 0;
            ratio = ratio > 1.0 ? 1.0 : ratio;
            final isOver = currentKcal > targetCalorie;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Calorie Intake', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    // 현재 / 목표 표시 순서 유지
                    Text('$currentKcal / $targetCalorie kcal', 
                      style: TextStyle(fontWeight: FontWeight.w600, color: isOver ? Colors.red : Colors.black87)
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
                      isOver ? Colors.red : const Color(0xFFFFD600)
                    ),
                    minHeight: 12,
                  ),
                ),
                if (isOver)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Calorie Goal Exceeded!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class MealSection extends StatefulWidget {
  // 호출자 수정 - meal_input_screen에서 반환된 결과를 처리하도록 메서드 시그니처 변경
  final Future<void> Function(String mealType)? onMealTap;
  final void Function(int)? onTotalKcalChanged;
  const MealSection({Key? key, this.onMealTap, this.onTotalKcalChanged}) : super(key: key);

  @override
  State<MealSection> createState() => _MealSectionState();
}

class _MealSectionState extends State<MealSection> {
  // 명시적 타입 지정으로 타입 안전성 보장
  Map<String, int> foods = {'Breakfast': 0, 'Lunch': 0, 'Dinner': 0};
  Map<String, int> kcals = {'Breakfast': 0, 'Lunch': 0, 'Dinner': 0};
  final Map<String, int> goalKcals = {
    'Breakfast': 631,
    'Lunch': 1262,
    'Dinner': 946,
  };
  
  // 오늘 날짜를 저장하는 변수 추가
  String _currentDate = '';
  // 마지막으로 데이터를 로드한 날짜 저장
  String _lastLoadedDate = '';

  @override
  void initState() {
    super.initState();
    
    // 시각적 피드백 제공을 위해 약간 지연 후 실행
    Future.delayed(Duration(milliseconds: 500), () {
      // 앱 시작시 저장된 모든 키 출력 (디버깅용)
      _debugPrintAllKeys();
      
      // 현재 날짜 가져오기
      String today = _getTodayString();
      
      // 마지막으로 로드한 날짜가 없거나 현재 날짜와 다른 경우에만 초기화
      if (_lastLoadedDate.isEmpty || _lastLoadedDate != today) {
        print('날짜가 변경되었거나 처음 로드하는 경우에만 초기화: $_lastLoadedDate -> $today');
        
        // 날짜가 바뀌 경우에만 데이터 초기화
        _currentDate = today;
        _lastLoadedDate = today;
      }
      
      // 저장된 데이터 로드
      _loadFromStorage();
    });
    
    // 날짜 변경 감지를 위한 타이머 설정
    _setupDateCheckTimer();
  }
  
  // 디버깅용: 모든 SharedPreferences 키 출력
  Future<void> _debugPrintAllKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    print('\n===== DEBUG: 모든 SharedPreferences 키 =====');
    for (var key in allKeys) {
      if (key.contains('meal_cards')) {
        print('키: $key, 값: ${prefs.getString(key)}');
      }
    }
    print('=====================================\n');
  }
  
  // 해결책: 모든 식사 데이터 강제 초기화
  Future<void> _forceClearAllMealData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys().toList();
      int cleared = 0;
      
      // 기존 데이터 삭제 전 로그
      print('\n===== 초기화 전 식사 관련 키 =====');
      for (var key in allKeys) {
        if (key.contains('meal_cards')) {
          print('삭제 대상 키: $key');
          await prefs.remove(key);
          cleared++;
        }
      }
      
      print('\n[*] 해결책 적용: 식사 데이터 $cleared개 항목 강제 초기화 완료');
      print('\n===== 초기화 후 식사 관련 키 =====');
      final keysAfter = prefs.getKeys().toList();
      int remaining = 0;
      for (var key in keysAfter) {
        if (key.contains('meal_cards')) {
          print('남아있는 키: $key');
          remaining++;
        }
      }
      print('\n[*] 남아있는 식사 데이터 키: $remaining개');
      
      return;
    } catch (e) {
      print('\n[!] 데이터 초기화 중 오류 발생: $e');
    }
  }

  // 현재 날짜를 YYYY-MM-DD 형식의 문자열로 반환
  String _getTodayString() {
    final now = DateTime.now();
    return DateFormat('yyyy-MM-dd').format(now);
  }

  // 날짜 변경을 감지하는 타이머 설정
  void _setupDateCheckTimer() {
    // 앱이 활성화될 때마다 현재 날짜 확인
    WidgetsBinding.instance.addObserver(LifecycleChangeObserver(
      onAppResume: () {
        print('앱이 재개됨: 날짜 변화 확인');
        _checkDateChange();
      },
    ));
    
    // 최초 실행 시 날짜 설정
    _currentDate = _getTodayString();
    _lastLoadedDate = _currentDate;
    
    // 즉시 한 번 확인
    _checkDateChange();
    
    // 주기적으로 날짜 확인 (30초마다 - 더 빠른 감지를 위해)
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _checkDateChange();
        _setupDateCheckTimer();
      }
    });
  }
  
  // 날짜가 변경되었는지 확인하고 필요시 데이터 리셋
  void _checkDateChange() {
    final today = _getTodayString();
    if (_currentDate != today || foods['Breakfast'] == null) {
      print('날짜가 변경됨 또는 초기화 필요: $_currentDate -> $today');
      setState(() {
        _currentDate = today;
        // 날짜가 변경되었으므로 데이터 리셋
        foods = {'Breakfast': 0, 'Lunch': 0, 'Dinner': 0};
        kcals = {'Breakfast': 0, 'Lunch': 0, 'Dinner': 0};
      });
      // 새 날짜의 데이터 로드
      _loadAll();
      // 칼로리 바 리셋
      CalorieBar.updateKcal(0);
    } else if (_lastLoadedDate != today) {
      // 같은 날짜지만 마지막 로드 날짜가 다른 경우 (홈스크린으로 다시 돌아왔을 때)
      print('같은 날짜지만 데이터 새로고침 필요: $_lastLoadedDate -> $today');
      _loadAll(); // 오늘 날짜의 최신 데이터 로드
    }
  }

  Future<void> _loadAll() async {
    // 현재 날짜 업데이트
    final today = _getTodayString();
    _currentDate = today;
    _lastLoadedDate = today;
    
    print('식사 데이터 로드 중: $_currentDate');
    
    // 임시 변수 - 이것으로 타입 문제 피하기
    Map<String, int> tempFoods = {'Breakfast': 0, 'Lunch': 0, 'Dinner': 0};
    Map<String, int> tempKcals = {'Breakfast': 0, 'Lunch': 0, 'Dinner': 0};
    
    for (final mealType in ['Breakfast', 'Lunch', 'Dinner']) {
      try {
        final summary = await _loadMealSummary(mealType, _currentDate);
        // 확실한 int 변환
        final foodCount = int.parse((summary['foods'] ?? 0).toString());
        final kcalCount = int.parse((summary['kcal'] ?? 0).toString());
        
        tempFoods[mealType] = foodCount;
        tempKcals[mealType] = kcalCount;
        
        print('$mealType 데이터 로드됨: $foodCount 음식, $kcalCount kcal');
      } catch (e) {
        print('$mealType 데이터 로드 오류: $e');
        tempFoods[mealType] = 0;
        tempKcals[mealType] = 0;
      }
    }
    
    // 마지막에 한 번에 전체 상태 업데이트
    setState(() {
      foods = tempFoods;
      kcals = tempKcals;
    });
  }

  Future<Map<String, dynamic>> _loadMealSummary(String mealType, String date) async {
    final prefs = await SharedPreferences.getInstance();
    // 날짜별로 구분된 키 사용 - 명확하게 로그 출력
    final key = 'meal_cards_v1_${mealType}_$date';
    print('로딩 키: $key (${DateTime.now().toIso8601String()})');
    final raw = prefs.getString(key);
    
    // 이전 형식의 데이터가 있는지 확인 (마이그레이션 용도)
    if (raw == null) {
      // 이전 형식의 키 확인
      final oldKey = 'meal_cards_v1_${mealType}';
      final oldFormatRaw = prefs.getString(oldKey);
      
      if (oldFormatRaw != null && date == _getTodayString()) {
        // 이전 형식의 데이터를 새 형식으로 마이그레이션
        await prefs.setString(key, oldFormatRaw);
        // 이전 데이터는 더 이상 필요없으므로 삭제
        await prefs.remove(oldKey);
        print('마이그레이션 완료: $oldKey -> $key');
        return _processMealData(oldFormatRaw);
      }
      print('데이터 없음: $key');
      return {'foods': 0, 'kcal': 0};
    }
    
    print('데이터 로드됨: $key');
    return _processMealData(raw);
  }
  
  // 식사 데이터 처리 로직 분리
  Map<String, dynamic> _processMealData(String rawData) {
    try {
      final List list = jsonDecode(rawData);
      int kcalTotal = 0;
      for (final e in list) {
        final nutrients = e['nutrients'] ?? (e['parsed'] ?? {});
        final calStr = nutrients['칼로리']?.toString().replaceAll(RegExp(r'[^0-9]'), '');
        if (calStr != null && calStr.isNotEmpty) {
          kcalTotal += int.tryParse(calStr) ?? 0;
        }
      }
      return {'foods': list.length, 'kcal': kcalTotal};
    } catch (e) {
      print('식사 데이터 처리 오류: $e');
      return {'foods': 0, 'kcal': 0};
    }
  }

  int get totalKcal {
    int total = 0;
    for (final value in kcals.values) {
      total += value; // kcals는 이미 <String, int> 타입이므로 값이 모두 int임
    }
    return total;
  }

  // 식사 카드 탭 이벤트 처리 메서드
  Future<void> _handleMealCardTap(String mealType) async {
    print('$mealType 식사 카드 탭 - 식사 입력 화면으로 이동');

    Map<String, dynamic>? result;
    
    // 상위 위젯에 알림 (홈 메인 위젯에서 처리)
    if (widget.onMealTap != null) {
      await widget.onMealTap!(mealType);
      // 상위 위젯에서 처리한 후에도 데이터 갱신 필요
      _loadFromStorage();
      return;
    } else {
      // 직접 식사 입력 화면으로 이동하고 결과 처리
      result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => MealInputScreen(mealType: mealType),
        ),
      );
    }
    
    // 결과가 있으면 데이터 갱신
    if (result != null) {
      try {
        // Null 안전성을 위해 bool? 형식으로 확인
        final bool isUpdated = result.containsKey('updated') && result['updated'] == true;
        
        if (isUpdated) {
          print('식사 입력 화면에서 돌아옴: $result');
          
          // 변수를 인라인으로 사용하지 않고 미리 추출하여 안전한 널 처리
          final dynamic mealTypeValue = result.containsKey('mealType') ? result['mealType'] : null;
          final dynamic mealCountValue = result.containsKey('mealCount') ? result['mealCount'] : null;
          final dynamic totalKcalValue = result.containsKey('totalKcal') ? result['totalKcal'] : null;
          
          setState(() {
            // 즉시 화면 갱신을 위해 해당 식사 타입 데이터 업데이트
            if (mealTypeValue != null && mealTypeValue is String) {
              final String type = mealTypeValue;
              
              // mealCount가 정수이거나 정수로 변환 가능한지 확인
              if (mealCountValue != null) {
                try {
                  foods[type] = mealCountValue is int ? mealCountValue : int.parse(mealCountValue.toString());
                } catch (e) {
                  print('식사 개수 변환 오류: $e');
                }
              }
              
              // totalKcal이 정수인지 확인
              if (totalKcalValue != null) {
                try {
                  kcals[type] = totalKcalValue is int ? totalKcalValue : int.parse(totalKcalValue.toString());
                } catch (e) {
                  print('칼로리 변환 오류: $e');
                }
              }
            }
          });
          
          // 총 칼로리 업데이트
          final newTotal = totalKcal;
          widget.onTotalKcalChanged?.call(newTotal);
          CalorieBar.updateKcal(newTotal);
          
          // 캘린더에 데이터 갱신 내역 저장
          _loadAll();
          return; // 데이터가 갱신되었으니 여기서 반환
        }
      } catch (e) {
        print('식사 데이터 처리 오류: $e');
        // 오류 발생 시 계속 진행하여 스토리지에서 로드하도록 함
      }
      
      // isUpdated가 false이거나 오류가 발생했거나 result가 null인 경우
      // 스토리지에서 직접 데이터 로드
      _loadFromStorage();
    }
  }
  
  // 스토리지에서 식사 데이터 직접 로드
  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getTodayString();
    print('⚡️ 스토리지에서 식사 데이터 직접 로드: $today');
    
    // 각 식사 유형에 대한 데이터 로드
    Map<String, int> tempFoods = {'Breakfast': 0, 'Lunch': 0, 'Dinner': 0};
    Map<String, int> tempKcals = {'Breakfast': 0, 'Lunch': 0, 'Dinner': 0};
    
    // 가능한 모든 키 형식 처리
    for (String mealType in ['Breakfast', 'Lunch', 'Dinner']) {
      // 기본 키 형식 (meal_{date}_{mealType})
      final standardKey = 'meal_${today}_$mealType';
      
      // 기본 형식으로 먼저 식사 데이터 처리 시도
      final standardData = prefs.getStringList(standardKey);
      if (standardData != null && standardData.isNotEmpty) {
        print('표준 키로 데이터 발견: $standardKey - ${standardData.length}개 항목');
        _processStoredMealData(mealType, standardData, tempFoods, tempKcals);
        continue; // 이 식사 유형에 대해 연속 시도하지 않음
      }
      
      // 이전 형식 시도 1 (meal_{date}\_{mealType}) - 이스케이프 문자 포함
      final escapeKey = 'meal_$today\_$mealType';
      final escapeData = prefs.getStringList(escapeKey);
      if (escapeData != null && escapeData.isNotEmpty) {
        print('이스케이프 키로 데이터 발견: $escapeKey - ${escapeData.length}개 항목');
        _processStoredMealData(mealType, escapeData, tempFoods, tempKcals);
        
        // 역호환성을 위해 표준 키로 데이터 다시 저장
        await prefs.setStringList(standardKey, escapeData);
        await prefs.remove(escapeKey); // 이전 형식 삭제
        print('데이터 이전 완료: $escapeKey -> $standardKey');
        continue;
      }
      
      // JSON 형식으로 저장된 데이터 확인
      final jsonKey = 'mealData_${today}_$mealType';
      final jsonRaw = prefs.getString(jsonKey);
      if (jsonRaw != null) {
        try {
          final jsonData = json.decode(jsonRaw);
          print('JSON 키로 데이터 발견: $jsonKey');
          if (jsonData is List) {
            tempFoods[mealType] = jsonData.length;
            
            int totalKcal = 0;
            for (var item in jsonData) {
              if (item is Map && item.containsKey('nutrients')) {
                final nutrients = item['nutrients'];
                if (nutrients is Map && nutrients.containsKey('칼로리')) {
                  final kcalStr = nutrients['칼로리'].toString().replaceAll(RegExp(r'[^0-9]'), '');
                  totalKcal += int.tryParse(kcalStr) ?? 0;
                }
              }
            }
            tempKcals[mealType] = totalKcal;
            
            // StringList 형식으로 변환하여 저장 (표준화)
            List<String> stringItems = [];
            for (var item in jsonData) {
              stringItems.add(json.encode(item));
            }
            await prefs.setStringList(standardKey, stringItems);
            await prefs.remove(jsonKey); // 이전 형식 삭제
            print('데이터 이전 완료: $jsonKey -> $standardKey');
          }
        } catch (e) {
          print('JSON 데이터 처리 오류: $e');
        }
      }
    }
    
    if (mounted) {
      setState(() {
        foods = tempFoods;
        kcals = tempKcals;
        print('✅ 갱신된 식사 데이터: $foods');
        print('✅ 갱신된 칼로리 데이터: $kcals'); 
      });
      
      // 총 칼로리 업데이트
      final newTotal = totalKcal;
      widget.onTotalKcalChanged?.call(newTotal);
      CalorieBar.updateKcal(newTotal);
    }
  }
  
  // 저장된 식사 데이터 처리 하는 헬퍼 메서드
  void _processStoredMealData(String mealType, List<String> mealData, 
      Map<String, int> tempFoods, Map<String, int> tempKcals) {
    tempFoods[mealType] = mealData.length;
    
    // 총 칼로리 계산
    int totalKcal = 0;
    for (String item in mealData) {
      try {
        final foodData = json.decode(item);
        if (foodData != null) {
          if (foodData.containsKey('kcal')) {
            totalKcal += int.tryParse(foodData['kcal'].toString()) ?? 0;
          } else if (foodData.containsKey('nutrients')) {
            final nutrients = foodData['nutrients'];
            if (nutrients is Map && nutrients.containsKey('칼로리')) {
              final kcalStr = nutrients['칼로리'].toString().replaceAll(RegExp(r'[^0-9]'), '');
              totalKcal += int.tryParse(kcalStr) ?? 0;
            }
          }
        }
      } catch (e) {
        print('식사 데이터 파싱 오류: $e');
      }
    }
    tempKcals[mealType] = totalKcal;
    print('$mealType 처리 결과: ${mealData.length}개 항목, $totalKcal 칼로리');
  }
  
  // 강제로 데이터 새로고침 (사용하지 않음)
  void _forceRefreshData() {
    print('강제 데이터 새로고침 실행');
    _loadFromStorage();
    Future.delayed(Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          // UI 갱신 포스
          final newTotal = totalKcal;
          widget.onTotalKcalChanged?.call(newTotal);
          CalorieBar.updateKcal(newTotal);
        });
      }
    });
  }
  
  @override
  void didUpdateWidget(MealSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.onTotalKcalChanged?.call(totalKcal);
  }

  @override
  Widget build(BuildContext context) {
    // 화면이 그려질 때마다 날짜 확인 및 데이터 갱신
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDateChange();
      widget.onTotalKcalChanged?.call(totalKcal);
    });
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Meal",
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD600),
                  shape: BoxShape.circle,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(19),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MealPlanningFlow(),
                        ),
                      );
                    },
                    child: const Center(
                      child: Text(
                        'AI',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MealCard(
                  mealType: 'Breakfast',
                  foods: foods['Breakfast'] ?? 0,
                  kcal: kcals['Breakfast'] ?? 0,
                  goalKcal: goalKcals['Breakfast']!,
                  onTap: () => _handleMealCardTap('Breakfast'),
                  // 이미지 대신 아이콘 위젯 사용
                  icon: Icons.free_breakfast,
                  iconColor: Colors.amber[700],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MealCard(
                  mealType: 'Lunch',
                  foods: foods['Lunch'] ?? 0,
                  kcal: kcals['Lunch'] ?? 0,
                  goalKcal: goalKcals['Lunch']!,
                  onTap: () => _handleMealCardTap('Lunch'),
                  // 이미지 대신 아이콘 위젯 사용
                  icon: Icons.lunch_dining,
                  iconColor: Colors.orange[700],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MealCard(
                  mealType: 'Dinner',
                  foods: foods['Dinner'] ?? 0,
                  kcal: kcals['Dinner'] ?? 0,
                  goalKcal: goalKcals['Dinner']!,
                  onTap: () => _handleMealCardTap('Dinner'),
                  // 이미지 대신 아이콘 위젯 사용
                  icon: Icons.dinner_dining,
                  iconColor: Colors.deepPurple[400],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _MealCard extends StatelessWidget {
  final String mealType;
  final int foods;
  final int kcal;
  final int goalKcal;
  final String? image; // 선택적 이미지 경로
  final IconData? icon; // 선택적 아이콘
  final Color? iconColor; // 아이콘 색상
  final VoidCallback? onTap;
  
  const _MealCard({
    required this.mealType,
    required this.foods,
    required this.kcal,
    required this.goalKcal,
    this.image,
    this.icon,
    this.iconColor,
    this.onTap,
  }) : assert(image != null || icon != null, '이미지 또는 아이콘이 지정되어야 합니다');

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: icon != null
                ? Icon(icon, size: 32, color: iconColor ?? Colors.grey)
                : Image.asset(
                    image!,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => 
                        const Icon(Icons.restaurant_menu, size: 32, color: Colors.grey),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              mealType,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              foods > 0 ? '$foods Foods' : '0 Foods',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 2),
            Text(
              '$kcal kcal',
              style: const TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Icon(Icons.chevron_right, color: Color(0xFFB7E66B), size: 22),
          ],
        ),
      ),
    );
  }
}

