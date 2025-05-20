// lib/250411 Aerosync Dummy App/widgets/gps_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

class GpsWidget extends StatefulWidget {
  const GpsWidget({Key? key}) : super(key: key);

  @override
  State<GpsWidget> createState() => _GpsWidgetState();
}

class _GpsWidgetState extends State<GpsWidget> {
  final LocationService _locService = LocationService();
  Position? _currentPosition;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    // BuildContext를 비동기 간격에서 사용하지 않도록 문제 해결
    if (!mounted) return;
    
    bool granted = await _locService.requestPermission();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치 권한이 필요합니다.')),
      );
      return;
    }
    
    try {
      _currentPosition = await _locService.getCurrentPosition();
      if (mounted) setState(() {});
    } catch (e) {
      // print 대신 디버그 모드에서만 로그 출력
      debugPrint('초기 위치 가져오기 오류: $e');
    }
    
    _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        Position pos = await _locService.getCurrentPosition();
        if (mounted) {
          setState(() {
            _currentPosition = pos;
          });
        }
      } catch (e) {
        // print 대신 디버그 모드에서만 로그 출력
        debugPrint('위치 갱신 오류: $e');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '현재 위치',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        if (_currentPosition != null)
          Text(
            '위도: 	${_currentPosition!.latitude}\n경도: ${_currentPosition!.longitude}',
          )
        else
          const Text('위치 정보를 불러오는 중...'),
      ],
    );
  }
}
