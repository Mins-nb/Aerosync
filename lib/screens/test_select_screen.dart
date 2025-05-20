import 'package:flutter/material.dart';
import 'test_running_screen.dart';
import 'countdown_screen.dart';
import 'test_detail_screen.dart'; // TestScreenType enum 사용
import '../widgets/custom_button.dart';

/// 체력 테스트 선택 화면
class TestSelectScreen extends StatelessWidget {
  const TestSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Test',
          style: TextStyle(
            fontSize: 20,
            color: Colors.black,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: SizedBox(
            width: 400,
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: 24,
              crossAxisSpacing: 24,
              childAspectRatio: 1,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _TestSquareButton(
                  label: '1마일 걷기',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TestDetailScreen(testType: TestScreenType.walk1mile),
                      ),
                    );
                  },
                ),
                _TestSquareButton(
                  label: '1.5마일 달리기',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CountDownScreen(onCountdownEnd: () {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => TestRunningScreen(testType: TestScreenType.run1_5mile),
    ),
  );
}),
                      ),
                    );
                  },
                ),
                _TestSquareButton(
                  label: '5분 달리기',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CountDownScreen(onCountdownEnd: () {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => TestRunningScreen(testType: TestScreenType.run5min),
    ),
  );
}),
                      ),
                    );
                  },
                ),
                _TestSquareButton(
                  label: '12분 달리기',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CountDownScreen(onCountdownEnd: () {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => TestRunningScreen(testType: TestScreenType.run12min),
    ),
  );
}),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 노란색 정사각형 커스텀 버튼 위젯
class _TestSquareButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TestSquareButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100, // 정사각형 (GridView에서 childAspectRatio=1)
      width: 100,
      child: CustomButton(
        text: label,
        color: Colors.yellow.shade600,
        textColor: Colors.black,
        fontSize: 18,
        onPressed: onTap,
        hasBorder: false,
      ),
    );
  }
}
