import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // 이벤트를 저장할 맵
  Map<DateTime, List<dynamic>> _events = {};
  
  // 러닝 기록 로드
  Future<void> _loadRunningEvents() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 자유 달리기 기록 불러오기
    final freeRunJson = prefs.getString('free_run_records_v1');
    if (freeRunJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(freeRunJson) as List<dynamic>;
        
        for (var record in decoded) {
          final date = DateTime.parse(record['date'] as String);
          final formattedDate = DateTime(date.year, date.month, date.day);
          
          if (!_events.containsKey(formattedDate)) {
            _events[formattedDate] = [];
          }
          
          _events[formattedDate]!.add({
            'type': 'free_run',
            'distance': record['distance'] as double,
            'duration': Duration(seconds: record['duration'] as int),
            'date': date,
          });
        }
      } catch (e) {
        print('자유 달리기 기록 로딩 오류: $e');
      }
    }
    
    // 테스트 기록 불러오기
    final testRecordsJson = prefs.getString('test_records_v1');
    if (testRecordsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(testRecordsJson) as List<dynamic>;
        
        for (var record in decoded) {
          final date = DateTime.parse(record['date'] as String);
          final formattedDate = DateTime(date.year, date.month, date.day);
          
          if (!_events.containsKey(formattedDate)) {
            _events[formattedDate] = [];
          }
          
          _events[formattedDate]!.add({
            'type': 'test',
            'testType': record['testType'] as int,
            'distance': record['distance'] as double,
            'duration': Duration(seconds: record['duration'] as int),
            'date': date,
            'vo2max': record['vo2max'] as double,
          });
        }
      } catch (e) {
        print('테스트 기록 로딩 오류: $e');
      }
    }
    
    // 식단 기록 불러오기
    final mealRecordsJson = prefs.getString('meal_records_v1');
    if (mealRecordsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(mealRecordsJson) as List<dynamic>;
        
        for (var record in decoded) {
          final date = DateTime.parse(record['date'] as String);
          final formattedDate = DateTime(date.year, date.month, date.day);
          
          if (!_events.containsKey(formattedDate)) {
            _events[formattedDate] = [];
          }
          
          _events[formattedDate]!.add({
            'type': 'meal',
            'mealType': record['mealType'] as String,
            'mealName': record['mealName'] as String,
            'date': date,
          });
        }
      } catch (e) {
        print('식단 기록 로딩 오류: $e');
      }
    }
    
    // UI 업데이트
    setState(() {});
  }
  
  // 시간 형식 변환 (초 -> MM:SS)
  String _formatDuration(int seconds) {
    final mins = (seconds / 60).floor();
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  
  // 선택한 날짜의 이벤트 목록
  List<dynamic> _getEventsForDay(DateTime day) {
    final formattedDate = DateTime(day.year, day.month, day.day);
    return _events[formattedDate] ?? [];
  }
  
  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadRunningEvents();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
  backgroundColor: const Color(0xFF3C4452),
  elevation: 0,
  iconTheme: const IconThemeData(color: Colors.white),
  title: const Text('활동 캘린더', style: TextStyle(color: Colors.white)),

      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2023, 1, 1),
            lastDay: DateTime.utc(2025, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            eventLoader: _getEventsForDay,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            calendarStyle: const CalendarStyle(
              markersMaxCount: 3,
              markerDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.grey,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return null;
                
                return Positioned(
                  bottom: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: events.any((e) => e is Map && (e['type'] == 'free_run' || e['type'] == 'test')) 
                        ? Colors.blue  // 러닝 기록이 있으면 파란색
                        : Colors.green, // 식단 기록만 있으면 초록색
                    ),
                    width: 8.0,
                    height: 8.0,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: _selectedDay == null
                ? const Center(child: Text('날짜를 선택하세요'))
                : _buildEventList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEventList() {
    final events = _getEventsForDay(_selectedDay!);
    
    if (events.isEmpty) {
      return const Center(child: Text('이 날의 기록이 없습니다'));
    }
    
    // 이벤트 종류별로 그룹화
    final runningEvents = events.where((e) => e is Map && (e['type'] == 'free_run' || e['type'] == 'test')).toList();
    final mealEvents = events.where((e) => e is Map && e['type'] == 'meal').toList();
    
    return ListView(
      children: [
        if (runningEvents.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '러닝 활동',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ...runningEvents.map(_buildRunningEventCard),
        ],
        
        if (mealEvents.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '식단 기록',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ...mealEvents.map(_buildMealEventCard),
        ],
      ],
    );
  }
  
  Widget _buildRunningEventCard(dynamic event) {
    if (event is! Map) return const SizedBox.shrink(); // 유효하지 않은 이벤트 무시
    
    final isFreeRun = event['type'] == 'free_run';
    final formattedDate = DateFormat.jm().format(event['date'] as DateTime);
    final distance = (event['distance'] as double).toStringAsFixed(2);
    final duration = _formatDuration((event['duration'] as Duration).inSeconds);
    
    String title = isFreeRun ? '자유 달리기' : '테스트 달리기';
    if (!isFreeRun && event['testType'] != null) {
      // 테스트 타입 확인
      final testType = event['testType'] as int;
      switch (testType) {
        case 0: title = '1.5마일(2.4km) 달리기'; break;
        case 1: title = '5분 달리기'; break;
        case 2: title = '12분 달리기'; break;
        case 3: title = '1마일 걷기'; break;
      }
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(formattedDate, style: TextStyle(color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.straighten, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                Text('거리: $distance km'),
                const SizedBox(width: 16),
                const Icon(Icons.timer, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                Text('시간: $duration'),
              ],
            ),
            if (!isFreeRun && event['vo2max'] != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.trending_up, size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text('VO2max: ${(event['vo2max'] as double).toStringAsFixed(1)}'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildMealEventCard(dynamic event) {
    if (event is! Map) return const SizedBox.shrink(); // 유효하지 않은 이벤트 무시
    
    final formattedDate = DateFormat.jm().format(event['date'] as DateTime);
    final mealType = event['mealType'] as String;
    final mealName = event['mealName'] as String;
    
    // 식사 타입에 따른 색상
    Color typeColor;
    switch (mealType.toLowerCase()) {
      case 'breakfast': typeColor = Colors.orange; break;
      case 'lunch': typeColor = Colors.green; break;
      case 'dinner': typeColor = Colors.indigo; break;
      default: typeColor = Colors.grey;
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: typeColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                mealType,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mealName,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            Text(formattedDate, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}