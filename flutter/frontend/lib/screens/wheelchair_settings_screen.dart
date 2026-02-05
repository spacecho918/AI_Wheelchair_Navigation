import 'package:flutter/material.dart';
import 'package:gilbeot/widgets/custom_back_button.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';

class WheelchairSettingsScreen extends StatefulWidget {
  const WheelchairSettingsScreen({super.key});

  @override
  State<WheelchairSettingsScreen> createState() =>
      _WheelchairSettingsScreenState();
}

class _WheelchairSettingsScreenState extends State<WheelchairSettingsScreen> {
  // Default selection
  String _selectedType =
      'Electric'; // 'Electric', 'Manual', 'CaregiverManual', 'None'
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWheelchairType();
  }

  Future<void> _loadWheelchairType() async {
    final user = await ApiService.getUserProfile();
    if (user != null) {
      setState(() {
        _selectedType = user.wheelchairType;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveWheelchairType() async {
    final success = await ApiService.updateWheelchairType(_selectedType);
    if (success) {
      if (mounted) Navigator.pop(context);
    } else {
      // Show error snackbar?
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('설정에 실패했습니다')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            // Custom Header
            // Custom Header
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
                    '휠체어 설정',
                    style: TextStyle(
                      color: Color(0xFF354152), // Community Screen Header Color
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _saveWheelchairType,
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
                      child: const Text('저장'),
                    ),
                  ),
                ],
              ),
            ),
            Container(color: const Color(0xFFF0F2F5), height: 1.0),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10), // reduced top padding
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
                      style: TextStyle(fontSize: 13, color: Color(0xFF4A5565)),
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
                      iconPath: 'assets/wheelchair_icon.svg',
                      iconWidth: 28,
                    ),
                    const SizedBox(height: 12),
                    _buildOptionCard(
                      type: 'CaregiverManual',
                      title: '보호자 동반 수동 휠체어',
                      subtitle: '보호자와 함께 수동 휠체어를 사용합니다',
                      iconData: Icons.person,
                      iconWidth: 34,
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
                        ).withOpacity(0.5), // Light blue
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
                          _buildInfoItem('보호자 동반 수동: 보호자의 도움으로 이동 가능한 경로 추천'),
                          const SizedBox(height: 4),
                          _buildInfoItem('사용 안함: 일반 보행자 경로 추천'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
    String? iconPath,
    IconData? iconData,
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
                color: Colors.black.withOpacity(0.05),
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
              child: iconData != null
                  ? Icon(
                      iconData,
                      size: iconWidth ?? 28,
                      color: isSelected
                          ? const Color(0xFF00C853)
                          : const Color(0xFF4A5565),
                    )
                  : (iconPath != null && iconPath.endsWith('.svg'))
                  ? SvgPicture.asset(
                      iconPath,
                      width: iconWidth ?? 28,
                      colorFilter: ColorFilter.mode(
                        isSelected
                            ? const Color(0xFF00C853)
                            : const Color(0xFF4A5565),
                        BlendMode.srcIn,
                      ),
                    )
                  : Image.asset(
                      iconPath!,
                      width:
                          iconWidth ??
                          (isXIcon
                              ? 22
                              : 28), // X icon might need size adjustment
                      color: isSelected
                          ? const Color(0xFF00C853)
                          : const Color(0xFF4A5565), // Green or Dark Grey
                    ),
            ),
            const SizedBox(
              width: 16,
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
                      color: const Color(0xFF4A5565),
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
