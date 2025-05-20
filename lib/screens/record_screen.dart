import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/run_type.dart';
import 'test_detail_screen.dart';
import 'running_result_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

// 테스트 기록 클래스 (자유 달리기, 1마일 걷기, 1.5마일 달리기, 5분 달리기, 12분 달리기)
class _TestRecord {
  final TestScreenType testType;
  final double distance; // km
  final Duration duration;
  final DateTime date;
  final double vo2max;
  final List<LatLng>? route; // 경로 추가
  final String? recordId; // UUID 추가
  final int? calories; // 소모된 칼로리
  final String? intensity; // 운동 강도

  _TestRecord({
    required this.testType,
    required this.distance,
    required this.duration,
    required this.date,
    required this.vo2max,
    this.route,
    this.recordId,
    this.calories,
    this.intensity,
  });

  String get testName {
    switch (testType) {
      case TestScreenType.run1_5mile:
        return '1.5마일(2.4km) 달리기';
      case TestScreenType.run5min:
        return '5분 달리기';
      case TestScreenType.run12min:
        return '12분 달리기';
      case TestScreenType.walk1mile:
        return '1마일 걷기';
    }
  }

  double get pace {
    if (distance <= 0) return 0;
    return duration.inSeconds / 60 / distance; // min/km
  }

  String getVO2maxLevel() {
    if (vo2max <= 0) return '-';
    if (vo2max < 30) return '체력 수준: 낮음';
    if (vo2max < 40) return '체력 수준: 보통';
    if (vo2max < 50) return '체력 수준: 양호';
    return '체력 수준: 우수';
  }

  // RunGoal 객체 생성
  RunGoal getRunGoal() {
    switch (testType) {
      case TestScreenType.run1_5mile:
        return RunGoal.test1_5Mile();
      case TestScreenType.run5min:
        return RunGoal.test5Min();
      case TestScreenType.run12min:
        return RunGoal.test12Min();
      case TestScreenType.walk1mile:
        return RunGoal.testWalk1_6km();
    }
  }

  Map<String, dynamic> toJson() {
    // 경로 직렬화 (위도/경도 쌍의 리스트)
    final routeJson = route?.map((latLng) => {
      'lat': latLng.latitude,
      'lng': latLng.longitude,
    }).toList();
    
    return {
      'testType': testType.index,
      'distance': distance,
      'duration': duration.inSeconds,
      'date': date.toIso8601String(),
      'vo2max': vo2max,
      'route': routeJson,
      'recordId': recordId,  
      'calories': calories,
      'intensity': intensity,  
    };
  }

  factory _TestRecord.fromJson(Map<String, dynamic> json) {
    // 경로 역직렬화
    List<LatLng>? routeData;
    if (json['route'] != null) {
      routeData = (json['route'] as List).map<LatLng>((pointJson) {
        final Map<String, dynamic> point = pointJson as Map<String, dynamic>;
        return LatLng(
          point['lat'] as double,
          point['lng'] as double,
        );
      }).toList();
    }
    
    return _TestRecord(
      testType: TestScreenType.values[json['testType'] as int],
      distance: json['distance'] as double,
      duration: Duration(seconds: json['duration'] as int),
      date: DateTime.parse(json['date'] as String),
      vo2max: json['vo2max'] as double,
      route: routeData,
      recordId: json['recordId'] as String?,
    );
  }
}

// 자유 달리기 기록 클래스 (별도 관리)
class _FreeRunRecord {
  final double distance; // km
  final Duration duration;
  final DateTime date;
  final List<LatLng>? route;
  final double pace; // min/km
  final String? recordId; // UUID 추가
  final int? calories; // 소모된 칼로리
  final String? intensity; // 운동 강도 (low, medium, high)
  
  _FreeRunRecord({
    required this.distance,
    required this.duration,
    required this.date,
    this.route,
    double? pace,
    this.recordId,
    this.calories,
    this.intensity,
  }) : pace = pace ?? (distance > 0 ? duration.inSeconds / 60 / distance : 0);

