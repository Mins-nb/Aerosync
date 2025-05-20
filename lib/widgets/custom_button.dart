import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// AeroSync 공통 버튼 위젯
/// [text] : 버튼 안에 들어갈 문자열
/// [onPressed] : 버튼 클릭 시 동작 처리 함수
/// [color] : 버튼 배경 색상 (선택, 기본값 primary color)
/// [textColor] : 버튼 내 텍스트 색상 (선택, 기본값 검정색)
/// [hasBorder] : 버튼 테두리 유무 (선택, 기본값 false)
/// [fontSize] : 텍스트 크기 (선택, 기본값 24)

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? color;
  final Color? textColor;
  final bool hasBorder;
  final double? fontSize; // ✅ 추가: 글자 크기 옵션

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color,
    this.textColor,
    this.hasBorder = false,
    this.fontSize, // ✅ 초기화
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed, // 버튼 클릭 시 동작
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? AppColors.primary, // 배경 색상
        minimumSize: const Size.fromHeight(50), // 버튼 높이 고정
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25), // 라운드 박스 스타일
          side: hasBorder
              ? const BorderSide(color: Colors.black) // 테두리 O
              : BorderSide.none, // 테두리 X
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: textColor ?? Colors.black, // 텍스트 색상
          fontWeight: FontWeight.bold,
          fontSize: fontSize ?? 24, // ✅ 전달값 없으면 기본값 24
        ),
      ),
    );
  }
}
