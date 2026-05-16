class ReportSummary {
  final String id;
  final String title;
  final String location;
  final String status; // 'confirmed', 'resolved', 'pending'
  final int commentCount;
  final int likeCount;
  final int dislikeCount;
  final DateTime date;
  final String content;
  final String? imageUrl;
  final String? reportedBy;
  final String? authorNickname;
  final String? authorAvatarUrl;

  ReportSummary({
    required this.id,
    required this.title,
    required this.location,
    required this.status,
    required this.commentCount,
    required this.likeCount,
    this.dislikeCount = 0,
    required this.date,
    this.content = '',
    this.imageUrl,
    this.reportedBy,
    this.authorNickname,
    this.authorAvatarUrl,
  });

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    return ReportSummary(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      location: json['location'] ?? '',
      status: json['status'] ?? 'pending',
      commentCount: json['comment_count'] ?? 0,
      likeCount: json['like_count'] ?? 0,
      dislikeCount: json['dislike_count'] ?? 0,
      date: DateTime.parse(json['date']),
      content: json['content'] ?? '',
      imageUrl: json['image_url'],
      reportedBy: json['reported_by']?.toString(),
      authorNickname: json['author_nickname'] as String?,
      authorAvatarUrl: json['author_avatar_url'] as String?,
    );
  }
}
