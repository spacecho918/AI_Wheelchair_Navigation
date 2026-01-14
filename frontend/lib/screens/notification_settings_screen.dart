import 'package:flutter/material.dart';
import 'package:gilbeot/widgets/custom_back_button.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  // Colors - 다른 화면들과 통일
  final Color primaryGreen = const Color(0xFF00C853);
  final Color textDark = const Color(0xFF101727);
  final Color textGrey = const Color(0xFF4A5565);

  // Notification settings state
  bool _pushEnabled = true;
  bool _emailEnabled = true;
  bool _communityPush = true;
  bool _reportStatusPush = true;
  bool _routeAlertPush = true;
  bool _marketingEmail = false;

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
                    '알림 수신 설정',
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
                        // Push Notifications Section
                        _buildSectionTitle('푸시 알림'),
                        const SizedBox(height: 12),
                        _buildSettingsCard([
                          _buildToggleItem(
                            icon: Icons.notifications_active_outlined,
                            title: '푸시 알림',
                            subtitle: '앱 푸시 알림 수신',
                            value: _pushEnabled,
                            onChanged: (value) {
                              setState(() {
                                _pushEnabled = value;
                                if (!value) {
                                  _communityPush = false;
                                  _reportStatusPush = false;
                                  _routeAlertPush = false;
                                }
                              });
                            },
                          ),
                        ]),

                        if (_pushEnabled) ...[
                          const SizedBox(height: 12),
                          _buildSettingsCard([
                            _buildToggleItem(
                              icon: Icons.forum_outlined,
                              title: '커뮤니티 알림',
                              subtitle: '댓글, 좋아요 알림 수신',
                              value: _communityPush,
                              onChanged: (value) {
                                setState(() {
                                  _communityPush = value;
                                });
                              },
                            ),
                            _buildDivider(),
                            _buildToggleItem(
                              icon: Icons.fact_check_outlined,
                              title: '제보 상태 알림',
                              subtitle: '내 제보 처리 상태 알림',
                              value: _reportStatusPush,
                              onChanged: (value) {
                                setState(() {
                                  _reportStatusPush = value;
                                });
                              },
                            ),
                            _buildDivider(),
                            _buildToggleItem(
                              icon: Icons.warning_amber_outlined,
                              title: '경로 안내 알림',
                              subtitle: '장애물 정보, 우회 경로 안내',
                              value: _routeAlertPush,
                              onChanged: (value) {
                                setState(() {
                                  _routeAlertPush = value;
                                });
                              },
                            ),
                          ]),
                        ],

                        const SizedBox(height: 24),

                        // Email Notifications Section
                        _buildSectionTitle('이메일 알림'),
                        const SizedBox(height: 12),
                        _buildSettingsCard([
                          _buildToggleItem(
                            icon: Icons.email_outlined,
                            title: '이메일 알림',
                            subtitle: '이메일로 알림 수신',
                            value: _emailEnabled,
                            onChanged: (value) {
                              setState(() {
                                _emailEnabled = value;
                                if (!value) {
                                  _marketingEmail = false;
                                }
                              });
                            },
                          ),
                        ]),

                        if (_emailEnabled) ...[
                          const SizedBox(height: 12),
                          _buildSettingsCard([
                            _buildToggleItem(
                              icon: Icons.campaign_outlined,
                              title: '마케팅 정보 수신',
                              subtitle: '이벤트, 프로모션 정보 수신',
                              value: _marketingEmail,
                              onChanged: (value) {
                                setState(() {
                                  _marketingEmail = value;
                                });
                              },
                            ),
                          ]),
                        ],

                        const SizedBox(height: 24),

                        // Info Box
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F9FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBAE6FD)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Color(0xFF0284C7),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      '알림 설정 안내',
                                      style: TextStyle(
                                        color: Color(0xFF0369A1),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '기기 설정에서 알림이 꺼져있으면 푸시 알림이 오지 않을 수 있습니다.',
                                      style: TextStyle(
                                        color: Color(0xFF0369A1),
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

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

  Widget _buildToggleItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: value ? const Color(0xFFE8F5E9) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: value ? primaryGreen : const Color(0xFF9CA3AF),
              size: 22,
            ),
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
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: primaryGreen,
            activeTrackColor: const Color(0xFFB9F6CA),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFE5E7EB),
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
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
}
