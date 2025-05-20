import 'package:flutter/material.dart';
import '../core/app_routes.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LoginFormScreen extends StatefulWidget {
  const LoginFormScreen({super.key});
  @override
  State<LoginFormScreen> createState() => _LoginFormScreenState();
}

class _LoginFormScreenState extends State<LoginFormScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _errorMessage;

  Future<void> _login() async {
    String? savedId = await _storage.read(key: 'userId');
    String? savedPw = await _storage.read(key: 'password');
    if (_emailController.text == savedId && _passwordController.text == savedPw) {
      // 로그인 성공: 홈 화면으로 이동
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else {
      setState(() {
        _errorMessage = '아이디 또는 비밀번호가 올바르지 않습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 60),

              const CustomText(
                text: 'Welcome back! Glad\nto see you, Again!',
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),

              const SizedBox(height: 32),

              // 이메일 입력
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  hintText: 'Enter your email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 비밀번호 입력
              TextField(
                controller: _passwordController,
                obscureText: true, // 비밀번호 입력시 텍스트 숨김
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 로그인 버튼
              CustomButton(
                text: 'Login',
                onPressed: _login,
                color: Colors.black,
                textColor: Colors.white,
                fontSize: 18,
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 60),

              const CustomText(
                text: 'Welcome back! Glad\nto see you, Again!',
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),

              const SizedBox(height: 32),

              // 이메일 입력
              TextField(
                decoration: InputDecoration(
                  hintText: 'Enter your email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 비밀번호 입력
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),

              const SizedBox(height: 24),

              // 로그인 버튼
              CustomButton(
                text: 'Login',
                onPressed: () {
                  Navigator.pushReplacementNamed(context, AppRoutes.home);
                },
                color: Colors.black,
                textColor: Colors.white,
              ),

              const SizedBox(height: 24),

              const Text('Or Login with'),

              const SizedBox(height: 16),

              // 소셜 로그인 아이콘
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: const [
                  Icon(Icons.facebook, size: 40),
                  Icon(Icons.g_mobiledata, size: 40),
                  Icon(Icons.apple, size: 40),
                ],
              ),

              const Spacer(),

              const Text.rich(
                TextSpan(
                  text: "Don't have an account? ",
                  children: [
                    TextSpan(
                      text: 'Register Now',
                      style: TextStyle(color: Colors.green),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
