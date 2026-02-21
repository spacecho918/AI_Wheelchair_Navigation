import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gilbeot/screens/login_screen.dart';
import 'package:gilbeot/screens/signup_screen.dart';
import 'reset_password_success_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  // 이메일 입력값을 제어할 컨트롤러
  final TextEditingController _emailController = TextEditingController();
  bool _isEmailValid = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _validateEmail() {
    // Basic email regex
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    setState(() {
      _isEmailValid = emailRegex.hasMatch(_emailController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // 배경색
      body: SafeArea(
        child: SingleChildScrollView(
          // 스크롤 가능하게 설정
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  // 1. 로고 영역
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF354152),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C853),
                          borderRadius: BorderRadius.circular(8.75),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: SvgPicture.asset(
                          'assets/wheelchair_icon.svg',
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                          placeholderBuilder: (context) => const Icon(
                            Icons.accessible,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '길벗',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFF1F5F9)
                              : const Color(0xFF101727),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // 2. 비밀번호 재설정 카드
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 50,
                          offset: const Offset(0, 25),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          '비밀번호 재설정',
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFF1F5F9)
                                : const Color(0xFF101727),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '비밀번호 재설정 링크를 받으려면 이메일을 입력하세요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFB6C2CF)
                                : const Color(0xFF495565),
                            fontSize: 12.25,
                          ),
                        ),
                        const SizedBox(height: 30),

                        // 이메일 입력창
                        _buildTextField(
                          '이메일 주소',
                          '이메일을 입력하세요',
                          _emailController,
                          inputType: TextInputType.emailAddress,
                        ),

                        const SizedBox(height: 24),

                        // [버튼 1] 링크 전송 버튼
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isEmailValid
                                ? () {
                                    // Navigate to success screen
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ResetPasswordSuccessScreen(
                                              email: _emailController.text,
                                            ),
                                      ),
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00C853),
                              disabledBackgroundColor: const Color(0xFFE5E7EB),
                              foregroundColor: Colors.white,
                              disabledForegroundColor: const Color(0xFF9CA3AF),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              '재설정 링크 보내기',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // [버튼 2] 로그인으로 돌아가기 (Outlined Button 스타일)
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF2F3945)
                                    : Colors.black.withValues(alpha: 0.1),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              '로그인으로 돌아가기',
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFF1F5F9)
                                    : const Color(0xFF141414),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // [버튼 3] 로그인으로 가기
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '계정이 없으신가요?',
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF9CA3AF)
                                    : const Color(0xFF697282),
                                fontSize: 12.25,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SignupScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                '회원가입',
                                style: TextStyle(
                                  color: Color(0xFF00C853),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 하단 약관
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      '계정을 만들면 서비스 약관 및 개인정보 처리방침에 동의하게 됩니다',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF697282),
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- [팝업창] 링크 전송 완료 ---

  // 입력창 만들기 도구
  Widget _buildTextField(
    String label,
    String placeholder,
    TextEditingController controller, {
    TextInputType inputType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.25,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFCBD5E1)
                : Colors.black,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: inputType,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF6B7280)
                : const Color(0xFF717182), fontSize: 14),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2A2A2A)
                : const Color(0xFFF3F3F5),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
