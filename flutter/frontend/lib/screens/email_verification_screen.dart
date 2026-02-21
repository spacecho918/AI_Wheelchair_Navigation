import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';
import 'package:gilbeot/widgets/common_toast.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isResending = false;

  Future<void> _resendVerification() async {
    if (_isResending) return;
    setState(() => _isResending = true);
    try {
      await AuthService.resendVerificationEmail(widget.email);
      if (mounted) {
        CommonToast.show(context, '인증 링크를 다시 보냈습니다. 메일함을 확인해주세요.');
      }
    } catch (e) {
      if (mounted) {
        CommonToast.show(context, '재발송 실패: $e');
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

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
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF0FDF4),
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
                        icon: Icon(
                          Icons.arrow_back,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFCBD5E1)
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

                  // 2. Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).cardColor
                          : Colors.white,
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
                          '이메일 인증',
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
                          '메일함에서 인증 링크를 클릭해주세요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFB6C2CF)
                                : const Color(0xFF4A5565),
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

                        Text(
                          '인증 메일을 보냈습니다!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFF1F5F9)
                                : const Color(0xFF101727),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '메일함을 확인하고 인증 링크를 클릭해주세요',
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF9EA6B8),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.email,
                          style: const TextStyle(
                            color: Color(0xFF9EA6B8),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LoginScreen(),
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

                        // Return Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              foregroundColor: const Color(0xFF4A5565),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              '회원가입으로 돌아가기',
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
                            Text(
                              '메일을 받지 못하셨나요?',
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF9EA6B8),
                                fontSize: 12.25,
                              ),
                            ),
                            TextButton(
                              onPressed: _isResending
                                  ? null
                                  : _resendVerification,
                              child: Text(
                                _isResending ? '전송 중...' : '다시 보내기',
                                style: const TextStyle(
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
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      '계정을 생성하시면 서비스 약관 및 개인정보 처리방침에 동의하는 것으로 간주됩니다',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF64748B)
                            : const Color(0xFF9EA6B8),
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
}
