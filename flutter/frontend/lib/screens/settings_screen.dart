import 'package:flutter/material.dart';
import 'package:gilbeot/widgets/custom_back_button.dart';
import 'profile_edit_screen.dart';
import 'notification_settings_screen.dart';
import 'terms_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Colors - 다른 화면들과 통일
  final Color primaryGreen = const Color(0xFF00C853);
  final Color textDark = const Color(0xFF101727);
  final Color textGrey = const Color(0xFF4A5565);
  final Color bgLight = Colors.white;

  // Theme mode state
  String _selectedTheme = 'system'; // 'light', 'dark', 'system'

  @override
  Widget build(BuildContext context) {
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
                    '설정',
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. 개인정보 수정
                        _buildSectionTitle('계정'),
                        const SizedBox(height: 12),
                        _buildSettingsCard([
                          _buildSettingsItem(
                            icon: Icons.person_outline,
                            title: '개인정보 수정',
                            subtitle: '닉네임, 비밀번호 변경',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ProfileEditScreen(),
                                ),
                              );
                            },
                          ),
                        ]),

                        const SizedBox(height: 24),

                        // 2. 알림 설정
                        _buildSectionTitle('알림'),
                        const SizedBox(height: 12),
                        _buildSettingsCard([
                          _buildSettingsItem(
                            icon: Icons.notifications_none_outlined,
                            title: '알림 수신 설정',
                            subtitle: '이메일, 푸시 알림 관리',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const NotificationSettingsScreen(),
                                ),
                              );
                            },
                          ),
                        ]),

                        const SizedBox(height: 24),

                        // 3. 테마 설정
                        _buildSectionTitle('화면'),
                        const SizedBox(height: 12),
                        _buildThemeCard(),

                        const SizedBox(height: 24),

                        // 4. 이용약관
                        _buildSectionTitle('정보'),
                        const SizedBox(height: 12),
                        _buildSettingsCard([
                          _buildSettingsItem(
                            icon: Icons.description_outlined,
                            title: '이용약관',
                            subtitle: '서비스 이용약관 확인',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const TermsScreen(),
                                ),
                              );
                            },
                          ),
                          _buildDivider(),
                          _buildSettingsItem(
                            icon: Icons.privacy_tip_outlined,
                            title: '개인정보 처리방침',
                            subtitle: '개인정보 수집 및 이용 안내',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const TermsScreen(isPrivacyPolicy: true),
                                ),
                              );
                            },
                          ),
                          _buildDivider(),
                          _buildSettingsItem(
                            icon: Icons.info_outline,
                            title: '앱 정보',
                            subtitle: '버전 1.0.0',
                            showArrow: false,
                            onTap: () {},
                          ),
                        ]),

                        const SizedBox(height: 40),
                      ],
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
        style: TextStyle(
          color: textGrey,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
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

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showArrow = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: textDark, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (showArrow)
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFFD1D5DB),
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Divider(height: 1, color: Color(0xFFF3F4F6)),
    );
  }

  Widget _buildThemeCard() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.palette_outlined,
                  color: Color(0xFF374151),
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                '테마',
                style: TextStyle(
                  color: Color(0xFF101727),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildThemeOption(
                icon: Icons.light_mode_outlined,
                label: '라이트',
                value: 'light',
              ),
              const SizedBox(width: 12),
              _buildThemeOption(
                icon: Icons.dark_mode_outlined,
                label: '다크',
                value: 'dark',
              ),
              const SizedBox(width: 12),
              _buildThemeOption(
                icon: Icons.settings_suggest_outlined,
                label: '시스템',
                value: 'system',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final isSelected = _selectedTheme == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTheme = value;
          });
          // TODO: Actually apply theme
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? primaryGreen : const Color(0xFFE5E7EB),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              if (!isSelected)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? primaryGreen : textGrey, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? primaryGreen : textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
