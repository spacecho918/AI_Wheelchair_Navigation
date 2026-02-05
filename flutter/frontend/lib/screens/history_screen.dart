import 'package:flutter/material.dart';
import 'package:gilbeot/widgets/custom_back_button.dart';
import '../services/api_service.dart';
import '../models/driving_history.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Colors
  final Color primaryGreen = const Color(0xFF00C853);
  final Color textDark = const Color(0xFF101727);
  final Color textGrey = const Color(0xFF4A5565);
  final Color bgLight = const Color(0xFFF5F6F8);

  // State
  int _selectedFilterIndex = 0;
  final List<String> _filters = ['이번 주', '이번 달', '전체'];
  bool _isLoading = true;
  List<DrivingHistory> _historyItems = [];

  // Dummy Data for fallback or if API fails
  /*
  final List<Map<String, dynamic>> _dummyHistory = [
    {
      'date': '1월 1일',
      'time': '14:30',
      'start': '강남역',
      'end': '서울대학교병원',
      'distance': '8.5km',
      'duration': '25분',
    },
    // ...
  ];
  */

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await ApiService.getUserHistory();
    setState(() {
      _historyItems = history;
      _isLoading = false;
    });
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
                    '주행 기록',
                    style: TextStyle(
                      color: Color(0xFF354152),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: const Color(0xFFF0F2F5)),

            // 1. Filter Tabs (Now Fixed)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: List.generate(_filters.length, (index) {
                  final isSelected = _selectedFilterIndex == index;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedFilterIndex = index;
                        });
                      },
                      child: Container(
                        margin: EdgeInsets.only(
                          right: index == _filters.length - 1 ? 0 : 8,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? primaryGreen : Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: isSelected
                                ? primaryGreen
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _filters[index],
                          style: TextStyle(
                            color: isSelected ? Colors.white : textGrey,
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            const Divider(height: 1, thickness: 1, color: Color(0xFFF0F2F5)),
            const SizedBox(height: 20),

            // 2. Summary Cards
            // TODO: Calculate real stats from _historyItems
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildSummaryCard(
                    '총 이동 거리',
                    '${_historyItems.fold(0.0, (sum, item) => sum + item.distance).toStringAsFixed(1)}km',
                    '이번 주',
                    Icons.route_outlined,
                    isGreenIcon: true,
                  ),
                  const SizedBox(width: 6),
                  _buildSummaryCard(
                    '주행 횟수',
                    '${_historyItems.length}회',
                    '이번 주',
                    Icons.trending_up_rounded,
                    isGreenIcon: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 3. Recent History Label
                    Padding(
                      padding: const EdgeInsets.only(left: 24, bottom: 12),
                      child: Text(
                        '최근 주행',
                        style: TextStyle(
                          color: textDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),

                    // 4. History List
                    ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: _historyItems.length,
                      itemBuilder: (context, index) {
                        return _buildHistoryCard(_historyItems[index]);
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    String subLabel,
    IconData icon, {
    bool isGreenIcon = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            // Shadow 1
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              spreadRadius: -1,
              offset: const Offset(0, 4),
            ),
            // Shadow 2
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              spreadRadius: -1,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: const Color(0xFFF0F2F5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: textGrey,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Icon(
                  icon,
                  color: isGreenIcon ? primaryGreen : textGrey,
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              value,
              style: TextStyle(
                color: textDark,
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subLabel,
              style: TextStyle(
                color: textGrey,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(DrivingHistory item) {
    // Format Date: "1월 1일"
    final dateStr = '${item.date.month}월 ${item.date.day}일';
    // Format Time: "14:30"
    final timeStr =
        '${item.date.hour.toString().padLeft(2, '0')}:${item.date.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, // Same as summary cards
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          // Shadow 1
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            spreadRadius: -1,
            offset: const Offset(0, 4),
          ),
          // Shadow 2
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            spreadRadius: -1,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFF0F2F5)),
      ),
      child: Column(
        children: [
          // Header: Date & Time
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 14, color: textGrey),
              const SizedBox(width: 6),
              Text(
                '$dateStr • $timeStr',
                style: TextStyle(
                  color: textGrey,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Route Info
          Stack(
            children: [
              // Vertical Line
              Positioned(
                top: 10,
                bottom: 15,
                left:
                    7.5, // Center of 16px width is 8. Line width 1. Left = 7.5
                child: Container(width: 1, color: Colors.grey[300]),
              ),
              Column(
                children: [
                  // Start Location
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        child: Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: primaryGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.startLocation,
                          style: TextStyle(
                            color: textDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // End Location
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        child: Center(
                          child: Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: const Color(0xFFFF5252),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.endLocation,
                          style: TextStyle(
                            color: textDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Footer: Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.route, size: 14, color: textGrey),
              const SizedBox(width: 4),
              Text(
                '${item.distance}km',
                style: TextStyle(
                  color: textGrey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.access_time, size: 14, color: textGrey),
              const SizedBox(width: 4),
              Text(
                '${item.duration}분',
                style: TextStyle(
                  color: textGrey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
