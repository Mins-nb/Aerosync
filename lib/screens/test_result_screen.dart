import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'test_detail_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/record.dart';
import 'package:hive/hive.dart';
import 'package:vibration/vibration.dart';

class TestResultScreen extends StatefulWidget {
  final TestScreenType testType;
  final double distance; // meter
  final Duration duration;
  final String? recordId; // 고유 식별자
  final bool isFromReport; // report 탭에서 접근했는지 여부

  const TestResultScreen({
    super.key, 
    required this.testType, 
    required this.distance, 
    required this.duration,
    this.recordId,
    this.isFromReport = false, // 기본값은 false
  });
  
  @override
  State<TestResultScreen> createState() => _TestResultScreenState();
}
  
class _TestResultScreenState extends State<TestResultScreen> {
  bool _isRecordSaved = false; // 기록 저장 완료 플래그
  
  @override
  void initState() {
    super.initState();
    _saveTestRecord();
    
    // 테스트가 완료되었음을 알리는 진동 (3초 지속)
    _triggerVibration();
    
    // 추가 진동 발생
    try {
      // 기본 진동 바로 호출
      if (!widget.isFromReport) {
        Vibration.vibrate();
        print("[결과 화면] 직접 진동 발생 1");
      }
    } catch (e) {
      print("[결과 화면] 직접 진동 오류: $e");
    }
  }
  
  // 3초간 진동을 실행하는 메서드
  Future<void> _triggerVibration() async {
    try {
      // report 탭에서 접근한 경우에는 진동을 실행하지 않음
      if (widget.isFromReport) return;
      
      print("[결과 화면] 진동 시작");
      
      // 기본 진동 - 가장 기본적인 호출
      Vibration.vibrate();
      
      // 잠시 대기 후 다시 진동
      await Future.delayed(const Duration(milliseconds: 500));
      Vibration.vibrate();
      
      print("[결과 화면] 진동 완료");
    } catch (e) {
      print("[결과 화면] 진동 오류: $e");
    }
  }
  
