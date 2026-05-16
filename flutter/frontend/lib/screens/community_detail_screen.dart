import 'package:flutter/material.dart';

import 'package:gilbeot/widgets/custom_back_button.dart';
import 'package:gilbeot/widgets/common_toast.dart';
import 'package:gilbeot/screens/report_edit_screen.dart';
import 'package:gilbeot/services/api_service.dart';
import 'package:gilbeot/services/auth_service.dart';
import 'package:gilbeot/utils/time_format.dart';

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

  List<Map<String, dynamic>> comments = [];
  bool isLoadingComments = false;

  bool _isAdmin = false;
  /// 관리자가 본문 수정 후 목록과 맞추기 위한 표시용 (원문 description 파싱 결과)
  String? _displayContentOverride;
  String? _displayAddressOverride;

  bool get _isOwnReport {
    final reportedBy = widget.report['reported_by']?.toString();
    final me = AuthService.currentUser?.id;
    return reportedBy != null && me != null && reportedBy == me;
  }

  @override
  void initState() {
    super.initState();
    likeCount = widget.report['likes'] ?? 0;
    dislikeCount = widget.report['dislikes'] ?? 0;
    _fetchComments();
    _loadMyReaction();
    _loadAdminFlag();
  }

  Future<void> _loadAdminFlag() async {
    final v = await ApiService.isCurrentUserAdmin();
    if (mounted) setState(() => _isAdmin = v);
  }

  void _applyRawDescriptionToDisplayOverrides(String raw) {
    var content = raw;
    var address = widget.report['address']?.toString() ?? '위치 정보 없음';
    final locMatch = RegExp(r'\[Location: (.*?)\]').firstMatch(raw);
    if (locMatch != null) {
      address = locMatch.group(1)!;
      content = raw.replaceAll(locMatch.group(0)!, '').trim();
    }
    final userMatch = RegExp(r'\[User: (.*?)\]').firstMatch(content);
    if (userMatch != null) {
      content = content.replaceAll(userMatch.group(0)!, '').trim();
    }
    setState(() {
      _displayAddressOverride = address;
      _displayContentOverride = content;
    });
  }

  Future<void> _adminDeleteReport() async {
    final id = widget.report['id']?.toString();
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('제보 삭제 (관리자)'),
        content: const Text('이 제보를 삭제하시겠습니까? 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final success = await ApiService.deleteReport(id);
    if (!mounted) return;
    if (success) {
      CommonToast.show(context, '삭제되었습니다.');
      Navigator.pop(context, {
        'likeCount': likeCount,
        'dislikeCount': dislikeCount,
        'isLiked': isLiked,
        'isDisliked': isDisliked,
        'deleted': true,
      });
    } else {
      CommonToast.show(context, '삭제에 실패했습니다.');
    }
  }

  Future<void> _adminEditDescription() async {
    final id = widget.report['id']?.toString();
    if (id == null) return;
    final raw = await ApiService.getObstacleRawDescription(id);
    if (!mounted) return;
    final controller = TextEditingController(text: raw ?? '');
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('본문 수정 (관리자)'),
        content: SingleChildScrollView(
          child: TextField(
            controller: controller,
            maxLines: 10,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '[Location: 주소] 줄이 있으면 유지하는 것을 권장합니다.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    final newDesc = controller.text;
    controller.dispose();
    if (save != true || !mounted) return;
    final success = await ApiService.updateObstacleReport(id, description: newDesc);
    if (!mounted) return;
    if (success) {
      CommonToast.show(context, '저장되었습니다.');
      _applyRawDescriptionToDisplayOverrides(newDesc);
    } else {
      CommonToast.show(context, '저장에 실패했습니다.');
    }
  }

  Future<void> _loadMyReaction() async {
    final reaction = await ApiService.getMyReaction(widget.report['id']);
    if (!mounted) return;
    setState(() {
      isLiked = reaction == true;
      isDisliked = reaction == false;
    });
  }

  Future<void> _fetchComments() async {
    setState(() => isLoadingComments = true);
    final data = await ApiService.getComments(widget.report['id']);
    if (mounted) {
      setState(() {
        comments = data;
        isLoadingComments = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    if (_isOwnReport) {
      CommonToast.show(context, '본인 제보에는 좋아요를 할 수 없습니다.');
      return;
    }
    // Optimistic Update
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

    final success = await ApiService.toggleLike(widget.report['id'], true);
    if (!success && mounted) {
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
  }

  Future<void> _toggleDislike() async {
    if (_isOwnReport) {
      CommonToast.show(context, '본인 제보에는 싫어요를 할 수 없습니다.');
      return;
    }
    // Optimistic Update
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

    final success = await ApiService.toggleLike(widget.report['id'], false);
    if (!success && mounted) {
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
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    _commentController.clear();
    FocusScope.of(context).unfocus();

    // Optimistic: Add locally (optional) or just wait for fetch
    final success = await ApiService.postComment(widget.report['id'], text);
    if (success) {
      await _fetchComments();
    }
  }

  void _popWithResult() {
    Navigator.pop(context, {
      'likeCount': likeCount,
      'dislikeCount': dislikeCount,
      'isLiked': isLiked,
      'isDisliked': isDisliked,
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _popWithResult();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).scaffoldBackgroundColor
            : Colors.white,
        resizeToAvoidBottomInset: true,
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CustomBackButton(
                      onPressed: _popWithResult,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                        '상세 정보',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF4A5565),
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isAdmin)
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : textDark,
                            ),
                            padding: EdgeInsets.zero,
                            onSelected: (value) {
                              if (value == 'edit') _adminEditDescription();
                              if (value == 'delete') _adminDeleteReport();
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('본문 수정'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  '제보 삭제',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : textDark,
                          onPressed: _popWithResult,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
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
                          if (widget.report['imageUrl'] != null &&
                              widget.report['imageUrl'].toString().isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                final imageUrl =
                                    widget.report['imageUrl']
                                        .toString()
                                        .startsWith('http')
                                    ? widget.report['imageUrl']
                                    : '${ApiService.baseUrl}${widget.report['imageUrl']}';

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => Scaffold(
                                      backgroundColor: Colors.black,
                                      appBar: AppBar(
                                        backgroundColor: Colors.black,
                                        iconTheme: const IconThemeData(
                                          color: Colors.white,
                                        ),
                                        elevation: 0,
                                      ),
                                      body: Center(
                                        child: InteractiveViewer(
                                          panEnabled: true,
                                          boundaryMargin: const EdgeInsets.all(
                                            20,
                                          ),
                                          minScale: 0.5,
                                          maxScale: 4.0,
                                          child: Image.network(
                                            imageUrl,
                                            fit: BoxFit.contain,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return const Icon(
                                                    Icons.error,
                                                    color: Colors.white,
                                                    size: 50,
                                                  );
                                                },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  widget.report['imageUrl']
                                          .toString()
                                          .startsWith('http')
                                      ? widget.report['imageUrl']
                                      : '${ApiService.baseUrl}${widget.report['imageUrl']}',
                                  height: 250,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 250,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE5E7EB),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.image_not_supported,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            )
                          else
                            Container(
                              height: 250,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5E7EB),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Icon(Icons.photo, color: Colors.grey),
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
                            backgroundImage: widget.report['user_avatar_url'] != null &&
                                    (widget.report['user_avatar_url'] as String).isNotEmpty
                                ? NetworkImage(widget.report['user_avatar_url'] as String)
                                : null,
                            child: widget.report['user_avatar_url'] == null ||
                                    (widget.report['user_avatar_url'] as String).isEmpty
                                ? Text(
                                    (widget.report['user'] as String).isNotEmpty
                                        ? (widget.report['user'] as String)[0]
                                        : '?',
                                    style: TextStyle(fontSize: 16, color: textDark),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.report['user'],
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : textDark,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                formatTimeAgo(
                                  widget.report['time']?.toString() ?? '',
                                ),
                                style: TextStyle(color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF9CA3AF)
                                    : textGrey, fontSize: 12),
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
                            _displayAddressOverride ??
                                widget.report['address']?.toString() ??
                                '',
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xFF4A5565),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 28),
                        child: Text(
                          '37.566500, 126.978000',
                          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF9CA3AF)
                              : textGrey, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 4. Content
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).cardColor
                              : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _displayContentOverride ??
                              widget.report['content']?.toString() ??
                              '',
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : textDark,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 5. Like/Dislike Buttons
                      Opacity(
                        opacity: _isOwnReport ? 0.45 : 1,
                        child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _isOwnReport ? null : _toggleLike,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isLiked
                                      ? primaryGreen.withValues(alpha: 0.1)
                                      : Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF9CA3AF)
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
                              onTap: _isOwnReport ? null : _toggleDislike,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isDisliked
                                      ? Colors.red.withValues(alpha: 0.1)
                                      :Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF9CA3AF)
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
                      ),
                      const SizedBox(height: 16),

                      // 6. Edit Request Button (Keep as is)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ReportEditScreen(report: widget.report),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : textDark,
                          ),
                          label: Text(
                            '수정 요청',
                            style: TextStyle(color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : textDark),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '댓글 (${comments.length})',
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : textDark,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF2A2A2A)
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: TextField(
                                controller: _commentController,
                                decoration: InputDecoration(
                                  hintText: '댓글을 입력하세요...',
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF697282)
                                        : const Color(0xFF9CA3AF),
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
                              color: const Color(0xFF6EE7B7),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: _submitComment,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Comments List
                      if (comments.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text('아직 댓글이 없습니다.'),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: comments.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final comment = comments[index];
                            // Assuming backend returns created_at etc.
                            // Currently simple map from API logic
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Theme.of(context).cardColor
                                    : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.grey.shade300,
                                    radius: 16,
                                    backgroundImage: comment['profile_image_url'] != null &&
                                            (comment['profile_image_url'] as String).isNotEmpty
                                        ? NetworkImage(comment['profile_image_url'] as String)
                                        : null,
                                    child: comment['profile_image_url'] == null ||
                                            (comment['profile_image_url'] as String).isEmpty
                                        ? const Icon(
                                            Icons.person,
                                            size: 20,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          comment['nickname'] ?? '탈퇴한 사용자',
                                          style: TextStyle(
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? Colors.white
                                                : textDark,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          comment['content'] ?? '',
                                          style: TextStyle(
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? Colors.white
                                                : textDark,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
