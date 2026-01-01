import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'login_screen.dart';

class ResetPasswordSuccessScreen extends StatelessWidget {
  final String email;

  const ResetPasswordSuccessScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              // 1. Header
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
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
                  const Text(
                    '길벗',
                    style: TextStyle(
                      color: Color(0xFF101727),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // 2. Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
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
                    const Text(
                      '비밀번호 재설정',
                      style: TextStyle(
                        color: Color(0xFF101727),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '이메일을 확인하고 비밀번호를 변경하세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF495565),
                        fontSize: 12.25,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Icon Circle
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9), // Light green bg
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mail_outline,
                        color: Color(0xFF00C853),
                        size: 40,
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      '재설정 메일을 보냈습니다!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF101727),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '메일함의 링크를 클릭하여 새 비밀번호를 설정해주세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF697282), fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        color: Color(0xFF697282),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Verify Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LoginScreen(),
                            ), // Go to Login
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C853),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.check_circle_outline, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '로그인으로 이동',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Return Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(
                            context,
                          ); // Go back to enter email again ?? Or navigate to ResetPasswordScreen? pop is simpler if we pushed.
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          foregroundColor: const Color(0xFF4B5563),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          '이메일 다시 입력하기',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Resend Link
                    Column(
                      children: [
                        const Text(
                          '메일을 받지 못하셨나요?',
                          style: TextStyle(
                            color: Color(0xFF697282),
                            fontSize: 12.25,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // Resend logic
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('재설정 메일을 다시 보냈습니다.'),
                              ),
                            );
                          },
                          child: const Text(
                            '다시 보내기',
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '계정을 생성하시면 서비스 약관 및 개인정보 처리방침에 동의하는 것으로 간주됩니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF697282), fontSize: 10.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
