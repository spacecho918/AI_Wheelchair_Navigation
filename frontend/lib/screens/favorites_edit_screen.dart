import 'package:flutter/material.dart';
import 'package:gilbeot/screens/location_search_screen.dart';
import 'package:gilbeot/widgets/custom_back_button.dart';

class FavoritesEditScreen extends StatefulWidget {
  final String homeAddress;
  final String workAddress;
  final String workLabel; // '회사' or '학교'

  const FavoritesEditScreen({
    super.key,
    required this.homeAddress,
    required this.workAddress,
    required this.workLabel,
  });

  @override
  State<FavoritesEditScreen> createState() => _FavoritesEditScreenState();
}

class _FavoritesEditScreenState extends State<FavoritesEditScreen> {
  late String _homeAddress;
  late String _workAddress;
  late String _workLabel;

  @override
  void initState() {
    super.initState();
    _homeAddress = widget.homeAddress;
    _workAddress = widget.workAddress;
    _workLabel = widget.workLabel;
  }

  void _saveAndExit() {
    Navigator.pop(context, {
      'homeAddress': _homeAddress,
      'workAddress': _workAddress,
      'workLabel': _workLabel,
    });
  }

  void _toggleWorkLabel() {
    // Optional: Allow toggling label if user wants to change 'Company' <-> 'School'
    // For now, let's just cycle or show a selector if needed.
    // Given the previous requirement "Company/School swap", let's make it a simple toggle or action sheet.
    // Or we can just let 'Edit' on the card handle it?
    // The reference image has a list of cards. I'll implement a simple tap to edit or distinct buttons.
    setState(() {
      _workLabel = (_workLabel == '회사') ? '학교' : '회사';
    });
  }

  @override
  Widget build(BuildContext context) {
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
                    '즐겨찾기 편집',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _saveAndExit,
                      child: const Text(
                        '완료',
                        style: TextStyle(
                          color: Color(0xFF00C853),
                          fontSize: 15,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(color: const Color(0xFFE5E7EB), height: 1.0),

            // List Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  const Text(
                    '즐겨찾기',
                    style: TextStyle(fontSize: 14, color: Color(0xFF697282)),
                  ),
                  const Spacer(),
                  Text(
                    '2개', // Fixed for now as we have Home + Work
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF697282),
                    ),
                  ),
                ],
              ),
            ),

            // List Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildFavoriteCard(
                    title: '집',
                    address: _homeAddress,
                    onEdit: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LocationSearchScreen(),
                        ),
                      );
                      if (result != null && result is Map) {
                        setState(() {
                          _homeAddress = result['address'];
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildFavoriteCard(
                    title: _workLabel,
                    address: _workAddress,
                    onEdit: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LocationSearchScreen(),
                        ),
                      );
                      if (result != null && result is Map) {
                        setState(() {
                          _workAddress = result['address'];
                        });
                      }
                    },
                    onLabelTap: _toggleWorkLabel,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteCard({
    required String title,
    required String address,
    required VoidCallback onEdit,
    VoidCallback? onLabelTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon Circle
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF9C4), // Light Yellow
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.star,
              color: Color(0xFFFBC02D), // Yellow
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          // Text Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onLabelTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF101727),
                        ),
                      ),
                      if (onLabelTap != null) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.swap_horiz,
                          size: 14,
                          color: Colors.grey,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  address.isEmpty ? '주소를 등록해주세요' : address,
                  style: TextStyle(
                    fontSize: 13,
                    color: address.isEmpty
                        ? Colors.grey[400]
                        : const Color(0xFF697282),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Edit Button (Pencil)
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, color: Color(0xFF9EA6B8)),
          ),
        ],
      ),
    );
  }
}
