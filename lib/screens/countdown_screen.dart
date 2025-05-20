import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'test_running_screen.dart';
import 'test_detail_screen.dart';
class CountDownScreen extends StatefulWidget {
  final VoidCallback? onCountdownEnd;
  const CountDownScreen({super.key, this.onCountdownEnd});

  @override
  State<CountDownScreen> createState() => _CountDownScreenState();
}

class _CountDownScreenState extends State<CountDownScreen> {
  int _count = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    startCountdown();
  }

  void startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_count > 1) {
        setState(() {
          _count--;
        });
      } else if (_count == 1) {
        setState(() {
          _count = 0; // 0으로 설정해서 'Go!' 표시
        });
        // 'Go!' 표시 후 잠시 대기 후 화면 전환
        Future.delayed(const Duration(milliseconds: 800), () {
          timer.cancel();
          if (!mounted) return;

          try {
            if (widget.onCountdownEnd != null) {
              widget.onCountdownEnd!();
            } else {
              print('테스트 시간 끝: 기본 테스트 화면으로 이동');
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const TestRunningScreen(testType: TestScreenType.run12min)),
              );
            }
          } catch (e) {
            print('화면 전환 오류: $e');
            // 오류 발생 시 안전하게 수동으로 이동
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const TestRunningScreen(testType: TestScreenType.run12min)),
              (route) => false,
            );
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.yellow.shade600,  // 배경색 노란색 적용
      body: Center(
        child: Text(
          _count > 0 ? '$_count' : 'Go!',
          style: TextStyle(
            fontSize: _count > 0 ? 110 : 80,  // Go!는 조금 더 작게
            fontWeight: FontWeight.bold,
            color: Colors.black,  // 글자색 검정
          ),
        ),
      ),
    );
  }
}
