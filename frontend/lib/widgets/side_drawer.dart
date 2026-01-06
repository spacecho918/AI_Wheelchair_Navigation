import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../screens/login_screen.dart';
import '../screens/wheelchair_settings_screen.dart';
import '../screens/community_screen.dart';
import '../screens/my_reports_screen.dart';
import '../screens/notification_screen.dart';
import '../screens/history_screen.dart';

class SideDrawer extends StatelessWidget {
  const SideDrawer({super.key});

  // 색상 상수 (디자인에 맞춘 색상)
  final Color primaryGreen = const Color(0xFF00C853);
  final Color textDark = const Color(0xFF354152);
  final Color textGrey = const Color(0xFF99A1AE);

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: Drawer(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: SafeArea(
          // 상하단 시스템 영역 침범 방지
          child: Column(
            children: [
              // 1. 상단 녹색 헤더 영역 (고정)
              _buildHeader(context),

              // 2. 메뉴 리스트 영역 (유연하게 늘어남)
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  children: [
                    _buildMenuItem(
                      iconPath: 'assets/document_icon.svg',
                      text: '나의 제보',
                      onTap: () {
                        Navigator.pop(context); // Close drawer
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MyReportsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 7),
                    _buildMenuItem(
                      iconPath: 'assets/bookmark_icon.svg',
                      text: '저장된 장소',
                      onTap: () {},
                    ),
                    const SizedBox(height: 7),
                    _buildMenuItem(
                      iconPath: 'assets/clock_icon.svg',
                      text: '주행 기록',
                      onTap: () {
                        Navigator.pop(context); // Close drawer
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HistoryScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 7),
                    _buildMenuItem(
                      iconPath: 'assets/community_icon.svg', // New Icon
                      text: '제보 커뮤니티',
                      onTap: () {
                        Navigator.pop(context); // Close drawer first
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CommunityScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 7),
                    _buildMenuItem(
                      iconPath: 'assets/bell_icon.svg', // New Icon
                      text: '공지사항',
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              // 3. 하단 푸터 (고정)
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  // 헤더 위젯
  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        24,
        20,
        24,
        20,
      ), // 패딩을 20 -> 24로 늘려 여유 확보
      decoration: BoxDecoration(color: primaryGreen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 버튼 Row (알림 + 닫기)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 알림 아이콘 (뱃지 포함)
              GestureDetector(
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationScreen(),
                    ),
                  );
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.notifications_none_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF3B30), // Red badge color
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // 닫기 버튼
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 24),
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    // Fallback
                  }
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 프로필 이미지
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 14),

          // 이름
          const Text(
            '김사라',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              fontFamily: 'Arial',
            ),
          ),
          const SizedBox(height: 10),

          // 휠체어 정보 칩
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WheelchairSettingsScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      'assets/wheelchair_icon.svg',
                      width: 16,
                      height: 16,
                      colorFilter: ColorFilter.mode(
                        primaryGreen,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '전동 휠체어',
                      style: TextStyle(
                        color: primaryGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 통계 정보
          Row(
            children: [
              SvgPicture.asset(
                'assets/graph_icon.svg',
                width: 14,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                '레벨 3',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('•', style: TextStyle(color: Colors.white60)),
              ),
              SvgPicture.asset(
                'assets/document_icon.svg',
                width: 14,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                '15건의 제보',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 메뉴 아이템 빌더
  Widget _buildMenuItem({
    required String iconPath,
    required String text,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 8,
      ), // 하단 Footer Item과 동일하게 8로 변경
      minLeadingWidth: 20, // 하단 Footer Item과 동일하게 20으로 변경
      leading: SvgPicture.asset(
        iconPath,
        width: 20,
        height: 20,
        colorFilter: ColorFilter.mode(textDark, BlendMode.srcIn),
      ),
      title: Text(
        text,
        style: TextStyle(
          color: textDark,
          fontSize: 14,
          fontFamily: 'Arial',
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  // 하단 푸터 빌더
  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        children: [
          _buildFooterItem(Icons.settings_outlined, '설정', () {}, false),
          _buildFooterItem(Icons.logout, '로그아웃', () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }, true), // isLogout = true for red color
          const SizedBox(height: 20),
          Text(
            'Gilbeot v1.0.0',
            style: TextStyle(color: textGrey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterItem(
    IconData icon,
    String text,
    VoidCallback onTap, [
    bool isLogout = false,
  ]) {
    return _FooterItem(
      icon: icon,
      text: text,
      onTap: onTap,
      isLogout: isLogout,
    );
  }
}

class _FooterItem extends StatefulWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool isLogout;

  const _FooterItem({
    required this.icon,
    required this.text,
    required this.onTap,
    this.isLogout = false,
  });

  @override
  State<_FooterItem> createState() => _FooterItemState();
}

class _FooterItemState extends State<_FooterItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final Color defaultColor = const Color(0xFF495565);
    // 로그아웃이면서 눌렸을 때만 빨간색
    final Color activeColor = widget.isLogout && _isPressed
        ? const Color(0xFFFF3B30)
        : defaultColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (value) {
          if (widget.isLogout) {
            setState(() {
              _isPressed = value;
            });
          }
        },
        splashColor: widget.isLogout
            ? const Color(0xFFFF3B30).withValues(alpha: 0.2)
            : null,
        highlightColor: widget.isLogout
            ? const Color(0xFFFF3B30).withValues(alpha: 0.1)
            : null,
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          minLeadingWidth: 20,
          leading: Icon(widget.icon, size: 20, color: activeColor),
          title: Text(
            widget.text,
            style: TextStyle(
              color: activeColor,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
