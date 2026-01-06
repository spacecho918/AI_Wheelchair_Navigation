import 'package:flutter/material.dart';
import 'community_detail_screen.dart';
import 'package:gilbeot/widgets/custom_back_button.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final Color primaryGreen = const Color(0xFF00C853);
  final Color textDark = const Color(0xFF101727);
  final Color textGrey = const Color(0xFF4A5565);
  final Color bgLight = Colors.white;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Navigation Helper
  void _navigateToDetail(Map<String, dynamic> item, {bool isComment = false}) {
    // Construct a full dummy report object compatible with CommunityDetailScreen
    final fullReport = {
      'id': 999, // Dummy ID
      'user': '김사라', // Current user
      'time': item['date'],
      'timestamp': DateTime.now(), // Dummy timestamp
      'address': item['location'],
      'content': isComment
          ? '이 제보글에 대한 원본 내용입니다.' // Placeholder for original report content if clicking a comment
          : '제보한 내용입니다. ${item['title']}', // Placeholder
      'likes': item['likes'],
      'dislikes': 0,
      'comments': item['comments'] ?? 0,
      'tag': item['title'], // Using title as tag for now or we can map it
      'commentContent': isComment
          ? item['content']
          : null, // Pass comment content if needed
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommunityDetailScreen(report: fullReport),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
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
                  Text(
                    '나의 제보',
                    style: TextStyle(
                      color: Color(0xFF354152), // Community Screen Header Color
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(color: const Color(0xFFF0F2F5), height: 1.0),

            // 1. Stats Section
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                children: [
                  _buildStatItem('3', '작성한 글'),
                  _buildDivider(),
                  _buildStatItem('4', '작성한 댓글'),
                  _buildDivider(),
                  _buildStatItem('25', '총 좋아요', color: primaryGreen),
                ],
              ),
            ),

            // 2. Tab Bar
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: textDark,
                unselectedLabelColor: textGrey,
                indicatorColor: primaryGreen,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.description_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('작성한 글 3'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 18),
                        SizedBox(width: 8),
                        Text('작성한 댓글 4'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3. Content List
            Expanded(
              child: Container(
                color: bgLight,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Written Posts Tab
                    _buildReportList(),
                    // Written Comments Tab
                    _buildCommentList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String count, String label, {Color? color}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              color: color ?? textDark,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: textGrey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 40, color: Colors.grey.shade200);
  }

  Widget _buildReportList() {
    final reports = [
      {
        'title': '경사로 파손',
        'location': '강남역 2번 출구',
        'date': '1월 1일',
        'status': '확인됨',
        'statusColor': const Color(0xFF00C853), // Green
        'statusBg': const Color(0xFFE8F5E9), // Light Green
        'comments': 8,
        'likes': 12,
      },
      {
        'title': '보도블럭 파손',
        'location': '서초대로 인도',
        'date': '12월 30일',
        'status': '해결됨',
        'statusColor': const Color(0xFF2979FF), // Blue
        'statusBg': const Color(0xFFE3F2FD), // Light Blue
        'comments': 5,
        'likes': 8,
      },
      {
        'title': '엘리베이터 고장',
        'location': '서울대학교병원',
        'date': '12월 28일',
        'status': '검토중',
        'statusColor': const Color(0xFFFF9100), // Orange
        'statusBg': const Color(0xFFFFF3E0), // Light Orange
        'comments': 3,
        'likes': 5,
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                    spreadRadius: -1,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    spreadRadius: -1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _navigateToDetail(report),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              report['title'] as String,
                              style: TextStyle(
                                color: textDark,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: report['statusBg'] as Color,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: report['statusColor'] as Color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    report['status'] as String,
                                    style: TextStyle(
                                      color: report['statusColor'] as Color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          report['location'] as String,
                          style: TextStyle(
                            color: Color(0xFF9EA6B8),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          report['date'] as String,
                          style: TextStyle(
                            color: Color(0xFF9EA6B8),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 14,
                              color: textGrey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${report['comments']}',
                              style: TextStyle(
                                color: Color(0xFF9EA6B8),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.thumb_up_outlined,
                              size: 14,
                              color: textGrey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${report['likes']}',
                              style: TextStyle(
                                color: Color(0xFF9EA6B8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentList() {
    final comments = [
      {
        'title': '경사로 파손',
        'location': '강남역 2번 출구',
        'content': '저도 어제 이곳을 지나다가 같은 문제를 발견했습니다. 빠른 조치가 필요할 것 같아요.',
        'date': '12월 31일',
        'likes': 4,
      },
      {
        'title': '보도블록 파손',
        'location': '여의도역 3번 출구',
        'content': '감사합니다. 이 정보 덕분에 다른 경로를 이용할 수 있었어요.',
        'date': '12월 29일',
        'likes': 2,
      },
      {
        'title': '인도 공사',
        'location': '신촌역 앞',
        'content': '현재는 공사가 완료되어 정상적으로 이용 가능합니다.',
        'date': '12월 27일',
        'likes': 6,
      },
      {
        'title': '엘리베이터 고장',
        'location': '코엑스몰',
        'content': '관리사무소에 문의해보니 내일 수리 예정이라고 합니다.',
        'date': '12월 25일',
        'likes': 3,
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final comment = comments[index];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: GestureDetector(
              onTap: () => _navigateToDetail(comment, isComment: true),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                      spreadRadius: -1,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      spreadRadius: -1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.description_outlined,
                            color: primaryGreen,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                comment['title'] as String,
                                style: TextStyle(
                                  color: textDark,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                comment['location'] as String,
                                style: TextStyle(
                                  color: Color(0xFF9EA6B8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      comment['content'] as String,
                      style: TextStyle(
                        color: textDark,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          comment['date'] as String,
                          style: TextStyle(color: textGrey, fontSize: 12),
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.thumb_up_outlined,
                              size: 14,
                              color: textGrey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${comment['likes']}',
                              style: TextStyle(
                                color: Color(0xFF9EA6B8),
                                fontSize: 12,
                              ),
                            ),
                          ],
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
    );
  }
}
