import 'package:flutter/material.dart';
import 'community_detail_screen.dart';
import 'package:gilbeot/widgets/custom_back_button.dart';
import 'package:gilbeot/widgets/common_toast.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import '../models/report_summary.dart';

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

  bool _isLoading = true;
  List<ReportSummary> _reports = [];
  List<ReportSummary> _comments = [];
  User? _userProfile;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await ApiService.getUserProfile();
    final reports = await ApiService.getUserReports();
    final comments = await ApiService.getUserComments();

    if (mounted) {
      setState(() {
        _userProfile = user;
        _reports = reports;
        _comments = comments;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Navigation Helper
  Future<void> _deleteReport(ReportSummary report) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('제보 삭제'),
        content: const Text(
          '이 제보를 삭제하시겠습니까? 삭제된 내용은 복구할 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('취소', style: TextStyle(color: textGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('삭제', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await ApiService.deleteReport(report.id);
    if (!mounted) return;
    if (ok) {
      CommonToast.show(context, '제보가 삭제되었습니다.');
      _loadData();
    } else {
      CommonToast.show(context, '삭제에 실패했습니다. 다시 시도해 주세요.');
    }
  }

  void _navigateToDetail(Map<String, dynamic> item, {bool isComment = false}) {
    // Construct a full report object compatible with CommunityDetailScreen
    final fullReport = {
      'id': item['id'],
      'user': item['user'],
      'time': item['time'],
      'timestamp': item['date'], // Using DateTime object
      'address': item['location'],
      'content': isComment
          ? (item['commentContent'] ??
                item['content']) // Use comment content if available
          : item['content'], // Use actual report content
      'likes': item['likes'],
      'dislikes': item['dislikes'] ?? 0,
      'comments': item['comments'] ?? 0,
      'tag': item['title'], // Map title to tag
      'commentContent': isComment ? item['content'] : null,
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
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bgLight,
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
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: CustomBackButton(),
                  ),
                  Text(
                    '나의 제보',
                    style: TextStyle(
                      color: Color(0xFF354152),
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
                  _buildStatItem('${_reports.length}', '작성한 글'),
                  _buildDivider(),
                  _buildStatItem('${_comments.length}', '작성한 댓글'),
                  _buildDivider(),
                  _buildStatItem(
                    '${_reports.fold(0, (sum, item) => sum + item.likeCount)}',
                    '총 좋아요',
                    color: primaryGreen,
                  ),
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
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.description_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text('작성한 글'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 18),
                        const SizedBox(width: 8),
                        Text('작성한 댓글'),
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
    if (_reports.isEmpty) {
      return const Center(child: Text('작성한 제보가 없습니다.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final report = _reports[index];

        // Create a map for navigation
        final reportMap = {
          'id': report.id,
          'user': _userProfile?.nickname ?? '나',
          'time': '${report.date.month}월 ${report.date.day}일',
          'address': report.location,
          'location': report.location,
          'title': report.title,
          'content': report.content,
          'likes': report.likeCount,
          'dislikes': report.dislikeCount,
          'comments': report.commentCount,
          'status': report.status,
          'date': report.date,
        };

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: GestureDetector(
              onTap: () => _navigateToDetail(reportMap),
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
                    // Tag + 삭제 버튼
                    Row(
                      children: [
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
                            report.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.delete_outline, size: 22, color: textGrey),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          onPressed: () => _deleteReport(report),
                          tooltip: '삭제',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Image area
                    if (report.imageUrl != null && report.imageUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          report.imageUrl!.startsWith('http')
                              ? report.imageUrl!
                              : 'http://localhost:8000${report.imageUrl}',
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 120,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5E7EB),
                                borderRadius: BorderRadius.circular(8),
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
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.photo, color: Colors.grey),
                      ),
                    const SizedBox(height: 12),

                    // User Info
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.grey.shade200,
                          radius: 14,
                          child: Text(
                            (_userProfile?.nickname ?? '나')[0],
                            style: TextStyle(fontSize: 12, color: textDark),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userProfile?.nickname ?? '나',
                              style: TextStyle(
                                color: textDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${report.date.month}월 ${report.date.day}일',
                              style: TextStyle(color: textGrey, fontSize: 10),
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
                        Expanded(
                          child: Text(
                            report.location,
                            style: TextStyle(
                              color: const Color(0xFF4A5565),
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Content
                    Text(
                      report.content,
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
                          '${report.likeCount}',
                          style: TextStyle(color: textGrey, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.thumb_down_outlined,
                          size: 16,
                          color: textGrey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${report.dislikeCount}',
                          style: TextStyle(color: textGrey, fontSize: 12),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 16,
                          color: textGrey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${report.commentCount}',
                          style: TextStyle(color: textGrey, fontSize: 12),
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

  Widget _buildCommentList() {
    if (_comments.isEmpty) {
      return const Center(child: Text('작성한 댓글이 없습니다.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _comments.length,
      itemBuilder: (context, index) {
        final comment = _comments[index];

        final commentMap = {
          'id': comment.id,
          'user': _userProfile?.nickname ?? '나',
          'time': '${comment.date.month}월 ${comment.date.day}일',
          'address': comment.location,
          'location': comment.location,
          'title': comment.title,
          'content': comment.content,
          'likes': comment.likeCount,
          'dislikes': comment.dislikeCount,
          'comments': comment.commentCount,
          'status': comment.status,
          'date': comment.date,
        };

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: GestureDetector(
              onTap: () => _navigateToDetail(commentMap, isComment: true),
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
                                comment.title,
                                style: TextStyle(
                                  color: textDark,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                comment.location,
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
                      comment.content,
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
                          '${comment.date.month}월 ${comment.date.day}일',
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
                              '${comment.likeCount}',
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
