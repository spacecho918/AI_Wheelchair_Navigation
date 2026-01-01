import 'package:flutter/material.dart';

class WheelchairSettingsScreen extends StatefulWidget {
  const WheelchairSettingsScreen({super.key});

  @override
  State<WheelchairSettingsScreen> createState() =>
      _WheelchairSettingsScreenState();
}

class _WheelchairSettingsScreenState extends State<WheelchairSettingsScreen> {
  // Default selection
  String _selectedType = 'Electric'; // 'Electric', 'Manual', 'None'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Header with Save Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left: Back Button + Title
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '휠체어 설정',
                        style: TextStyle(
                          color: Color(0xFF101727),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),

                  // Right: Save Button
                  ElevatedButton(
                    onPressed: () {
                      // Save logic here
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      minimumSize: const Size(64, 32),
                    ),
                    child: const Text(
                      '저장',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),
              const Text(
                '사용하시는 휠체어 타입을 선택하세요',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF101727),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '더 정확한 경로 추천을 위해 필요합니다',
                style: TextStyle(fontSize: 13, color: Color(0xFF697282)),
              ),
              const SizedBox(height: 24),

              // Options
              _buildOptionCard(
                type: 'Electric',
                title: '전동 휠체어',
                subtitle: '전동 휠체어를 사용합니다',
                iconPath: 'assets/electiric.png',
              ),
              const SizedBox(height: 12),
              _buildOptionCard(
                type: 'Manual',
                title: '수동 휠체어',
                subtitle: '수동 휠체어를 사용합니다',
                iconPath: 'assets/wheelchair.png',
                iconWidth: 34,
                iconAlignment: const Alignment(0, -1.2), // Move up slightly
              ),
              const SizedBox(height: 12),
              _buildOptionCard(
                type: 'None',
                title: '사용 안함',
                subtitle: '휠체어를 사용하지 않습니다',
                iconPath: 'assets/x.png',
                isXIcon: true,
                iconWidth: 26,
              ),

              const SizedBox(height: 32),

              // Info Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFFE3F2FD,
                  ).withValues(alpha: 0.5), // Light blue
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBBDEFB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          color: Color(0xFF1976D2),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: const Text(
                            '알림: 휠체어 타입에 따라 다른 경로가 추천됩니다',
                            style: TextStyle(
                              color: Color(0xFF1565C0),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem('전동: 경사로와 엘리베이터를 우선적으로 고려'),
                    const SizedBox(height: 4),
                    _buildInfoItem('수동: 가장 평평하고 쉬운 경로 추천'),
                    const SizedBox(height: 4),
                    _buildInfoItem('사용 안함: 일반 보행자 경로 추천'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4), // slightly indent
      child: Text(
        '• $text', // Bullet point manually or use Row with circle
        style: const TextStyle(
          color: Color(0xFF1565C0),
          fontSize: 12, // Small text
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required String type,
    required String title,
    required String subtitle,
    required String iconPath,
    bool isXIcon = false,
    double? iconWidth,
    AlignmentGeometry? iconAlignment,
  }) {
    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00C853)
                : const Color(0xFFE5E7EB), // Green if selected, else light grey
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            if (!isSelected) // Slight shadow for unselected to look like card
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40, // Adjust size
              height: 40,
              alignment: iconAlignment ?? Alignment.center,
              child: Image.asset(
                iconPath,
                width:
                    iconWidth ??
                    (isXIcon ? 22 : 28), // X icon might need size adjustment
                color: isSelected
                    ? const Color(0xFF00C853)
                    : const Color(0xFF495565), // Green or Dark Grey
              ),
            ), // Or specific coloring per icon? Image shows Flash is Yellow/Orange when active?
            // Actually image shows:
            // Electric: Flash icon is Yellow/Orange.
            // Manual: Wheelchair icon is Grey.
            // None: X icon is Dark Grey.
            // And checkmark is Green.
            // Let's try to match that better.
            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? const Color(0xFF00C853)
                          : const Color(0xFF101727),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF697282),
                    ),
                  ),
                ],
              ),
            ),

            if (isSelected)
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF00C853),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }
}
