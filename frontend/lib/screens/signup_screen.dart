import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'map_screen.dart';

class SignupScreen extends StatelessWidget {
  // 컨트롤러들
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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

              // 2. 회원가입 폼 카드
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
                      '계정 만들기',
                      style: TextStyle(
                        color: Color(0xFF101727),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '수천 명의 사용자와 함께 안전하게 이동하세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF495565),
                        fontSize: 12.25,
                      ),
                    ),
                    const SizedBox(height: 30),

                    _buildTextField('이름', '이름을 입력하세요', _nameController),
                    const SizedBox(height: 16),
                    _buildTextField(
                      '이메일 주소',
                      '이메일을 입력하세요',
                      _emailController,
                      inputType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      '전화번호',
                      '전화번호를 입력하세요',
                      _phoneController,
                      inputType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      '비밀번호',
                      '비밀번호를 생성하세요',
                      _passwordController,
                      isPassword: true,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      '비밀번호 확인',
                      '비밀번호를 다시 입력하세요',
                      _confirmPasswordController,
                      isPassword: true,
                    ),

                    const SizedBox(height: 24),

                    // [수정된 부분] 회원가입 버튼 (팝업 -> 이동)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          // 1. 팝업창 띄우기 함수 호출
                          _showSignupSuccessDialog(context);
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
                          '계정 만들기',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 로그인으로 돌아가기
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

  // [추가된 함수] 회원가입 완료 팝업창
  void _showSignupSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // 바깥을 눌러도 안 꺼지게 설정 (확인 버튼 강제)
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ), // 둥근 모서리
          title: const Text(
            '알림',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text('길벗에 오신 것을 환영합니다!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 1. 팝업창 닫기

                // 2. 메인 지도 화면으로 이동 (이전 화면 스택 모두 제거)
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const MapScreen()),
                  (route) => false,
                );
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

  Widget _buildTextField(
    String label,
    String placeholder,
    TextEditingController controller, {
    bool isPassword = false,
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
          obscureText: isPassword,
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
