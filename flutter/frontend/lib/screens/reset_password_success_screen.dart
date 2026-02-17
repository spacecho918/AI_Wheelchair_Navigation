import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gilbeot/screens/login_screen.dart';
import 'package:gilbeot/widgets/common_toast.dart';

class ResetPasswordSuccessScreen extends StatefulWidget {
  final String email;

  const ResetPasswordSuccessScreen({super.key, required this.email});

  @override
  State<ResetPasswordSuccessScreen> createState() =>
      _ResetPasswordSuccessScreenState();
}

class _ResetPasswordSuccessScreenState
    extends State<ResetPasswordSuccessScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                children: [
                  // 1. Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF354152),
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
                          '비밀번호 재설정 메일 발송',
                          style: TextStyle(
                            color: Color(0xFF101727),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '메일함에서 재설정 링크를 클릭해주세요',
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
                          '링크를 클릭하여 비밀번호를 변경해주세요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF697282),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.email,
                          style: const TextStyle(
                            color: Color(0xFF697282),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Verify Button -> Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            },
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
                              '로그인하러 가기',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

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
                                CommonToast.show(context, '재설정 링크를 다시 보냈습니다.');
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
