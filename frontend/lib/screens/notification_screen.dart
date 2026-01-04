import 'package:flutter/material.dart';
import '../widgets/custom_back_button.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // Dummy Data
  List<Map<String, dynamic>> notifications = [
    {
      'id': 1,
      'title': '새로운 장애물 제보',
      'description': '강남역 2번 출구 근처에 새로운 장애물이 제보되었습니다.',
      'time': '10분 전',
      'type': 'warning', // warning, location, like, info
      'isRead': false,
      'hasAction': true,
    },
    {
      'id': 2,
      'title': '경로 업데이트',
      'description': '자주 이용하시는 경로에 더 안전한 대체 경로가 추가되었습니다.',
      'time': '2시간 전',
      'type': 'location',
      'isRead': false,
      'hasAction': true,
    },
    {
      'id': 3,
      'title': '커뮤니티 반응',
      'description': '회사 근처 장애물 제보에 5명이 공감했습니다.',
      'time': '5시간 전',
      'type': 'like',
      'isRead': true,
      'hasAction': false,
    },
    {
      'id': 4,
      'title': '시스템 공지',
      'description': '길벗 앱이 v1.0.2로 업데이트되었습니다. 새로운 기능을 확인해보세요!',
      'time': '1일 전',
      'type': 'info',
      'isRead': true,
      'hasAction': false,
    },
    {
      'id': 5,
      'title': '장애물 제거 확인',
      'description': '서울대학교병원 앞 제보하신 장애물이 제거되었습니다.',
      'time': '2일 전',
      'type': 'warning',
      'isRead': true,
      'hasAction': false,
    },
  ];

  void _markAllAsRead() {
    setState(() {
      for (var notification in notifications) {
        notification['isRead'] = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: CustomBackButton(),
                  ),
                  const Text(
                    '알림',
                    style: TextStyle(
                      color: Color(0xFF101727),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _markAllAsRead,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        '모두 읽음',
                        style: TextStyle(
                          color: Color(0xFF00C853),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(color: const Color(0xFFE5E7EB), height: 1.0),

            // List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final item = notifications[index];
                  return _buildNotificationItem(item);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> item) {
    final bool isRead = item['isRead'];
    final Color bgColor = isRead
        ? Colors.white
        : const Color(0xFFF0FDF4); // Light Green if unread

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isRead ? const Color(0xFFF3F4F6) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: isRead
                  ? null
                  : Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Icon(
              _getIcon(item['type']),
              size: 20,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item['title'],
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (!isRead) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00C853),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      item['time'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item['description'],
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280), // Grey 500
                    height: 1.4,
                  ),
                ),
                if (item['hasAction'] == true && !isRead) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      '자세히 보기 →',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00C853),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'location':
        return Icons.place_outlined;
      case 'like':
        return Icons.thumb_up_alt_outlined;
      case 'info':
        return Icons.info_outline;
      default:
        return Icons.notifications_none;
    }
  }
}
