import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import '../screens/login_screen.dart';
import '../screens/wheelchair_settings_screen.dart';
import '../screens/community_screen.dart';
import '../screens/my_reports_screen.dart';
import '../screens/notification_screen.dart';
import '../screens/history_screen.dart';
import '../screens/saved_places_screen.dart';
import '../screens/settings_screen.dart';
import '../services/auth_service.dart';
import '../services/recent_searches_service.dart';

class SideDrawer extends StatefulWidget {
  const SideDrawer({super.key});

  @override
  State<SideDrawer> createState() => _SideDrawerState();
}

class _SideDrawerState extends State<SideDrawer> {
  // 색상 상수 (디자인에 맞춘 색상)
  final Color primaryGreen = const Color(0xFF00C853);
  final Color textDark = const Color(0xFF354152);
  final Color textGrey = const Color(0xFF99A1AE);

  User? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = await ApiService.getUserProfile();
    if (mounted) {
      setState(() {
        _userProfile = user;
      });
    }
  }

  String _getWheelchairDisplayText(String? type) {
    switch (type) {
      case 'electric':
        return '전동 휠체어';
      case 'manual':
        return '수동 휠체어';
      case 'manual_with_helper':
        return '보호자 동반';
      case 'none':
        return '사용 안함';
      default:
        return '휠체어 설정';
    }
  }

  Widget _getWheelchairIcon(String? type, Color color) {
    switch (type) {
      case 'Electric':
      case 'Manual':
        return SvgPicture.asset(
          'assets/wheelchair_icon.svg',
          width: 16,
          height: 16,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        );
      case 'CaregiverManual':
        return Icon(Icons.person, size: 16, color: color);
      case 'None':
        return Image.asset('assets/x.png', width: 14, height: 14, color: color);
      default:
        return SvgPicture.asset(
          'assets/wheelchair_icon.svg',
          width: 16,
          height: 16,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: Drawer(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).cardColor
            : Colors.white,
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
                      onTap: () {
                        Navigator.pop(context); // Close drawer
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SavedPlacesScreen(),
                          ),
                        );
                      },
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

          // 프로필 이미지 (_userProfile은 비동기 로드되므로 null일 수 있음)
          Builder(
            builder: (context) {
              final profileImageUrl = _userProfile?.profileImage;
              final hasImage = profileImageUrl != null && profileImageUrl.isNotEmpty;
              final nickname = _userProfile?.nickname ?? '사용자';
              final initial = nickname.isNotEmpty ? nickname[0].toUpperCase() : '?';
              return CircleAvatar(
                radius: 30,
                backgroundColor: hasImage ? Colors.white : Colors.grey.shade300,
                backgroundImage: hasImage ? NetworkImage(profileImageUrl!) : null,
                child: hasImage
                    ? null
                    : Text(
                        initial,
                        style: TextStyle(
                          color: textDark,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              );
            },
          ),
          const SizedBox(height: 14),

          // 이름
          Text(
            _userProfile?.nickname ?? '사용자',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
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
                ).then((_) => _loadUserProfile()); // Refresh on return
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
                    _getWheelchairIcon(
                      _userProfile?.wheelchairType,
                      primaryGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getWheelchairDisplayText(_userProfile?.wheelchairType),
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
              // Level logic can be added later, static for now or based on driveCount?
              const Text(
                '레벨 1',
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
              Text(
                '${_userProfile?.reportCount ?? 0}건의 제보',
                style: const TextStyle(color: Colors.white, fontSize: 13),
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
        colorFilter: ColorFilter.mode(Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            :textDark, BlendMode.srcIn),
      ),
      title: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : textDark,
          fontSize: 14,
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
          _buildFooterItem(Icons.settings_outlined, '설정', () {
            Navigator.pop(context); // Close drawer
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          }, false),
          _buildFooterItem(Icons.logout, '로그아웃', () async {
            await AuthService.signOut();
            RecentSearchesService.reload();
            if (!context.mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }, true), // isLogout = true for red color
          const SizedBox(height: 20),
          Text(
            'Gilbeot v1.0.0',
            style: TextStyle(color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : textGrey, fontSize: 11),
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
    final Color defaultColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF495565);
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
