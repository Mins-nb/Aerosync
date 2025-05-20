import 'package:flutter/material.dart';
import '../core/app_routes.dart';
import '../widgets/custom_text.dart';
import '../widgets/custom_button.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/run_type.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/record.dart';
import 'package:hive/hive.dart';
import 'package:vibration/vibration.dart';
import '../widgets/exercise_bar.dart'; // 운동 바 위젯 추가
import '../services/exercise_service.dart'; // 운동 서비스 추가

/// 운동 결과 화면
/// 운동 거리, 시간, 평균 페이스 데이터를 표시
/// Back to Home 클릭 시 HomeScreen 으로 이동
class RunningResultScreen extends StatefulWidget {
  final List<LatLng> route;
  final double distance; // km
  final Duration duration;
  final double pace; // min/km
  final RunGoal? runGoal; // 테스트 유형 정보 추가
  final double? vo2max; // VO2max 값 추가
  final String? recordId; // 기록의 고유 식별자
  final bool isFromReport; // report 탭에서 접근했는지 여부
  final int calories; // 소모된 칼로리 (kcal)
  final String intensity; // 운동 강도 (low, medium, high)
  
  const RunningResultScreen({
    super.key, 
    required this.route, 
    required this.distance, 
    required this.duration, 
    required this.pace,
    required this.calories,
    required this.intensity,
    this.runGoal,
    this.vo2max,
    this.recordId,
    this.isFromReport = false, // 기본값은 false
  });

  @override
  State<RunningResultScreen> createState() => _RunningResultScreenState();
}

class _RunningResultScreenState extends State<RunningResultScreen> {
  GoogleMapController? _mapController;
  bool _mapReady = false;
  double? _vo2max; // VO2max 계산 결과
  String _vo2maxLevel = ''; // VO2max 기반 체력 수준
  bool _isRecordSaved = false; // 기록 저장 완료 플래그
  
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

  String _formatPace(double pace) {
    if (!pace.isFinite || pace <= 0) return '-';
    final min = pace.floor();
    final sec = ((pace - min) * 60).round();
    return '$min\'$sec\" min/km';
  }
  
  @override
  void initState() {
  super.initState();
  // 경로가 비어있는 경우를 방지
  if (widget.route.isEmpty) {
  print('경로가 비어있습니다. 기본 위치를 사용합니다.');
  } else {
  print('경로 포인트 개수: ${widget.route.length}');
  // 맵이 렌더링된 후 카메라 위치 조정을 위한 지연
  Timer(const Duration(milliseconds: 500), () {
  if (_mapController != null && widget.route.isNotEmpty && mounted) {
  _fitMapToRoute();
  }
  });
  }
  
  // VO2max 계산 (테스트일 경우에만)
  _calculateVO2max();
  
  // 기록 저장
  _saveRecordToStorage();
  
  // 테스트인 경우에만 진동 실행 (3초 지속)
  if (!widget.isFromReport && widget.runGoal?.isTest == true) {
      _triggerVibration();
    }
  }
  
  // 3초간 진동을 실행하는 메서드
  Future<void> _triggerVibration() async {
    try {
      // 진동 기능 지원 확인
      bool? hasVibrator = await Vibration.hasVibrator();
      print('진동 지원 여부: $hasVibrator');
      
      if (hasVibrator == true) {
        // 오직 테스트일 경우에만 진동 실행 (report 탭에서 접근한 경우 제외)
        if (!widget.isFromReport && widget.runGoal?.isTest == true) {
          // iOS에서는 진동 지속 시간이 제한되어 있으므로, 패턴을 사용하여 여러 번 진동
          // 3초 동안 지속되는 패턴 (500ms 진동 6번 = 3초)
          print('진동 시작...');
          await Vibration.vibrate(pattern: [0, 500, 100, 500, 100, 500, 100, 500, 100, 500, 100, 500]);
          print('진동 완료');
        }
      }
    } catch (e) {
      print('진동 실행 중 오류 발생: $e');
    }
  }
  
