import 'package:flutter/material.dart';
import '../core/app_routes.dart';
import '../widgets/custom_button.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // AeroSync 텍스트
              const Text(
                'AeroSync',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const Spacer(flex: 1),

              // Login 버튼 (텍스트 크기 축소)
              CustomButton(
                text: 'Login',
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.loginForm);
                },
                color: Colors.black,
                textColor: Colors.white,
                fontSize: 18,   // 추가 옵션 전달
              ),

              const SizedBox(height: 16),

              // Register 버튼 (텍스트 크기 축소)
              CustomButton(
                text: 'Register',
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.register);
                },
                color: Colors.white,
                textColor: Colors.black,
                hasBorder: true,  // 테두리 적용
                fontSize: 18,     // 추가 옵션 전달
              ),

              const SizedBox(height: 16),

              const Text(
                'Continue as a guest',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