  Map<String, dynamic> toJson() {
    final routeJson = route?.map((latLng) => {
      'lat': latLng.latitude,
      'lng': latLng.longitude,
    }).toList();
    
    return {
      'distance': distance,
      'duration': duration.inSeconds,
      'date': date.toIso8601String(),
      'route': routeJson,
      'pace': pace,
      'recordId': recordId,
      'calories': calories,
      'intensity': intensity,
    };
  }

  factory _FreeRunRecord.fromJson(Map<String, dynamic> json) {
    List<LatLng>? routeData;
    if (json['route'] != null) {
      routeData = (json['route'] as List).map<LatLng>((pointJson) {
        final Map<String, dynamic> point = pointJson as Map<String, dynamic>;
        return LatLng(
          point['lat'] as double,
          point['lng'] as double,
        );
      }).toList();
    }
    
    return _FreeRunRecord(
      distance: json['distance'] as double,
      duration: Duration(seconds: json['duration'] as int),
      date: DateTime.parse(json['date'] as String),
      route: routeData,
      pace: json['pace'] as double,
      calories: json['calories'] as int?,
      intensity: json['intensity'] as String?,
      recordId: json['recordId'] as String?,
    );
  }
}

class _RecordScreenState extends State<RecordScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  List<_FreeRunRecord> _freeRunRecords = [];
  List<_TestRecord> _testRecords = [];
  
  static const String _freeRunRecordsKey = 'free_run_records_v1';
  static const String _testRecordsKey = 'test_records_v1';

  // 식단 기록 클래스
  List<Map<String, dynamic>> _mealRecords = [];
  static const String _mealRecordsKey = 'meal_records_v1';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // 탭 수 3개로 변경
    _loadRecords();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 모든 기록 불러오기
  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 자유 달리기 기록 불러오기
    final freeRunJson = prefs.getString(_freeRunRecordsKey);
    if (freeRunJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(freeRunJson) as List<dynamic>;
        setState(() {
          _freeRunRecords = decoded
              .map((e) => _FreeRunRecord.fromJson(Map<String, dynamic>.from(e as Map<dynamic, dynamic>)))
              .toList();
          // 날짜 기준 내림차순 정렬
          _freeRunRecords.sort((a, b) => b.date.compareTo(a.date));
        });
      } catch (e) {
        print('자유 달리기 기록 로딩 오류: $e');
      }
    }

    // 테스트 기록 불러오기
    final testRecordsJson = prefs.getString(_testRecordsKey);
    if (testRecordsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(testRecordsJson) as List<dynamic>;
        setState(() {
          _testRecords = decoded
              .map((e) => _TestRecord.fromJson(Map<String, dynamic>.from(e as Map<dynamic, dynamic>)))
              .toList();
          // 날짜 기준 내림차순 정렬
          _testRecords.sort((a, b) => b.date.compareTo(a.date));
        });
      } catch (e) {
        print('테스트 기록 로딩 오류: $e');
      }
    }

    // 식단 기록 불러오기
    final mealRecordsJson = prefs.getString(_mealRecordsKey);
    if (mealRecordsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(mealRecordsJson) as List<dynamic>;
        setState(() {
          _mealRecords = List<Map<String, dynamic>>.from(decoded);
          // 날짜 기준 내림차순 정렬 (날짜 문자열 비교)
          _mealRecords.sort((a, b) {
            final dateA = DateTime.parse(a['date'] as String);
            final dateB = DateTime.parse(b['date'] as String);
            return dateB.compareTo(dateA);
          });
        });
      } catch (e) {
        print('식단 기록 로딩 오류: $e');
      }
    }
  }

  // 자유 달리기 기록 저장
  Future<void> _saveFreeRunRecord(_FreeRunRecord record) async {
    setState(() {
      _freeRunRecords.insert(0, record);
    });
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_freeRunRecordsKey, 
      jsonEncode(_freeRunRecords.map((e) => e.toJson()).toList())
    );
  }

  // 테스트 기록 저장
  Future<void> _saveTestRecord(_TestRecord record) async {
    setState(() {
      _testRecords.insert(0, record);
    });
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_testRecordsKey, 
      jsonEncode(_testRecords.map((e) => e.toJson()).toList())
    );
  }

  // 테스트 데이터 생성 (개발용)
  Future<void> _generateSampleData() async {
    // 자유 달리기 샘플
    final freeRunSample = _FreeRunRecord(
      distance: 5.2,
      duration: const Duration(minutes: 28, seconds: 35),
      date: DateTime.now().subtract(const Duration(days: 2)),
      route: [
        const LatLng(37.5665, 126.9780),
        const LatLng(37.5675, 126.9790),
        const LatLng(37.5685, 126.9800),
      ],
    );
    
    // 1.5마일 테스트 샘플
    final mileTestSample = _TestRecord(
      testType: TestScreenType.run1_5mile,
      distance: 2.4,
      duration: const Duration(minutes: 12, seconds: 45),
      date: DateTime.now().subtract(const Duration(days: 5)),
      vo2max: 41.8,
      route: [
        const LatLng(37.5665, 126.9780),
        const LatLng(37.5670, 126.9785),
        const LatLng(37.5675, 126.9790),
      ],
    );
    
    // 5분 테스트 샘플
    final min5TestSample = _TestRecord(
      testType: TestScreenType.run5min,
      distance: 1.1,
      duration: const Duration(minutes: 5),
      date: DateTime.now().subtract(const Duration(days: 10)),
      vo2max: 44.5,
      route: [
        const LatLng(37.5665, 126.9780),
        const LatLng(37.5670, 126.9785),
      ],
    );
    
    await _saveFreeRunRecord(freeRunSample);
    await _saveTestRecord(mileTestSample);
    await _saveTestRecord(min5TestSample);
  }

  // 시간 형식 변환 (초 -> MM:SS)
  String _formatDuration(int seconds) {
    final mins = (seconds / 60).floor();
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // 페이스 형식 변환 (분/km -> MM'SS")
  String _formatPace(double pace) {
    if (pace <= 0) return '-';
    final mins = pace.floor();
    final secs = ((pace - mins) * 60).round();
    return '$mins\'${secs.toString().padLeft(2, '0')}"';
  }

  // 날짜 형식 변환
  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // 자유 달리기 기록 탭
  Widget _buildFreeRunRecordsTab() {
    if (_freeRunRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('자유 달리기 기록이 없습니다. 새로운 달리기를 시작해보세요!'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _generateSampleData,
              child: const Text('샘플 데이터 생성 (개발용)'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _freeRunRecords.length,
      itemBuilder: (context, index) {
        final record = _freeRunRecords[index];
        return InkWell(
          onTap: () {
            // 러닝 결과 화면으로 이동
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => RunningResultScreen(
                  route: record.route ?? [],
                  distance: record.distance,
                  duration: record.duration,
                  pace: record.pace,
                  calories: record.calories ?? 0, // 칼로리 추가 (레거시 데이터는 기본값 0 사용)
                  intensity: record.intensity ?? 'low', // 운동 강도 추가 (레거시 데이터는 기본값 'low' 사용)
                  runGoal: RunGoal.freeRun(), // 자유 달리기 목표
                  recordId: record.recordId, // recordId 전달
                  isFromReport: true, // report 탭에서 접근했음을 표시
                ),
              ),
            );
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            color: Colors.grey[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '자유 달리기',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            _formatDate(record.date),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => _deleteFreeRunRecord(index),
                            tooltip: '기록 삭제',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem(
                        icon: Icons.straighten,
                        value: '${record.distance.toStringAsFixed(2)} km',
                        label: '거리',
                      ),
                      _buildStatItem(
                        icon: Icons.timer,
                        value: _formatDuration(record.duration.inSeconds),
                        label: '시간',
                      ),
                      _buildStatItem(
                        icon: Icons.speed,
                        value: _formatPace(record.pace),
                        label: '페이스',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 테스트 결과 탭
  Widget _buildTestRecordsTab() {
    if (_testRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('테스트 기록이 없습니다. 테스트를 진행해보세요!'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _generateSampleData,
              child: const Text('샘플 테스트 기록 추가 (개발용)'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _testRecords.length,
      itemBuilder: (context, index) {
        final record = _testRecords[index];
        return InkWell(
          onTap: () {
            // 테스트 결과 화면으로 이동
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => RunningResultScreen(
                  route: record.route ?? [],
                  distance: record.distance,
                  duration: record.duration,
                  pace: record.pace,
                  calories: record.calories ?? 0, // 칼로리 추가 (레거시 데이터는 기본값 0 사용)
                  intensity: record.intensity ?? 'low', // 운동 강도 추가 (레거시 데이터는 기본값 'low' 사용)
                  runGoal: record.getRunGoal(),
                  vo2max: record.vo2max,
                  recordId: record.recordId, // recordId 전달 추가
                  isFromReport: true, // report 탭에서 접근했음을 표시
                ),
              ),
            );
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            color: Colors.grey[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          record.testName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            _formatDate(record.date),
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => _deleteTestRecord(index),
                            tooltip: '기록 삭제',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _buildStatItem(
                              icon: Icons.straighten,
                              value: '${record.distance.toStringAsFixed(2)} km',
                              label: '거리',
                              iconSize: 18,
                              valueSize: 14,
                              labelSize: 12,
                            ),
                            const SizedBox(height: 8),
                            _buildStatItem(
                              icon: Icons.timer,
                              value: _formatDuration(record.duration.inSeconds),
                              label: '시간',
                              iconSize: 18,
                              valueSize: 14,
                              labelSize: 12,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            _buildStatItem(
                              icon: Icons.speed,
                              value: _formatPace(record.pace),
                              label: '페이스',
                              iconSize: 18,
                              valueSize: 14,
                              labelSize: 12,
                            ),
                            const SizedBox(height: 8),
                            _buildStatItem(
                              icon: Icons.trending_up,
                              value: record.vo2max.toStringAsFixed(1),
                              label: 'VO2max',
                              iconSize: 18,
                              valueSize: 14,
                              labelSize: 12,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      record.getVO2maxLevel(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 통계 아이템 위젯
  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    double iconSize = 22,
    double valueSize = 16,
    double labelSize = 14,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: Colors.grey[700]),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: valueSize,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: labelSize,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 러닝 기록 삭제 다이얼로그
  Future<bool?> _showDeleteConfirmDialog(String recordType, int index) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$recordType 삭제'),
        content: Text('이 $recordType을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // 자유 달리기 기록 삭제
  Future<void> _deleteFreeRunRecord(int index) async {
    final confirm = await _showDeleteConfirmDialog('자유 달리기 기록', index);
    if (confirm == true) {
      setState(() {
        _freeRunRecords.removeAt(index);
      });
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_freeRunRecordsKey, 
        jsonEncode(_freeRunRecords.map((e) => e.toJson()).toList())
      );
    }
  }

  // 테스트 기록 삭제
  Future<void> _deleteTestRecord(int index) async {
    final confirm = await _showDeleteConfirmDialog('테스트 기록', index);
    if (confirm == true) {
      setState(() {
        _testRecords.removeAt(index);
      });
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_testRecordsKey, 
        jsonEncode(_testRecords.map((e) => e.toJson()).toList())
      );
    }
  }

  // 식단 기록 탭
  Widget _buildMealRecordsTab() {
    if (_mealRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('식단 기록이 없습니다. 식단을 기록해보세요!'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // MealInputScreen으로 이동
                Navigator.pushNamed(context, '/meal-input', arguments: 'Breakfast');
              },
              child: const Text('식단 추가하기'),
            ),
          ],
        ),
      );
    }

    // 날짜별로 그룹화
    final Map<String, List<Map<String, dynamic>>> groupedMeals = {};
    for (final meal in _mealRecords) {
      final dateKey = _formatDate(DateTime.parse(meal['date'] as String));
      if (!groupedMeals.containsKey(dateKey)) {
        groupedMeals[dateKey] = [];
      }
      groupedMeals[dateKey]!.add(meal);
    }

    // 날짜 리스트 (정렬됨)
    final dateKeys = groupedMeals.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dateKeys.length,
      itemBuilder: (context, dateIndex) {
        final dateKey = dateKeys[dateIndex];
        final dayMeals = groupedMeals[dateKey]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                dateKey,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            ...dayMeals.map((meal) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              color: Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getMealTypeColor(meal['mealType'] as String),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            meal['mealType'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (meal['emoji'] != null) Text(meal['emoji'] as String, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            meal['mealName'] as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                          onPressed: () => _deleteMealRecord(dateIndex, dayMeals.indexOf(meal)),
                          tooltip: '기록 삭제',
                        ),
                      ],
                    ),
                    if (meal['nutrients'] != null && (meal['nutrients'] as Map<String, dynamic>).isNotEmpty) ...[  
                      const SizedBox(height: 12),
                      Table(
                        columnWidths: const {
                          0: IntrinsicColumnWidth(),
                          1: FlexColumnWidth(),
                        },
                        children: (meal['nutrients'] as Map<String, dynamic>).entries.map((e) => TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(e.value.toString(), style: const TextStyle(fontSize: 13)),
                            ),
                          ],
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            )).toList(),
          ],
        );
      },
    );
  }
  
  // 식단 기록 삭제
  Future<void> _deleteMealRecord(int dateIndex, int mealIndex) async {
    final confirm = await _showDeleteConfirmDialog('식단 기록', mealIndex);
    if (confirm == true) {
      // 날짜별로 그룹화한 데이터에서 삭제하는 것이 아니라 원본 리스트에서 삭제해야 함
      // 같은 날짜에 여러 개의 식단이 있을 수 있으므로 순서를 정확히 찾아야 함
      
      // 날짜별로 그룹화
      final Map<String, List<Map<String, dynamic>>> groupedMeals = {};
      for (final meal in _mealRecords) {
        final dateKey = _formatDate(DateTime.parse(meal['date'] as String));
        if (!groupedMeals.containsKey(dateKey)) {
          groupedMeals[dateKey] = [];
        }
        groupedMeals[dateKey]!.add(meal);
      }

      // 날짜 리스트 (정렬됨)
      final dateKeys = groupedMeals.keys.toList()..sort((a, b) => b.compareTo(a));
      
      // 해당 날짜와 식단 인덱스에 해당하는 식단 찾기
      if (dateIndex < dateKeys.length) {
        final dateKey = dateKeys[dateIndex];
        final dayMeals = groupedMeals[dateKey]!;
        
        if (mealIndex < dayMeals.length) {
          final targetMeal = dayMeals[mealIndex];
          
          // 원본 리스트에서 해당 식단 찾아서 삭제
          setState(() {
            _mealRecords.removeWhere((meal) => 
              meal['date'] == targetMeal['date'] && 
              meal['mealName'] == targetMeal['mealName'] &&
              meal['mealType'] == targetMeal['mealType']
            );
          });
          
          // 변경된 리스트 저장
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_mealRecordsKey, jsonEncode(_mealRecords));
        }
      }
    }
  }

  // 식단 유형별 색상
  Color _getMealTypeColor(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return Colors.orange;
      case 'lunch':
        return Colors.green;
      case 'dinner':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('기록', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF3C4452),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: '자유 달리기'),
            Tab(text: '테스트 결과'),
            Tab(text: '식단 기록'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFreeRunRecordsTab(),
          _buildTestRecordsTab(),
          _buildMealRecordsTab(),
        ],
      ),
    );
  }
}