  // 러닝 기록 저장
  Future<void> _saveRecordToStorage() async {
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
    final now = DateTime.now(); // 현재 시간 한 번만 생성
    
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
    
    // Hive에 기록 저장
    final record = Record(
      date: now,
      duration: widget.duration.inSeconds,
      distance: widget.distance,
      pace: widget.pace,
      recordId: uuid, // 고유 식별자
    );
    
    // 레코드 ID를 키로 사용하여 저장
    recordBox.put(uuid, record);
    
    // 테스트 기록인 경우
    if (widget.runGoal?.isTest == true) {
      // 테스트 기록 저장
      const String testRecordsKey = 'test_records_v1';
      List<Map<String, dynamic>> testRecords = [];
      
      // 기존 기록 불러오기
      final String? testRecordsJson = prefs.getString(testRecordsKey);
      if (testRecordsJson != null) {
        final List<dynamic> decoded = jsonDecode(testRecordsJson) as List<dynamic>;
        testRecords = List<Map<String, dynamic>>.from(decoded);
      }
      
      // 경로 직렬화
      final routeJson = widget.route.map((latLng) => {
        'lat': latLng.latitude,
        'lng': latLng.longitude,
      }).toList();
      
      // 테스트 유형 확인
      int testType = 0; // 기본값
      
      if (widget.runGoal?.type == RunType.distance && widget.runGoal?.targetDistance == 2.4) {
        testType = 1; // run1_5mile
      } else if (widget.runGoal?.type == RunType.time && widget.runGoal?.targetDuration?.inMinutes == 5) {
        testType = 2; // run5min
      } else if (widget.runGoal?.type == RunType.time && widget.runGoal?.targetDuration?.inMinutes == 12) {
        testType = 3; // run12min
      } else if (widget.runGoal?.type == RunType.walk) {
        testType = 0; // walk1mile
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
        // 새 기록 생성
        Map<String, dynamic> newRecord = {
          'testType': testType,
          'distance': widget.distance,
          'duration': widget.duration.inSeconds,
          'date': now.toIso8601String(),
          'vo2max': widget.vo2max ?? _vo2max ?? 0.0,
          'route': routeJson,
          'recordId': uuid,
          'calories': widget.calories,
          'intensity': widget.intensity,
        };
        
        testRecords.insert(0, newRecord);
        await prefs.setString(testRecordsKey, jsonEncode(testRecords));
        print('테스트 기록 저장 완료: $uuid');
      }
    } 
    // 자유 달리기 기록인 경우
    else {
      // 자유 달리기 기록 저장
      const String freeRunRecordsKey = 'free_run_records_v1';
      List<Map<String, dynamic>> freeRunRecords = [];
      
      // 기존 기록 불러오기
      final String? freeRunRecordsJson = prefs.getString(freeRunRecordsKey);
      if (freeRunRecordsJson != null) {
        final List<dynamic> decoded = jsonDecode(freeRunRecordsJson) as List<dynamic>;
        freeRunRecords = List<Map<String, dynamic>>.from(decoded);
      }
      
      // 경로 직렬화
      final routeJson = widget.route.map((latLng) => {
        'lat': latLng.latitude,
        'lng': latLng.longitude,
      }).toList();
      
      // UUID로 이미 저장된 기록인지 확인
      bool isDuplicate = false;
      for (var record in freeRunRecords) {
        if (record['recordId'] == uuid) {
          isDuplicate = true;
          print('이미 저장된 자유 달리기 기록 ID가 있습니다: $uuid');
          break;
        }
      }
      
      if (!isDuplicate) {
        // 새 기록 생성
        Map<String, dynamic> newRecord = {
          'distance': widget.distance,
          'duration': widget.duration.inSeconds,
          'date': now.toIso8601String(),
          'route': routeJson,
          'pace': widget.pace,
          'recordId': uuid,
          'calories': widget.calories,
          'intensity': widget.intensity,
        };
        
        freeRunRecords.insert(0, newRecord);
        await prefs.setString(freeRunRecordsKey, jsonEncode(freeRunRecords));
        print('자유 달리기 기록 저장 완료: $uuid');
      }
    }
    
    // 저장 완료를 표시하는 플래그 설정
    setState(() {
      _isRecordSaved = true;
    });
    
    // 운동 기록이 저장되면 업데이트된 칼로리 정보를 ExerciseBar에 반영
    ExerciseService.calculateTotalExerciseCalories().then((calories) {
      ExerciseBar.updateKcal(calories);
      print('저장 후 운동 칼로리 업데이트: $calories');
    });
  }
  
