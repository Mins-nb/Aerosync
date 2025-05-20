import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/home_screen.dart';
import '../screens/test_select_screen.dart';
import '../screens/countdown_screen.dart';
import '../screens/running_screen.dart';
import '../screens/running_result_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/health_report_detail_screen_fixed.dart';
import '../screens/health_report_screen.dart';

/// AeroSync 앱의 모든 라우트 경로를 관리하는 파일
class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String loginForm = '/loginForm'; // 신규 추가
  static const String register = '/register';
  static const String home = '/home';
  static const String testSelect = '/test-select';
  static const String countdown = '/countdown';
  static const String running = '/running';
  static const String runningResult = '/running-result';
  static const String profile = '/profile';
  static const String healthReport = '/health-report';
  static const String healthReportDetail = '/health-report-detail';

  /// 화면 이동 처리 Map
  static Map<String, WidgetBuilder> routes = {
    splash: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),
    home: (context) => const HomeScreen(),
    testSelect: (context) => const TestSelectScreen(),
    countdown: (context) => const CountDownScreen(),
    running: (context) => const RunningScreen(),
    runningResult: (context) {
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
    profile: (context) => const ProfileScreen(),
    healthReport: (context) => const HealthReportScreen(),
    healthReportDetail: (context) {
      final String reportId = ModalRoute.of(context)!.settings.arguments as String? ?? '';
      return HealthReportDetailScreenFixed(reportId: reportId);
    },
  };

  /// 러닝 결과 화면으로 이동 시 필요한 모든 인자(route, distance, duration, pace)를 넘기도록 주석 또는 네비게이션 예시
  // Navigator.pushReplacementNamed(
  //   context, AppRoutes.runningResult,
  //   arguments: {
  //     'route': route,
  //     'distance': distance,
  //     'duration': duration,
  //     'pace': pace,
  //   },
  // );
  // 실제 네비게이션은 직접 MaterialPageRoute 등으로 넘겨야 합니다.
}
