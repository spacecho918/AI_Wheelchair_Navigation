import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'email_verification_screen.dart';
import 'login_screen.dart';
import 'reset_password_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // State Variables
  String? _selectedWheelchairType; // 'Electric', 'Manual', 'None'
  bool _isEmailValid = true;
  bool _isPasswordFormatValid = true;
  bool _isPasswordMatch = true;
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_validateForm);
    _nicknameController.addListener(_validateForm);
    _emailController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
    _confirmPasswordController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validateForm() {
    // Email Validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    final isEmailValid =
        _emailController.text.isEmpty ||
        emailRegex.hasMatch(_emailController.text);

    // Password Validation
    // At least 8 chars, must contain at least one letter and one number
    final password = _passwordController.text;
    final passwordRegex = RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$');
    final isPasswordFormatValid =
        password.isEmpty || passwordRegex.hasMatch(password);

    final isPasswordMatch =
        _passwordController.text == _confirmPasswordController.text;

    // Check all fields
    final isNameFilled = _nameController.text.isNotEmpty;
    final isNicknameFilled = _nicknameController.text.isNotEmpty;
    final isEmailFilled = _emailController.text.isNotEmpty;
    final isPasswordFilled = _passwordController.text.isNotEmpty;
    final isConfirmFilled = _confirmPasswordController.text.isNotEmpty;
    final isWheelchairSelected = _selectedWheelchairType != null;

    setState(() {
      _isEmailValid = isEmailValid;
      _isPasswordFormatValid = isPasswordFormatValid;
      _isPasswordMatch = isPasswordMatch;
      _isFormValid =
          isNameFilled &&
          isNicknameFilled &&
          isEmailFilled &&
          isPasswordFilled &&
          isConfirmFilled &&
          isWheelchairSelected &&
          isEmailValid &&
          isPasswordFormatValid &&
          isPasswordMatch;
    });
  }

  void _onWheelchairTypeSelected(String type) {
    setState(() {
      _selectedWheelchairType = type;
    });
    _validateForm();
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 1. Header (Logo)
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

                  // 2. Form Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: 0.1,
                          ), // changed withValues to withOpacity for compatibility if needed, but withValues is fine in new flutter. Previous code used withValues. I'll stick to withValues(alpha: 0.1).
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
                          '안전한 길안내를 시작하세요', // Changed text to match image "안전한 길안내를 시작하세요" (Start safe navigation) vs "수천 명의..."
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF4A5565),
                            fontSize: 12.25,
                          ),
                        ),
                        const SizedBox(height: 30),

                        _buildTextField('이름', '이름을 입력하세요', _nameController),
                        const SizedBox(height: 16),
                        _buildTextField(
                          '닉네임',
                          '닉네임을 입력하세요',
                          _nicknameController,
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          '이메일 주소',
                          '이메일을 입력하세요',
                          _emailController,
                          inputType: TextInputType.emailAddress,
                          errorText:
                              _isEmailValid || _emailController.text.isEmpty
                              ? null
                              : '올바른 이메일 형식을 입력해주세요',
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          '비밀번호',
                          '비밀번호를 생성하세요',
                          _passwordController,
                          isPassword: true,
                          errorText: _isPasswordFormatValid
                              ? null
                              : '영어, 숫자 포함 8자리 이상 입력해주세요',
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          '비밀번호 확인',
                          '비밀번호를 다시 입력하세요',
                          _confirmPasswordController,
                          isPassword: true,
                          errorText:
                              _isPasswordMatch ||
                                  _confirmPasswordController.text.isEmpty
                              ? null
                              : '비밀번호가 일치하지 않습니다',
                        ),
                        const SizedBox(height: 16),

                        // Wheelchair Type Selection
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '휠체어 타입',
                            style: const TextStyle(
                              fontSize: 12.25,
                              color: Color(0xFF101727),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildWheelchairOption(
                                '전동',
                                value: 'Electric',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildWheelchairOption(
                                '수동',
                                value: 'Manual',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildWheelchairOption(
                                '보호자 동반 수동',
                                value: 'CaregiverManual',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildWheelchairOption(
                                '선택안함',
                                value: 'None',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '더 나은 경로 추천을 위해 휠체어 타입을 선택해주세요',
                          style: TextStyle(
                            color: Color(0xFF9EA6B8),
                            fontSize: 10.5,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isFormValid
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            EmailVerificationScreen(
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
                              '인증 메일 발송',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Links
                        Center(
                          child: Column(
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ResetPasswordScreen(),
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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
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
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => LoginScreen(),
                                        ),
                                        (route) => false,
                                      );
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
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      '계정을 생성하시면 서비스 약관 및 개인정보 처리방침에 동의하는 것으로 간주됩니다',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF697282),
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

  Widget _buildWheelchairOption(String label, {required String value}) {
    final isSelected = _selectedWheelchairType == value;
    return GestureDetector(
      onTap: () => _onWheelchairTypeSelected(value),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00C853)
                : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFF00C853)
                : const Color(0xFF101727),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String placeholder,
    TextEditingController controller, {
    bool isPassword = false,
    TextInputType inputType = TextInputType.text,
    String? errorText,
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
          style: const TextStyle(fontSize: 14), // Input text style
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
            errorText: errorText, // Display validation error
            errorStyle: const TextStyle(color: Colors.red, fontSize: 11),
          ),
        ),
      ],
    );
  }
}
