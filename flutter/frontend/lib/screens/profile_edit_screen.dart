import 'package:flutter/material.dart';
import 'package:gilbeot/widgets/custom_back_button.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api_service.dart';
import '../widgets/common_toast.dart';
import '../screens/login_screen.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController(text: '김사라');
  final _emailController = TextEditingController(text: 'sara.kim@example.com');
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isEditingNickname = false;
  bool _isEditingPassword = false;

  bool _isLoading = true;
  String _initialNickname = '';
  String? _nicknameErrorMessage; // 닉네임 중복 등 차단 사유
  String? _profileImageUrl; // 프로필 이미지 URL

  // Nickname verification state
  bool _isCheckingNickname = false;
  bool? _nicknameCheckedAvailable;
  String? _lastVerifiedNickname;

  // Password validation state
  bool _hasMinLength = false;
  bool _hasLetterAndNumber = false;
  bool _passwordsMatch = false;
  bool _currentPasswordFilled = false;
  bool _isDifferentFromCurrent = true;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    // Add password validation listeners
    _currentPasswordController.addListener(_validatePasswordForm);
    _newPasswordController.addListener(_validatePasswordForm);
    _confirmPasswordController.addListener(_validatePasswordForm);
    // Trigger initial validation
    _validatePasswordForm();
  }

  void _validatePasswordForm() {
    final password = _newPasswordController.text;
    final passwordRegex = RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$');

    setState(() {
      _hasMinLength = password.length >= 8;
      _hasLetterAndNumber = passwordRegex.hasMatch(password);
      _passwordsMatch =
          password.isNotEmpty && password == _confirmPasswordController.text;
      _currentPasswordFilled = _currentPasswordController.text.isNotEmpty;
      _isDifferentFromCurrent =
          password != _currentPasswordController.text || password.isEmpty;

      // Generate error message
      if (_currentPasswordFilled &&
          _newPasswordController.text.isNotEmpty &&
          _confirmPasswordController.text.isNotEmpty) {
        if (!_isDifferentFromCurrent) {
          _validationError = '새 비밀번호는 현재 비밀번호와 달라야 합니다';
        } else if (!_hasMinLength) {
          _validationError = '비밀번호는 8자 이상이어야 합니다';
        } else if (!_hasLetterAndNumber) {
          _validationError = '영문, 숫자 조합이어야 합니다';
        } else if (!_passwordsMatch) {
          _validationError = '새 비밀번호가 일치하지 않습니다';
        } else {
          _validationError = null;
        }
      } else {
        _validationError = null;
      }
    });
  }

  bool get _isPasswordFormValid =>
      _currentPasswordFilled &&
      _hasMinLength &&
      _hasLetterAndNumber &&
      _passwordsMatch &&
      _isDifferentFromCurrent;

  Future<void> _loadUserProfile() async {
    final user = await ApiService.getUserProfile();
    if (user != null) {
      setState(() {
        _initialNickname = user.nickname;
        _nicknameController.text = user.nickname;
        _emailController.text = user.email;
        if (user.profileImage != null) {
          _profileImageUrl = user.profileImage;
        }
        _isLoading = false;
      });
    } else {
      // Fallback or error handling
      setState(() {
        _isLoading = false;
      });
      // Keep default values or show error
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _currentPasswordController.removeListener(_validatePasswordForm);
    _newPasswordController.removeListener(_validatePasswordForm);
    _confirmPasswordController.removeListener(_validatePasswordForm);
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onNicknameDuplicateCheck() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) return;

    if (nickname == _initialNickname) {
      setState(() {
        _nicknameCheckedAvailable = false;
        _nicknameErrorMessage = '새로운 닉네임을 입력해주세요.';
      });
      return;
    }

    setState(() => _isCheckingNickname = true);

    final isAvailable = await ApiService.isNicknameAvailableInUserProfiles(
      nickname,
    );

    if (!mounted) return;

    setState(() {
      _isCheckingNickname = false;
      _nicknameCheckedAvailable = isAvailable;
      if (isAvailable) {
        _lastVerifiedNickname = nickname;
        _nicknameErrorMessage = null;
      } else {
        _nicknameErrorMessage = '이미 사용 중인 닉네임입니다.';
      }
    });
  }

  Future<void> _saveNickname() async {
    final newNickname = _nicknameController.text.trim();

    final result = await ApiService.updateUserProfile(nickname: newNickname);
    final success = result['success'] == true;
    final error = result['error'] as String?;
    if (success && mounted) {
      CommonToast.show(context, '닉네임이 저장되었습니다');
      setState(() {
        _initialNickname = newNickname;
        _isEditingNickname = false;
        _nicknameErrorMessage = null;
      });
    } else if (mounted) {
      setState(
        () => _nicknameErrorMessage = error == 'duplicate'
            ? '이미 사용 중인 닉네임입니다.'
            : '저장에 실패했습니다.',
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked != null) _uploadImage(picked);
  }

  Future<void> _uploadImage(XFile file) async {
    setState(() => _isLoading = true);
    final url = await ApiService.uploadProfileImageToSupabase(file);

    if (url != null) {
      // Update profile with new image URL
      final result = await ApiService.updateUserProfile(profileImageUrl: url);
      if (result['success'] == true) {
        if (mounted) {
          setState(() {
            _profileImageUrl = url;
            _isLoading = false;
          });
          CommonToast.show(context, '프로필 사진이 변경되었습니다');
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          CommonToast.show(context, '프로필 업데이트 실패');
        }
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        CommonToast.show(context, '이미지 업로드 실패');
      }
    }
  }

  Future<void> _savePassword() async {
    if (_currentPasswordController.text.isEmpty) {
      CommonToast.show(context, '현재 비밀번호를 입력해주세요');
      return;
    }
    if (_newPasswordController.text.length < 8) {
      CommonToast.show(context, '비밀번호는 8자 이상이어야 합니다');
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      CommonToast.show(context, '새 비밀번호가 일치하지 않습니다');
      return;
    }

    final result = await ApiService.updatePassword(_newPasswordController.text);

    if (result['success'] == true) {
      CommonToast.show(context, result['message']);
      setState(() {
        _isEditingPassword = false;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });
    } else {
      CommonToast.show(context, result['message']);
    }
  }

  @override
  Widget build(BuildContext context) {
    // signout check
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      });
      return const SizedBox();
    }
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Stack(
                alignment: Alignment.center,
                children: const [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CustomBackButton(),
                  ),
                  Text(
                    '개인정보 수정',
                    style: TextStyle(
                      color: Color(0xFF354152),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(color: const Color(0xFFF0F2F5), height: 1.0),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile Photo Section
                          Center(
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE5E7EB),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 4,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.1,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: _profileImageUrl != null
                                          ? ClipOval(
                                              child: Image.network(
                                                _profileImageUrl!,
                                                width: 100,
                                                height: 100,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      return const Icon(
                                                        Icons.person,
                                                        size: 50,
                                                        color: Color(
                                                          0xFF9CA3AF,
                                                        ),
                                                      );
                                                    },
                                              ),
                                            )
                                          : const Icon(
                                              Icons.person,
                                              size: 50,
                                              color: Color(0xFF9CA3AF),
                                            ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: () =>
                                            _pickImage(ImageSource.camera),
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00C853),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () =>
                                      _pickImage(ImageSource.gallery),
                                  child: const Text(
                                    '사진 변경',
                                    style: TextStyle(
                                      color: Color(0xFF00C853),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Nickname Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionTitle('닉네임'),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isEditingNickname = !_isEditingNickname;
                                    _nicknameErrorMessage = null;
                                    // Reset verification state on cancel/toggle
                                    _nicknameCheckedAvailable = null;
                                    _lastVerifiedNickname = null;
                                  });
                                },
                                child: Text(
                                  _isEditingNickname ? '취소' : '변경하기',
                                  style: TextStyle(
                                    color: _isEditingNickname
                                        ? const Color(0xFF6B7280)
                                        : const Color(0xFF00C853),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_isEditingNickname)
                            Column(
                              children: [
                                _buildInputCard([
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 8,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '닉네임',
                                          style: TextStyle(
                                            color: Color(0xFF6B7280),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: _nicknameController,
                                                style: const TextStyle(
                                                  color: Color(0xFF1F2937),
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                decoration:
                                                    const InputDecoration(
                                                      isDense: true,
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                            vertical: 8,
                                                          ),
                                                      border: InputBorder.none,
                                                    ),
                                                onChanged: (value) {
                                                  // Reset verification on change
                                                  if (_nicknameCheckedAvailable !=
                                                      null) {
                                                    setState(() {
                                                      _nicknameCheckedAvailable =
                                                          null;
                                                      _lastVerifiedNickname =
                                                          null;
                                                      _nicknameErrorMessage =
                                                          null;
                                                    });
                                                  }
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              height: 36,
                                              child: TextButton(
                                                onPressed: _isCheckingNickname
                                                    ? null
                                                    : _onNicknameDuplicateCheck,
                                                style: TextButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFFE8F5E9,
                                                  ),
                                                  foregroundColor: const Color(
                                                    0xFF00C853,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                                child: _isCheckingNickname
                                                    ? const SizedBox(
                                                        width: 16,
                                                        height: 16,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          valueColor:
                                                              AlwaysStoppedAnimation<
                                                                Color
                                                              >(
                                                                Color(
                                                                  0xFF00C853,
                                                                ),
                                                              ),
                                                        ),
                                                      )
                                                    : const Text(
                                                        '중복 확인',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ]),
                                // Verification Message
                                if (_nicknameCheckedAvailable != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _nicknameCheckedAvailable!
                                        ? '사용 가능한 닉네임입니다.'
                                        : _nicknameErrorMessage!,
                                    style: TextStyle(
                                      color: _nicknameCheckedAvailable!
                                          ? const Color(0xFF00C853)
                                          : const Color(0xFFE53935),
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],

                                const SizedBox(height: 16),
                                // Nickname Save Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed:
                                        (_nicknameCheckedAvailable == true &&
                                            _lastVerifiedNickname ==
                                                _nicknameController.text
                                                    .trim() &&
                                            _nicknameController.text.trim() !=
                                                _initialNickname)
                                        ? _saveNickname
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00C853),
                                      disabledBackgroundColor: const Color(
                                        0xFFE5E7EB,
                                      ),
                                      foregroundColor: Colors.white,
                                      disabledForegroundColor: const Color(
                                        0xFF9CA3AF,
                                      ),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      '닉네임 저장',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            _buildInputCard([
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.person_outline,
                                        color: Color(0xFF9CA3AF),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            '닉네임',
                                            style: TextStyle(
                                              color: Color(0xFF6B7280),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _nicknameController.text,
                                            style: const TextStyle(
                                              color: Color(0xFF1F2937),
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ]),

                          const SizedBox(height: 24),

                          // Email Section
                          _buildSectionTitle('이메일'),
                          const SizedBox(height: 12),
                          _buildInputCard([
                            _buildTextField(
                              label: '이메일',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              enabled: false,
                              suffixIcon: const Icon(
                                Icons.lock_outline,
                                size: 18,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ]),

                          const SizedBox(height: 24),

                          // Password Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionTitle('비밀번호 변경'),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isEditingPassword = !_isEditingPassword;
                                    if (!_isEditingPassword) {
                                      _currentPasswordController.clear();
                                      _newPasswordController.clear();
                                      _confirmPasswordController.clear();
                                    }
                                  });
                                },
                                child: Text(
                                  _isEditingPassword ? '취소' : '변경하기',
                                  style: TextStyle(
                                    color: _isEditingPassword
                                        ? const Color(0xFF6B7280)
                                        : const Color(0xFF00C853),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_isEditingPassword)
                            Column(
                              children: [
                                _buildInputCard([
                                  _buildTextField(
                                    label: '현재 비밀번호',
                                    controller: _currentPasswordController,
                                    obscureText: !_isPasswordVisible,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isPasswordVisible
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 20,
                                        color: const Color(0xFF9CA3AF),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isPasswordVisible =
                                              !_isPasswordVisible;
                                        });
                                      },
                                    ),
                                  ),
                                  _buildDivider(),
                                  _buildTextField(
                                    label: '새 비밀번호',
                                    controller: _newPasswordController,
                                    obscureText: !_isNewPasswordVisible,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isNewPasswordVisible
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 20,
                                        color: const Color(0xFF9CA3AF),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isNewPasswordVisible =
                                              !_isNewPasswordVisible;
                                        });
                                      },
                                    ),
                                  ),
                                  _buildDivider(),
                                  _buildTextField(
                                    label: '새 비밀번호 확인',
                                    controller: _confirmPasswordController,
                                    obscureText: !_isConfirmPasswordVisible,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isConfirmPasswordVisible
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 20,
                                        color: const Color(0xFF9CA3AF),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isConfirmPasswordVisible =
                                              !_isConfirmPasswordVisible;
                                        });
                                      },
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 16),
                                if (_validationError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 16,
                                      left: 4,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.info_outline,
                                          color: Color(0xFFEF4444),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _validationError!,
                                          style: const TextStyle(
                                            color: Color(0xFFEF4444),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                // Password Save Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _isPasswordFormValid
                                        ? _savePassword
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isPasswordFormValid
                                          ? const Color(0xFF00C853)
                                          : const Color(0xFFE5E7EB),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      '비밀번호 변경',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: _isPasswordFormValid
                                            ? Colors.white
                                            : const Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.lock_outline,
                                      color: Color(0xFF9CA3AF),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Text(
                                    '••••••••',
                                    style: TextStyle(
                                      color: Color(0xFF9CA3AF),
                                      fontSize: 16,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 40),

                          // Danger Zone
                          _buildSectionTitle('계정 관리'),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFFEE2E2),
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  _showDeleteAccountDialog();
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEE2E2),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.delete_outline,
                                          color: Color(0xFFEF4444),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '계정 삭제',
                                              style: TextStyle(
                                                color: Color(0xFFEF4444),
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              '모든 데이터가 영구적으로 삭제됩니다',
                                              style: TextStyle(
                                                color: Color(0xFFFCA5A5),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right,
                                        color: Color(0xFFFCA5A5),
                                        size: 24,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInputCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool obscureText = false,
    bool enabled = true,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            obscureText: obscureText,
            enabled: enabled,
            keyboardType: keyboardType,
            validator: validator,
            textAlignVertical: TextAlignVertical.center,
            style: TextStyle(
              color: enabled
                  ? const Color(0xFF1F2937)
                  : const Color(0xFF9CA3AF),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: InputBorder.none,
              suffixIcon: suffixIcon,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Divider(height: 1, color: Color(0xFFF3F4F6)),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '계정 삭제',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark
                ?  Colors.white
                : Color(0xFF1F2937) ,
          ),
        ),
        content: const Text(
          '정말로 계정을 삭제하시겠습니까?\n삭제된 계정은 복구할 수 없습니다.',
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '취소',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              // TODO: Implement account deletion
              Navigator.of(context).pop(); // 다이얼로그 닫기

              setState(() => _isLoading = true);

              final result = await ApiService.deleteAccount();

              if (!mounted) return;

              setState(() => _isLoading = false);

              if (result['success'] == true) {

                await Supabase.instance.client.auth.signOut();

              } else {
                CommonToast.show(
                  context,
                  result['message'] ?? '계정 삭제 실패',
                );
              }
            },
            child: const Text(
              '삭제',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
