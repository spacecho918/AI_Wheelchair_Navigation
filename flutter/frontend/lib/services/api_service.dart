import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  // 서버 주소 설정
  // 에뮬레이터: 10.0.2.2:8000
  // 실기기: PC의 내부 IP (예: 192.168.0.x:8000)
  // 웹: localhost:8000
  static String get baseUrl {
    if (kIsWeb) return "http://localhost:8000";
    if (Platform.isAndroid) return "http://10.0.2.2:8000"; 
    return "http://localhost:8000";
  }

  /// 이미지를 분석하여 장애물 유형을 감지합니다.
  static Future<Map<String, dynamic>> analyzeImage(String imagePath) async {
    final uri = Uri.parse('$baseUrl/report/analyze');
    
    var request = http.MultipartRequest('POST', uri);
    
    if (kIsWeb) {
      // 웹에서는 파일 경로 대신 바이트로 처리해야 할 수도 있음 (이 구현은 모바일/데스크탑 로컬 파일 기준)
      // 웹 지원이 필요하면 http.MultipartFile.fromBytes 사용 필요
      throw UnimplementedError("Web image upload not fully implemented yet");
    } else {
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // 성공: JSON 파싱
        // 예: {"success": true, "detected_type": "stairs", ...}
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded;
      } else {
        // 실패
        debugPrint('Image Analysis Failed: ${response.statusCode} ${response.body}');
        return {
          "success": false,
          "message": "서버 오류: ${response.statusCode}"
        };
      }
    } catch (e) {
      debugPrint('Connection Error: $e');
      return {
        "success": false,
        "message": "연결 오류: $e"
      };
    }
  }

  /// 장애물 신고를 제출합니다.
  static Future<Map<String, dynamic>> submitReport({
    required double latitude,
    required double longitude,
    required String obstacleType,
    String description = "",
    String? imagePath,
  }) async {
    final uri = Uri.parse('$baseUrl/report/submit');
    
    var request = http.MultipartRequest('POST', uri);
    
    // 폼 데이터 추가
    request.fields['latitude'] = latitude.toString();
    request.fields['longitude'] = longitude.toString();
    request.fields['obstacle_type'] = obstacleType;
    request.fields['description'] = description;
    
    // 이미지 추가 (선택사항)
    if (imagePath != null && imagePath.isNotEmpty) {
      if (!kIsWeb) {
        request.files.add(await http.MultipartFile.fromPath('image', imagePath));
      }
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded;
      } else {
        debugPrint('Report Submission Failed: ${response.statusCode} ${response.body}');
        return {
          "success": false,
          "message": "제출 실패 (${response.statusCode})"
        };
      }
    } catch (e) {
      debugPrint('Submit Error: $e');
      return {
        "success": false,
        "message": "연결 오류: $e"
      };
    }
  }

  /// 경로를 탐색합니다.
  static Future<Map<String, dynamic>> findRoute({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    required String mode, // 'short', 'safe', 'optimal'
    String wheelchairType = 'manual', // 'electric', 'manual', 'helper', 'none'
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
      } else {
        debugPrint('Route Search Failed: ${response.statusCode} ${response.body}');
        return {
          "success": false,
          "message": "경로 탐색 실패 (${response.statusCode})"
        };
      }
    } catch (e) {
      debugPrint('Route Connection Error: $e');
      return {
        "success": false,
        "message": "연결 오류: $e"
      };
    }
  }
}
