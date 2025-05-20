import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// 위젯
import '../widgets/meal_section.dart'; // CalorieBar도 이 파일에 정의되어 있음
import '../widgets/exercise_bar.dart';
import '../widgets/custom_text.dart';

// 서비스
import '../services/calorie_service.dart';
import '../services/exercise_service.dart';

// 화면
import 'meal_input_screen.dart';
import 'calories_management_widget.dart';
import 'profile_screen.dart';
import '../core/app_routes.dart';


class HomeMainWidget extends StatefulWidget {
  const HomeMainWidget({Key? key}) : super(key: key);

  @override
  State<HomeMainWidget> createState() => _HomeMainWidgetState();
}

// 글로벌 RouteObserver 인스턴스 - 어느 클래스에서든 접근 가능
// MainApp에서 접근하기 위해 파일 레벨로 옮김
 final RouteObserver<PageRoute> appRouteObserver = RouteObserver<PageRoute>();

class _HomeMainWidgetState extends State<HomeMainWidget> with WidgetsBindingObserver, RouteAware {
  // 지도 관련 변수
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  final Location _location = Location();
  LatLng _currentPosition = const LatLng(37.5665, 126.9780); // 서울 시청 기본 위치
  bool _mapLoaded = false;
  Set<Marker> _markers = {};
  StreamSubscription<LocationData>? _locationSubscription;
  @override
  void initState() {
    super.initState();
    // 앱 라이프사이클 관찰을 위한 옵저버 등록
    WidgetsBinding.instance.addObserver(this);
    _refreshData();
    // 사용자 위치 권한 요청 및 초기화
    _initLocation();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 라우트 관찰 시작
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route != null && route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }
  
  // 화면이 다른 화면으로 이동할 때 호출
  @override
  void didPushNext() {
    // 다른 화면으로 이동할 때
    print('HomeMainWidget: 다른 화면으로 이동');
  }
  
  // 화면이 다시 나타날 때 호출 (중요!)
  @override
  void didPopNext() {
    // 다른 화면에서 돌아올 때 (예: 러닝 결과 화면에서 홈으로 돌아올 때)
    print('HomeMainWidget: 다른 화면에서 돌아옴 - 데이터 새로고침 시작');
    _refreshData(); // 운동 데이터를 새로고침
  }
  
  // 위치 권한 확인 및 초기화
  Future<void> _initLocation() async {
    try {
      // 권한 확인
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          return;
        }
      }
      
      // 권한 요청
      PermissionStatus permissionStatus = await _location.hasPermission();
      if (permissionStatus == PermissionStatus.denied) {
        permissionStatus = await _location.requestPermission();
        if (permissionStatus != PermissionStatus.granted) {
          return;
        }
      }
      
