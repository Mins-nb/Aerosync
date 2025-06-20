import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'calorie_result_screen.dart';

class BMICalculatorScreen extends StatefulWidget {
  const BMICalculatorScreen({Key? key}) : super(key: key);

  @override
  State<BMICalculatorScreen> createState() => _BMICalculatorScreenState();
}

class _BMICalculatorScreenState extends State<BMICalculatorScreen> {
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _targetWeightController = TextEditingController();
  
  // 오늘 날짜로 자동 초기화
  late String _year;
  late String _month;
  late String _day;
  
  int _weightLossDuration = 6; // 기본값 6개월
  bool _isMonthSelected = true; // 기본값 개월
  
  // 기초대사량 계산 타입
  String _bmrCalculationType = '자동계산';
  final _bmrController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    // 오늘 날짜 자동 초기화
    final now = DateTime.now();
    _year = now.year.toString();
    _month = now.month.toString().padLeft(2, '0');
    _day = now.day.toString().padLeft(2, '0');
  }
  
  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    _bmrController.dispose();
    super.dispose();
  }
  
  // 기초대사량 자동 계산 (Harris-Benedict 방정식 사용)
  double _calculateBMR(double weight, double height) {
    // 남성 기준 - 실제 앱에서는 성별 선택 추가 필요
    return 66.5 + (13.75 * weight) + (5.003 * height) - (6.75 * 30); // 나이 30 가정
  }
  
  void _calculateBMI() {
    double height = double.tryParse(_heightController.text) ?? 0;
    double weight = double.tryParse(_weightController.text) ?? 0;
    
    if (height > 0 && weight > 0) {
      setState(() {
        // 기초대사량 자동 업데이트
        if (_bmrCalculationType == '자동계산') {
          _bmrController.text = _calculateBMR(weight, height).toStringAsFixed(0);
        }
      });
    }
  }
  
  void _submitForm() {
    if (_heightController.text.isEmpty || 
        _weightController.text.isEmpty || 
        _targetWeightController.text.isEmpty ||
        _bmrController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 항목을 입력해주세요')),
      );
      return;
    }
    
    double height = double.tryParse(_heightController.text) ?? 0;
    double weight = double.tryParse(_weightController.text) ?? 0;
    double targetWeight = double.tryParse(_targetWeightController.text) ?? 0;
    double bmr = double.tryParse(_bmrController.text) ?? 0;
    
    // 시작일 설정
    DateTime startDate = DateTime(
      int.parse(_year),
      int.parse(_month),
      int.parse(_day),
    );
    
    // 감량 기간 (일 또는 개월)
    int durationInDays = _isMonthSelected 
        ? _weightLossDuration * 30 // 월 단위를 일 단위로 대략 변환
        : _weightLossDuration;
    
    // 결과 화면으로 이동
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => CalorieResultScreen(
          height: height,
          weight: weight,
          targetWeight: targetWeight,
          bmr: bmr,
          startDate: startDate,
          durationInDays: durationInDays,
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('칼로리 계산', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        shadowColor: Colors.black12,
      ),
      backgroundColor: Colors.white, // 완전 흰색 배경으로 변경
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 목표 설정 섹션 (디자인 개선)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        color: Color(0xFFFFD600), // 노란색으로 변경
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '목표 설정',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFD600), // 노란색으로 변경
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '맞춤 칼로리 계산을 위해 정보를 입력해주세요',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 키 입력
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.height,
                              size: 18,
                              color: Color(0xFFFFD600),
                            ),
                            SizedBox(width: 4),
                            Text(
                              '키', 
                              style: TextStyle(
                                fontSize: 17, 
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF424242),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '*', 
                        style: TextStyle(
                          color: Color(0xFFFFD600), 
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: '예) 177',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      suffixText: 'cm',
                      suffixStyle: const TextStyle(color: Color(0xFFFFD600), fontWeight: FontWeight.bold),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFFFD600), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (_) => _calculateBMI(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 몸무게 입력
                  Row(
                    children: [
                      const Text(
                        '몸무게', 
                        style: TextStyle(
                          fontSize: 17, 
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF424242),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '*', 
                        style: TextStyle(
                          color: Color(0xFFFFD600), 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: '예) 100',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFFFD600), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      suffixText: 'kg',
                      suffixStyle: const TextStyle(color: Color(0xFFFFD600), fontWeight: FontWeight.bold),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onChanged: (_) => _calculateBMI(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 기초대사량 계산 방식
                  Row(
                    children: [
                      const Text(
                        '기초대사량',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF424242),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '*',
                        style: TextStyle(
                          color: Color(0xFFFFD600),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Theme(
                          data: Theme.of(context).copyWith(
                            unselectedWidgetColor: Colors.grey.shade400,
                            colorScheme: Theme.of(context).colorScheme.copyWith(
                              secondary: const Color(0xFFFFD600),
                            ),
                          ),
                          child: Radio<String>(
                            value: '자동계산',
                            groupValue: _bmrCalculationType,
                            onChanged: (value) {
                              setState(() {
                                _bmrCalculationType = value!;
                                // 자동계산 시 키와 몸무게가 입력되어 있으면 계산
                                if (_heightController.text.isNotEmpty && 
                                    _weightController.text.isNotEmpty) {
                                  _calculateBMI();
                                }
                              });
                            },
                          ),
                        ),
                        const Text('자동계산',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Theme(
                          data: Theme.of(context).copyWith(
                            unselectedWidgetColor: Colors.grey.shade400,
                            colorScheme: Theme.of(context).colorScheme.copyWith(
                              secondary: const Color(0xFFFFD600),
                            ),
                          ),
                          child: Radio<String>(
                            value: '직접입력',
                            groupValue: _bmrCalculationType,
                            onChanged: (value) {
                              setState(() {
                                _bmrCalculationType = value!;
                              });
                            },
                          ),
                        ),
                        const Text('직접입력',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bmrController,
                    decoration: InputDecoration(
                      hintText: _bmrCalculationType == '자동계산' ? '자동 계산됨' : '예) 1800',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFFFD600), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      suffixText: 'kcal',
                      suffixStyle: const TextStyle(color: Color(0xFFFFD600), fontWeight: FontWeight.bold),
                      filled: true,
                      fillColor: _bmrCalculationType == '자동계산' ? Colors.grey.shade100 : Colors.grey.shade50,
                    ),
                    enabled: _bmrCalculationType == '직접입력',
                    style: TextStyle(color: _bmrCalculationType == '자동계산' ? Colors.grey : Colors.black),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 목표체중 입력
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.fitness_center,
                              size: 18,
                              color: Color(0xFFFFD600),
                            ),
                            SizedBox(width: 4),
                            Text(
                              '목표체중', 
                              style: TextStyle(
                                fontSize: 17, 
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF424242),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '*', 
                        style: TextStyle(
                          color: Color(0xFFFFD600), 
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _targetWeightController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: '예) 75',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      suffixText: 'kg',
                      suffixStyle: const TextStyle(color: Color(0xFFFFD600), fontWeight: FontWeight.bold),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFFFD600), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 다이어트 시작일
                  Row(
                    children: [
                      const Text(
                        '다이어트 시작일',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF424242),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '*',
                        style: TextStyle(
                          color: Color(0xFFFFD600),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // 연도 선택
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _year,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFFFD600)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFFFD600)),
                            dropdownColor: Colors.white,
                            style: const TextStyle(color: Color(0xFF424242), fontSize: 15),
                            items: ['2025', '2026', '2027'].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _year = newValue!;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 월 선택
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _month,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFFFD600)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFFFD600)),
                            dropdownColor: Colors.white,
                            style: const TextStyle(color: Color(0xFF424242), fontSize: 15),
                            items: List.generate(12, (index) {
                              String month = (index + 1).toString().padLeft(2, '0');
                              return DropdownMenuItem<String>(
                                value: month,
                                child: Text(month),
                              );
                            }),
                            onChanged: (String? newValue) {
                              setState(() {
                                _month = newValue!;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 일 선택
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _day,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFFFD600)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFFFD600)),
                            dropdownColor: Colors.white,
                            style: const TextStyle(color: Color(0xFF424242), fontSize: 15),
                            items: List.generate(31, (index) {
                              String day = (index + 1).toString().padLeft(2, '0');
                              return DropdownMenuItem<String>(
                                value: day,
                                child: Text(day),
                              );
                            }),
                            onChanged: (String? newValue) {
                              setState(() {
                                _day = newValue!;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 체중 감량 기간
                  Row(
                    children: [
                      const Text(
                        '체중 감량 기간',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        '*',
                        style: TextStyle(
                          color: Color(0xFFFFD600),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFFFD600), width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          controller: TextEditingController(text: _weightLossDuration.toString()),
                          onChanged: (value) {
                            setState(() {
                              _weightLossDuration = int.tryParse(value) ?? 6;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Theme(
                      data: Theme.of(context).copyWith(
                        unselectedWidgetColor: Colors.grey.shade400,
                        colorScheme: Theme.of(context).colorScheme.copyWith(
                          secondary: const Color(0xFFFFD600),
                        ),
                      ),
                      child: Radio<bool>(
                        value: false,
                        groupValue: _isMonthSelected,
                        onChanged: (value) {
                          setState(() {
                            _isMonthSelected = value!;
                          });
                        },
                      ),
                    ),
                    const Text('일', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 16),
                    Theme(
                      data: Theme.of(context).copyWith(
                        unselectedWidgetColor: Colors.grey.shade400,
                        colorScheme: Theme.of(context).colorScheme.copyWith(
                          secondary: const Color(0xFFFFD600),
                        ),
                      ),
                      child: Radio<bool>(
                        value: true,
                        groupValue: _isMonthSelected,
                        onChanged: (value) {
                          setState(() {
                            _isMonthSelected = value!;
                          });
                        },
                      ),
                    ),
                    const Text('개월', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 계산 버튼
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD600).withOpacity(0.4),
                          spreadRadius: 1,
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD600),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.calculate_rounded,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '칼로리 계산하기',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 레이아웃 개선을 위한 하단 여백
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
