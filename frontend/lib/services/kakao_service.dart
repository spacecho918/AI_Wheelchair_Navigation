import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class KakaoService {
  static const String _apiKey = '2ce06f247dfeac64311fd8be7691e3a8';
  static const String _baseUrl = 'https://dapi.kakao.com/v2/local';

  // Keyword Search
  static Future<List<Map<String, dynamic>>> searchKeyword(
    String query, {
    double? lat,
    double? lng,
    int? radius,
  }) async {
    if (query.isEmpty) return [];

    // sort=accuracy로 장소명 일치 우선, 위치 정보 포함하여 주변 결과 우선 확보
    String urlString =
        '$_baseUrl/search/keyword.json?query=$query&sort=accuracy';

    // 위치 정보가 있으면 파라미터 추가 (주변 검색 결과 확보용)
    if (lat != null && lng != null) {
      urlString += '&y=$lat&x=$lng';
      // radius가 없으면 기본 20km(20000m) 정도로 설정하여 넓은 범위 커버
      urlString += '&radius=${radius ?? 20000}';
    }

    final url = Uri.parse(urlString);
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'KakaoAK $_apiKey'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final documents = data['documents'] as List;

        final results = documents
            .map((doc) {
              return {
                'name': doc['place_name'],
                'address': doc['road_address_name'].isNotEmpty
                    ? doc['road_address_name']
                    : doc['address_name'],
                'lat': double.parse(doc['y']),
                'lng': double.parse(doc['x']),
                'category': doc['category_group_code'], // Add category code
                'phone': doc['phone'] ?? '',
                'url': doc['place_url'] ?? '',
              };
            })
            .toList()
            .cast<Map<String, dynamic>>();

        // Calculate distance client-side if user location is provided
        if (lat != null && lng != null) {
          for (var item in results) {
            double itemLat = item['lat'];
            double itemLng = item['lng'];
            double dist = Geolocator.distanceBetween(
              lat,
              lng,
              itemLat,
              itemLng,
            );
            item['distance'] = dist;
          }
        }

        // 검색어 정규화 (앞뒤 공백 제거)
        String normalizedQuery = query.trim();

        List<Map<String, dynamic>> primaryMatches =
            []; // 시작 일치, 정확 일치 통합 (거리순 정렬 위함)
        List<Map<String, dynamic>> secondaryMatches = []; // 중간 포함
        List<Map<String, dynamic>> othersMatches = [];

        for (var item in results) {
          String placeName = item['name']?.toString() ?? '';

          // 공백 제거된 이름으로 비교 (정확도 향상)
          String cleanName = placeName.replaceAll(' ', '');
          String cleanQuery = normalizedQuery.replaceAll(' ', '');

          if (placeName.startsWith(normalizedQuery) ||
              cleanName.startsWith(cleanQuery)) {
            // 1순위: 검색어로 시작하는 모든 결과 (정확 일치 포함)
            // 거리순으로 정렬하기 위해 통합
            primaryMatches.add(item);
          } else if (placeName.contains(normalizedQuery) ||
              cleanName.contains(cleanQuery)) {
            // 2순위: 포함
            secondaryMatches.add(item);
          } else {
            // 3순위: 기타
            othersMatches.add(item);
          }
        }

        // 카테고리별 가중치 (낮을수록 중요 -> 거리가 그대로 적용됨)
        // 지하철, 공공기관 등 랜드마크는 거리가 멀어도 상위에 노출
        // 음식점, 카페 등은 거리가 가까워야 노출 (가중치 페널티 부여)
        double getCategoryWeight(String? code) {
          switch (code) {
            case 'SW8': // 지하철역
            case 'PO3': // 공공기관
            case 'HP8': // 병원
            case 'SC4': // 학교
            case 'MT1': // 대형마트
            case 'AT4': // 관광명소
              return 1.0; // 중요도 높음 (원래 거리)

            case 'CT1': // 문화시설
            case 'BK9': // 은행
            case 'OL7': // 주유소
            case 'PK6': // 주차장
              return 1.5; // 보통

            case 'FD6': // 음식점
            case 'CE7': // 카페
            case 'CS2': // 편의점
            case 'AG2': // 중개업소
            case 'AC5': // 학원
            case 'PS3': // 유치원
            case 'AD5': // 숙박
              return 3.0; // 중요도 낮음 (거리에 3배 페널티)

            default:
              return 2.0; // 기타
          }
        }

        // 거리순 정렬 함수 (가중치 적용)
        int sortByWeightedDistance(
          Map<String, dynamic> a,
          Map<String, dynamic> b,
        ) {
          double distA = (a['distance'] is num)
              ? a['distance'].toDouble()
              : double.infinity;
          double distB = (b['distance'] is num)
              ? b['distance'].toDouble()
              : double.infinity;

          double weightA = getCategoryWeight(a['category']);
          double weightB = getCategoryWeight(b['category']);

          // 비교용 가중 거리 계산
          double scoreA = distA * weightA;
          double scoreB = distB * weightB;

          return scoreA.compareTo(scoreB);
        }

        primaryMatches.sort(sortByWeightedDistance);
        secondaryMatches.sort(sortByWeightedDistance);
        othersMatches.sort(sortByWeightedDistance);

        // 상용 앱 스타일 결합 (거리 우선)
        return [...primaryMatches, ...secondaryMatches, ...othersMatches];
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
