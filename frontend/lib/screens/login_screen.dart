import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'signup_screen.dart';
import 'reset_password_screen.dart';
import 'map_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // [수정 1] MaterialApp 제거 (main.dart에 이미 있으므로 중복 제거)
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4), // 배경색
      body: SafeArea(
        // 화면 상단 바(노치) 침범 방지
        child: SingleChildScrollView(
          // 스크롤 가능하게 설정
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0), // 좌우 여백 추가
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Gilbeot(),
              ),
            ), // Gilbeot 위젯 호출
          ),
        ),
      ),
    );
  }
}

class Gilbeot extends StatelessWidget {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Gilbeot({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 60),

        // 로고 영역 (기존 유지)
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: const Color(0xFF00C853),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 50,
                offset: const Offset(0, 25),
              ),
            ],
          ),
          child: Center(
            child: SvgPicture.asset(
              'assets/wheelchair_icon.svg',
              width: 35,
              height: 35,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
              placeholderBuilder: (context) => const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '길벗',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF101727),
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '모두를 위한 안전한 이동',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF4A5565), fontSize: 14),
        ),

        const SizedBox(height: 40),

        // 로그인 폼 카드
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
                '환영합니다',
                style: TextStyle(color: Color(0xFF101727), fontSize: 14),
              ),
              const SizedBox(height: 24),

              // [1, 2] 소셜 로그인 버튼 (누르면 물결 효과 발생)
              _buildSocialButton(
                'Google 계정으로 로그인',
                'assets/google_icon.svg',
                () => debugPrint("구글 로그인 클릭됨"),
              ),
              const SizedBox(height: 10),
              _buildKakaoButton(() => debugPrint("카카오 로그인 클릭됨")),

              const SizedBox(height: 20),
              const Text('또는', style: TextStyle(color: Color(0xFF9EA6B8))),
              const SizedBox(height: 20),

              // 입력창
              _buildTextField('이메일', '이메일을 입력하세요', _emailController),
              const SizedBox(height: 14),
              _buildTextField(
                '비밀번호',
                '비밀번호를 입력하세요',
                _passwordController,
                isPassword: true,
              ),

              const SizedBox(height: 20),

              // [3] 로그인 버튼 (ElevatedButton 사용 - 확실한 클릭감)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MapScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853), // 초록색 배경
                    foregroundColor: Colors.white, // 흰색 글자 (누를 때 효과)
                    elevation: 0, // 그림자 없애기 (플랫한 디자인)
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '로그인',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // [4] 비밀번호 찾기 (TextButton 사용)
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ResetPasswordScreen(),
                    ),
                  );
                },
                child: const Text(
                  '비밀번호를 잊으셨나요?',
                  style: TextStyle(
                    color: Color(0xFF00C853),
                    fontSize: 12.25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // [5] 회원가입 (Sign Up) - 텍스트 버튼으로 구현
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "계정이 없으신가요?",
                    style: TextStyle(
                      color: Color(0xFF697282), // SignupScreen과 동일한 색상
                      fontSize: 12.25,
                    ),
                  ),
                  TextButton(
                    // [수정] 화살표(=>)를 지우고 중괄호({ })를 열어서 이동 코드를 넣습니다.
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SignupScreen()),
                      );
                    },
                    child: const Text(
                      "회원가입",
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
        const SizedBox(height: 40),
      ],
    );
  }

  // 구글 로그인 버튼 스타일 (OutlinedButton 사용)
  Widget _buildSocialButton(String text, String iconPath, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFF2F2F2), // 채우기: #F2F2F2
          foregroundColor: const Color(0xFF1F1F1F).withValues(alpha: 0.1),
          side: BorderSide.none, // 획: 없음
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(iconPath, width: 20, height: 20),
            const SizedBox(width: 10), // 카카오와 동일하게 10
            Text(
              text,
              style: const TextStyle(
                color: Color(0xFF101727), // Unified Dark Text
                fontWeight: FontWeight.w500, // Medium
                fontSize: 14, // 14
                height: 20 / 14, // 20 (line-height)
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 카카오 로그인 버튼 주입
  Widget _buildKakaoButton(VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFEE500), // 카카오 노란색
          foregroundColor: Colors.black.withValues(alpha: 0.1),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // Radius 12px
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/kakao_symbol.png',
              width: 20, // 심볼 크기 유지 (또는 가이드에 맞게 조정 가능하나 언급 없으므로 유지)
              height: 20,
            ),
            const SizedBox(width: 10),
            Text(
              '카카오 로그인',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.85),
                fontSize: 14, // 30px (approx 15sp)
                height:
                    1.0, // 컨테이너 높이(48)의 1/3(16)을 넘지 않도록 tight하게 설정 (15 * 1.0 = 15)
                // OS 별 기본 시스템 서체 사용 (fontFamily 지정 안 함, weight 기본값 사용)
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String placeholder,
    TextEditingController controller, {
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF101727)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(color: Color(0xFF9EA6B8)),
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
