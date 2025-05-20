import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/user.dart';
import 'models/record.dart';
import 'core/app_routes.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/login_form_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';

import 'screens/home_main_widget.dart';
import 'screens/countdown_screen.dart';
import 'screens/running_screen.dart';
import 'screens/running_result_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/health_report_screen.dart';
import 'screens/health_report_detail_screen_fixed.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'services/location_service.dart';

import 'services/app_state_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  // Hive 초기화
  await Hive.initFlutter();
  Hive.registerAdapter(UserAdapter());
  Hive.registerAdapter(RecordAdapter());
  await Hive.openBox<User>('userBox');
  await Hive.openBox<Record>('recordBox');
  
  // 앱 상태 관리자 초기화 (새로 추가)
  await appStateManager.loadAllTargets();
  
  // GPS 서비스 초기화 - async 호출이 완료되기를 기다리지 않고 직접 안전하게 호출
  Future.microtask(() async {
    try {
      await locationService.initialize();
      
      // 백그라운드에서 위치 업데이트 시작
      locationService.startLocationUpdates(intervalMs: 2000); // 연속 위치 파악을 위한 간격을 2초로 설정
    } catch (e) {
      // 오류 발생 시 3초 후 다시 시도
      Future.delayed(const Duration(seconds: 3), () {
        locationService.startLocationUpdates(intervalMs: 2000);
      });
    }
  });
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [appRouteObserver], // 글로벌 RouteObserver 사용
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.splash,  // 시작화면
      routes: {
        AppRoutes.splash: (context) => const SplashScreen(),
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.loginForm: (context) => const LoginFormScreen(),
        AppRoutes.register: (context) => const RegisterScreen(),
        AppRoutes.home: (context) => const HomeScreen(),
        AppRoutes.countdown: (context) => const CountDownScreen(),
        AppRoutes.running: (context) => const RunningScreen(),
        AppRoutes.runningResult: (context) {
  final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
  return RunningResultScreen(
    route: args?['route'] ?? [],
    distance: args?['distance'] ?? 0.0,
    duration: args?['duration'] ?? Duration.zero,
    pace: args?['pace'] ?? 0.0,
    calories: args?['calories'] ?? 0,
    intensity: args?['intensity'] ?? 'medium',
  );
},
        AppRoutes.profile: (context) => const ProfileScreen(),
        AppRoutes.healthReport: (context) => const HealthReportScreen(),
        AppRoutes.healthReportDetail: (context) {
          final String reportId = ModalRoute.of(context)!.settings.arguments as String? ?? '';
          return HealthReportDetailScreenFixed(reportId: reportId);
        },
      },
    );
  }
}