  // VO2max 계산 메서드
  void _calculateVO2max() {
    if (widget.vo2max != null) {
      // 전달받은 VO2max 사용
      final vo2max = widget.vo2max!;
      
      // 체력 수준 판정
      String level;
      if (vo2max < 30) level = '체력 수준: 낮음';
      else if (vo2max < 40) level = '체력 수준: 보통';
      else if (vo2max < 50) level = '체력 수준: 양호';
      else level = '체력 수준: 우수';
      
      setState(() {
        _vo2max = vo2max;
        _vo2maxLevel = level;
      });
    } else if (widget.runGoal != null && widget.runGoal!.isTest) {
      // VO2max 계산
      final vo2max = widget.runGoal!.calculateVO2max(
        distance: widget.distance,
        duration: widget.duration,
        // 1마일 걷기 테스트에 필요한 추가 데이터
        // 현재는 사용하지 않지만 추후 필요시 사용
        heartRate: 120, // 기본값
        age: 30, // 기본값
        weight: 70, // 기본값 (kg)
        gender: 1, // 기본값 (남성=1, 여성=0)
      );
      
      // VO2max 수준 텍스트 가져오기
      final level = widget.runGoal!.getVO2maxLevel(vo2max);
      
      setState(() {
        _vo2max = vo2max;
        _vo2maxLevel = level;
      });
    }
  }
  
