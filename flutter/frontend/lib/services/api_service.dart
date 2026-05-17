import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../models/driving_history.dart';
import '../models/report_summary.dart';

import 'auth_service.dart';

/// 마지막으로 제보된 장애물 정보를 임시 저장하는 클래스.
/// NavigationScreen이 제보 완료 후 이 값을 확인해 경로 재탐색 여부를 판단합니다.
class LastReportedObstacle {
  static double? latitude;
  static double? longitude;
  static double radius = 15.0;
  static DateTime? reportedAt;

  /// 제보 데이터 저장
  static void set(double lat, double lon, {double r = 15.0}) {
    latitude = lat;
    longitude = lon;
    radius = r;
    reportedAt = DateTime.now();
  }

  /// 데이터 소비 후 초기화 (한 번만 사용)
  static Map<String, double>? consume() {
    if (latitude == null || longitude == null) return null;
    final data = {'lat': latitude!, 'lon': longitude!, 'radius': radius};
    latitude = null;
    longitude = null;
    reportedAt = null;
    return data;
  }
}

class ApiService {
  static final _supabase = supabase.Supabase.instance.client;

  // 서버 주소 (AI 분석 및 길찾기용)
  // 웹, 모바일: Supabase server_config 테이블에서 자동 읽어옴
  static String? _cachedServerUrl;

  static String get baseUrl {
    if (_cachedServerUrl == null) {
      throw Exception('Server URL not initialized');
    }
    return _cachedServerUrl!;
  }

  /// 서버 시작 시 Supabase에 등록된 서버 IP를 읽어와서 캐시
  /// 앱 시작 시 한 번만 호출하면 됨
  static Future<void> loadServerUrl() async {
    /// 웹,앱 URL 자동 감지 적용
    if (_cachedServerUrl != null) return;
    try {
      final result = await _supabase
          .from('server_config')
          .select('value')
          .eq('key', 'server_url')
          .maybeSingle();
      if (result != null && result['value'] != null) {
        _cachedServerUrl = result['value'] as String;
        debugPrint('서버 URL 자동 감지: $_cachedServerUrl');
        return;
      }
    } catch (e) {
      debugPrint('서버 URL 로드 실패: $e');
    }
    _cachedServerUrl = "http://10.0.2.2:8000";
    debugPrint('fallback 서버 URL 사용: $_cachedServerUrl');
  }


