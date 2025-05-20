import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart'; // debugPrint 사용을 위해 추가
import 'package:vibration/vibration.dart'; // 진동 패키지 추가
import '../widgets/custom_text.dart';
import '../widgets/custom_button.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:math';
import 'running_result_screen.dart';
import '../services/location_service.dart';
import '../core/app_routes.dart';
import '../models/run_type.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// 운동 진행 화면 (RunningScreen)
/// 기획안 기반 UI 구성 및 화면 이동 처리
class RunningScreen extends StatefulWidget {
  final RunGoal? runGoal; // 달리기 목표 정보
  
  const RunningScreen({super.key, this.runGoal});

  @override
  State<RunningScreen> createState() => _RunningScreenState();
}

class _RunningScreenState extends State<RunningScreen> {
  final List<LatLng> _route = [];
  DateTime? _startTime;
  GoogleMapController? _mapController;
  Timer? _timer;
  Timer? _goalCheckTimer; // 목표 확인을 위한 타이머
  bool _isFinishing = false; // 종료 중인지 확인하는 플래그
  
  // 현재 러닝 정보
  bool _isGoalReached = false;
  String? _goalAchievedMessage;
  
  // 칼로리 및 운동 강도 추가
  int _burnedCalories = 0;
  String _intensity = 'low'; // 'low', 'medium', 'high'

  // 이상치 필터링 설정값
  static const double maxJump = 50.0;      // 이상치 거리 (m)
  static const double maxSpeed = 7.0;      // 최대 허용 속도 (m/s)
  LatLng? _lastValidPoint;
  DateTime? _lastValidTime;
  // 최근 속도 기록
  List<double> _recentSpeeds = [];

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _startTracking();
    
    // 화면 꺼짐 방지 설정
    WakelockPlus.enable();
    
