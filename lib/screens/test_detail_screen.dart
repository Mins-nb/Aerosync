import 'package:flutter/material.dart';

// TestScreenType으로 이름 변경하여 충돌 방지
enum TestScreenType {
  walk1mile,
  run1_5mile,
  run5min,
  run12min,
}

// [중요] 1.5마일, 5분, 12분 테스트는 TestRunningScreen에서 측정 후 결과를 사용하세요.
// 이 화면에서 수동 입력은 비권장 (자동 측정/입력 권장)

class TestDetailScreen extends StatefulWidget {
  final TestScreenType testType;
  const TestDetailScreen({required this.testType, super.key});

  @override
  State<TestDetailScreen> createState() => _TestDetailScreenState();
}

class _TestDetailScreenState extends State<TestDetailScreen> {
  // 입력값 컨트롤러
  final TextEditingController weightController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController genderController = TextEditingController();
  final TextEditingController timeMinController = TextEditingController();
  final TextEditingController timeSecController = TextEditingController();
  final TextEditingController hrController = TextEditingController();
  final TextEditingController distanceController = TextEditingController();

  double? result;
  String? error;

  @override
  void dispose() {
    weightController.dispose();
    ageController.dispose();
    genderController.dispose();
    timeMinController.dispose();
    timeSecController.dispose();
    hrController.dispose();
    distanceController.dispose();
    super.dispose();
  }

  String getTestTitle() {
    switch (widget.testType) {
      case TestScreenType.walk1mile:
        return '1마일 걷기 테스트';
      case TestScreenType.run1_5mile:
        return '1.5마일 달리기 테스트';
      case TestScreenType.run5min:
        return '5분 달리기 테스트';
      case TestScreenType.run12min:
        return '12분 달리기 테스트';
    }
  }

  String getTestDescription() {
    switch (widget.testType) {
      case TestScreenType.walk1mile:
        return '1 mile(1.6km)을 가능한 한 빠르게 걷고, 그 시간과 심박수로 VO2max를 추정합니다.';
      case TestScreenType.run1_5mile:
        return '1.5 mile(2.4km)을 최대한 빠르게 달리고, 그 시간으로 VO2max를 추정합니다.';
      case TestScreenType.run5min:
        return '5분 동안 가능한 한 먼 거리를 달리고, 그 거리로 VO2max를 추정합니다.';
      case TestScreenType.run12min:
        return '12분 동안 가능한 한 먼 거리를 달리고, 그 거리로 VO2max를 추정합니다.';
    }
  }

  Widget getInputFields() {
    switch (widget.testType) {
      case TestScreenType.walk1mile:
        return Column(
          children: [
            TextField(
              controller: weightController,
              decoration: const InputDecoration(labelText: '체중(kg)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: ageController,
              decoration: const InputDecoration(labelText: '나이'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: genderController,
              decoration: const InputDecoration(labelText: '성별 (남=1, 여=0)'),
              keyboardType: TextInputType.number,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: timeMinController,
                    decoration: const InputDecoration(labelText: '소요시간(분)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: timeSecController,
                    decoration: const InputDecoration(labelText: '소요시간(초)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            TextField(
              controller: hrController,
              decoration: const InputDecoration(labelText: '심박수(마지막 1분 평균)'),
              keyboardType: TextInputType.number,
            ),
          ],
        );
      case TestScreenType.run1_5mile:
        return Column(
          children: [
            TextField(
              controller: genderController,
              decoration: const InputDecoration(labelText: '성별 (남=1, 여=0)'),
              keyboardType: TextInputType.number,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: timeMinController,
                    decoration: const InputDecoration(labelText: '소요시간(분)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: timeSecController,
                    decoration: const InputDecoration(labelText: '소요시간(초)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        );
      case TestScreenType.run5min:
        return TextField(
          controller: distanceController,
          decoration: const InputDecoration(labelText: '달린 거리(m)'),
          keyboardType: TextInputType.number,
        );
      case TestScreenType.run12min:
        return TextField(
          controller: distanceController,
          decoration: const InputDecoration(labelText: '달린 거리(m)'),
          keyboardType: TextInputType.number,
        );
    }
  }

  void calculateResult() {
    setState(() {
      error = null;
      try {
        switch (widget.testType) {
          case TestScreenType.walk1mile:
            // 1마일 걷기 공식:
            // 132.853 - (0.0769 * 체중(파운드)) - (0.3877 * 나이) + (6.315 * 성별) - (3.2649 * 소요시간(분)) - (0.1565 * 심박수)
            double weightKg = double.parse(weightController.text);
            double weightLb = weightKg * 2.20462;
            double age = double.parse(ageController.text);
            double gender = double.parse(genderController.text); // 남=1, 여=0
            double min = double.parse(timeMinController.text);
            double sec = double.parse(timeSecController.text);
            double time = min + (sec / 60.0);
            double hr = double.parse(hrController.text);
            result = 132.853 - (0.0769 * weightLb) - (0.3877 * age) + (6.315 * gender) - (3.2649 * time) - (0.1565 * hr);
            break;
          case TestScreenType.run1_5mile:
            // 1.5마일 달리기 공식: 483 / 시간(분) + 3.5
            double min = double.parse(timeMinController.text);
            double sec = double.parse(timeSecController.text);
            double time = min + (sec / 60.0);
            result = 483 / time + 3.5;
            break;
          case TestScreenType.run5min:
            // 5분 달리기 공식: (달린 거리(m) / 5) * 0.2 + 3.5
            double dist = double.parse(distanceController.text);
            result = (dist / 5.0) * 0.2 + 3.5;
            break;
          case TestScreenType.run12min:
            // 12분 달리기 공식: (달린 거리(m) - 504.9) / 44.73
            double dist = double.parse(distanceController.text);
            result = (dist - 504.9) / 44.73;
            break;
        }
      } catch (e) {
        error = '모든 값을 올바르게 입력해 주세요.';
        result = null;
      }
    });
  }

  String getFormula() {
    switch (widget.testType) {
      case TestScreenType.walk1mile:
        return 'VO2max = 132.853 - (0.0769 * 체중(파운드)) - (0.3877 * 나이) + (6.315 * 성별) - (3.2649 * 소요시간(분)) - (0.1565 * 심박수)';
      case TestScreenType.run1_5mile:
        return 'VO2max = 483 / 시간(분) + 3.5';
      case TestScreenType.run5min:
        return 'VO2max = (달린 거리(m) / 5) * 0.2 + 3.5';
      case TestScreenType.run12min:
        return 'VO2max = (달린 거리(m) - 504.9) / 44.73';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(getTestTitle())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(getTestDescription(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(getFormula(), style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 24),
            getInputFields(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: calculateResult,
              child: const Text('VO2max 계산'),
            ),
            const SizedBox(height: 24),
            if (result != null)
              Text('VO2max: ${result!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