  // 경로에 맞게 지도 표시 영역 조정
  void _fitMapToRoute() {
    if (widget.route.isEmpty || _mapController == null) return;
    
    try {
      // 경로의 모든 좌표를 포함하는 경계 계산
      double minLat = widget.route.first.latitude;
      double maxLat = widget.route.first.latitude;
      double minLng = widget.route.first.longitude;
      double maxLng = widget.route.first.longitude;
      
      for (final point in widget.route) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }
      
      // 경계에 패딩 추가
      final bounds = LatLngBounds(
        southwest: LatLng(minLat - 0.001, minLng - 0.001),
        northeast: LatLng(maxLat + 0.001, maxLng + 0.001),
      );
      
      // 경로에 맞게 카메라 위치 조정
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
      
      setState(() {
        _mapReady = true;
      });
    } catch (e) {
      print('경로 표시 오류: $e');
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // 테스트 유형에 따른 결과 텍스트 생성
  String _getResultText() {
    if (widget.runGoal?.isTest != true) return '';
    
    switch (widget.runGoal!.type) {
      case RunType.distance:
        if (widget.runGoal!.targetDistance != null && widget.runGoal!.targetDistance! >= 2.4) {
          // 1.5마일 테스트
          final min = widget.duration.inMinutes;
          final sec = widget.duration.inSeconds % 60;
          return '2.4km를 ${min}분 ${sec}초에 완주했습니다.';
        }
        return '';
      case RunType.time:
        if (widget.runGoal!.targetDuration?.inMinutes == 5) {
          // 5분 테스트
          return '5분 동안 ${(widget.distance * 1000).toStringAsFixed(0)}m를 달렸습니다.';
        } else if (widget.runGoal!.targetDuration?.inMinutes == 12) {
          // 12분 테스트
          return '12분 동안 ${(widget.distance * 1000).toStringAsFixed(0)}m를 달렸습니다.';
        }
        return '';
      case RunType.walk:
        // 1마일 걷기 테스트
        return '1마일을 ${_formatDuration(widget.duration)}에 걸었습니다.';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // 화면 크기 가져오기
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isTest = widget.runGoal?.isTest ?? false;
    
    return WillPopScope(
      // 뒤로가기 방지
      onWillPop: () async {
        // 홈 화면으로 돌아가기 전에 운동 데이터 업데이트
        await ExerciseService.calculateTotalExerciseCalories().then((calories) {
          ExerciseBar.updateKcal(calories);
          print('홈으로 돌아갈 때 운동 칼로리 업데이트: $calories');
        });
        
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (route) => false,
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.yellow.shade600,
        appBar: AppBar(
          backgroundColor: Colors.yellow.shade600,
          elevation: 0,
          centerTitle: true,
          title: Text(
            isTest ? '테스트 결과' : '러닝 결과',
            style: const TextStyle(
              fontSize: 20,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.black),
          leading: IconButton(
            icon: const Icon(Icons.home),
            onPressed: () async {
              // 홈 버튼 클릭 시 운동 데이터 업데이트
              await ExerciseService.calculateTotalExerciseCalories().then((calories) {
                ExerciseBar.updateKcal(calories);
                print('홈 버튼 클릭 시 운동 칼로리 업데이트: $calories');
              });
              
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.home,
                (route) => false,
              );
            },
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 테스트 결과일 경우 VO2max 표시
                  if (isTest && _vo2max != null) ...[
                    Column(
                      children: [
                        Text(widget.runGoal?.label ?? '',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Text('VO₂max', style: TextStyle(fontSize: 20, color: Colors.grey.shade800)),
                        const SizedBox(height: 4),
                        Text(
                          _vo2max!.isNaN ? '-' : _vo2max!.toStringAsFixed(2),
                          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)
                        ),
                        const SizedBox(height: 4),
                        Text(_vo2maxLevel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 16),
                        Text(_getResultText(), style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ],
                  
                  // 기본 정보 세션 (테스트가 아닐 경우에만 표시)
                  if (!isTest)
                    Card(
                      color: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      CustomText(
                                        text: '${widget.distance.toStringAsFixed(2)} km',
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      const CustomText(
                                        text: 'Distance',
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      CustomText(
                                        text: _formatDuration(widget.duration),
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      const CustomText(
                                        text: 'Time',
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      CustomText(
                                        text: _formatPace(widget.pace).split(' ').first,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      const CustomText(
                                        text: 'Pace',
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      CustomText(
                                        text: '${widget.calories}',
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      const CustomText(
                                        text: 'Kcal',
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      CustomText(
                                        text: widget.intensity,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      const CustomText(
                                        text: 'Intensity',
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // 지도 표시
                  if (widget.route.isNotEmpty)
                    Card(
                      color: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 8, top: 8, bottom: 8),
                              child: CustomText(
                                text: 'Your Route',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(
                              height: screenHeight * 0.35, // 화면 높이의 35%
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: widget.route.isNotEmpty 
                                      ? widget.route[widget.route.length ~/ 2] // 경로 중간 위치
                                      : const LatLng(37.5665, 126.9780), // 기본값: 서울
                                    zoom: 15,
                                  ),
                                  polylines: {
                                    Polyline(
                                      polylineId: const PolylineId('run_result'),
                                      points: widget.route,
                                      color: Colors.blue,
                                      width: 5,
                                      startCap: Cap.roundCap,
                                      endCap: Cap.roundCap,
                                    ),
                                  },
                                  markers: {
                                    if (widget.route.isNotEmpty) 
                                      Marker(
                                        markerId: const MarkerId('start'),
                                        position: widget.route.first,
                                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                                      ),
                                    if (widget.route.isNotEmpty)
                                      Marker(
                                        markerId: const MarkerId('end'),
                                        position: widget.route.last,
                                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                                      ),
                                  },
                                  mapToolbarEnabled: false,
                                  zoomControlsEnabled: true,
                                  myLocationEnabled: false,
                                  myLocationButtonEnabled: false,
                                  onMapCreated: (controller) {
                                    _mapController = controller;
                                    _fitMapToRoute();
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // 홈으로 돌아가기 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: CustomButton(
                      text: '홈으로 돌아가기',
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.home,
                          (route) => false,
                        );
                      },
                      color: Colors.black,
                      textColor: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