  /// 1. 이미지 업로드 (Python 서버의 /api/upload 활용)
  static Future<String?> uploadImage(String imagePath) async {
    final uri = Uri.parse('$baseUrl/report/upload');
    var request = http.MultipartRequest('POST', uri);

    if (!kIsWeb) {
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));
    } else {
      // 웹: bytes 변환 로직 필요 (웹 지원 시)
      return null;
    }

    try {
      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        return data['url']; // /static/uploads/...
      }
    } catch (e) {
      debugPrint('Upload Error: $e');
    }
    return null;
  }

  /// 2. AI 분석 (Python 서버 /report/analyze)
  /// 반환값:
  ///   success: bool
  ///   annotated_image: String (base64 JPEG — bbox가 그려진 이미지)
  ///   detections: List<Map> [{class, confidence, box}, ...]
  ///   detected_type: String? (가장 높은 신뢰도 클래스)
  ///   message: String
  static Future<Map<String, dynamic>> analyzeImage(
    String imagePath, {
    Uint8List? imageBytes, // 웹에서 blob URL 대신 bytes 직접 전달
  }) async {
    final uri = Uri.parse('$baseUrl/report/analyze');
    var request = http.MultipartRequest('POST', uri);

    if (kIsWeb && imageBytes != null) {
      // 웹: bytes로 직접 첨부 (blob URL은 MultipartFile.fromPath 불가)
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'photo.jpg',
        ),
      );
    } else if (!kIsWeb) {
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));
    }

    try {
      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      }
      debugPrint('Analyze HTTP ${res.statusCode}: ${res.body}');
    } catch (e) {
      debugPrint('Analyze Error: $e');
    }
    return {"success": false, "message": "분석 실패"};
  }

  /// 3. 경로 탐색 (Python 서버 /route - Smart Sync 적용됨)
  static Future<Map<String, dynamic>> findRoute({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    required String mode,
    String wheelchairType = 'manual',
  }) async {
    final uri = Uri.parse('$baseUrl/route');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'start_lat': startLat,
          'start_lon': startLon,
          'end_lat': endLat,
          'end_lon': endLon,
          'mode': mode,
          'wheelchair_type': wheelchairType,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
    } catch (e) {
      debugPrint('Route Error: $e');
    }
    return {"success": false, "message": "경로 탐색 실패"};
  }

  /// 3-2. 경로 비교 (3가지 모드 동시 조회)
  static Future<Map<String, dynamic>> compareRoutes({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    String wheelchairType = 'manual',
  }) async {
    final uri = Uri.parse('$baseUrl/route/compare');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'start_lat': startLat,
          'start_lon': startLon,
          'end_lat': endLat,
          'end_lon': endLon,
          'wheelchair_type': wheelchairType,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
    } catch (e) {
      debugPrint('Compare Routes Error: $e');
    }
    return {"success": false, "message": "경로 비교 실패"};
  }

  // === Supabase 직접 호출 ===

  /// `user_profiles.role == 'admin'` 여부 (RLS와 별도로 UI/API 분기용)
  static Future<bool> isCurrentUserAdmin() async {
    final user = AuthService.currentUser;
    if (user == null) return false;
    try {
      final row = await _supabase
          .from('user_profiles')
          .select('role')
          .eq('user_id', user.id)
          .maybeSingle();
      return row != null && row['role'] == 'admin';
    } catch (e) {
      debugPrint('isCurrentUserAdmin error: $e');
      return false;
    }
  }

  /// 4. 제보하기 (Python 서버 /report/submit - 이미지 업로드 + DB 저장 + 그래프 즉시 반영)
  static Future<Map<String, dynamic>> submitReport({
    required double latitude,
    required double longitude,
    required String obstacleType,
    String description = "",
    String? imagePath,
    String? address,
    Uint8List? imageBytes, // 웹용 이미지 바이트
    String? imageName, // 웹용 이미지 파일명
    /// 콤마 구분 영문 id (예: stairs, cone). 서버에서 기간 기본값 판별에 사용.
    String? obstacleIds,
    /// unknown | custom (계단 전용 제보 시 생략)
    String? durationMode,
    /// custom 일 때 종료 시각 ISO8601 (UTC 권장)
    String? locationValidUntilIso,
  }) async {
    final uri = Uri.parse('$baseUrl/report/submit');
    var request = http.MultipartRequest('POST', uri);

    // 폼 데이터 추가
    request.fields['latitude'] = latitude.toString();
    request.fields['longitude'] = longitude.toString();
    request.fields['obstacle_type'] = obstacleType;
    request.fields['description'] = description;
    if (address != null) request.fields['address'] = address;
    if (obstacleIds != null && obstacleIds.isNotEmpty) {
      request.fields['obstacle_ids'] = obstacleIds;
    }
    if (durationMode != null && durationMode.isNotEmpty) {
      request.fields['duration_mode'] = durationMode;
    }
    if (locationValidUntilIso != null && locationValidUntilIso.isNotEmpty) {
      request.fields['location_valid_until'] = locationValidUntilIso;
    }

    final user = AuthService.currentUser;
    if (user != null) {
      request.fields['reported_by'] = user.id;
      request.fields['reporter_name'] =
          user.userMetadata?['nickname'] ?? 'Unknown';
    }

    // 이미지 추가 (웹: bytes, 모바일: path)
    if (kIsWeb && imageBytes != null && imageBytes.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: imageName ?? 'image.jpg',
        ),
      );
    } else if (!kIsWeb && imagePath != null && imagePath.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));
    }

    try {
      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        // 제보 성공 시 장애물 위치를 LastReportedObstacle에 저장
        LastReportedObstacle.set(latitude, longitude);
        return jsonDecode(utf8.decode(res.bodyBytes));
      } else {
        debugPrint('Submit Failed: ${res.statusCode} ${res.body}');
        return {"success": false, "message": "제출 실패 (${res.statusCode})"};
      }
    } catch (e) {
      debugPrint('Submit Error: $e');
      return {"success": false, "message": "연결 오류: $e"};
    }
  }

  /// 지도 위 장애물 마커 표시용 — 활성 장애물 좌표 조회
  static Future<List<Map<String, dynamic>>> getActiveObstacles() async {
    try {
      final data = await _supabase
          .from('obstacles')
          .select('id, latitude, longitude, obstacle_type, location_valid_until')
          .eq('is_active', true)
          .not('latitude', 'is', null)
          .not('longitude', 'is', null)
          .limit(200);

      final items = data as List;
      final nowUtc = DateTime.now().toUtc();
      return items.map((item) {
        final vu = item['location_valid_until'];
        if (vu != null) {
          final end = DateTime.tryParse(vu.toString());
          if (end != null && !end.toUtc().isAfter(nowUtc)) {
            return null;
          }
        }
        return {
          'id': item['id']?.toString() ?? '',
          'lat': (item['latitude'] as num?)?.toDouble(),
          'lng': (item['longitude'] as num?)?.toDouble(),
          'type': item['obstacle_type'] ?? '기타',
        };
      }).whereType<Map<String, dynamic>>().where((o) => o['lat'] != null && o['lng'] != null).toList();
    } catch (e) {
      debugPrint('Active Obstacles Fetch Error: $e');
      return [];
    }
  }

  /// 5. 커뮤니티 목록 (Direct Select) — 댓글 수 포함
  static Future<List<Map<String, dynamic>>> getCommunityReports() async {
    try {
      final data = await _supabase
          .from('obstacles')
          .select('*')
          .order('created_at', ascending: false)
          .limit(50);

      final items = data as List;
      if (items.isEmpty) return [];

      final obstacleIds = items
          .map((item) => item['id']?.toString())
          .whereType<String>()
          .toList();

      // obstacle별 댓글 수 조회 (목록 화면 표시용)
      final commentCountMap = <String, int>{};
      try {
        final commentsData = await _supabase
            .from('comments')
            .select('obstacle_id')
            .inFilter('obstacle_id', obstacleIds);
        for (final c in commentsData as List) {
          final oid = c['obstacle_id']?.toString();
          if (oid != null) {
            commentCountMap[oid] = (commentCountMap[oid] ?? 0) + 1;
          }
        }
      } catch (_) {
        // comments 테이블 없거나 RLS 등으로 실패 시 0으로 유지
      }

      // obstacle별 좋아요/싫어요 수 조회 (likes 테이블)
      final likeCountMap = <String, int>{};
      final dislikeCountMap = <String, int>{};
      try {
        final likesData = await _supabase
            .from('likes')
            .select('obstacle_id, is_like')
            .inFilter('obstacle_id', obstacleIds);
        for (final row in likesData as List) {
          final oid = row['obstacle_id']?.toString();
          if (oid == null) continue;
          final isLike = row['is_like'] == true;
          if (isLike) {
            likeCountMap[oid] = (likeCountMap[oid] ?? 0) + 1;
          } else {
            dislikeCountMap[oid] = (dislikeCountMap[oid] ?? 0) + 1;
          }
        }
      } catch (_) {
        // likes 테이블 없거나 RLS 등으로 실패 시 0으로 유지
      }

      // 작성자 프로필(닉네임, 프로필 사진) 조회 — 홈/커뮤니티 아바타 표시용
      final reportedByIds = items
          .map((item) => item['reported_by']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final authorProfileMap = <String, Map<String, dynamic>>{};
      if (reportedByIds.isNotEmpty) {
        try {
          final profiles = await _supabase
              .from('user_profiles')
              .select('user_id, nickname, profile_image_url')
              .inFilter('user_id', reportedByIds);
          for (final p in profiles as List) {
            final uid = p['user_id']?.toString();
            if (uid != null) {
              authorProfileMap[uid] = {
                'nickname': p['nickname'] as String?,
                'profile_image_url':
                    (p['profile_image_url'] as String?)?.isNotEmpty == true
                    ? p['profile_image_url'] as String
                    : null,
              };
            }
          }
        } catch (_) {}
      }

      return items.map((item) {
        String content = item['description'] ?? "";
        String address = "위치 정보 없음";

        final locMatch = RegExp(r'\[Location: (.*?)\]').firstMatch(content);
        if (locMatch != null) {
          address = locMatch.group(1)!;
          content = content.replaceAll(locMatch.group(0)!, '').trim();
        }

        final userMatch = RegExp(r'\[User: (.*?)\]').firstMatch(content);
        final reportedBy = item['reported_by']?.toString();
        final authorProfile = reportedBy != null
            ? authorProfileMap[reportedBy]
            : null;
        String user = reportedBy == null
            ? '탈퇴한 사용자'
            : (authorProfile?['nickname'] ??
                  (userMatch != null ? userMatch.group(1)! : "알 수 없음"));
        if (userMatch != null && authorProfile == null && reportedBy != null) {
          user = userMatch.group(1)!;
          content = content.replaceAll(userMatch.group(0)!, '').trim();
        } else if (userMatch != null) {
          content = content.replaceAll(userMatch.group(0)!, '').trim();
        }

        final idStr = item['id']?.toString() ?? '';

        return {
          'id': idStr,
          'tag': item['obstacle_type'],
          'user': user,
          'user_avatar_url': authorProfile?['profile_image_url'],
          'time': item['created_at'],
          'timestamp': item['created_at'],
          'address': address,
          'content': content,
          'likes': likeCountMap[idStr] ?? 0,
          'dislikes': dislikeCountMap[idStr] ?? 0,
          'comments': commentCountMap[idStr] ?? 0,
          'imageUrl': item['image_url'],
          if (reportedBy != null) 'reported_by': reportedBy,
        };
      }).toList();
    } catch (e) {
      debugPrint('Community Fetch Error: $e');
      return [];
    }
  }

  /// 단일 게시글 조회 (알림 딥링크용) — getCommunityReports와 동일한 형태 반환
  static Future<Map<String, dynamic>?> getReportById(String obstacleId) async {
    try {
      final item = await _supabase
          .from('obstacles')
          .select('*')
          .eq('id', obstacleId)
          .single();

      int likes = 0, dislikes = 0, comments = 0;
      try {
        final likesData = await _supabase
            .from('likes')
            .select('is_like')
            .eq('obstacle_id', obstacleId);
        for (final row in likesData as List) {
          if (row['is_like'] == true) likes++; else dislikes++;
        }
      } catch (_) {}
      try {
        final commentsData = await _supabase
            .from('comments')
            .select('obstacle_id')
            .eq('obstacle_id', obstacleId);
        comments = (commentsData as List).length;
      } catch (_) {}

      final reportedBy = item['reported_by']?.toString();
      String user = '알 수 없음';
      String? avatarUrl;
      if (reportedBy != null) {
        try {
          final profile = await _supabase
              .from('user_profiles')
              .select('nickname, profile_image_url')
              .eq('user_id', reportedBy)
              .maybeSingle();
          user = profile?['nickname']?.toString() ?? '알 수 없음';
          avatarUrl = profile?['profile_image_url']?.toString();
        } catch (_) {}
      }

      String content = item['description'] ?? '';
      String address = '위치 정보 없음';
      final locMatch = RegExp(r'\[Location: (.*?)\]').firstMatch(content);
      if (locMatch != null) {
        address = locMatch.group(1)!;
        content = content.replaceAll(locMatch.group(0)!, '').trim();
      }
      final userMatch = RegExp(r'\[User: (.*?)\]').firstMatch(content);
      if (userMatch != null) {
        content = content.replaceAll(userMatch.group(0)!, '').trim();
      }

      return {
        'id': obstacleId,
        'tag': item['obstacle_type'],
        'user': user,
        'user_avatar_url': avatarUrl,
        'time': item['created_at'],
        'timestamp': item['created_at'],
        'address': address,
        'content': content,
        'likes': likes,
        'dislikes': dislikes,
        'comments': comments,
        'imageUrl': item['image_url'],
        'latitude': item['latitude'],
        'longitude': item['longitude'],
        if (reportedBy != null) 'reported_by': reportedBy,
      };
    } catch (e) {
      debugPrint('getReportById error: $e');
      return null;
    }
  }

  /// 5-1. 현재 사용자의 좋아요/싫어요 상태 (상세 화면용). true=좋아요, false=싫어요, null=미선택
  static Future<bool?> getMyReaction(String reportId) async {
    final user = AuthService.currentUser;
    if (user == null) return null;
    try {
      final row = await _supabase
          .from('likes')
          .select('is_like')
          .eq('user_id', user.id)
          .eq('obstacle_id', reportId)
          .maybeSingle();
      if (row == null) return null;
      return row['is_like'] as bool?;
    } catch (_) {
      return null;
    }
  }

  /// 6. 내 제보 (Direct Select) — 댓글/좋아요/싫어요 수 집계 포함
  /// 관리자(`role=admin`)는 본인 글이 아닌 **전체 제보** 목록(최대 500건)을 동일 형식으로 반환.
  static Future<List<ReportSummary>> getUserReports() async {
    final user = AuthService.currentUser;
    if (user == null) return [];
    try {
      final admin = await isCurrentUserAdmin();
      final List<dynamic> items;
      if (admin) {
        final data = await _supabase
            .from('obstacles')
            .select('*')
            .order('created_at', ascending: false)
            .limit(500);
        items = data as List;
      } else {
        final data = await _supabase
            .from('obstacles')
            .select('*')
            .eq('reported_by', user.id)
            .order('created_at', ascending: false);
        items = data as List;
      }
      if (items.isEmpty) return [];

      final obstacleIds = items
          .map((item) => item['id']?.toString())
          .whereType<String>()
          .toList();

      // obstacle별 댓글 수
      final commentCountMap = <String, int>{};
      try {
        final commentsData = await _supabase
            .from('comments')
            .select('obstacle_id')
            .inFilter('obstacle_id', obstacleIds);
        for (final c in commentsData as List) {
          final oid = c['obstacle_id']?.toString();
          if (oid != null) {
            commentCountMap[oid] = (commentCountMap[oid] ?? 0) + 1;
          }
        }
      } catch (_) {}

      // obstacle별 좋아요/싫어요 수
      final likeCountMap = <String, int>{};
      final dislikeCountMap = <String, int>{};
      try {
        final likesData = await _supabase
            .from('likes')
            .select('obstacle_id, is_like')
            .inFilter('obstacle_id', obstacleIds);
        for (final row in likesData as List) {
          final oid = row['obstacle_id']?.toString();
          if (oid == null) continue;
          if (row['is_like'] == true) {
            likeCountMap[oid] = (likeCountMap[oid] ?? 0) + 1;
          } else {
            dislikeCountMap[oid] = (dislikeCountMap[oid] ?? 0) + 1;
          }
        }
      } catch (_) {}

      final reportedByIds = items
          .map((item) => item['reported_by']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final authorProfileMap = <String, Map<String, dynamic>>{};
      if (reportedByIds.isNotEmpty) {
        try {
          final profiles = await _supabase
              .from('user_profiles')
              .select('user_id, nickname, profile_image_url')
              .inFilter('user_id', reportedByIds);
          for (final p in profiles as List) {
            final uid = p['user_id']?.toString();
            if (uid != null) {
              authorProfileMap[uid] = {
                'nickname': p['nickname'] as String?,
                'profile_image_url':
                    (p['profile_image_url'] as String?)?.isNotEmpty == true
                    ? p['profile_image_url'] as String
                    : null,
              };
            }
          }
        } catch (_) {}
      }

      return items.map((item) {
        String content = item['description'] ?? "";
        String address = "위치 정보 없음";
        final locMatch = RegExp(r'\[Location: (.*?)\]').firstMatch(content);
        if (locMatch != null) {
          address = locMatch.group(1)!;
          content = content.replaceAll(locMatch.group(0)!, '').trim();
        }
        final userMatch = RegExp(r'\[User: (.*?)\]').firstMatch(content);
        if (userMatch != null)
          content = content.replaceAll(userMatch.group(0)!, '').trim();

        final idStr = item['id']?.toString() ?? '';
        final reportedBy = item['reported_by']?.toString();
        final authorProfile = reportedBy != null
            ? authorProfileMap[reportedBy]
            : null;

        return ReportSummary(
          id: idStr,
          title: item['obstacle_type'],
          location: address,
          status: 'confirmed',
          commentCount: commentCountMap[idStr] ?? 0,
          likeCount: likeCountMap[idStr] ?? 0,
          dislikeCount: dislikeCountMap[idStr] ?? 0,
          date: DateTime.parse(item['created_at']),
          content: content,
          imageUrl: item['image_url'],
          reportedBy: reportedBy,
          authorNickname: authorProfile?['nickname'] as String?,
          authorAvatarUrl: authorProfile?['profile_image_url'] as String?,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// 6-1. 제보글 삭제 — 본인 글 또는 관리자(`role=admin`)는 전체 삭제 가능 (RLS와 동일)
  static Future<bool> deleteReport(String reportId) async {
    final user = AuthService.currentUser;
    if (user == null) return false;
    try {
      final admin = await isCurrentUserAdmin();
      if (admin) {
        await _supabase.from('obstacles').delete().eq('id', reportId);
      } else {
        await _supabase
            .from('obstacles')
            .delete()
            .eq('id', reportId)
            .eq('reported_by', user.id);
      }
      await _notifyAlgorithmServerObstaclesRefresh();
      return true;
    } catch (e) {
      debugPrint('Delete report error: $e');
      return false;
    }
  }

  /// 제보 `description` 원문 (주소 `[Location: …]` 접두 포함). 관리자 수정 다이얼로그용.
  static Future<String?> getObstacleRawDescription(String reportId) async {
    try {
      final row = await _supabase
          .from('obstacles')
          .select('description')
          .eq('id', reportId)
          .maybeSingle();
      return row?['description'] as String?;
    } catch (e) {
      debugPrint('getObstacleRawDescription error: $e');
      return null;
    }
  }

  /// 제보 수정 — 본인 또는 관리자. `description`은 DB 컬럼 전체를 덮어씀.
  static Future<bool> updateObstacleReport(
    String reportId, {
    String? description,
    String? obstacleType,
    bool? isActive,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) return false;
    final updates = <String, dynamic>{};
    if (description != null) updates['description'] = description;
    if (obstacleType != null) updates['obstacle_type'] = obstacleType;
    if (isActive != null) updates['is_active'] = isActive;
    if (updates.isEmpty) return true;
    try {
      final admin = await isCurrentUserAdmin();
      if (admin) {
        await _supabase.from('obstacles').update(updates).eq('id', reportId);
      } else {
        await _supabase
            .from('obstacles')
            .update(updates)
            .eq('id', reportId)
            .eq('reported_by', user.id);
      }
      await _notifyAlgorithmServerObstaclesRefresh();
      return true;
    } catch (e) {
      debugPrint('updateObstacleReport error: $e');
      return false;
    }
  }

  /// DB에서 장애물이 삭제·변경된 뒤 알고리즘 서버 그래프를 즉시 맞춤 (실패해도 무시)
  static Future<void> _notifyAlgorithmServerObstaclesRefresh() async {
    try {
      final uri = Uri.parse('$baseUrl/obstacles/refresh');
      await http
          .post(uri)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('알고리즘 서버 장애물 동기화 알림 실패(다음 주기에 반영될 수 있음): $e');
    }
  }

  /// 제보 수정 요청 (edit_requests 테이블 삽입)
  static Future<bool> submitEditRequest({
    required String obstacleId,
    required String reason, // 'resolved', 'obstacle_error', 'location_error', 'other'
    String? description,
    String? photoUrl,
    double? newLat,
    double? newLon,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) return false;

    try {
      await _supabase.from('edit_requests').insert({
        'obstacle_id': obstacleId,
        'requester_id': user.id,
        'reason': reason,
        if (description != null && description.isNotEmpty) 'description': description,
        if (photoUrl != null && photoUrl.isNotEmpty) 'photo_url': photoUrl,
        if (newLat != null) 'new_lat': newLat,
        if (newLon != null) 'new_lon': newLon,
        'status': 'pending',
      });
      return true;
    } catch (e) {
      debugPrint('submitEditRequest error: $e');
      return false;
    }
  }

  /// 특정 장애물의 대기 중인 수정 요청 목록 조회
  static Future<List<Map<String, dynamic>>> getPendingEditRequests(String obstacleId) async {
    try {
      final data = await _supabase
          .from('edit_requests')
          .select('*')
          .eq('obstacle_id', obstacleId)
          .eq('status', 'pending')
          .order('created_at', ascending: true);

      final items = data as List;
      final List<Map<String, dynamic>> results = [];

      for (final item in items) {
        String nickname = '누군가';
        String? avatar;
        if (item['requester_id'] != null) {
          try {
            final profile = await _supabase
                .from('user_profiles')
                .select('nickname, profile_image_url')
                .eq('user_id', item['requester_id'])
                .maybeSingle();
            if (profile != null) {
              nickname = profile['nickname'] ?? '누군가';
              avatar = profile['profile_image_url'];
            }
          } catch (_) {}
        }
        
        results.add({
          'edit_request_id': item['edit_request_id'],
          'reason': item['reason'],
          'description': item['description'],
          'photo_url': item['photo_url'],
          'new_lat': item['new_lat'],
          'new_lon': item['new_lon'],
          'created_at': item['created_at'],
          'requester_nickname': nickname,
          'requester_avatar': avatar,
        });
      }
      return results;
    } catch (e) {
      debugPrint('getPendingEditRequests error: $e');
      return [];
    }
  }

  /// 수정 요청 수락
  static Future<bool> approveEditRequest(String editRequestId, Map<String, dynamic> requestData, String obstacleId) async {
    try {
      // 1. edit_requests 상태 업데이트
      await _supabase.from('edit_requests').update({
        'status': 'approved',
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('edit_request_id', editRequestId);

      // 2. obstacles 테이블에 반영
      final updates = <String, dynamic>{};
      final reason = requestData['reason'];
      
      if (reason == 'resolved') {
        updates['is_active'] = false;
      } else if (reason == 'location_error') {
        if (requestData['new_lat'] != null) updates['latitude'] = requestData['new_lat'];
        if (requestData['new_lon'] != null) updates['longitude'] = requestData['new_lon'];
      }
      
      if (updates.isNotEmpty) {
        await _supabase.from('obstacles').update(updates).eq('id', obstacleId);
        await _notifyAlgorithmServerObstaclesRefresh();
      }

      return true;
    } catch (e) {
      debugPrint('approveEditRequest error: $e');
      return false;
    }
  }

  /// 수정 요청 거절
  static Future<bool> rejectEditRequest(String editRequestId) async {
    try {
      await _supabase.from('edit_requests').update({
        'status': 'rejected',
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('edit_request_id', editRequestId);
      return true;
    } catch (e) {
      debugPrint('rejectEditRequest error: $e');
      return false;
    }
  }

  /// 7. 내 댓글 (Direct Select)
  static Future<List<ReportSummary>> getUserComments() async {
    final user = AuthService.currentUser;
    if (user == null) return [];
    try {
      // 댓글 작성한 장애물 정보 조인
      final data = await _supabase
          .from('comments')
          .select('*, obstacles(*)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return (data as List)
          .map((item) {
            final obs = item['obstacles'];
            if (obs == null) return null;

            return ReportSummary(
              id: obs['id'].toString(),
              title: obs['obstacle_type'],
              location: "댓글: ${item['content']}",
              status: 'confirmed',
              commentCount: 0,
              likeCount: 0,
              dislikeCount: 0,
              date: DateTime.parse(item['created_at']),
              content: item['content'],
            );
          })
          .whereType<ReportSummary>()
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 8. 좋아요/댓글 액션
  static Future<bool> toggleLike(String reportId, bool isLike) async {
    final user = AuthService.currentUser;
    if (user == null) return false;
    try {
      final obstacle = await _supabase
          .from('obstacles')
          .select('reported_by')
          .eq('id', reportId)
          .maybeSingle();
      if (obstacle?['reported_by']?.toString() == user.id) return false;

      // 기존 반응 확인
      final existing = await _supabase
          .from('likes')
          .select()
          .eq('user_id', user.id)
          .eq('obstacle_id', reportId)
          .maybeSingle();

      if (existing != null) {
        if (existing['is_like'] == isLike) {
          // 삭제 (토글 해제)
          await _supabase.from('likes').delete().eq('id', existing['id']);
        } else {
          // 업데이트
          await _supabase
              .from('likes')
              .update({'is_like': isLike})
              .eq('id', existing['id']);
        }
      } else {
        // 삽입
        await _supabase.from('likes').insert({
          'user_id': user.id,
          'obstacle_id': reportId,
          'is_like': isLike,
        });
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> postComment(String reportId, String content) async {
    final user = AuthService.currentUser;
    if (user == null) return false;
    try {
      await _supabase.from('comments').insert({
        'user_id': user.id,
        'obstacle_id': reportId,
        'content': content,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getComments(String reportId) async {
    try {
      final data = await _supabase
          .from('comments')
          .select()
          .eq('obstacle_id', reportId)
          .order('created_at', ascending: false);

      final list = (data as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
      if (list.isEmpty) return list;

      // user_profiles에서 닉네임 조회 후 댓글에 병합 (user_id null = 탈퇴한 사용자)
      final userIds = list
          .map((c) => c['user_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      if (userIds.isEmpty) {
        for (final c in list) {
          c['nickname'] = '탈퇴한 사용자';
          c['profile_image_url'] = null;
        }
        return list;
      }

      final profiles = await _supabase
          .from('user_profiles')
          .select('user_id, nickname, profile_image_url')
          .inFilter('user_id', userIds);
      final nickMap = <String, String>{};
      final avatarMap = <String, String?>{};
      for (final p in profiles as List) {
        final id = p['user_id']?.toString();
        final nick = p['nickname'] as String?;
        final avatar = p['profile_image_url'] as String?;
        if (id != null) {
          if (nick != null && nick.isNotEmpty) nickMap[id] = nick;
          avatarMap[id] = (avatar != null && avatar.isNotEmpty) ? avatar : null;
        }
      }

      for (final c in list) {
        final uid = c['user_id']?.toString();
        final nick = uid != null ? nickMap[uid] : null;
        c['nickname'] = nick ?? (uid == null ? '탈퇴한 사용자' : '사용자');
        c['profile_image_url'] = uid != null ? avatarMap[uid] : null;
      }
      return list;
    } catch (e) {
      return [];
    }
  }

  /// 프로필 조회: user_profiles 테이블 우선, 없으면 auth 메타데이터 사용.
  /// 로그인 직후(회원가입 직후) metadata에만 휠체어 타입이 있을 수 있으므로, 한 번 user_profiles에 동기화 시도.
  static Future<User?> getUserProfile() async {
    final user = AuthService.currentUser;
    if (user == null) return null;
    final metadata = user.userMetadata;

    try {
      final res = await _supabase
          .from('user_profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

       // 제보 개수 카운트
      final reportCountRes = await _supabase
          .from('obstacles')
          .select('id')
          .eq('reported_by', user.id);

      final realReportCount = (reportCountRes as List).length;
      if (res != null) {
        final nick = res['nickname'] as String?;
        var wt = res['wheelchair_type'] as String?;
        final metaWt = metadata?['wheelchair_type'] as String?;
        // 회원가입 직후: 트리거가 metadata를 안 넣었을 수 있음 → metadata로 user_profiles 동기화
        if (metaWt != null &&
            metaWt.isNotEmpty &&
            _toDbWheelchairType(metaWt) != wt) {
          try {
            await _supabase
                .from('user_profiles')
                .update({'wheelchair_type': _toDbWheelchairType(metaWt)})
                .eq('user_id', user.id);
            wt = _toDbWheelchairType(metaWt);
          } catch (_) {}
        }
        final reportLevel = res['report_level'] ?? 0;
        final score = res['score'] ?? 0;
        final profileImageUrl = res['profile_image_url'] as String?;
        final roleStr = res['role']?.toString() ?? 'user';
        return User(
          nickname: nick?.isNotEmpty == true
              ? nick
              : (metadata?['nickname'] ?? '사용자'),
          email: user.email ?? '',
          profileImage: profileImageUrl?.isNotEmpty == true
              ? profileImageUrl
              : null,
          wheelchairType: _normalizeWheelchairType(
            wt ?? metadata?['wheelchair_type'] ?? 'none',
          ),
          role: roleStr == 'admin' ? 'admin' : 'user',
          driveCount: metadata?['drive_count'] ?? 0,
          reportCount: realReportCount,
          likeCount: metadata?['like_count'] ?? 0,
          commentCount: metadata?['comment_count'] ?? 0,
          level: reportLevel,
          score: score,
        );
      }
    } catch (e) {
      debugPrint('getUserProfile user_profiles fetch error: $e');
    }
    return getUserProfileSync();
  }

  static String _normalizeWheelchairType(String v) {
    if (v.isEmpty) return 'None';
    final lower = v.toLowerCase();
    if (lower == 'none') return 'None';
    if (lower == 'electric') return 'Electric';
    if (lower == 'manual') return 'Manual';
    if (lower == 'caregivermanual' || lower == 'assisted_manual')
      return 'CaregiverManual';
    return v;
  }

  static String _toDbWheelchairType(String frontendType) {
    final lower = frontendType.toString().toLowerCase();
    if (lower == 'electric') return 'electric';
    if (lower == 'manual') return 'manual';
    if (lower == 'caregivermanual' || lower == 'assisted_manual')
      return 'assisted_manual';
    if (lower == 'none') return 'none';
    return 'manual';
  }

  /// 회원가입용. user_profiles 테이블 기준 닉네임 중복 검사 (비로그인에서 호출, RPC 사용)
  static Future<bool> isNicknameAvailableInUserProfilesForSignup(
    String nickname,
  ) async {
    if (nickname.trim().isEmpty) return false;
    try {
      final res = await _supabase.rpc(
        'check_nickname_available_user_profiles',
        params: {'p_nickname': nickname.trim()},
      );
      return res == true;
    } catch (e) {
      debugPrint('check_nickname_available_user_profiles RPC error: $e');
      return true;
    }
  }

  /// 회원가입용. auth.users 기준 이메일 중복 검사 (비로그인에서 호출, RPC 사용)
  static Future<bool> isEmailAvailableForSignup(String email) async {
    if (email.trim().isEmpty) return false;
    try {
      final res = await _supabase.rpc(
        'check_email_available',
        params: {'p_email': email.trim()},
      );
      return res == true;
    } catch (e) {
      debugPrint('check_email_available RPC error: $e');
      return false;
    }
  }

  /// 설정 > 닉네임 변경용. user_profiles 기준으로 중복 검사 (RPC 사용, RLS 우회)
  static Future<bool> isNicknameAvailableInUserProfiles(String nickname) async {
    if (nickname.trim().isEmpty) return false;
    try {
      final res = await _supabase.rpc(
        'check_nickname_available_user_profiles',
        params: {'p_nickname': nickname.trim()},
      );
      return res == true;
    } catch (e) {
      debugPrint('isNicknameAvailableInUserProfiles error: $e');
      return true;
    }
  }

  // 동기 프로필 추출 헬퍼
  static User? getUserProfileSync() {
    final user = AuthService.currentUser;
    if (user == null) return null;
    final metadata = user.userMetadata;
    return User(
      nickname: metadata?['nickname'] ?? '사용자',
      email: user.email ?? '',
      wheelchairType: metadata?['wheelchair_type'] ?? 'None',
      role: 'user',
      driveCount: metadata?['drive_count'] ?? 0,
      reportCount: metadata?['report_count'] ?? 0,
      likeCount: metadata?['like_count'] ?? 0,
      commentCount: metadata?['comment_count'] ?? 0,
      level: metadata?['report_level'] ?? 0,
      score: metadata?['score'] ?? 0,
    );
  }

  static Future<Map<String, dynamic>> updateUserProfile({
    String? nickname,
    String? profileImageUrl,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) return {'success': false, 'error': null};

    final updates = <String, dynamic>{};
    final userAttributes = <String, dynamic>{};

    if (nickname != null) {
      updates['nickname'] = nickname;
      updates['name'] = nickname;
      userAttributes['nickname'] = nickname;
    }

    if (profileImageUrl != null) {
      updates['profile_image_url'] = profileImageUrl;
      // 메타데이터도 업데이트 (DB 우선)
      userAttributes['profile_image_url'] = profileImageUrl;
    }

    if (updates.isEmpty) return {'success': true, 'error': null};

    try {
      if (userAttributes.isNotEmpty) {
        await _supabase.auth.updateUser(
          supabase.UserAttributes(data: userAttributes),
        );
      }

      try {
        await _supabase
            .from('user_profiles')
            .update(updates)
            .eq('user_id', user.id);
      } catch (_) {}
      return {'success': true, 'error': null};
    } catch (e) {
      debugPrint('updateUserProfile error: $e');
      final msg = e.toString().toLowerCase();
      final isDuplicate =
          msg.contains('23505') ||
          msg.contains('unique') ||
          msg.contains('duplicate');
      return {'success': false, 'error': isDuplicate ? 'duplicate' : null};
    }
  }

  /// 9. 프로필 이미지 업로드 (Supabase Storage)

  static Future<String?> uploadProfileImageToSupabase(XFile file) async {
    final user = AuthService.currentUser;
    if (user == null) return null;

    try {
      final fileExt = file.path.split('.').last;
      final fileName =
          '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      debugPrint('Uploading profile image: $fileName for user: ${user.id}');

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        await _supabase.storage
            .from('profile_image')
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: const supabase.FileOptions(upsert: true),
            );
      } else {
        final ioFile = File(file.path);
        await _supabase.storage
            .from('profile_image')
            .upload(
              fileName,
              ioFile,
              fileOptions: const supabase.FileOptions(upsert: true),
            );
      }

      final imageUrl = _supabase.storage
          .from('profile_image')
          .getPublicUrl(fileName);
      return imageUrl;
    } catch (e) {
      debugPrint('Supabase Storage Upload Error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> updatePassword(String newPassword) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        return {'success': false, 'message': '로그인이 필요합니다'};
      }

      await _supabase.auth.updateUser(
        supabase.UserAttributes(password: newPassword),
      );
      return {'success': true, 'message': '비밀번호가 변경되었습니다'};
    } catch (e) {
      debugPrint('Update Password Error: $e');
      String errorMessage = '비밀번호 변경에 실패했습니다';
      if (e.toString().contains('weak_password')) {
        errorMessage = '비밀번호가 너무 약합니다';
      } else if (e.toString().contains('same_password')) {
        errorMessage = '현재 비밀번호와 동일합니다';
      }
      return {'success': false, 'message': errorMessage};
    }
  }

  /// 주행 기록 저장: drive_logs 테이블에 Insert
  static Future<bool> saveHistory({
    required String startLocation,
    required String endLocation,
    required String totalDistance, // "1.2km" 형식
    required String estimatedTime, // "15분" 형식
    double? startLat,
    double? startLon,
    double? endLat,
    double? endLon,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) return false;

    // 숫자만 파싱
    double distanceKm = 0;
    int durationMin = 0;
    try {
      distanceKm = double.parse(
        totalDistance.replaceAll(RegExp(r'[^0-9.]'), ''),
      );
    } catch (_) {}
    try {
      durationMin = int.parse(estimatedTime.replaceAll(RegExp(r'[^0-9]'), ''));
    } catch (_) {}

    final durationSec = durationMin * 60;
    final now = DateTime.now().toUtc();

    try {
      await _supabase.from('drive_logs').insert({
        'user_id': user.id,
        'start_lat': startLat ?? 37.5665, // 기본값(null 방지)
        'start_lon': startLon ?? 126.9780,
        'end_lat': endLat ?? 37.5665,
        'end_lon': endLon ?? 126.9780,
        'duration_sec': durationSec,
        'started_at': now
            .subtract(Duration(seconds: durationSec))
            .toIso8601String(),
        'ended_at': now.toIso8601String(),
        'start_label': startLocation,
        'end_label': endLocation,
        'distance_km': distanceKm,
        // created_at, drive_log_id 는 Supabase default 값 자동 생성
      });
      debugPrint('saveHistory: saved successfully');
      return true;
    } catch (e) {
      debugPrint('saveHistory error: $e');
      return false;
    }
  }

  static Future<List<DrivingHistory>> getUserHistory() async {
    final user = AuthService.currentUser;
    if (user == null) return [];

    try {
      final data = await _supabase
          .from('drive_logs') // 주행기록 테이블
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false); // date 기준 정렬

      return (data as List)
          .map((item) => DrivingHistory.fromJson(item))
          .toList();
    } catch (e) {
      debugPrint('History Load Error: $e');
      return [];
    }
  }

  /// 휠체어 타입 수정: auth 메타데이터 + user_profiles 테이블 모두 반영.
  /// type: 'Electric' | 'Manual' | 'CaregiverManual' | 'None'
  static Future<bool> updateWheelchairType(String type) async {
    final user = AuthService.currentUser;
    if (user == null) return false;
    final dbType = _toDbWheelchairType(type);
    try {
      await _supabase.auth.updateUser(
        supabase.UserAttributes(data: {'wheelchair_type': type}),
      );
      await _supabase
          .from('user_profiles')
          .update({'wheelchair_type': dbType})
          .eq('user_id', user.id);
      return true;
    } catch (e) {
      debugPrint('updateWheelchairType error: $e');
      return false;
    }
  }

  // ─── Notifications ───────────────────────────────────────────

  /// 내 알림 목록 조회 (notifications 테이블)
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final user = AuthService.currentUser;
    if (user == null) return [];
    try {
      final data = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      debugPrint('getNotifications error: $e');
      return [];
    }
  }

  /// 특정 알림 읽음 처리
  static Future<void> markNotificationRead(int notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('notification_id', notificationId);
    } catch (e) {
      debugPrint('markNotificationRead error: $e');
    }
  }

  /// 내 모든 알림 읽음 처리
  static Future<void> markAllNotificationsRead() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('markAllNotificationsRead error: $e');
    }
  }

  /// 미읽음 알림 수
  static Future<int> getUnreadNotificationCount() async {
    final user = AuthService.currentUser;
    if (user == null) return 0;
    try {
      final data = await _supabase
          .from('notifications')
          .select('notification_id')
          .eq('user_id', user.id)
          .eq('is_read', false);
      return (data as List).length;
    } catch (e) {
      debugPrint('getUnreadNotificationCount error: $e');
      return 0;
    }
  }

  static Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final session = supabase.Supabase.instance.client.auth.currentSession;

      if (session == null) {
        return {'success': false, 'message': '세션이 없습니다'};
      }

      final response = await http.delete(
        Uri.parse('${ApiService.baseUrl}/delete-account'),
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );

      if (response.statusCode == 200) {
        await supabase.Supabase.instance.client.auth.signOut();
        return {'success': true};
      } else {
        return {'success': false, 'message': response.body};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 주행 중 장애물 존재 여부 검증 데이터 전송
  static Future<void> submitObstacleVerification(String obstacleId, String status) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      await _supabase.from('obstacle_verifications').upsert({
        'user_id': user.id,
        'obstacle_id': obstacleId,
        'status': status,
      });
    } catch (e) {
      debugPrint('Error submitting verification: $e');
    }
  }
}
