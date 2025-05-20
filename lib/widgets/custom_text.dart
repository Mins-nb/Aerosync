import 'package:flutter/material.dart';

/// AeroSync 공통 Text 위젯
/// [text] : 출력할 문자열
/// [fontSize] : 글자 크기 (기본값 16)
/// [fontWeight] : 글자 두께 (기본값 normal)
/// [color] : 글자 색상 (기본값 검정)
class CustomText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final Color color;

  const CustomText({
    super.key,
    required this.text,
    this.fontSize = 16,
    this.fontWeight = FontWeight.normal,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      ),
    );
  }
}
