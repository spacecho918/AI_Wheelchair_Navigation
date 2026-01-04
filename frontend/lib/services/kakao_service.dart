import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class KakaoService {
  static const String _apiKey = '2ce06f247dfeac64311fd8be7691e3a8';
  static const String _baseUrl = 'https://dapi.kakao.com/v2/local';

  // Keyword Search
  static Future<List<Map<String, dynamic>>> searchKeyword(String query) async {
    if (query.isEmpty) return [];

    final url = Uri.parse('$_baseUrl/search/keyword.json?query=$query');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'KakaoAK $_apiKey'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final documents = data['documents'] as List;

        return documents.map((doc) {
          return {
            'name': doc['place_name'],
            'address': doc['road_address_name'].isNotEmpty
                ? doc['road_address_name']
                : doc['address_name'],
            'lat': double.parse(doc['y']),
            'lng': double.parse(doc['x']),
          };
        }).toList();
      } else {
        debugPrint('Kakao Search Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Kakao Search Exception: $e');
      return [];
    }
  }

  // Reverse Geocoding (Coord -> Address)
  static Future<String> coord2Address(double lat, double lng) async {
    final url = Uri.parse('$_baseUrl/geo/coord2address.json?x=$lng&y=$lat');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'KakaoAK $_apiKey'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final documents = data['documents'] as List;

        if (documents.isNotEmpty) {
          final doc = documents[0];
          if (doc['road_address'] != null) {
            return doc['road_address']['address_name'];
          } else if (doc['address'] != null) {
            return doc['address']['address_name'];
          }
        }
        return '주소를 찾을 수 없음';
      } else {
        debugPrint('Kakao Geo Error: ${response.statusCode}');
        return '주소 변환 오류';
      }
    } catch (e) {
      debugPrint('Kakao Geo Exception: $e');
      return '주소 변환 실패';
    }
  }
}
