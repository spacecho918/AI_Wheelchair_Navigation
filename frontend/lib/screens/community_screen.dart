import 'package:flutter/material.dart';
import 'community_detail_screen.dart';
import 'package:gilbeot/widgets/custom_back_button.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  // Colors
  final Color primaryGreen = const Color(0xFF00C853);
  final Color textDark = const Color(0xFF354152);
  final Color textGrey = const Color(0xFF99A1AE);
  final Color backgroundLightGreen = const Color(
    0xFFE8F5E9,
  ); // Light green background

  // State
  final List<String> filters = ['전체', '높은 턱', '좁은 통로', '계단'];
  String selectedFilter = '전체';
  bool isFilterVisible = false;
  String sortOption = 'latest'; // 'latest' or 'popular'

  // Dummy Data for Reports
  final List<Map<String, dynamic>> reports = [
    {
      'id': 1,
      'user': 'Sarah Kim',
      'time': '2시간 전',
      'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
      'address': '서울시 강남구 역삼동 123-45',
      'content': '카페 입구에 15cm 높이의 턱이 있어 휠체어 진입이 어렵습니다.',
      'likes': 12,
      'dislikes': 1,
      'comments': 1,
      'tag': '높은 턱',
    },
    {
      'id': 2,
      'user': 'Mike Lee',
      'time': '5시간 전',
      'timestamp': DateTime.now().subtract(const Duration(hours: 5)),
      'address': '서울시 강남구 삼성동 567-89',
      'content': '지하철 출구에서 버스 정류장까지 통로가 좁아서 휠체어 통행이 불가능합니다.',
      'likes': 8,
      'dislikes': 0,
      'comments': 0,
      'tag': '좁은 통로',
    },
    {
      'id': 3,
      'user': 'Linda Choi',
      'time': '1일 전',
      'timestamp': DateTime.now().subtract(const Duration(days: 1)),
      'address': '서울시 서초구 서초동 789-12',
      'content': '건물 입구에 계단만 있고 경사로가 없습니다.',
      'likes': 15,
      'dislikes': 2,
      'comments': 2,
      'tag': '계단',
    },
    {
      'id': 4,
      'user': 'James Han',
      'time': '30분 전',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 30)),
      'address': '서울시 강남구 논현동 111-22',
      'content': '장애인 화장실 문이 고장나서 열리지 않습니다.',
      'likes': 2,
      'dislikes': 0,
      'comments': 0,
      'tag': '좁은 통로', // Categorizing roughly
    },
  ];

  List<Map<String, dynamic>> getFilteredAndSortedReports() {
    // 1. Filter
    List<Map<String, dynamic>> filtered = reports.where((report) {
      if (selectedFilter == '전체') return true;
      return report['tag'] == selectedFilter;
    }).toList();

    // 2. Sort
    filtered.sort((a, b) {
      if (sortOption == 'latest') {
        return b['timestamp'].compareTo(a['timestamp']);
      } else {
        return b['likes'].compareTo(a['likes']);
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final displayReports = getFilteredAndSortedReports();

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
                  Column(
                    mainAxisSize: MainAxisSize.min,
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
                        '지역 내 장애물 정보 공유',
                        style: TextStyle(
                          color: textGrey,
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: Icon(
                        isFilterVisible
                            ? Icons.filter_list_off
                            : Icons.filter_list,
                        color: textDark,
                      ),
                      onPressed: () {
                        setState(() {
                          isFilterVisible = !isFilterVisible;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            Container(color: Colors.grey.shade200, height: 1.0),

            // 1. Filter Chips (Collapsible)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: isFilterVisible ? 60 : 0,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: filters.map((filter) {
                    final isSelected = selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(
                        right: 8,
                        top: 10,
                        bottom: 10,
                      ), // Adjust padding for vertical center
                      child: ChoiceChip(
                        label: Text(
                          filter,
                          style: TextStyle(
                            color: isSelected ? Colors.white : textDark,
                            fontSize: 14,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: primaryGreen,
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? primaryGreen
                                : Colors.grey.shade300,
                          ),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            selectedFilter = filter;
                          });
                        },
                        showCheckmark: false,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // 2. Sort Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    spreadRadius: 2,
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          sortOption = 'latest';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: sortOption == 'latest'
                              ? primaryGreen
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.access_time,
                                color: sortOption == 'latest'
                                    ? Colors.white
                                    : const Color(0xFF6B7280),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '최신순',
                                style: TextStyle(
                                  color: sortOption == 'latest'
                                      ? Colors.white
                                      : const Color(0xFF6B7280),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          sortOption = 'popular';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: sortOption == 'popular'
                              ? primaryGreen
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.trending_up,
                                color: sortOption == 'popular'
                                    ? Colors.white
                                    : const Color(0xFF6B7280),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '인기순',
                                style: TextStyle(
                                  color: sortOption == 'popular'
                                      ? Colors.white
                                      : const Color(0xFF6B7280),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Report List
            Expanded(
              child: Container(
                color: backgroundLightGreen, // Changed background color
                child: displayReports.isEmpty
                    ? Center(
                        child: Text(
                          '해당하는 제보가 없습니다.',
                          style: TextStyle(color: textGrey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: displayReports.length,
                        itemBuilder: (context, index) {
                          final report = displayReports[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CommunityDetailScreen(report: report),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    spreadRadius: 0,
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Tag
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryGreen,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      report['tag'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Placeholder for Map/Image area
                                  Container(
                                    height: 120,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE5E7EB),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // User Info
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.grey.shade200,
                                        radius: 14,
                                        child: Text(
                                          report['user'][0],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: textDark,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            report['user'],
                                            style: TextStyle(
                                              color: textDark,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            report['time'], // You might want to format timestamp if needed, but 'time' string works
                                            style: TextStyle(
                                              color: textGrey,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Location
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined,
                                        size: 14,
                                        color: primaryGreen,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        report['address'],
                                        style: TextStyle(
                                          color: textGrey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Content
                                  Text(
                                    report['content'],
                                    style: TextStyle(
                                      color: textDark,
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 12),

                                  // Footer
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.thumb_up_outlined,
                                        size: 16,
                                        color: textGrey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${report['likes']}',
                                        style: TextStyle(
                                          color: textGrey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.thumb_down_outlined,
                                        size: 16,
                                        color: textGrey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${report['dislikes']}',
                                        style: TextStyle(
                                          color: textGrey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        Icons.chat_bubble_outline,
                                        size: 16,
                                        color: textGrey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${report['comments']}',
                                        style: TextStyle(
                                          color: textGrey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(
                                        Icons.keyboard_arrow_down,
                                        size: 16,
                                        color: textGrey,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