  // 테스트 결과 저장
  Future<void> _saveTestRecord() async {
    // 이미 저장되었다면 중복 저장 방지
    if (_isRecordSaved) {
      print('이미 기록이 저장되었습니다');
      return;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final recordBox = Hive.box<Record>('recordBox');
    
    // 새 기록이면 UUID 생성, 기존 기록이면 기존 UUID 사용
    // report 탭에서 접근한 경우에는 기록 저장 스킵
    final bool isReportView = widget.isFromReport;
    final uuid = widget.recordId ?? const Uuid().v4();
    
    // 현재 시간
    final now = DateTime.now();
    
    // report 탭에서 접근한 경우에는 기록 저장 단계 건너뛰기
    if (isReportView) {
      print('report 탭에서 접근한 기록입니다: $uuid');
      setState(() {
        _isRecordSaved = true;
      });
      return;
    }
    
    // UUID로 이미 저장된 기록이 있는지 확인
    final existingRecord = recordBox.get(uuid);
    if (existingRecord != null) {
      print('이미 저장된 기록 ID가 있습니다: $uuid');
      setState(() {
        _isRecordSaved = true;
      });
      return;
    }
    
    // 1. Hive에 기록 저장
    final record = Record(
      date: now,
      duration: widget.duration.inSeconds,
      distance: widget.distance / 1000, // m를 km로 변환
      pace: widget.duration.inSeconds / 60 / (widget.distance / 1000), // min/km
      recordId: uuid, // 고유 식별자
    );
    
    // 레코드 ID를 키로 사용하여 저장
    recordBox.put(uuid, record);
    
    // 2. SharedPreferences에 테스트 기록 저장
    const String testRecordsKey = 'test_records_v1';
    List<Map<String, dynamic>> testRecords = [];
    
    // 기존 기록 불러오기
    final String? testRecordsJson = prefs.getString(testRecordsKey);
    if (testRecordsJson != null) {
      final List<dynamic> decoded = jsonDecode(testRecordsJson) as List<dynamic>;
      testRecords = List<Map<String, dynamic>>.from(decoded);
    }
    
    // 테스트 유형 확인
    int testTypeInt;
    switch (widget.testType) {
      case TestScreenType.run1_5mile:
        testTypeInt = 1; // 1.5마일 테스트
        break;
      case TestScreenType.run5min:
        testTypeInt = 2; // 5분 테스트
        break;
      case TestScreenType.run12min:
        testTypeInt = 3; // 12분 테스트
        break;
      case TestScreenType.walk1mile:
        testTypeInt = 0; // 1마일 걸기 테스트
        break;
    }
    
    // UUID로 이미 저장된 기록인지 확인
    bool isDuplicate = false;
    for (var record in testRecords) {
      if (record['recordId'] == uuid) {
        isDuplicate = true;
        print('이미 저장된 테스트 기록 ID가 있습니다: $uuid');
        break;
      }
    }
    
    if (!isDuplicate) {
      // 새 기록
      Map<String, dynamic> newRecord = {
        'testType': testTypeInt,
        'distance': widget.distance / 1000, // m를 km로 변환
        'duration': widget.duration.inSeconds,
        'date': now.toIso8601String(),
        'vo2max': getVO2max(),
        'recordId': uuid,
      };
      
      testRecords.insert(0, newRecord);
      await prefs.setString(testRecordsKey, jsonEncode(testRecords));
      print('테스트 기록 저장 완료: $uuid');
    }
    
    setState(() {
      _isRecordSaved = true; // 저장 플래그 설정
    });
  }

  String get testName {
    switch (widget.testType) {
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

  String getResultText() {
    switch (widget.testType) {
      case TestScreenType.run1_5mile:
        // 시간(초)와 거리(2.4km)로 VO2max 추정 공식 예시
        // 실제 공식 필요시 수정
        final min = widget.duration.inMinutes;
        final sec = widget.duration.inSeconds % 60;
        return '2.4km를 $min분 $sec초에 완주했습니다.';
      case TestScreenType.run5min:
        // 5분 동안 달린 거리(m)로 VO2max 추정 공식 예시
        // 실제 공식 필요시 수정
        return '5분 동안 ${widget.distance.toStringAsFixed(0)}m를 달렸습니다.';
      case TestScreenType.run12min:
        // 12분 동안 달린 거리(m)로 VO2max 추정 공식 예시
        // 실제 공식 필요시 수정
        return '12분 동안 ${widget.distance.toStringAsFixed(0)}m를 달렸습니다.';
      case TestScreenType.walk1mile:
        return '1마일 걷기 결과 화면은 별도 구현 필요';
    }
  }

  double getVO2max() {
    switch (widget.testType) {
      case TestScreenType.run1_5mile:
        // VO2max = 483 / 시간(분) + 3.5
        final min = widget.duration.inSeconds / 60.0;
        if (min == 0) return 0;
        return 483 / min + 3.5;
      case TestScreenType.run5min:
        // VO2max = (달린 거리(m) / 5) * 0.2 + 3.5
        return (widget.distance / 5.0) * 0.2 + 3.5;
      case TestScreenType.run12min:
        // VO2max = (달린 거리(m) - 504.9) / 44.73
        return (widget.distance - 504.9) / 44.73;
      case TestScreenType.walk1mile:
        return 0;
    }
  }

  String getVO2maxComment(double vo2max) {
    if (vo2max == 0) return '';
    if (vo2max < 30) return '체력 수준: 낮음';
    if (vo2max < 40) return '체력 수준: 보통';
    if (vo2max < 50) return '체력 수준: 양호';
    return '체력 수준: 우수';
  }

  @override
  Widget build(BuildContext context) {
    final vo2max = getVO2max();
    return Scaffold(
      backgroundColor: Colors.yellow.shade600,
      appBar: AppBar(title: const Text('테스트 결과'), backgroundColor: Colors.yellow.shade600, elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(testName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Text('VO₂max', style: TextStyle(fontSize: 22, color: Colors.grey.shade800)),
              const SizedBox(height: 6),
              Text(vo2max.isNaN ? '-' : vo2max.toStringAsFixed(2), style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(getVO2maxComment(vo2max), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              const SizedBox(height: 20),
              Text(getResultText(), style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 12),
              Text('측정 시간: ${_formatDuration(widget.duration)}', style: const TextStyle(fontSize: 16)),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text('홈으로'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }


  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    final hours = d.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }
}
