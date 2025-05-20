import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _lastPosition;
  final StreamController<Position> _positionController = StreamController<Position>.broadcast();
  Stream<Position> get positionStream => _positionController.stream;
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  // 앱 시작 시 GPS 서비스 및 권한 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('위치 서비스가 비활성화되어 있습니다. 초기화를 건너뜁니다.');
        return; // 예외를 던지지 않고 그냥 반환
      }
    }
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('위치 권한이 거부되었습니다. 초기화를 건너뜁니다.');
        return; // 예외를 던지지 않고 그냥 반환
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      debugPrint('위치 권한이 영구적으로 거부되었습니다. 초기화를 건너뜁니다.');
      return; // 예외를 던지지 않고 그냥 반환
    }
    
    // 위치 서비스가 활성화되고 권한을 받았으므로 초기 위치 가져오기
    try {
      // 타임아웃 시간을 늘려서 위치를 얻을 가능성을 높임
      _lastPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best, // 정확도를 높임
        timeLimit: const Duration(seconds: 10), // 타임아웃을 10초로 설정
      );
      _isInitialized = true;
      debugPrint('위치 초기화 성공: ${_lastPosition?.latitude}, ${_lastPosition?.longitude}');
    } catch (e) {
      debugPrint('초기 위치를 가져오는데 실패했습니다: $e');
      // 오류가 발생해도 예외를 던지지 않고 위치 스트림 시작
      startLocationUpdates(intervalMs: 2000); // 위치 업데이트 시작
    }
  }

  // 위치 권한 요청 메서드
  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('위치 서비스가 비활성화되어 있습니다.');
        return false;
      }
    }
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('위치 권한이 거부되었습니다.');
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      debugPrint('위치 권한이 영구적으로 거부되었습니다.');
      return false;
    }
    
    return true;
  }

  // 현재 위치 제공
  Future<Position> getCurrentPosition() async {
    if (!_isInitialized) {
      try {
        await initialize();
      } catch (e) {
        debugPrint('위치 서비스 초기화 실패: $e');
        // 실패해도 계속 진행
      }
    }
    
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5), // 5초 타임아웃 설정
      );
      _lastPosition = position;
      _positionController.add(position);
      return position;
    } catch (e) {
      debugPrint('위치 업데이트 문제 발생: $e');
      
      // 마지막 위치가 있으면 사용
      if (_lastPosition != null) {
        return _lastPosition!;
      }
      
      // 그렇지 않으면 기본 위치 제공 (서울 중심부)
      return Position(
        longitude: 126.9780, 
        latitude: 37.5665,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );
    }
  }

  // 위치 정보를 LatLng 객체로 변환
  Future<LatLng> getCurrentLatLng() async {
    final position = await getCurrentPosition();
    return LatLng(position.latitude, position.longitude);
  }

  // 위치 정보 스트림 시작
  StreamSubscription<Position>? _positionStreamSubscription;
  
  void startLocationUpdates({int intervalMs = 1000}) {
    if (_positionStreamSubscription != null) {
      _positionStreamSubscription!.cancel();
    }
    
    try {
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // 최소 5m 이동해야 업데이트
          timeLimit: Duration(milliseconds: intervalMs),
        ),
      ).listen(
        (position) {
          _lastPosition = position;
          _positionController.add(position);
          debugPrint('위치 업데이트 받음: ${position.latitude}, ${position.longitude}');
        },
        onError: (e) {
          debugPrint('위치 스트림 오류: $e');
          // 오류 발생 시 3초 후 다시 시도
          Future.delayed(const Duration(seconds: 3), () {
            if (_positionStreamSubscription == null) {
              startLocationUpdates(intervalMs: intervalMs);
            }
          });
        },
      );
    } catch (e) {
      debugPrint('위치 스트림 시작 오류: $e');
      // 오류 발생 시 3초 후 다시 시도
      Future.delayed(const Duration(seconds: 3), () {
        startLocationUpdates(intervalMs: intervalMs);
      });
    }
  }

  // 위치 정보 스트림 중지
  void stopLocationUpdates() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  // 서비스 정리
  void dispose() {
    stopLocationUpdates();
    _positionController.close();
  }
}

// 전역 인스턴스
final locationService = LocationService();
