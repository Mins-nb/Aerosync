import 'package:flutter/material.dart';
import 'health_report_list_screen.dart';

class HealthReportScreen extends StatelessWidget {
  const HealthReportScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 리포트 화면을 목록 화면으로 리디렉션
    return const HealthReportListScreen();
  }
}
