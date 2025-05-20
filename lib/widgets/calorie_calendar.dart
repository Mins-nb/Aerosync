import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/calorie_service.dart';

class CalorieCalendar extends StatefulWidget {
  const CalorieCalendar({Key? key}) : super(key: key);

  @override
  State<CalorieCalendar> createState() => _CalorieCalendarState();
}

class _CalorieCalendarState extends State<CalorieCalendar> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, DayStatus> _dayStatusMap = {};

  @override
  void initState() {
    super.initState();
    _loadCalendarData();
  }

  // 지난 30일간의 데이터 불러오기
  Future<void> _loadCalendarData() async {
    // 임시로 Map 초기화
    final Map<DateTime, DayStatus> statusMap = {};
    
    // 최근 30일 데이터 불러오기
    final now = DateTime.now();
    for (int i = 0; i < 30; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      
      // 식이 목표 달성 여부
      final dietSuccess = await CalorieService.isCalorieIntakeGoalAchieved(date);
      
      // 운동 목표 달성 여부
      final exerciseSuccess = await CalorieService.isExerciseGoalAchieved(date);
      
      // 상태 저장
      if (dietSuccess && exerciseSuccess) {
        statusMap[date] = DayStatus.bothSuccess;
      } else if (dietSuccess) {
        statusMap[date] = DayStatus.dietSuccess;
      } else if (exerciseSuccess) {
        statusMap[date] = DayStatus.exerciseSuccess;
      } else {
        statusMap[date] = DayStatus.failed;
      }
    }
    
    if (mounted) {
      setState(() {
        _dayStatusMap = statusMap;
      });
    }
  }

  // 캘린더 날짜 셀 빌더
  Widget _buildCalendarCell(BuildContext context, DateTime day, DateTime focusedDay) {
    final isSelected = isSameDay(day, _selectedDay);
    final dayStatus = _dayStatusMap[DateTime(day.year, day.month, day.day)];
    
    // 오늘 날짜 표시
    final isToday = isSameDay(day, DateTime.now());
    
    BoxDecoration cellDecoration;
    Color textColor = Colors.black;
    IconData? statusIcon;
    Color? iconColor;
    
    if (isSelected) {
      cellDecoration = BoxDecoration(
        color: const Color(0xFFE3F2FD),
        shape: BoxShape.circle,
      );
    } else if (isToday) {
      cellDecoration = BoxDecoration(
        border: Border.all(color: const Color(0xFF00BCD4), width: 1.5),
        shape: BoxShape.circle,
      );
    } else {
      cellDecoration = const BoxDecoration();
    }
    
    // 날짜 상태에 따른 아이콘 지정
    if (dayStatus != null) {
      switch (dayStatus) {
        case DayStatus.bothSuccess:
          statusIcon = Icons.emoji_events;
          iconColor = const Color(0xFF4CAF50);
          break;
        case DayStatus.dietSuccess:
          statusIcon = Icons.restaurant;
          iconColor = const Color(0xFFFF9800);
          break;
        case DayStatus.exerciseSuccess:
          statusIcon = Icons.directions_run;
          iconColor = const Color(0xFF2196F3);
          break;
        case DayStatus.failed:
          statusIcon = Icons.close;
          iconColor = const Color(0xFFF44336);
          break;
        // default: (제거됨)
          statusIcon = null;
      }
    }
    
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: cellDecoration,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  color: textColor,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (statusIcon != null)
                Icon(
                  statusIcon,
                  size: 12,
                  color: iconColor,
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Text(
                '칼로리 관리 캘린더',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ),
            TableCalendar(
              firstDay: DateTime.utc(2022, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
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
              calendarBuilders: CalendarBuilders(
                defaultBuilder: _buildCalendarCell,
                todayBuilder: _buildCalendarCell,
                selectedBuilder: _buildCalendarCell,
              ),
              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLegendItem(
                    icon: Icons.emoji_events, 
                    label: '전체 성공', 
                    color: const Color(0xFF4CAF50)
                  ),
                  _buildLegendItem(
                    icon: Icons.restaurant, 
                    label: '식단 성공', 
                    color: const Color(0xFFFF9800)
                  ),
                  _buildLegendItem(
                    icon: Icons.directions_run, 
                    label: '운동 성공', 
                    color: const Color(0xFF2196F3)
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 캘린더 범례 아이템 위젯
  Widget _buildLegendItem({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

// 날짜 상태 열거형
enum DayStatus {
  bothSuccess,    // 식이 및 운동 모두 성공
  dietSuccess,    // 식이만 성공
  exerciseSuccess, // 운동만 성공
  failed,         // 모두 실패
}
