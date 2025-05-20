import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/run_type.dart';
import '../widgets/custom_button.dart';
import 'running_result_screen.dart';
import 'test_detail_screen.dart'; // TestScreenType enum 사용

class TestRunningScreen extends StatefulWidget {
  final TestScreenType testType;
  const TestRunningScreen({required this.testType, super.key});

  @override
  State<TestRunningScreen> createState() => _TestRunningScreenState();
}

class _TestRunningScreenState extends State<TestRunningScreen> {
  final List<LatLng> _route = [];
  Timer? _timer;
  Timer? _locationTimer;
  int _secondsLeft = 0;
  int _secondsElapsed = 0;
  DateTime? _startTime;
  GoogleMapController? _mapController;
  bool _isFinishing = false; // 테스트 종료 처리 중인지 확인하는 플래그
  
  // 칼로리 및 운동 강도 관련 변수 추가
  int _burnedCalories = 0;
  String _intensity = 'low'; // 'low', 'medium', 'high'
  
  // 속도 기록 및 간격 바탕 속도 계산
  List<double> _recentSpeeds = [];
  static const double _lowSpeedThreshold = 1.4;   // m/s, 걷기 속도
  static const double _mediumSpeedThreshold = 2.7; // m/s, 조깅 속도
  
  int get testDurationSec {
    switch (widget.testType) {
      case TestScreenType.run1_5mile:
        // 1.5마일(2.4km) 테스트: 시간 제한 없음, 목표 거리 도달 시 종료
        return 0;
      case TestScreenType.run5min:
        return 5 * 60;
      case TestScreenType.run12min:
        return 12 * 60;
      case TestScreenType.walk1mile:
        return 0;
    }
  }

  String get testTitle {
    switch (widget.testType) {
      case TestScreenType.run1_5mile:
        return 'Run 2.4km';
      case TestScreenType.run5min:
        return '5 Min Test';
      case TestScreenType.run12min:
        return '12 Min Test';
      case TestScreenType.walk1mile:
        return 'Walk 1.6km';
    }
  }

