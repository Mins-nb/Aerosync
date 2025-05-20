import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/openai_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MealInputScreen extends StatefulWidget {
  final String mealType;
  const MealInputScreen({Key? key, required this.mealType}) : super(key: key);

  @override
  State<MealInputScreen> createState() => _MealInputScreenState();
}

class _MealInputScreenState extends State<MealInputScreen> {
  // 식단 기록 저장 키
  // 캘린더용 기록 키 (캘린더 화면과 호환되도록 v1 추가)
  String get _mealRecordsKey => 'meal_records_v1';
  
  // 오늘 날짜 문자열
  String get _todayString => DateFormat('yyyy-MM-dd').format(DateTime.now());
  
  // 홈 화면용 Today's Meal 위젯을 위한 키 - MealSection 형식과 호환
  String get _homeMealKey => 'meal_${_todayString}_${widget.mealType}';
  
  String _input = '';
  bool _loading = false;
  late final TextEditingController _controller;

  // 카드 리스트: [{meal: 음식명, result: 분석결과, parsed: 표 데이터(Map<String,String>)}]
  List<Map<String, dynamic>> _mealCards = [];

  // 날짜별 식사 데이터 저장을 위한 키
  String get _prefsKey => 'meal_cards_v1_${widget.mealType}_$_todayString';
  
  // 이전 형식의 키 (마이그레이션용)
  String get _oldPrefsKey => 'meal_cards_v1_${widget.mealType}';

  // OpenAI API 키를 .env 파일에서 로드
  late final OpenAIService _openAIService;

  Future<void> _saveCards() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. 기존 레거시 형식으로 저장 (meal_cards_v1_*)
    final enc = jsonEncode(_mealCards.map((e) => {
      ...e,
      // parsed(Map) 저장시 String으로 변환
      if (e['parsed'] != null) 'parsed': jsonEncode(e['parsed'])
    }).toList());
    await prefs.setString(_prefsKey, enc);
    
    // 2. 홈 화면의 Today's Meal 위젯과 호환되는 형식으로도 저장 (meal_{date}_{mealType})
    print('홈 화면 호환 형식으로 저장: $_homeMealKey');
    
    // 각 음식을 별도의 JSON 문자열로 변환하여 리스트로 저장
    List<String> stringItems = [];
    for (var card in _mealCards) {
      final mealItem = {
        'meal': card['meal'],
        'nutrients': card['nutrients'],
        'kcal': _extractKcalFromNutrients(card['nutrients']),
        'emoji': card['emoji'],
        'servingInfo': card['servingInfo']
      };
      stringItems.add(jsonEncode(mealItem));
    }
    
