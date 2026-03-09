import 'package:flutter/material.dart';
import 'package:gilbeot/services/api_service.dart';
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
  final Color textDark = const Color(0xFF101727);
  final Color textGrey = const Color(0xFF9EA6B8);
  final Color backgroundLightGreen = const Color(
    0xFFE8F5E9,
  ); // Light green background

  // State
  final List<String> filters = [
    '전체',
    '높은 턱',
    '좁은 통로',
    '계단',
    '라바콘',
    '볼라드',
    '경사로',
    '턱',
  ];
  /// 선택된 필터들 (빈 집합이거나 '전체' 포함 시 전체 표시)
  Set<String> selectedFilters = {'전체'};
  bool isFilterVisible = false;
  String sortOption = 'latest'; // 'latest' or 'popular'

  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    final data = await ApiService.getCommunityReports();
    if (mounted) {
      setState(() {
        _reports = data;
        _isLoading = false;
      });
    }
  }

  String _formatTimeAgo(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays}일 전';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}시간 전';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}분 전';
      } else {
        return '방금 전';
      }
    } catch (e) {
      return '알 수 없음';
    }
  }

  /// 게시물의 tag 문자열을 태그 목록으로 변환 (쉼표 구분, 공백 제거)
  List<String> _parseTags(dynamic tagValue) {
    if (tagValue == null) return [];
    final s = tagValue.toString().trim();
    if (s.isEmpty) return [];
    return s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  List<Map<String, dynamic>> getFilteredAndSortedReports() {
    // 1. Filter
    final showAll = selectedFilters.isEmpty || selectedFilters.contains('전체');
    List<Map<String, dynamic>> filtered = _reports.where((report) {
      if (showAll) return true;
      final reportTags = _parseTags(report['tag']);
      // 선택된 필터 중 하나라도 게시물 태그에 있으면 표시 (OR)
      return reportTags.any((tag) => selectedFilters.contains(tag));
    }).toList();

    // 2. Sort
    filtered.sort((a, b) {
      if (sortOption == 'latest') {
        final tA = a['timestamp'].toString();
        final tB = b['timestamp'].toString();
        return tB.compareTo(tA);
      } else {
        return (b['likes'] as num).compareTo(a['likes'] as num);
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final displayReports = getFilteredAndSortedReports();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            // Custom Header
            Container(
              height: 56,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).cardColor
                  : Colors.white,
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
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : textDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '지역 내 장애물 정보 공유',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF9CA3AF)
                              : Color(0xFF4A5565),
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
                            ? Icons.filter_alt_off
                            : Icons.filter_alt_outlined,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : textDark,
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
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).cardColor
                    : Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFF5F7FA))),
              ),
              child: Column(
                children: [
                  // 1. Filter Chips (Collapsible)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: isFilterVisible ? 60 : 0,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: filters.map((filter) {
                          final isSelected = selectedFilters.contains(filter);
                          return Padding(
                            padding: const EdgeInsets.only(
                              right: 8,
                              top: 10,
                              bottom: 10,
                            ),
                            child: ChoiceChip(
                              label: Text(
                                filter,
                                style: TextStyle(
                                  color: isSelected
                                      ?Colors.white
                                      : Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF9CA3AF) // 다크모드
                                      : const Color(0xFF4A5565),
                                  fontSize: 14,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: primaryGreen,
                              backgroundColor: Theme.of(context).brightness == Brightness.dark
                                  ? Theme.of(context).cardColor
                                  : Colors.white,
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
                                  if (filter == '전체') {
                                    selectedFilters = selected ? {'전체'} : {};
                                  } else {
                                    if (selected) {
                                      selectedFilters = Set.from(selectedFilters)
                                        ..remove('전체')
                                        ..add(filter);
                                    } else {
                                      selectedFilters = Set.from(selectedFilters)
                                        ..remove(filter);
                                    }
                                    if (selectedFilters.isEmpty) {
                                      selectedFilters = {'전체'};
                                    }
                                  }
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
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF2A2A2A)
                          : Colors.white,
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
                                            : const Color(0xFF9EA6B8),
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
                                            : const Color(0xFF9EA6B8),
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
                  const SizedBox(height: 6), // Bottom padding for the section
                ],
              ),
            ),

            // 3. Report List
            Expanded(
              child: Container(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).scaffoldBackgroundColor
                    : const Color(0xFFF5F7FA), // Changed background color
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: primaryGreen),
                      )
                    : displayReports.isEmpty
                    ? Center(
                        child: Text(
                          '해당하는 제보가 없습니다.',
                          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF9CA3AF)
                              : textGrey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: displayReports.length,
                        itemBuilder: (context, index) {
                          final report = displayReports[index];
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 600),
                              child: GestureDetector(
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          CommunityDetailScreen(report: report),
                                    ),
                                  );
                                  // 상세 화면에서 좋아요/싫어요 변경 후 돌아오면 즉시 반영
                                  if (result != null && result is Map && mounted) {
                                    setState(() {
                                      report['likes'] = result['likeCount'];
                                      report['dislikes'] = result['dislikeCount'];
                                    });
                                  }
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Theme.of(context).cardColor
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.03,
                                        ),
                                        spreadRadius: 0,
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Tag
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: primaryGreen,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
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

                                      // Image area
                                      if (report['imageUrl'] != null &&
                                          report['imageUrl']
                                              .toString()
                                              .isNotEmpty)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.network(
                                            report['imageUrl']
                                                    .toString()
                                                    .startsWith('http')
                                                ? report['imageUrl']
                                                : '${ApiService.baseUrl}${report['imageUrl']}',
                                            height: 150,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return Container(
                                                    height: 120,
                                                    width: double.infinity,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFFE5E7EB,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: const Icon(
                                                      Icons.image_not_supported,
                                                      color: Colors.grey,
                                                    ),
                                                  );
                                                },
                                          ),
                                        )
                                      else
                                        Container(
                                          height: 120,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE5E7EB),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.photo,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      const SizedBox(height: 12),

                                      // User Info
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor:
                                                Colors.grey.shade200,
                                            radius: 14,
                                            backgroundImage: report['user_avatar_url'] != null &&
                                                    (report['user_avatar_url'] as String).isNotEmpty
                                                ? NetworkImage(report['user_avatar_url'] as String)
                                                : null,
                                            child: report['user_avatar_url'] == null ||
                                                    (report['user_avatar_url'] as String).isEmpty
                                                ? Text(
                                                    (report['user'] as String).isNotEmpty
                                                        ? (report['user'] as String)[0]
                                                        : '?',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: textDark,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 8),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                report['user'],
                                                style: TextStyle(
                                                  color: Theme.of(context).brightness == Brightness.dark
                                                      ? Colors.white
                                                      : textDark,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                _formatTimeAgo(report['time']),
                                                style: TextStyle(
                                                  color: Theme.of(context).brightness == Brightness.dark
                                                      ? const Color(0xFF9CA3AF)
                                                      : textGrey,
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
                                              color: Theme.of(context).brightness == Brightness.dark
                                                  ? const Color(0xFF9CA3AF)
                                                  : Color(0xFF4A5565),
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
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? Colors.white
                                              : textDark,
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
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? const Color(0xFF9CA3AF)
                                                : textGrey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${report['likes']}',
                                            style: TextStyle(
                                              color: Theme.of(context).brightness == Brightness.dark
                                                  ? const Color(0xFF9CA3AF)
                                                  : textGrey,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Icon(
                                            Icons.thumb_down_outlined,
                                            size: 16,
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? const Color(0xFF9CA3AF)
                                                : textGrey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${report['dislikes']}',
                                            style: TextStyle(
                                              color: Theme.of(context).brightness == Brightness.dark
                                                  ? const Color(0xFF9CA3AF)
                                                  : textGrey,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const Spacer(),
                                          Icon(
                                            Icons.chat_bubble_outline,
                                            size: 16,
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? const Color(0xFF9CA3AF)
                                                : textGrey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${report['comments']}',
                                            style: TextStyle(
                                              color: Theme.of(context).brightness == Brightness.dark
                                                  ? const Color(0xFF9CA3AF)
                                                  : textGrey,
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
