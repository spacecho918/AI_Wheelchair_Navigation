import 'package:flutter/material.dart';
import 'package:gilbeot/screens/map_screen.dart';
import 'package:gilbeot/screens/camera_screen.dart';

class NavigationEndScreen extends StatefulWidget {
  final String routeType;
  final String estimatedTime;
  final String totalDistance;

  const NavigationEndScreen({
    super.key,
    required this.routeType,
    required this.estimatedTime,
    required this.totalDistance,
  });

  @override
  State<NavigationEndScreen> createState() => _NavigationEndScreenState();
}

class _NavigationEndScreenState extends State<NavigationEndScreen> {
  // Feedback State
  bool? _isGood; // true: Good, false: Bad, null: None
  final TextEditingController _feedbackController = TextEditingController();

  // Report State
  bool? _hasObstacle; // true: Yes, false: No, null: None

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9), // Light Green Background
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // 1. Completion Icon & Title
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF00C853),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '목적지 도착!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF101727),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '수고하셨습니다 \u{1F389}', // Party popper
                    style: TextStyle(fontSize: 14, color: Color(0xFF4A5565)),
                  ),
                  const SizedBox(height: 32),

                  // 2. Trip Summary Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '도착지',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9EA6B8),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Hardcoded for now, or could pass in
                                const Text(
                                  '강남역 2번 출구',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF101727),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00C853),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                widget.routeType,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoItem(
                                icon: Icons.directions_walk,
                                label: '이동거리',
                                value: widget.totalDistance,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInfoItem(
                                icon: Icons.access_time,
                                label: '소요시간',
                                value: widget.estimatedTime,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoItem(
                                icon: Icons.warning_amber_rounded,
                                label: '장애물 회피',
                                value: '3개', // Mock
                                highlightValue: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInfoItem(
                                icon: Icons.location_on_outlined,
                                label: '경사로 이용',
                                value: '2개', // Mock
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Feedback Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '오늘 이용한 경로가 어땠나요?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF101727),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSelectButton(
                                label: '편해요',
                                isSelected: _isGood == true,
                                activeColorOverride: const Color(
                                  0xFF00C853,
                                ), // Green
                                onTap: () => setState(() => _isGood = true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSelectButton(
                                label: '힘들어요',
                                isSelected: _isGood == false,
                                isNegative: true, // Red accent
                                onTap: () => setState(() => _isGood = false),
                              ),
                            ),
                          ],
                        ),
                        // Expandable Input Area
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            height: (_isGood == false) ? null : 0,
                            margin: EdgeInsets.only(
                              top: (_isGood == false) ? 20 : 0,
                            ),
                            child: (_isGood == false)
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF5F5),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFFFEBEE),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              '어떤 점이 불편하셨나요?',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF2D3748),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            TextField(
                                              controller: _feedbackController,
                                              maxLines: 3,
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                              decoration: InputDecoration(
                                                hintText:
                                                    '불편했던 점을 자세히 알려주시면 더 나은 경로를 제공하는 데 도움이 됩니다.',
                                                hintStyle: TextStyle(
                                                  color: Colors.grey[400],
                                                  fontSize: 13,
                                                ),
                                                filled: true,
                                                fillColor: Colors.white,
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  borderSide: BorderSide(
                                                    color: Colors.grey[300]!,
                                                  ),
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      borderSide: BorderSide(
                                                        color:
                                                            Colors.grey[300]!,
                                                      ),
                                                    ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      borderSide:
                                                          const BorderSide(
                                                            color: Color(
                                                              0xFFFF5252,
                                                            ),
                                                          ),
                                                    ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 14,
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                '0/200자',
                                                style: TextStyle(
                                                  color: Colors.grey[500],
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. Report Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '지도에 없던 장애물이 있었나요?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF101727),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSelectButton(
                                label: '예',
                                isSelected: _hasObstacle == true,
                                isNegative:
                                    true, // Orange/Red feeling for "Warning"
                                activeColorOverride: const Color(
                                  0xFFFF9800,
                                ), // Orange for Yes
                                onTap: () =>
                                    setState(() => _hasObstacle = true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSelectButton(
                                label: '아니요',
                                isSelected: _hasObstacle == false,
                                activeColorOverride: const Color(
                                  0xFF00C853,
                                ), // Green
                                onTap: () =>
                                    setState(() => _hasObstacle = false),
                              ),
                            ),
                          ],
                        ),
                        // Expandable Report Button
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            height: (_hasObstacle == true) ? null : 0,
                            margin: EdgeInsets.only(
                              top: (_hasObstacle == true) ? 20 : 0,
                            ),
                            child: (_hasObstacle == true)
                                ? Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFFFF3E0,
                                      ), // Light Orange
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFFFE0B2),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        const Text(
                                          '다른 사용자를 위해 장애물을 신고해주세요',
                                          style: TextStyle(
                                            color: Color(0xFF5D4037),
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 44,
                                          child: OutlinedButton(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      const CameraScreen(
                                                        fromNavigationEnd: true,
                                                      ),
                                                ),
                                              );
                                            },
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(
                                                color: Color(0xFFFF9800),
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              backgroundColor: Colors.white,
                                            ),
                                            child: const Text(
                                              '장애물 신고하기',
                                              style: TextStyle(
                                                color: Color(0xFFFF9800),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 5. Done Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MapScreen(),
                          ),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '완료',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    bool highlightValue = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA), // Very light grey
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF9EA6B8)),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF4A5565)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: highlightValue
                  ? const Color(0xFFFF9800)
                  : const Color(0xFF101727),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isNegative = false,
    Color? activeColorOverride,
  }) {
    final activeColor =
        activeColorOverride ??
        (isNegative ? const Color(0xFFFF5252) : const Color(0xFF101727));
    final borderColor = isSelected
        ? activeColor
        : const Color(0xFFE2E8F0); // Grey 200

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1.0),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : const Color(0xFF4A5565),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
