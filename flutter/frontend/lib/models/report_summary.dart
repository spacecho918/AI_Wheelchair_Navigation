class ReportSummary {
  final String id;
  final String title;
  final String location;
  final String status; // 'confirmed', 'resolved', 'pending'
  final int commentCount;
  final int likeCount;
  final DateTime date;
  final String content;
  final String? imageUrl;

  ReportSummary({
    required this.id,
    required this.title,
    required this.location,
    required this.status,
    required this.commentCount,
    required this.likeCount,
    required this.date,
    this.content = '',
    this.imageUrl,
  });

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    return ReportSummary(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      location: json['location'] ?? '',
      status: json['status'] ?? 'pending',
      commentCount: json['comment_count'] ?? 0,
      likeCount: json['like_count'] ?? 0,
      date: DateTime.parse(json['date']),
      content: json['content'] ?? '',
      imageUrl: json['image_url'],
    );
  }
}
