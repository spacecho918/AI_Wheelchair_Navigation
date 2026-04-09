/// ISO 8601 등의 타임스탬프를 목록/상세에 쓰기 좋은 상대 시각 문자열로 변환합니다.
String formatTimeAgo(String timestamp) {
  final s = timestamp.trim();
  if (s.isEmpty) return '알 수 없음';
  try {
    final date = DateTime.parse(s);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    }
    if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    }
    return '방금 전';
  } catch (_) {
    return '알 수 없음';
  }
}
