import 'package:flutter/material.dart';

import 'package:gilbeot/widgets/custom_back_button.dart';

class CommunityDetailScreen extends StatefulWidget {
  final Map<String, dynamic> report;

  const CommunityDetailScreen({super.key, required this.report});

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  final Color primaryGreen = const Color(0xFF00C853);
  final Color textDark = const Color(0xFF101727);
  final Color textGrey = const Color(0xFF9EA6B8);
  final TextEditingController _commentController = TextEditingController();

  int likeCount = 0;
  int dislikeCount = 0;
  bool isLiked = false;
  bool isDisliked = false;

  @override
  void initState() {
    super.initState();
    likeCount = widget.report['likes'] ?? 0;
    dislikeCount = widget.report['dislikes'] ?? 0;
  }

  void _toggleLike() {
    setState(() {
      if (isLiked) {
        likeCount--;
        isLiked = false;
      } else {
        likeCount++;
        isLiked = true;
        if (isDisliked) {
          dislikeCount--;
          isDisliked = false;
        }
      }
    });
  }

  void _toggleDislike() {
    setState(() {
      if (isDisliked) {
        dislikeCount--;
        isDisliked = false;
      } else {
        dislikeCount++;
        isDisliked = true;
        if (isLiked) {
          likeCount--;
          isLiked = false;
        }
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Back Button
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: CustomBackButton(),
                  ),
                  // Title
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '제보 커뮤니티',
                        style: TextStyle(
                          color: textDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '상세 정보',
                        style: TextStyle(
                          color: Color(0xFF4A5565),
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  // Close Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      color: textDark,
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ),
            Container(color: const Color(0xFFF0F2F5), height: 1.0),

            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Map/Image Placeholder
                      Stack(
                        children: [
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: primaryGreen,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                widget.report['tag'] ?? '태그',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 2. User Info
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.grey.shade200,
                            radius: 20,
                            child: Text(
                              widget.report['user'][0],
                              style: TextStyle(fontSize: 16, color: textDark),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.report['user'],
                                style: TextStyle(
                                  color: textDark,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                widget.report['time'],
                                style: TextStyle(color: textGrey, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 3. Address
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 20,
                            color: primaryGreen,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.report['address'],
                            style: TextStyle(
                              color: Color(0xFF4A5565),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      // Coordinates placeholder (Not in dummy data but in design)
                      Padding(
                        padding: const EdgeInsets.only(left: 28),
                        child: Text(
                          '37.566500, 126.978000',
                          style: TextStyle(color: textGrey, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 4. Content
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFF9FAFB,
                          ), // Very light grey bg for text
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.report['content'],
                          style: TextStyle(
                            color: textDark,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 5. Like/Dislike Buttons
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _toggleLike,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isLiked
                                      ? primaryGreen.withValues(alpha: 0.1)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isLiked
                                        ? primaryGreen
                                        : Colors.grey.shade200,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.02,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isLiked
                                          ? Icons.thumb_up
                                          : Icons.thumb_up_outlined,
                                      size: 18,
                                      color: isLiked ? primaryGreen : textDark,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$likeCount',
                                      style: TextStyle(
                                        color: isLiked
                                            ? primaryGreen
                                            : textDark,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: _toggleDislike,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isDisliked
                                      ? Colors.red.withValues(alpha: 0.1)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDisliked
                                        ? Colors.red
                                        : Colors.grey.shade200,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.02,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isDisliked
                                          ? Icons.thumb_down
                                          : Icons.thumb_down_outlined,
                                      size: 18,
                                      color: isDisliked ? Colors.red : textDark,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$dislikeCount',
                                      style: TextStyle(
                                        color: isDisliked
                                            ? Colors.red
                                            : textDark,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 6. Edit Request Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: textDark,
                          ),
                          label: Text(
                            '수정 요청',
                            style: TextStyle(color: textDark),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 7. Comments Section
                      Text(
                        '댓글 (${widget.report['comments']})',
                        style: TextStyle(
                          color: textDark,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Input Field
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: TextField(
                                controller: _commentController,
                                decoration: const InputDecoration(
                                  hintText: '댓글을 입력하세요...',
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 48,
                            width: 48,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF6EE7B7,
                              ), // Light green send button
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: () {},
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Single Comment Example (John Park)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.yellow.shade100,
                              radius: 16,
                              child: const Text(
                                '😵‍💫',
                                style: TextStyle(fontSize: 16),
                              ), // Text emoji as generic avatar replacement
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'John Park',
                                        style: TextStyle(
                                          color: textDark,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        '1시간 전',
                                        style: TextStyle(
                                          color: textGrey,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '정보 감사합니다. 이 곳은 피해가야겠네요.',
                                    style: TextStyle(
                                      color: textDark,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
