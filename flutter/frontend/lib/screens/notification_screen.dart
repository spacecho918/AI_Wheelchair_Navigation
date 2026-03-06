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
      'id': 6,
      'title': '장애물 상태 확인',
      'description': '일주일 전 제보하신 장애물이 아직 존재하나요?',
      'time': '방금 전',
      'type': 'feedback',
      'isRead': false,
      'location': '강남역 2번 출구',
      'obstacleId': 'obs_123',
      'feedbackSubmitted': false,
    },
    {
      'id': 1,
      'title': '새로운 장애물 제보',
      'description': '강남역 2번 출구 근처에 새로운 장애물이 제보되었습니다.',
      'time': '10분 전',
      'type': 'warning',
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
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).scaffoldBackgroundColor
          : Colors.white,
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
                  Text(
                    '알림',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : const Color(0xFF354152),
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
            Container(color: const Color(0xFFF0F2F5), height: 1.0),

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
        ? Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF9CA3AF)
        : Colors.white
        : const Color(0xFFF0FDF4); // Light Green if unread

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isRead
                  ? Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2A2A2A)
                  : const Color(0xFFF3F4F6)
                  : Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).cardColor
                  : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: isRead
                  ? null
                  : Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Icon(
              _getIcon(item['type']),
              size: 20,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFE5E7EB)
                  : const Color(0xFF6B7280),
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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFF111827),
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
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF4B5563)
                        : const Color(0xFF6B7280), // Grey 500
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
                // Feedback type notification with action buttons
                if (item['type'] == 'feedback' &&
                    item['feedbackSubmitted'] != true) ...[
                  if (item['location'] != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.place,
                          size: 14,
                          color: Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item['location'],
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildFeedbackButton(
                        label: '여전히 있음',
                        color: const Color(0xFFEF4444),
                        onTap: () => _submitFeedback(item, 'still_exists'),
                      ),
                      const SizedBox(width: 8),
                      _buildFeedbackButton(
                        label: '해결됨',
                        color: const Color(0xFF00C853),
                        onTap: () => _submitFeedback(item, 'resolved'),
                      ),
                      const SizedBox(width: 8),
                      _buildFeedbackButton(
                        label: '모름',
                        color: const Color(0xFF6B7280),
                        onTap: () => _submitFeedback(item, 'unknown'),
                      ),
                    ],
                  ),
                ],
                if (item['type'] == 'feedback' &&
                    item['feedbackSubmitted'] == true) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '피드백을 제출해주셔서 감사합니다!',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF00C853),
                      fontWeight: FontWeight.w500,
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
      case 'feedback':
        return Icons.help_outline_rounded;
      default:
        return Icons.notifications_none;
    }
  }

  void _submitFeedback(Map<String, dynamic> item, String status) {
    setState(() {
      item['feedbackSubmitted'] = true;
      item['feedbackStatus'] = status;
      item['isRead'] = true;
    });
    // TODO: Send feedback to backend
    debugPrint('Feedback submitted: ${item['obstacleId']} -> $status');
  }

  Widget _buildFeedbackButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
