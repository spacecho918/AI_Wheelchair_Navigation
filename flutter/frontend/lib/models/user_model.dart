class User {
  final String nickname;
  final String email;
  final String? profileImage;
  final String wheelchairType; // 'Electric', 'Manual', 'CaregiverManual', 'None'
  /// DB `user_profiles.role`: `user` | `admin`
  final String role;
  final double totalDistance;
  final int driveCount;
  final int reportCount;
  final int commentCount;
  final int likeCount;
  final int level;
  final int score;

  bool get isAdmin => role == 'admin';

  User({
    required this.nickname,
    required this.email,
    this.profileImage,
    required this.wheelchairType,
    this.role = 'user',
    this.totalDistance = 0.0,
    this.driveCount = 0,
    this.reportCount = 0,
    this.commentCount = 0,
    this.likeCount = 0,
    this.level = 0,
    this.score = 0,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      nickname: json['nickname'] ?? '사용자',
      email: json['email'] ?? '',
      profileImage: json['profile_image'],
      wheelchairType: json['wheelchair_type'] ?? 'None',
      role: json['role']?.toString() ?? 'user',
      totalDistance: (json['total_distance'] ?? 0).toDouble(),
      driveCount: json['drive_count'] ?? 0,
      reportCount: json['report_count'] ?? 0,
      commentCount: json['comment_count'] ?? 0,
      likeCount: json['like_count'] ?? 0,
      level: json['report_level'] ?? 0,
      score: json['score'] ?? 0,
    );
  }

  // Helper to get formatted total distance
  String get formattedDistance => '${totalDistance.toStringAsFixed(1)}km';
}
