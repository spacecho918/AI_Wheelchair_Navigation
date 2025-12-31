import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gilbeot/screens/signup_screen.dart';

class ResetPasswordScreen extends StatelessWidget {
  // 이메일 입력값을 제어할 컨트롤러
  final TextEditingController _emailController = TextEditingController();

  ResetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4), // 배경색
      body: SafeArea(
        child: SingleChildScrollView(
          // 스크롤 가능하게 설정
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // 1. 로고 영역
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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

              // 2. 비밀번호 재설정 카드
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
                      '비밀번호 재설정 링크를 받으려면 이메일을 입력하세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF495565),
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
                        onPressed: () {
                          // 이메일 전송 완료 팝업 띄우기
                          _showResetSuccessDialog(context);
                          debugPrint("비밀번호 재설정 이메일: ${_emailController.text}");
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C853),
                          foregroundColor: Colors.white,
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

                    // [버튼 2] 회원가입으로 돌아가기 (Outlined Button 스타일)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SignupScreen(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.black.withValues(alpha: 0.1),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          '회원가입으로 돌아가기',
                          style: TextStyle(
                            color: Color(0xFF0A0A0A),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // [버튼 3] 로그인으로 가기
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '이미 계정이 있으신가요?',
                          style: TextStyle(
                            color: Color(0xFF697282),
                            fontSize: 12.25,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // 로그인 화면으로 이동 (보통 Login -> Forgot PW 순서이므로 pop을 2번 하거나, pushAndRemoveUntil을 사용)
                            // 여기서는 간단히 창을 닫는 것으로 처리 (상황에 따라 수정 가능)
                            Navigator.pop(context);
                          },
                          child: const Text(
                            '로그인',
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '계정을 만들면 서비스 약관 및 개인정보 처리방침에 동의하게 됩니다',
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

  // --- [팝업창] 링크 전송 완료 ---
  void _showResetSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '알림',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text('비밀번호 재설정 링크가\n이메일로 전송되었습니다.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 1. 팝업 닫기
                Navigator.pop(context); // 2. 로그인(또는 이전) 화면으로 돌아가기
              },
              child: const Text(
                '확인',
                style: TextStyle(
                  color: Color(0xFF00C853),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

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
          style: const TextStyle(
            fontSize: 12.25,
            color: Colors.black,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: inputType,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(color: Color(0xFF717182), fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFF3F3F5),
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