      // 현재 위치 얻기
      final locationData = await _location.getLocation();
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(
            locationData.latitude ?? 37.5665,
            locationData.longitude ?? 126.9780,
          );
          _mapLoaded = true;
          _markers = {
            Marker(
              markerId: const MarkerId('currentLocation'),
              position: _currentPosition,
              infoWindow: const InfoWindow(title: '현재 위치'),
            ),
          };
        });
      }
      
      // 위치 변경 시 업데이트
      _locationSubscription = _location.onLocationChanged.listen((LocationData currentLocation) {
        if (mounted && currentLocation.latitude != null && currentLocation.longitude != null) {
          setState(() {
            _currentPosition = LatLng(
              currentLocation.latitude!,
              currentLocation.longitude!,
            );
            _updateCameraPosition(_currentPosition);
            _markers = {
              Marker(
                markerId: const MarkerId('currentLocation'),
                position: _currentPosition,
                infoWindow: const InfoWindow(title: '현재 위치'),
              ),
            };
          });
        }
      });
    } catch (e) {
      print('위치 초기화 오류: $e');
    }
  }
  
  // 지도 카메라 업데이트
  Future<void> _updateCameraPosition(LatLng position) async {
    if (_mapController.isCompleted) {
      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLng(position));
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appRouteObserver.unsubscribe(this);
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 앱이 포그라운드로 돌아왔을 때 데이터 새로고침
      _refreshData();
    }
  }
  
  // 화면에 다시 들어올 때마다 호출될 새로고침 메서드
  void _refreshData() {
    // 화면 전환 애니메이션이 끝난 후에 업데이트
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (mounted) {
        print('=============================================');
        print('HomeMainWidget: _refreshData() 호출됨');
        
        // 칼로리 바 데이터 새로고침
        CalorieBar.refreshTargetCalorie();

        // 운동 서비스에서 실제 운동 칼로리 계산 (순서 중요!)
        final exerciseCalories = await ExerciseService.calculateTotalExerciseCalories();
        print('홈 화면 로드 시 운동 칼로리 계산 결과: $exerciseCalories kcal');
        
        // 운동 바 업데이트
        if (mounted) {
          ExerciseBar.updateKcal(exerciseCalories);
          print('ExerciseBar에 운동 칼로리 업데이트: $exerciseCalories kcal');
          ExerciseBar.refreshTargetKcal();
        }
        
        // 오늘 날짜의 식사 기록에서 칼로리 업데이트
        await _loadTodayMeals();
        print('=============================================');
      }
    });
  }
  
  // 오늘 날짜의 식사 기록 불러오기
  Future<void> _loadTodayMeals() async {
    try {
      final today = DateTime.now();
      final formattedDate = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      // 식사 기록에서 칼로리 불러오기 (MealSection에서 비슷한 로직이 있음)
      final prefs = await SharedPreferences.getInstance();
      var totalCalories = 0;
      
      // 아침, 점심, 저녁 데이터 불러오기
      for (var mealTime in ['Breakfast', 'Lunch', 'Dinner']) {
        final key = 'meal_${formattedDate}_$mealTime';
        final jsonData = prefs.getStringList(key) ?? [];
        
        // 각 식사의 칼로리 계산
        for (var item in jsonData) {
          try {
            final mealData = json.decode(item);
            if (mealData['nutrients'] != null && mealData['nutrients']['칼로리'] != null) {
              final calories = int.tryParse(mealData['nutrients']['칼로리'].toString()) ?? 0;
              totalCalories += calories;
            }
          } catch (e) {
            print('식사 데이터 파싱 오류: $e');
          }
        }
      }
      
      // 칼로리 바 업데이트
      CalorieBar.updateKcal(totalCalories);
      print('오늘의 총 섭취 칼로리 로드 완료: $totalCalories');
    } catch (e) {
      print('식사 데이터 로드 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 상단 프로필 영역 배경 확장
        Container(
          height: 300,
          decoration: const BoxDecoration(
            color: Color(0xFF3C4452),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(25),
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () {
                      print('프로필 사진 탭됨 - 프로필 화면으로 이동');
                      Navigator.of(context).pushNamed(AppRoutes.profile);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Colors.white,
                          radius: 20,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                ),
                                children: [
                                  TextSpan(text: 'Hello, '),
                                  TextSpan(
                                    text: 'Andrew',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            const CustomText(
                              text: 'Beginner',
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      print('톱니바퀴 아이콘 탭됨 - 프로필 화면으로 이동');
                      Navigator.of(context).pushNamed(AppRoutes.profile);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(10.0), // 탭 가능 영역 확장
                      child: Icon(Icons.settings, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 본문 영역 - 스크롤 가능하도록 변경
        SingleChildScrollView(
          child: Column(
            children: [
            const SizedBox(height: 180), // 전체적으로 위로 올림 (220 -> 180)

            // 주간 목표 박스
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              child: Column(
                children: [
                  
                  // 주간 운동 그래프
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 운동 목표 그래프 - 칼로리 목표 그래프와 디자인 통일
                        const ExerciseBar(),
                        
                        // 구분선
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
                        ),
                        
                        // 칼로리 목표 및 프로그레스 바 - 기존 바 그래프 사용
                        // setState 호출 없이 바로 CalorieBar 사용
                        const CalorieBar(),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 위젯 간 간격 제거

            // 식단 기록/추천 섹션 추가
            MealSection(
              onMealTap: (mealType) async {
                // Future<void> 반환 필요
                final result = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MealInputScreen(mealType: mealType),
                  ),
                );
                
                // 결과 처리 - meal_section.dart에서도 처리하지만 중복 처리로 확실성 높임
                if (result != null && result['updated'] == true) {
                  print('홈 화면에서 식사 업데이트 처리: $result');
                }
                
                // Future<void> 반환이 필요하므로 리턴
                return Future.value();
              },
              onTotalKcalChanged: (kcal) {
                CalorieBar.updateKcal(kcal);
              },
            ),

            // 위젯 간 간격 축소
            const SizedBox(height: 5),
            
            // 칼로리 관리 카드 UI - 분리된 위젯 사용
            const CaloriesManagementWidget(),

            // 하단에 최소 여백만 확보
            const SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }
}
