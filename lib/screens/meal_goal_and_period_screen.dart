import 'package:flutter/material.dart';

import 'package:hive/hive.dart';
import '../../models/user.dart';

class MealGoalAndPeriodScreen extends StatefulWidget {
  final String? initialGoal;
  final int? initialPeriod;
  final void Function({required String goal, required int period, required double targetWeight, required String allergy, required int meals}) onNext;
  final VoidCallback onPrev;

  const MealGoalAndPeriodScreen({
    Key? key,
    this.initialGoal,
    this.initialPeriod,
    required this.onNext,
    required this.onPrev,
  }) : super(key: key);

  @override
  State<MealGoalAndPeriodScreen> createState() => _MealGoalAndPeriodScreenState();
}

class _MealGoalAndPeriodScreenState extends State<MealGoalAndPeriodScreen> {
  String? _goal;
  int? _period;
  double? _targetWeight;
  bool _hasAllergy = false;
  String? _allergy;
  int _meals = 3; // 추가: 하루 식사 수
  final TextEditingController _periodController = TextEditingController();
  final TextEditingController _targetWeightController = TextEditingController();
  final TextEditingController _allergyController = TextEditingController();

  User? _user;

  @override
  void initState() {
    super.initState();
    _goal = widget.initialGoal;
    _period = widget.initialPeriod;
    // 프로필 정보 불러오기
    final userBox = Hive.box<User>('userBox');
    _user = userBox.get('profile');
    if (_user != null) {
      _targetWeightController.text = _user!.weight.toString();
    }
    if (_period != null) {
      _periodController.text = _period.toString();
    }
  }

  @override
  void dispose() {
    _periodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('목표 및 기간 선택'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '식단의 목표를 선택해 주세요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _goal,
              items: const [
                DropdownMenuItem(value: '감량', child: Text('감량(다이어트)')),
                DropdownMenuItem(value: '유지', child: Text('유지')),
                DropdownMenuItem(value: '증량', child: Text('증량(벌크업)')),
              ],
              onChanged: (value) => setState(() => _goal = value),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '목표를 선택하세요',
              ),
            ),
            const SizedBox(height: 32),
            if (_user != null) ...[
              Text('회원 정보', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700])),
              const SizedBox(height: 8),
              Text('이름: ${_user!.name}'),
              Text('성별: ${_user!.gender}'),
              Text('나이: ${_user!.age}'),
              Text('키: ${_user!.height} cm'),
              Text('몸무게: ${_user!.weight} kg'),
              const SizedBox(height: 24),
            ],
            const Text('목표 체중을 입력해 주세요', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _targetWeightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '목표 체중 (kg)',
              ),
              onChanged: (value) {
                final v = double.tryParse(value);
                setState(() => _targetWeight = v);
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Checkbox(
                  value: _hasAllergy,
                  onChanged: (value) {
                    setState(() {
                      _hasAllergy = value ?? false;
                      if (!_hasAllergy) _allergyController.clear();
                    });
                  },
                ),
                const Text('알러지가 있으신가요?'),
              ],
            ),
            if (_hasAllergy) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _allergyController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '알러지(예: 견과류, 우유 등)',
                ),
                onChanged: (value) {
                  setState(() => _allergy = value);
                },
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              '며칠 동안의 식단을 추천받고 싶으신가요?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _periodController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '추천 기간(일)',
              ),
              onChanged: (value) {
                final v = int.tryParse(value);
                setState(() => _period = v);
              },
            ),
            
            const SizedBox(height: 24),
            const Text(
              '하루 식사 수',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _meals,
              items: [
                DropdownMenuItem(value: 2, child: Text('2끌니 (아침, 저녁)')),
                DropdownMenuItem(value: 3, child: Text('3끌니 (아침, 점심, 저녁)')),
                DropdownMenuItem(value: 5, child: Text('5끌니 (3끌니 + 간식 2회)')),
              ],
              onChanged: (value) => setState(() => _meals = value ?? 3),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '하루 식사 횟수를 선택하세요',
              ),
            ),
            
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onPrev,
                    child: const Text('이전'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_goal != null && _period != null && _period! > 0 && _targetWeight != null)
                        ? () => widget.onNext(
                              goal: _goal!,
                              period: _period!,
                              targetWeight: _targetWeight!,
                              allergy: _hasAllergy ? (_allergy ?? '') : '',
                              meals: _meals,
                            )
                        : null,
                    child: const Text('다음'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
