import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../models/user_model.dart';
import '../models/driving_history.dart';
import '../models/report_summary.dart';
import 'auth_service.dart';

class ApiService {
  static final _supabase = supabase.Supabase.instance.client;

  // 서버 주소 (AI 분석 및 길찾기용)
  static String get baseUrl {
    if (kIsWeb) return "http://localhost:8000";
    if (Platform.isAndroid) return "http://10.0.2.2:8000";
    return "http://localhost:8000";
  }

  /// 1. 이미지 업로드 (Python 서버의 /api/upload 활용)
  static Future<String?> uploadImage(String imagePath) async {
    final uri = Uri.parse('$baseUrl/report/upload');
    var request = http.MultipartRequest('POST', uri);

    if (!kIsWeb) {
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));
    } else {
      // Web logic (bytes) needed if web supported
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

  /// 2. AI 분석 (Python 서버 /api/analyze)
  static Future<Map<String, dynamic>> analyzeImage(String imagePath) async {
    final uri = Uri.parse('$baseUrl/report/analyze');
    var request = http.MultipartRequest('POST', uri);

    if (!kIsWeb) {
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));
    }

    try {
      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      }
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

  // === Direct Supabase Actions ===

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
  }) async {
    final uri = Uri.parse('$baseUrl/report/submit');
    var request = http.MultipartRequest('POST', uri);

    // 폼 데이터 추가
    request.fields['latitude'] = latitude.toString();
    request.fields['longitude'] = longitude.toString();
    request.fields['obstacle_type'] = obstacleType;
    request.fields['description'] = description;
    if (address != null) request.fields['address'] = address;

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

  /// 5. 커뮤니티 목록 (Direct Select)
  static Future<List<Map<String, dynamic>>> getCommunityReports() async {
    try {
      // Simple select - likes/comments tables are not properly linked
      final data = await _supabase
          .from('obstacles')
          .select('*')
          .order('created_at', ascending: false)
          .limit(50);

      return (data as List).map((item) {
        // Parse description
        String content = item['description'] ?? "";
        String address = "위치 정보 없음";

        final locMatch = RegExp(r'\[Location: (.*?)\]').firstMatch(content);
        if (locMatch != null) {
          address = locMatch.group(1)!;
          content = content.replaceAll(locMatch.group(0)!, '').trim();
        }

        final userMatch = RegExp(r'\[User: (.*?)\]').firstMatch(content);
        String user = "알 수 없음";
        if (userMatch != null) {
          user = userMatch.group(1)!;
          content = content.replaceAll(userMatch.group(0)!, '').trim();
        }

        return {
          'id': item['id'].toString(),
          'tag': item['obstacle_type'],
          'user': user,
          'time': item['created_at'], // ISO String
          'timestamp': item['created_at'],
          'address': address,
          'content': content,
          'likes': 0,
          'dislikes': 0,
          'comments': 0,
          'imageUrl': item['image_url'],
        };
      }).toList();
    } catch (e) {
      debugPrint('Community Fetch Error: $e');
      return [];
    }
  }

  // Helper to get reaction counts if needed (Complex)
  // For now, implementing simple count or client filtering if data small?
  // Or just accept that 'likes' is total reactions.

  /// 6. 내 제보 (Direct Select)
  static Future<List<ReportSummary>> getUserReports() async {
    final user = AuthService.currentUser;
    if (user == null) return [];
    try {
      final data = await _supabase
          .from('obstacles')
          .select('*')
          .eq('reported_by', user.id)
          .order('created_at', ascending: false);

      return (data as List).map((item) {
        // Parsing logic duplicated - could extract
        String content = item['description'] ?? "";
        String address = "위치 정보 없음";
        final locMatch = RegExp(r'\[Location: (.*?)\]').firstMatch(content);
        if (locMatch != null) {
          address = locMatch.group(1)!;
          content = content.replaceAll(locMatch.group(0)!, '').trim();
        }
        // Remove User tag
        final userMatch = RegExp(r'\[User: (.*?)\]').firstMatch(content);
        if (userMatch != null)
          content = content.replaceAll(userMatch.group(0)!, '').trim();

        return ReportSummary(
          id: item['id'].toString(),
          title: item['obstacle_type'],
          location: address,
          status: 'confirmed',
          commentCount: 0,
          likeCount: 0,
          date: DateTime.parse(item['created_at']),
          content: content,
          imageUrl: item['image_url'],
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// 7. 내 댓글 (Direct Select)
  static Future<List<ReportSummary>> getUserComments() async {
    final user = AuthService.currentUser;
    if (user == null) return [];
    try {
      // Join obstacles to show what we commented on
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
              location: "댓글: ${item['content']}", // Show comment content ?
              status: 'confirmed',
              commentCount: 0,
              likeCount: 0,
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
      // Check existing
      final existing = await _supabase
          .from('likes')
          .select()
          .eq('user_id', user.id)
          .eq('obstacle_id', reportId)
          .maybeSingle();

      if (existing != null) {
        if (existing['is_like'] == isLike) {
          // Delete (Toggle off)
          await _supabase.from('likes').delete().eq('id', existing['id']);
        } else {
          // Update
          await _supabase
              .from('likes')
              .update({'is_like': isLike})
              .eq('id', existing['id']);
        }
      } else {
        // Insert
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
      // Getting comments. Ideally join profiles for nickname?
      // Assuming 'user_id' matches auth.users.
      // We don't have public profiles table guaranteed.
      // Just return content for now.
      final data = await _supabase
          .from('comments')
          .select()
          .eq('obstacle_id', reportId)
          .order('created_at', ascending: false);

      return (data as List).map((e) => e as Map<String, dynamic>).toList();
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
      if (res != null) {
        final nick = res['nickname'] as String?;
        var wt = res['wheelchair_type'] as String?;
        final metaWt = metadata?['wheelchair_type'] as String?;
        // 회원가입 직후: 트리거가 metadata를 안 넣었을 수 있음 → metadata로 user_profiles 동기화
        if (metaWt != null && metaWt.isNotEmpty && _toDbWheelchairType(metaWt) != wt) {
          try {
            await _supabase
                .from('user_profiles')
                .update({'wheelchair_type': _toDbWheelchairType(metaWt)})
                .eq('user_id', user.id);
            wt = _toDbWheelchairType(metaWt);
          } catch (_) {}
        }
        final reportLevel = res['report_level'];
        final profileImageUrl = res['profile_image_url'] as String?;
        return User(
          nickname: nick?.isNotEmpty == true ? nick : (metadata?['nickname'] ?? '사용자'),
          email: user.email ?? '',
          profileImage: profileImageUrl?.isNotEmpty == true ? profileImageUrl : null,
          wheelchairType: _normalizeWheelchairType(wt ?? metadata?['wheelchair_type'] ?? 'none'),
          driveCount: metadata?['drive_count'] ?? 0,
          reportCount: reportLevel is int ? reportLevel : (metadata?['report_count'] ?? 0),
          likeCount: metadata?['like_count'] ?? 0,
          commentCount: metadata?['comment_count'] ?? 0,
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
    if (lower == 'caregivermanual' || lower == 'assisted_manual') return 'CaregiverManual';
    return v;
  }

  static String _toDbWheelchairType(String frontendType) {
    final lower = frontendType.toString().toLowerCase();
    if (lower == 'electric') return 'electric';
    if (lower == 'manual') return 'manual';
    if (lower == 'caregivermanual' || lower == 'assisted_manual') return 'assisted_manual';
    if (lower == 'none') return 'none';
    return 'manual';
  }

  /// 회원가입용. user_profiles 테이블 기준 닉네임 중복 검사 (비로그인에서 호출, RPC 사용)
  static Future<bool> isNicknameAvailableInUserProfilesForSignup(String nickname) async {
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

  /// 설정 > 닉네임 변경용. user_profiles 기준으로 중복 검사 (본인 닉네임이면 사용 가능)
  static Future<bool> isNicknameAvailableInUserProfiles(String nickname) async {
    if (nickname.trim().isEmpty) return false;
    final user = AuthService.currentUser;
    if (user == null) return false;
    try {
      final res = await _supabase
          .from('user_profiles')
          .select('user_id')
          .eq('nickname', nickname.trim())
          .maybeSingle();
      if (res == null) return true;
      return res['user_id'] == user.id;
    } catch (e) {
      debugPrint('isNicknameAvailableInUserProfiles error: $e');
      return true;
    }
  }

  // Helper for existing synchronous profile extraction
  static User? getUserProfileSync() {
    final user = AuthService.currentUser;
    if (user == null) return null;
    final metadata = user.userMetadata;
    return User(
      nickname: metadata?['nickname'] ?? '사용자',
      email: user.email ?? '',
      wheelchairType: metadata?['wheelchair_type'] ?? 'None',
      driveCount: metadata?['drive_count'] ?? 0,
      reportCount: metadata?['report_count'] ?? 0,
      likeCount: metadata?['like_count'] ?? 0,
      commentCount: metadata?['comment_count'] ?? 0,
    );
  }

  /// 닉네임 수정: auth 메타데이터 + user_profiles 테이블 반영. Returns: { 'success': bool, 'error': String? } — 'duplicate' 시 닉네임 중복
  static Future<Map<String, dynamic>> updateUserProfile(String nickname) async {
    final user = AuthService.currentUser;
    if (user == null) return {'success': false, 'error': null};
    try {
      await _supabase.auth.updateUser(
        supabase.UserAttributes(data: {'nickname': nickname}),
      );
      try {
        await _supabase
            .from('user_profiles')
            .update({'nickname': nickname, 'name': nickname})
            .eq('user_id', user.id);
      } catch (_) {}
      return {'success': true, 'error': null};
    } catch (e) {
      debugPrint('updateUserProfile error: $e');
      final msg = e.toString().toLowerCase();
      final isDuplicate = msg.contains('23505') ||
          msg.contains('unique') ||
          msg.contains('duplicate');
      return {
        'success': false,
        'error': isDuplicate ? 'duplicate' : null,
      };
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

  static Future<List<DrivingHistory>> getUserHistory() async {
    // Assuming 'driving_history' table exists?
    // If not, return empty.
    return [];
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
}