    // MealSection에서 읽을 수 있는 형식으로 저장
    await prefs.setStringList(_homeMealKey, stringItems);
    print('홈 화면용 식사 데이터 저장됨: ${stringItems.length}개 항목');
  }
  
  // 영양소 데이터에서 칼로리 값만 추출
  int _extractKcalFromNutrients(Map<String, dynamic>? nutrients) {
    if (nutrients == null) return 0;
    
    final kcalStr = nutrients['칼로리'];
    if (kcalStr == null) return 0;
    
    // 숫자값만 추출 (예: "214kcal" -> 214)
    final numericStr = kcalStr.toString().replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(numericStr) ?? 0;
  }

  Future<void> _loadCards() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    
    // 오늘 날짜의 데이터가 없으면 이전 형식의 키로 확인 (마이그레이션용)
    if (raw == null) {
      final oldRaw = prefs.getString(_oldPrefsKey);
      if (oldRaw != null) {
        print('이전 형식의 데이터 발견: $_oldPrefsKey -> $_prefsKey로 마이그레이션');  
        // 이전 형식의 데이터를 새 형식으로 이전
        await prefs.setString(_prefsKey, oldRaw);
        // 이전 데이터는 더이상 필요 없으므로 삭제
        await prefs.remove(_oldPrefsKey);
        
        // 마이그레이션된 데이터 로드
        _loadParsedData(oldRaw);
        return;
      }
      
      // 데이터가 없으면 빈 배열로 설정
      setState(() {
        _mealCards = [];
      });
      return;
    }
    
    // 기존 형식의 데이터 로드
    _loadParsedData(raw);
  }
  
  // 데이터 파싱을 위한 메서드 분리
  void _loadParsedData(String raw) {
    final List list = jsonDecode(raw);
    setState(() {
      _mealCards = list.map<Map<String, dynamic>>((e) => {
        ...e,
        'nutrients': e['nutrients'] != null
            ? Map<String, String>.from((e['nutrients'] as Map).map((key, value) => MapEntry(key.toString(), value.toString())))
            : null,
        'parsed': e['parsed'] != null
            ? Map<String, String>.from(jsonDecode(e['parsed']))
            : null,
      }).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(() {
      setState(() {
        _input = _controller.text;
      });
    });
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    _openAIService = OpenAIService(apiKey); // 새로운 OpenAIService 생성자 사용
    _loadCards();
  }

  // 홈 화면으로 돌아가면서 결과 전달
  void _notifyHomeScreenAndPop() {
    // 식사 항목과 총 칼로리 계산
    int mealCount = _mealCards.length;
    int totalKcal = 0;
    
    for (var card in _mealCards) {
      if (card['nutrients'] != null && card['nutrients']['칼로리'] != null) {
        final kcalStr = card['nutrients']['칼로리'] as String;
        final kcalNum = int.tryParse(kcalStr.replaceAll(RegExp(r'[^0-9]'), ''));
        if (kcalNum != null) {
          totalKcal += kcalNum;
        }
      }
    }
    
    print('홈 화면으로 돌아가기: ${widget.mealType}에 $mealCount개 항목, 총 $totalKcal 칼로리');
    
    // 결과 반환하고 화면 종료
    Navigator.pop(context, {
      'mealType': widget.mealType,
      'mealCount': mealCount,
      'totalKcal': totalKcal,
      'updated': true,
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  Future<void> _analyzeMeal() async {
    setState(() {
      _loading = true;
    });
    final res = await _openAIService.analyzeMeal(_input);

    // 영양성분 및 이모지 파싱
    String? emoji;
    Map<String, String> nutrients = {};
    String? servingInfo;
    if (res != null) {
      // 이모지: 마지막 줄에 단독 이모지
      final lines = res.trim().split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isNotEmpty && RegExp(r'^[\u{1F300}-\u{1FAFF}\u2600-\u27BF\uFE0F]+', unicode: true).hasMatch(lines.last.trim())) {
        emoji = lines.removeLast().trim();
      }
      // 영양성분: "이름 숫자" 패턴
      final nutriReg = RegExp(r'^(칼로리|단백질|지방|탄수화물)\s*([0-9.,]+\s*[a-zA-Z가-힣]*)$', multiLine: true);
      for (final l in lines) {
        final m = nutriReg.firstMatch(l.trim());
        if (m != null) {
          nutrients[m.group(1)!] = m.group(2)!.trim();
        } else if (servingInfo == null && l.contains('기준')) {
          servingInfo = l.trim();
        }
      }
    }
    
    // 새 식사 카드
    final mealCard = {
      'meal': _input,
      'result': res ?? '분석 결과 없음',
      'nutrients': nutrients,
      'emoji': emoji,
      'servingInfo': servingInfo,
    };
    
    setState(() {
      _mealCards.insert(0, mealCard);
      _controller.clear();
      _input = '';
      _loading = false;
    });
    
    // 로컬 저장소에 저장
    await _saveCards();
    
    // report 탭의 식단 기록에도 저장
    await _saveToMealRecords(mealCard);
  }

  Future<void> _removeCard(int idx) async {
    final removedCard = _mealCards[idx];
    setState(() {
      _mealCards.removeAt(idx);
    });
    await _saveCards();
    
    // report 탭의 식단 기록에서도 삭제
    await _removeFromMealRecords(removedCard);
  }
  
  // 식단 기록 저장 (report 탭용)
  Future<void> _saveToMealRecords(Map<String, dynamic> mealCard) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> mealRecords = [];
    
    // 기존 기록 불러오기
    final mealRecordsJson = prefs.getString(_mealRecordsKey);
    if (mealRecordsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(mealRecordsJson) as List<dynamic>;
        mealRecords = List<Map<String, dynamic>>.from(decoded);
        print('기존 식단 기록 ${mealRecords.length}개 불러옴');
      } catch (e) {
        print('식단 기록 로딩 오류: $e');
      }
    } else {
      print('저장된 식단 기록 없음, 새로 생성');
    }
    
    // 새 기록 추가
    final newRecord = {
      'date': DateTime.now().toIso8601String(),
      'mealType': widget.mealType,
      'mealName': mealCard['meal'],
      'nutrients': mealCard['nutrients'],
      'emoji': mealCard['emoji'],
      'servingInfo': mealCard['servingInfo'],
      'result': mealCard['result'],
    };
    
    mealRecords.add(newRecord);
    print('새 식단 기록 추가됨: ${newRecord['mealName']} (${widget.mealType})');
    
    // 저장
    await prefs.setString(_mealRecordsKey, jsonEncode(mealRecords));
    print('총 ${mealRecords.length}개의 식단 기록이 저장됨');
  }
  
  // 식단 기록 삭제 (report 탭용)
  Future<void> _removeFromMealRecords(Map<String, dynamic> mealCard) async {
    final prefs = await SharedPreferences.getInstance();
    final mealRecordsJson = prefs.getString(_mealRecordsKey);
    
    if (mealRecordsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(mealRecordsJson) as List<dynamic>;
        List<Map<String, dynamic>> mealRecords = List<Map<String, dynamic>>.from(decoded);
        
        final beforeCount = mealRecords.length;
        print('식단 기록 삭제 시도: ${mealCard['meal']} (${widget.mealType})');
        
        // 일치하는 항목 찾아 삭제 (식사명과 식사 유형으로 확인)
        mealRecords.removeWhere((record) => 
          record['mealName'] == mealCard['meal'] &&
          record['mealType'] == widget.mealType
        );
        
        final removedCount = beforeCount - mealRecords.length;
        print('$removedCount개 항목 삭제됨, 남은 기록 수: ${mealRecords.length}');
        
        // 저장
        await prefs.setString(_mealRecordsKey, jsonEncode(mealRecords));
        print('수정된 식단 기록 저장됨');
      } catch (e) {
        print('식단 기록 삭제 오류: $e');
      }
    } else {
      print('삭제할 식단 기록이 없음');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _notifyHomeScreenAndPop();
        return false; // 직접 pop을 처리할 것이므로 false 반환
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text('${widget.mealType} 입력'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: _notifyHomeScreenAndPop,
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What did you eat?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter your meal',
                ),
                controller: _controller,
              ),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _input.trim().isEmpty || _loading ? null : _analyzeMeal,
                  child: _loading ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text('분석'),
                ),
              ),
              SizedBox(height: 32),
              if (_mealCards.isNotEmpty)
                ...[
                  Text('내가 먹은 음식', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _mealCards.length,
                      itemBuilder: (context, idx) {
                        final card = _mealCards[idx];
                        final nutrients = card['nutrients'] as Map<String, String>?;
                        final emoji = card['emoji'] as String?;
                        final servingInfo = card['servingInfo'] as String?;
                        return Card(
                          color: Color(0xFFF7FAF7),
                          margin: EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Row(
                                        children: [
                                          if (emoji != null) Text(emoji, style: TextStyle(fontSize: 20)),
                                          SizedBox(width: emoji != null ? 8 : 0),
                                          Text(
                                            card['meal'] ?? '',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.close, size: 20, color: Colors.grey),
                                      onPressed: () => _removeCard(idx),
                                      tooltip: '삭제',
                                    ),
                                  ],
                                ),
                                if (servingInfo != null) ...[
                                  SizedBox(height: 6),
                                  Text(servingInfo, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                                ],
                                if (nutrients != null && nutrients.isNotEmpty) ...[
                                  SizedBox(height: 8),
                                  Table(
                                    columnWidths: const {
                                      0: IntrinsicColumnWidth(),
                                      1: FlexColumnWidth(),
                                    },
                                    children: nutrients.entries.map((e) => TableRow(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Text(e.key, style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Text(e.value),
                                        ),
                                      ],
                                    )).toList(),
                                  ),
                                ]
                                else ...[
                                  SizedBox(height: 8),
                                  Text(
                                    card['result'] ?? '',
                                    style: TextStyle(fontSize: 15, color: Colors.black87),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ]
            ],
          ),
        ),
      ),
    );
  }
}