    // 목표 체크 타이머 시작 (매 0.5초마다 확인)
    if (widget.runGoal != null) {
      _goalCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        _checkGoal();
      });
    }
  }
  
  // 시간 테스트의 경우 남은 시간 표시 가져오기
  String _getTimeDisplay() {
    // 시간 테스트인 경우 카운트다운 표시
    if (widget.runGoal?.type == RunType.time) {
      // 타겟 시간에서 현재 시간을 빼서 남은 시간을 표시
      final Duration? targetDuration = widget.runGoal?.targetDuration;
      if (targetDuration != null && _startTime != null) {
        final Duration elapsedTime = DateTime.now().difference(_startTime!);
        final Duration remainingTime = targetDuration - elapsedTime;
        
        // 남은 시간이 음수이면 0으로 표시
        if (remainingTime.isNegative) {
          return "00:00";
        }
        
        // 남은 시간 포맷팅
        final int mins = remainingTime.inMinutes.remainder(60);
        final int secs = remainingTime.inSeconds.remainder(60);
        return "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
      }
    }
    
    // 그 외의 테스트는 현재 소요 시간 표시
    return _formatDuration(_getCurrentDuration());
  }

  // 칼로리 및 운동 강도 계산 (1초마다 업데이트)
  void _calculateCaloriesAndIntensity() {
    if (_route.length < 2 || _startTime == null) return;
    
    // 현재까지의 거리(km)와 소요 시간(초)
    final double totalDistance = _calculateDistance(_route);
    final Duration elapsedTime = _getCurrentDuration();
    final int elapsedSeconds = elapsedTime.inSeconds > 0 ? elapsedTime.inSeconds : 1;
    
    // 현재 속도 계산 (m/s)
    final double currentSpeed = (totalDistance * 1000) / elapsedSeconds;
    
    // 최근 10개 속도 기록 유지
    if (_recentSpeeds.length >= 10) {
      _recentSpeeds.removeAt(0);
    }
    _recentSpeeds.add(currentSpeed);
    
    // 평균 속도 계산 (최근 기록 기반)
    final double avgSpeed = _recentSpeeds.isNotEmpty 
        ? _recentSpeeds.reduce((a, b) => a + b) / _recentSpeeds.length 
        : 0;
    
    // 운동 강도 결정 (속도 기반)
    // 걷기: ~1.4m/s, 조깅: ~2.7m/s, 달리기: ~4.0m/s 이상
    if (avgSpeed < 1.4) {
      _intensity = 'low';
    } else if (avgSpeed < 2.7) {
      _intensity = 'medium';
    } else {
      _intensity = 'high';
    }
    
    // 칼로리 소모량 계산 (MET 방식)
    // MET 값 결정 (운동 강도에 따라)
    double met;
    if (_intensity == 'low') {
      met = 2.5; // 걷기
    } else if (_intensity == 'medium') {
      met = 7.0; // 조깅
    } else {
      met = 11.5; // 달리기
    }
    
    // 칼로리 계산 공식: MET * 체중(kg) * 시간(hour)
    // 기본 체중 70kg 가정 (나중에 사용자 프로필에서 가져올 수 있음)
    const double weight = 70.0;
    final double hours = elapsedSeconds / 3600;
    _burnedCalories = (met * weight * hours).round();
  }
  
  // 목표 달성 확인 메서드
  void _checkGoal() {
    if (_isGoalReached || widget.runGoal == null || _startTime == null || _isFinishing) return;

    final currentDistance = _calculateDistance(_route); // km
    final currentDuration = _getCurrentDuration();
    
    // 칼로리 및 운동 강도 계산 업데이트
    _calculateCaloriesAndIntensity();

    // 목표 달성 확인
    if (widget.runGoal!.isGoalReached(
      distance: currentDistance,
      duration: currentDuration,
    )) {
      setState(() {
        _isGoalReached = true;
        _isFinishing = true; // 종료 중 플래그 설정

        // 목표 유형에 따른 메시지 설정
        switch (widget.runGoal!.type) {
          case RunType.distance:
            _goalAchievedMessage = '목표 거리 달성!';
            break;
          case RunType.time:
            _goalAchievedMessage = '목표 시간 달성!';
            break;
          case RunType.walk:
            _goalAchievedMessage = '목표 거리 달성!';
            break;
          default:
            _goalAchievedMessage = '목표 달성!';
        }
      });
      
      // 목표 달성 시 진동
      debugPrint("[목표 달성] 진동 시작");
      
      // 진동 후 결과 화면으로 이동
      _vibrateIndividually(() {
        debugPrint("[목표 달성] 진동 완료, 결과 화면으로 이동");
        if (mounted) {
          _stopAndShowResult(false); // 진동 스킵
        }
      });
    }
  }

  void _startTracking() async {
    // 이미 백그라운드에서 위치 초기화 시도했지만 한번 더 확인
    if (!locationService.isInitialized) {
      try {
        await locationService.initialize();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('위치 서비스 초기화 오류: $e')),
        );
        return;
      }
    }
    
    // 칼로리 계산 타이머 시작
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isFinishing || !mounted) {
        timer.cancel();
        return;
      }
      _calculateCaloriesAndIntensity();
    });
    
    // 운동 시작 시 위치 데이터 초기화
    try {
      // 현재 위치 가져오기
      final position = await locationService.getCurrentPosition();
      final LatLng initialPoint = LatLng(position.latitude, position.longitude);
      setState(() {
        _route.add(initialPoint);
        _lastValidPoint = initialPoint;
        _lastValidTime = DateTime.now();
      });
      
      // 지도 중앙에 표시
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(initialPoint),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('초기 위치 가져오기 오류: $e')),
      );
    }
    
    // 위치 업데이트 시작
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final position = await locationService.getCurrentPosition();
        final LatLng newPoint = LatLng(position.latitude, position.longitude);
        final DateTime now = DateTime.now();
        
        if (_lastValidPoint != null && _lastValidTime != null) {
          final double dist = _distanceBetween(_lastValidPoint!, newPoint); // meter
          final double timeSec = now.difference(_lastValidTime!).inSeconds.toDouble();
          final double speed = dist / (timeSec > 0 ? timeSec : 1);
          
          // 이상치 필터링
          if (dist > maxJump || speed > maxSpeed) {
            return;
          }
        }
        
        setState(() {
          _route.add(newPoint);
          _lastValidPoint = newPoint;
          _lastValidTime = now;
        });
        
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(newPoint),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('위치 갱신 오류: $e')),
        );
      }
    });
  }


  double _distanceBetween(LatLng a, LatLng b) {
    const double p = 0.017453292519943295;
    final double lat1 = a.latitude, lon1 = a.longitude, lat2 = b.latitude, lon2 = b.longitude;
    final aVal = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742000 * asin(sqrt(aVal)); // meter
  }

  // Catmull-Rom Spline 보간
  List<LatLng> catmullRomSpline(List<LatLng> points, {int samples = 10}) {
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

  Duration _getCurrentDuration() {
    if (_startTime == null) return Duration.zero;
    return DateTime.now().difference(_startTime!);
  }


  double _getCurrentPace() {
    final distance = _calculateDistance(_route); // km
    final duration = _getCurrentDuration();
    if (distance > 0) {
      return duration.inSeconds / 60 / distance; // min/km
    }
    return 0;
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

  String _formatPace(double pace) {
    if (pace == 0) return '-';
    final min = pace.floor();
    final sec = ((pace - min) * 60).round();
    return '$min\'$sec\"';
  }

  // 현재 실행 중인 달리기 유형 이름 가져오기
  String _getRunTypeText() {
    if (widget.runGoal == null) {
      return 'Free Run';
    }
    // 12분 테스트인 경우 "12분 달리기 테스트"로 표시
    if (widget.runGoal!.type == RunType.time && widget.runGoal!.targetDuration?.inMinutes == 12) {
      return '12분 달리기 테스트';
    }
    return widget.runGoal!.label;
  }

  // 목표 정보 텍스트 가져오기
  String _getGoalInfoText() {
    if (widget.runGoal == null) {
      return '';
    }
    
    switch (widget.runGoal!.type) {
      case RunType.distance:
        return '목표: ${widget.runGoal!.targetDistance?.toStringAsFixed(2)} km';
      case RunType.time:
        final minutes = widget.runGoal!.targetDuration?.inMinutes ?? 0;
        return '목표: $minutes 분';
      case RunType.walk:
        return '목표: ${widget.runGoal!.targetDistance?.toStringAsFixed(2)} km';
      default:
        return '';
    }
  }

  /// 테스트를 중지하고 결과 화면을 표시하는 메서드
  /// @param vibrate: 진동 여부 (기본값: true)
  void _stopAndShowResult([bool vibrate = true]) {
    // 중복 호출 방지
    if (_isFinishing) {
      return;
    }
    
    // 종료 플래그 설정
    _isFinishing = true;
    
    // 타이머 취소
    _timer?.cancel();
    _goalCheckTimer?.cancel();
    
    // STOP 버튼 클릭한 경우에만 진동 (자동 종료가 아닌 경우)
    if (vibrate) {
      debugPrint("[STOP 버튼] 진동 시작");
      
      // 개별 진동 후 결과 화면으로 이동
      _vibrateIndividually(() {
        debugPrint("[STOP 버튼] 진동 완료, 결과 화면으로 이동");
        _showResultScreen();
      });
    } else {
      // 이미 진동이 실행된 경우 바로 결과 화면으로 이동
      _showResultScreen();
    }
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
  
  /// 결과 화면으로 이동하는 메서드
  void _showResultScreen() {
    debugPrint("[결과 화면] 결과 화면으로 이동 시작");
    
    // 고유 UUID 생성
    final uuid = const Uuid().v4();
    
    // 런닝 결과 정보 연산
    final DateTime endTime = DateTime.now();
    final List<LatLng> routeCopy = List<LatLng>.from(_route); // 경로 복사
    final double distance = _calculateDistance(routeCopy); // km
    final Duration duration = endTime.difference(_startTime!);
    final double pace = distance > 0 ? duration.inSeconds / 60 / distance : 0; // min/km
    
    // 최종 칼로리 소모량 및 운동 강도 계산
    _calculateCaloriesAndIntensity();
    
    // 운동 강도 텍스트로 변환
    String intensityText = '';
    switch (_intensity) {
      case 'low':
        intensityText = 'low';
        break;
      case 'medium':
        intensityText = 'medium';
        break;
      case 'high':
        intensityText = 'high';
        break;
      default:
        intensityText = 'low';
    }
    
    // 맵 컨트롤러 해제
    _mapController?.dispose();
    _mapController = null;
    
    // 안전하게 화면 전환
    if (!mounted) return;
    
    try {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RunningResultScreen(
            route: routeCopy,
            distance: distance,
            duration: duration,
            pace: pace,
            calories: _burnedCalories,
            intensity: _intensity,
            runGoal: widget.runGoal, // 테스트 정보 전달
            recordId: uuid, // 고유 식별자 전달
          ),
        ),
      );
      debugPrint("테스트 기록 저장 완료: $uuid");
    } catch (e) {
      debugPrint('화면 전환 오류: $e');
      // 오류 발생 시 현재 화면을 모두 제거하고 홈으로 이동
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      );
    }
  }

  double _calculateDistance(List<LatLng> points) {
    double total = 0.0;
    for (int i = 1; i < points.length; i++) {
      total += _coordinateDistance(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return total;
  }

  // Haversine formula (단위: km)
  double _coordinateDistance(lat1, lon1, lat2, lon2) {
    const double p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) *
            (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _goalCheckTimer?.cancel();
    // 위치 업데이트 중지는 하지 않음 (locationService는 공유 자원으로 프로필 화면에서도 사용)
    // 매번 위치를 새로 받아오는 startLocationUpdates는 계속 유지
    _mapController?.dispose();
    
    // 화면 꺼짐 방지 해제
    WakelockPlus.disable();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.yellow.shade600,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 48),
            
            // 테스트 유형 정보 표시
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _getRunTypeText(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                if (_getGoalInfoText().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    _getGoalInfoText(),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 12),
            
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
                      polylineId: const PolylineId('running'),
                      points: _route.length >= 4 ? catmullRomSpline(_route) : _route,
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
            // Pace / Calories / Intensity / Time 표시 (실시간 값)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    CustomText(
                      text: _formatPace(_getCurrentPace()),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    CustomText(
                      text: 'Pace',
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ],
                ),
                Column(
                  children: [
                    CustomText(
                      text: _burnedCalories.toStringAsFixed(0),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    CustomText(
                      text: 'Kcal',
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ],
                ),
                Column(
                  children: [
                    CustomText(
                      text: _intensity,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    CustomText(
                      text: 'Intensity',
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ],
                ),
                Column(
                  children: [
                    CustomText(
                      text: _getTimeDisplay(), // 수정된 시간 표시 함수 사용
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    CustomText(
                      text: 'Time',
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ],
            ),

            const Spacer(),

            // 중앙 거리 표시 (실시간 값)
            Column(
              children: [
                // 목표 달성 메시지 표시
                if (_isGoalReached && _goalAchievedMessage != null)
                  Text(
                    _goalAchievedMessage!,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                
                const SizedBox(height: 8),
                
                CustomText(
                  text: (_calculateDistance(_route) * 1000).toStringAsFixed(0), // m
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                ),
                const CustomText(
                  text: 'm',
                  fontSize: 20,
                  color: Colors.grey,
                ),
              ],
            ),

            const Spacer(),

            // 하단 Stop 버튼
            SizedBox(
              height: 140,
              width: 140,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(0),
                ),
                onPressed: _isFinishing ? null : () => _stopAndShowResult(),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Stop',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'running',
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 하단 정보 표시 (제거됨 - 위로 이동함)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