  double get targetDistanceMeter {
    switch (widget.testType) {
      case TestScreenType.run1_5mile:
        return 2414.0; // 1.5마일 = 2.414km
      default:
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _startTracking();
    
    // 화면 꺼짐 방지 활성화
    WakelockPlus.enable();
    
    if (widget.testType == TestScreenType.run1_5mile) {
      // 목표 거리 도달 시까지 측정
      // 별도 타이머 필요 없음
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          // 1초씩 증가
          _secondsElapsed++;
        });
        
        // 매 초마다 칼로리 및 운동 강도 계산
        _calculateCaloriesAndIntensity();
      });
    } else {
      // 시간 기반 테스트의 경우 초기값 설정 (12분, 5분)
      _secondsLeft = testDurationSec;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          // 12분, 5분 테스트는 시간이 감소
          _secondsLeft--;
          _secondsElapsed++;
          
          // 매 초마다 칼로리 및 운동 강도 계산
          _calculateCaloriesAndIntensity();
          
          if (_secondsLeft <= 0 && !_isFinishing) {
            _isFinishing = true; // 종료 처리 중 플래그 설정
            // 테스트 완료 알림 - 진동 효과
            debugPrint("[테스트 완료] 타이머가 0에 도달했습니다. 진동 시작!");
            
            // 개별 진동 실행 후 결과 화면으로 이동
            _vibrateIndividually(() {
              debugPrint("[테스트 완료] 진동 완료, 결과 화면으로 이동");
              _stopAndShowResult(false); // 진동 스킵
            });
          }
        });
      });
    }
  }
  
  // 칼로리 및 운동 강도 계산 함수
  void _calculateCaloriesAndIntensity() {
    if (_route.length < 2 || _startTime == null) return;
    
    // 현재까지의 거리(km)와 소요 시간(초)
    final double totalDistance = _calculateDistance(_route);
    final Duration elapsedTime = _getCurrentDuration();
    final int elapsedSeconds = elapsedTime.inSeconds > 0 ? elapsedTime.inSeconds : 1;
    
    // 현재 속도 계산 (m/s)
    final double currentSpeed = (totalDistance * 1000) / elapsedSeconds;
    
    // 최근 속도 기록 관리 (10개까지)
    if (_recentSpeeds.length >= 10) {
      _recentSpeeds.removeAt(0);
    }
    _recentSpeeds.add(currentSpeed);
    
    // 평균 속도 계산
    final double avgSpeed = _recentSpeeds.isNotEmpty 
        ? _recentSpeeds.reduce((a, b) => a + b) / _recentSpeeds.length 
        : 0;
    
    // 운동 강도 결정 (속도 기반)
    if (avgSpeed < _lowSpeedThreshold) {
      _intensity = 'low';
    } else if (avgSpeed < _mediumSpeedThreshold) {
      _intensity = 'medium';
    } else {
      _intensity = 'high';
    }
    
    // 칼로리 계산 (MET 방식)
    double met;
    switch (_intensity) {
      case 'low':
        met = 2.5; // 걷기
        break;
      case 'medium':
        met = 7.0; // 조깅
        break;
      case 'high':
        met = 11.5; // 달리기
        break;
      default:
        met = 2.5;
    }
    
    // 칼로리 계산: MET * 체중(kg) * 시간(hour)
    // 기본 체중 70kg 가정
    const double weight = 70.0;
    final double hours = elapsedSeconds / 3600;
    _burnedCalories = (met * weight * hours).round();
    
    // 상태 업데이트 (UI 반영)
    if (mounted) {
      setState(() {});
    }
  }


  /// 위치 추적을 시작하는 메서드
  /// 1. 위치 서비스 활성화 확인
  /// 2. 권한 확인 및 요청
  /// 3. 위치 업데이트 타이머 시작
  void _startTracking() async {
    // 비동기 작업 시 mounted 확인
    if (!mounted) return;
    
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      // 관련 설정이 변경되었을 수 있으므로 mounted 다시 확인
      if (!mounted) return;
      return;
    }
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      // 권한 요청 후 mounted 확인
      if (!mounted) return;
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return;

    // 경로 추적 타이머 시작 (1초 간격)
    _locationTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        // 위치 정보 가져오기
        Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        // 비동기 작업 후 mounted 상태 확인
        if (!mounted) return;
        
        final LatLng newPoint = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _route.add(newPoint);
        });
        
        // 지도 업데이트
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(newPoint),
          );
        }
        
        // 1.5마일 테스트의 경우 목표 거리 도달 시 테스트 종료
        if (widget.testType == TestScreenType.run1_5mile && 
            _calculateDistance(_route) * 1000 >= targetDistanceMeter && 
            !_isFinishing) {
          _isFinishing = true; // 종료 처리 중 플래그 설정
          // 목표 거리 도달 시 진동 구현
          debugPrint("[목표 거리 도달] 진동 시작");
          
          // 진동 후 결과 화면으로 이동
          _vibrateIndividually(() {
            debugPrint("[목표 거리 도달] 진동 완료, 결과 화면으로 이동");
            if (mounted) {
              _stopAndShowResult(false); // 진동 스킵
            }
          });
          
          // 중복 호출 방지를 위해 타이머 중지
          _locationTimer?.cancel();
          return;
        }
        
        // walk1mile 테스트의 경우도 목표 거리(1.6km) 도달 시 테스트 종료
        if (widget.testType == TestScreenType.walk1mile && 
            _calculateDistance(_route) * 1000 >= 1609.0 && 
            !_isFinishing) {
          _isFinishing = true; // 종료 처리 중 플래그 설정
          // 우걸하기 테스트 성공 시 진동 구현
          debugPrint("[우걸 테스트 성공] 진동 시작");
          
          // 진동 후 결과 화면으로 이동
          _vibrateIndividually(() {
            debugPrint("[우걸 테스트 성공] 진동 완료, 결과 화면으로 이동");
            if (mounted) {
              _stopAndShowResult(false); // 진동 스킵
            }
          });
          
          // 중복 호출 방지를 위해 타이머 중지
          _locationTimer?.cancel();
          return;
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('위치 갱신 오류: $e')),
        );
      }
    });
  }

  /// 테스트를 중지하고 결과 화면을 표시하는 메서드
  /// @param vibrate: 진동 여부 (기본값: true)
  void _stopAndShowResult([bool vibrate = true]) {
    // 이미 종료 처리 중인 경우 중복 실행 방지
    if (_isFinishing && widget.testType != TestScreenType.run1_5mile && widget.testType != TestScreenType.walk1mile) {
      return;
    }
    
    // 플래그 설정
    _isFinishing = true;
    
    // 모든 타이머 취소
    _timer?.cancel();
    _locationTimer?.cancel();
    
    // STOP 버튼 클릭한 경우에만 진동 (자동 종료가 아닌 경우) 
    if (vibrate) {
      debugPrint("[STOP 버튼] 진동 시작");
      
      // STOP 버튼 클릭 시 진동 후 결과 화면으로 이동
      _vibrateIndividually(() {
        debugPrint("[STOP 버튼] 진동 완료, 결과 화면으로 이동");
        _showResultScreen();
      });
    } else {
      // 타이머 종료로 이미 진동이 실행된 경우는 바로 결과 화면으로 이동
      _showResultScreen();
    }
  }
  
  /// 결과 화면으로 이동하는 메서드
  void _showResultScreen() {
    debugPrint("[결과 화면] 결과 화면으로 이동 시작");
    
    // 기록을 위한 고유 UUID 생성
    final uuid = const Uuid().v4();
    
    // 결과 산출
    final DateTime endTime = DateTime.now();
    final double distance = _calculateDistance(_route); // km
    final Duration duration = endTime.difference(_startTime!);
    final double pace = distance > 0 ? duration.inSeconds / 60 / distance : 0;
    
    // mounted 상태 확인
    if (!mounted) return;
    
    // RunGoal 모델 생성 (테스트 타입에 따라)
    RunGoal? runGoal;
    double? vo2max;
    
    switch (widget.testType) {
      case TestScreenType.run1_5mile:
        runGoal = RunGoal.test1_5Mile(); 
        vo2max = 483 / (duration.inSeconds / 60.0) + 3.5;
        break;
      case TestScreenType.run5min:
        runGoal = RunGoal.test5Min();
        vo2max = (distance * 1000 / 5.0) * 0.2 + 3.5;
        break;
      case TestScreenType.run12min:
        runGoal = RunGoal.test12Min();
        vo2max = (distance * 1000 - 504.9) / 44.73;
        break;
      case TestScreenType.walk1mile:
        runGoal = RunGoal.testWalk1_6km();
        // 심박수, 나이, 체중 정보가 필요해서 여기서는 계산 불가
        break;
    }
    
    debugPrint("[결과 화면] 경로 포인트 개수: ${_route.length}");
    
    // 결과 화면으로 이동
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => RunningResultScreen(
          route: List<LatLng>.from(_route), // 경로 복사
          distance: distance, // km
          duration: duration,
          pace: pace, // min/km
          calories: _burnedCalories, // 추가: 소모된 칼로리
          intensity: _intensity, // 추가: 운동 강도
          runGoal: runGoal, // 테스트 정보 전달
          vo2max: vo2max, // VO2max 값 전달
          recordId: uuid, // 고유 식별자 전달
        ),
      ),
    );
  }

  /// 지점 리스트의 총 거리를 계산하는 메서드
  /// @param points: 경로를 구성하는 위치 좌표 리스트
  /// @return 총 거리(km)
  double _calculateDistance(List<LatLng> points) {
    double sum = 0;
    for (int i = 0; i < points.length - 1; i++) {
      sum += _distanceBetween(points[i], points[i + 1]);
    }
    return sum / 1000; // 미터를 킬로미터로 변환
  }

  /// 두 좌표 간의 거리를 계산하는 메서드 (Haversine 공식 사용)
  /// @param a: 첫 번째 좌표
  /// @param b: 두 번째 좌표
  /// @return 거리(m)
  double _distanceBetween(LatLng a, LatLng b) {
    const double p = 0.017453292519943295; // Math.PI / 180
    final double lat1 = a.latitude, lon1 = a.longitude, lat2 = b.latitude, lon2 = b.longitude;
    final aVal = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742000 * sqrt(aVal); // 2 * R * asin(sqrt(aVal)), R = 6371km (지구 반경)
  }

  @override
  void dispose() {
    _timer?.cancel();
    _locationTimer?.cancel();
    
    // 화면 꺼짐 방지 해제
    WakelockPlus.disable();
    
    super.dispose();
  }
  
  /// 개별 진동을 실행하는 함수 (패턴 배열 없이 직접 호출)
  /// @param onComplete: 진동 완료 후 실행할 콜백 함수
  void _vibrateIndividually([Function? onComplete]) {
    debugPrint("[진동] 5회 진동 시작 - 개별 방식");
    
    // 진동 지원 여부 확인
    Vibration.hasVibrator().then((hasVibrator) {
      debugPrint("진동 지원 여부: $hasVibrator");
      
      if (hasVibrator == true) {
        debugPrint("진동 시작...");
        
        // 각 진동 간격을 더 길게 설정 (450ms 진동, 450ms 휴지)
        const int vibrationDuration = 450;
        const int pauseDuration = 450;
        
        // 첫 번째 진동
        Vibration.vibrate(duration: vibrationDuration);
        debugPrint("[진동] 1번째 진동");
        
        // 두 번째 진동
        Future.delayed(Duration(milliseconds: vibrationDuration + pauseDuration), () {
          Vibration.vibrate(duration: vibrationDuration);
          debugPrint("[진동] 2번째 진동");
          
          // 세 번째 진동
          Future.delayed(Duration(milliseconds: vibrationDuration + pauseDuration), () {
            Vibration.vibrate(duration: vibrationDuration);
            debugPrint("[진동] 3번째 진동");
            
            // 네 번째 진동
            Future.delayed(Duration(milliseconds: vibrationDuration + pauseDuration), () {
              Vibration.vibrate(duration: vibrationDuration);
              debugPrint("[진동] 4번째 진동");
              
              // 다섯 번째 진동
              Future.delayed(Duration(milliseconds: vibrationDuration + pauseDuration), () {
                Vibration.vibrate(duration: vibrationDuration);
                debugPrint("[진동] 5번째 진동");
                
                // 마지막 진동 후 완료 콜백 호출
                Future.delayed(Duration(milliseconds: vibrationDuration), () {
                  debugPrint("진동 완료");
                  if (onComplete != null) {
                    onComplete();
                  }
                });
              });
            });
          });
        });
      } else {
        debugPrint("진동 기능이 지원되지 않습니다.");
        // 진동 지원되지 않는 경우 바로 콜백 호출
        if (onComplete != null) {
          onComplete();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.yellow.shade600,
      appBar: AppBar(
        title: Text(
          testTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.yellow.shade600,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 32),
            // 지도 표시
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _route.isNotEmpty ? _route.last : const LatLng(37.5665, 126.9780),
                    zoom: 16,
                  ),
                  polylines: {
                    Polyline(
                      polylineId: const PolylineId('test_route'),
                      points: _catmullRomSpline(_route),
                      color: Colors.blue,
                      width: 5,
                    ),
                  },
                  myLocationEnabled: true,
                  zoomControlsEnabled: false,
                  onMapCreated: (controller) => _mapController = controller,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 상단 Pace / Time 표시 (실시간 값)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatPace(_getCurrentPace()),
                  style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                ),
                // 테스트 유형에 따라 다르게 표시
                // 시간 기반 테스트(5분, 12분)은 남은 시간 표시
                // 거리 기반 테스트(1.5마일)는 소요 시간 표시
                Text(
                  (widget.testType == TestScreenType.run5min || widget.testType == TestScreenType.run12min)
                      ? _formatTime(_secondsLeft)  // 카운트다운 표시
                      : _formatDuration(Duration(seconds: _secondsElapsed)),  // 증가하는 시간 표시
                  style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Pace', style: TextStyle(fontSize: 14, color: Colors.grey)),
                Text('Time', style: TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
            const Spacer(),
            // 중앙 거리 표시 (실시간 값)
            Column(
              children: [
                Text(
                  (_calculateDistance(_route) * 1000).toStringAsFixed(0),
                  style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
                ),
                const Text('m', style: TextStyle(fontSize: 20, color: Colors.grey)),
              ],
            ),
            const Spacer(),
            // Stop 버튼 (러닝 스크린과 동일한 큰 원형 CustomButton)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CustomButton(
                    text: 'Stop\ntest',
                    onPressed: () => _stopAndShowResult(true),
                    color: Colors.black,
                    textColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                // 진동 테스트용 추가 버튼
                InkWell(
                  onTap: () {
                    // 현재 플래그를 저장하여 테스트 중임을 표시
                    debugPrint("[진동 테스트 버튼] 진동 시작!");
                    
                    // 진동 테스트 버튼은 짧게 1회만 진동
                    Vibration.vibrate(duration: 1000); // 1초 긴 진동
                    debugPrint("[테스트 버튼] 1초 진동 시작");
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.vibration, color: Colors.white),
                  ),
                ),
              ],
            ),
            const Spacer(),
            // 하단 HR / Kcal / Intensity
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                Column(
                  children: [
                    Text('101', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
                    Text('HR', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
                Column(
                  children: [
                    Text('136', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
                    Text('Kcal', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
                Column(
                  children: [
                    Text('low', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
                    Text('Intensity', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Catmull-Rom 스플라인을 사용하여 지도에 슬움한 경로 선을 그리는 메서드
  /// @param points: 경로를 구성하는 위치 좌표 리스트
  /// @param samples: 각 선분 사이에 생성할 새 점의 개수
  /// @return 보간된 경로 좌표 리스트
  List<LatLng> _catmullRomSpline(List<LatLng> points, {int samples = 10}) {
    if (points.length < 4) return points;
    List<LatLng> result = [];
    for (int i = 0; i < points.length - 3; i++) {
      for (int j = 0; j < samples; j++) {
        double t = j / samples;
        LatLng p = _catmullRom(
          points[i], points[i + 1], points[i + 2], points[i + 3], t,
        );
        result.add(p);
      }
    }
    result.add(points.last);
    return result;
  }
  
  /// Catmull-Rom 스플라인 계산을 위한 보조 메서드
  /// @param p0, p1, p2, p3: 컨트롤 포인트
  /// @param t: 보간 매개변수 (0~1)
  /// @return 보간된 새 좌표
  LatLng _catmullRom(LatLng p0, LatLng p1, LatLng p2, LatLng p3, double t) {
    double lat = 0.5 * ((2 * p1.latitude) +
        (-p0.latitude + p2.latitude) * t +
        (2 * p0.latitude - 5 * p1.latitude + 4 * p2.latitude - p3.latitude) * t * t +
        (-p0.latitude + 3 * p1.latitude - 3 * p2.latitude + p3.latitude) * t * t * t);
    double lng = 0.5 * ((2 * p1.longitude) +
        (-p0.longitude + p2.longitude) * t +
        (2 * p0.longitude - 5 * p1.longitude + 4 * p2.longitude - p3.longitude) * t * t +
        (-p0.longitude + 3 * p1.longitude - 3 * p2.longitude + p3.longitude) * t * t * t);
    return LatLng(lat, lng);
  }
  
  /// 현재까지 소요된 시간을 반환하는 메서드
  /// @return 현재까지 소요된 시간
  Duration _getCurrentDuration() {
    if (_startTime == null) return Duration.zero;
    return DateTime.now().difference(_startTime!);
  }
  
  /// 현재의 페이스(속도)를 계산하는 메서드
  /// @return 페이스(min/km)
  double _getCurrentPace() {
    final distance = _calculateDistance(_route); // km
    final duration = _getCurrentDuration();
    if (distance > 0) {
      return duration.inSeconds / 60 / distance; // min/km
    }
    return 0;
  }
  
  /// 소요 시간을 표시하기 좋은 형태의 문자열로 변환하는 메서드
  /// @param d: 포맷팅할 시간(Duration)
  /// @return 포맷팅된 시간 문자열 (HH:MM:SS 혹은 MM:SS)
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
  
  /// 페이스를 표시하기 좋은 형태의 문자열로 변환하는 메서드
  /// @param pace: 포맷팅할 페이스(min/km)
  /// @return 포맷팅된 페이스 문자열 (M'S")
  String _formatPace(double pace) {
    if (pace == 0) return '-';
    final min = pace.floor();
    final sec = ((pace - min) * 60).round();
    return '$min\'$sec"';
  }

  /// 초 단위 시간을 MM:SS 형태의 문자열로 변환하는 메서드
  /// @param seconds: 총 초 수
  /// @return MM:SS 형태의 문자열
  String _formatTime(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}
