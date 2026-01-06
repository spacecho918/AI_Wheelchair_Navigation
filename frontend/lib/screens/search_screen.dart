import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gilbeot/services/kakao_service.dart';
import 'package:latlong2/latlong.dart'; // 좌표 전달용
import 'package:gilbeot/screens/favorites_edit_screen.dart';
import 'package:geolocator/geolocator.dart';

class SearchScreen extends StatefulWidget {
  final LatLng? searchLocation;
  final LatLng? userLocation;

  const SearchScreen({super.key, this.searchLocation, this.userLocation});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  // 검색 결과 리스트 (API 호출 결과)
  List<dynamic> _searchResults = [];

  // 최근 검색어 더미 데이터 (시안과 동일하게 구성)
  final List<Map<String, dynamic>> _recentSearches = [
    {
      'name': '집',
      'address': '서울 성동구 성수동 123',
      'type': 'saved', // 저장된 장소 (노란 별)
    },
    {
      'name': '서울시청',
      'address': '서울 중구 세종대로 110',
      'type': 'recent', // 최근 기록 (초록 핀)
    },
    {'name': '스타벅스', 'address': '서울 성동구 성수1가', 'type': 'recent'},
    {'name': '강남역', 'address': '서울 강남구 서초대로 396', 'type': 'recent'},
  ];

  bool _isLoading = false;
  Timer? _debounce;

  // Favorites Data
  final String _homeName = '집';
  String _homeAddress = '서울 성동구 성수동 123';
  String _workLabel = '회사'; // Can be '회사' or '학교'
  String _workAddress = '서울 중구 세종대로 110';

  @override
  void initState() {
    super.initState();
    // 화면이 열리면 바로 키보드 띄우기 (UX 편의성)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  // 검색 로직 (Kakao Local API)
  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Use searchLocation for sorting if available (center of map)
      double? lat = widget.searchLocation?.latitude;
      double? lng = widget.searchLocation?.longitude;

      final results = await KakaoService.searchKeyword(
        query,
        lat: lat,
        lng: lng,
      );
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // 텍스트가 다 지워지면 결과 초기화 (기본 화면으로 돌아감)
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchPlaces(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 전체 배경 흰색
      body: SafeArea(
        child: Column(
          children: [
            // 1. 상단 검색바 영역
            _buildSearchBar(),

            // 2. 메인 컨텐츠 영역 (조건부 렌더링)
            Expanded(
              child: _searchController.text.isEmpty
                  ? _buildDefaultView() // 텍스트 없으면: 최근 검색어 화면
                  : _buildSearchResults(), // 텍스트 있으면: 자동완성 결과 화면
            ),
          ],
        ),
      ),
    );
  }

  // --- 위젯 빌더 ---

  // 1. 검색바 위젯
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 5),
      color: Colors.white, // 배경색 유지
      child: Row(
        children: [
          // 뒤로가기 버튼 (맵 화면의 햄버거 버튼 스타일과 통일)
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.pop(context),
                child: const Icon(
                  Icons.arrow_back,
                  color: Color(0xFF354152),
                  size: 24, // 맵 화면 햄버거는 SVG 20, 아이콘은 보통 24가 적절
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 검색 입력창
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 15),
                  SvgPicture.asset(
                    'assets/search_icon.svg',
                    width: 20,
                    colorFilter: const ColorFilter.mode(
                      Colors.grey,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: '장소 검색...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF9EA6B8),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Color(0xFF9EA6B8),
                                  size: 20,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 14, color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 5),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. 기본 화면 (최근 검색어)
  Widget _buildDefaultView() {
    return ListView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 15, bottom: 20),
      children: [
        // 상단 칩 버튼 (집, 회사, 편집)
        Row(
          children: [
            _buildChip(
              icon: Icons.home_rounded,
              label: _homeName,
              color: const Color(0xFF00C853),
            ),
            const SizedBox(width: 8),
            _buildChip(
              icon: Icons.business_rounded,
              label: _workLabel,
              color: const Color(0xFF00C853),
            ),
            const Spacer(),
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _showEditFavoritesDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '편집',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // 최근 검색어 헤더
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '최근 검색',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF101727),
              ),
            ),
            TextButton(
              onPressed: () {
                // 모두 지우기 로직 (여기서는 더미 초기화 안함, 실제 구현 시 리스트 비우기)
                debugPrint("모두 지우기 클릭");
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                '모두 지우기',
                style: TextStyle(fontSize: 13, color: Color(0xFF9EA6B8)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // 최근 검색어 리스트 (더미 데이터)
        ..._recentSearches.map((item) => _buildRecentItem(item)),
      ],
    );
  }

  // 3. 자동완성 결과 화면
  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text('검색 결과가 없습니다.', style: TextStyle(color: Colors.grey[500])),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        // 검색 결과 헤더
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            '검색 결과',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF101727),
            ),
          ),
        ),

        // 결과 리스트 (카드 스타일 적용)
        ..._searchResults.map((place) {
          final name = place['name'];
          final fullAddress = place['address'];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  // KakaoService already returns doubles
                  final lat = place['lat'];
                  final lon = place['lng'];
                  Navigator.pop(context, {
                    'latlng': LatLng(lat, lon),
                    'name': name,
                    'address': fullAddress,
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8FDF0), // 연두색 배경
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getCategoryIcon(place['category']),
                          color: const Color(0xFF00C853), // 메인 그린 색상
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF101727),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              fullAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4A5565),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.userLocation != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _formatDistance(
                            widget.userLocation!,
                            place['lat'],
                            place['lng'],
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF00C853),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: Color(0xFF9EA6B8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // --- 작은 부품 위젯들 ---

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => debugPrint("$label 클릭됨"),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentItem(Map<String, dynamic> item) {
    bool isSaved = item['type'] == 'saved'; // 저장은 노란별, 최근은 초록핀

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => debugPrint("${item['name']} 선택됨"),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 아이콘 원형 배경
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSaved
                        ? const Color(0xFFFFF9C4)
                        : const Color(0xFFE8FDF0), // 노랑(집) vs 연두(최근)
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item['name'] == '집'
                        ? Icons.home
                        : (item['name'] == '회사' || item['name'] == '학교'
                              ? (item['name'] == '회사'
                                    ? Icons.work
                                    : Icons.school)
                              : (isSaved
                                    ? Icons.star
                                    : Icons.location_on_outlined)),
                    color: isSaved
                        ? const Color(0xFFFBC02D)
                        : const Color(0xFF00C853),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // 텍스트 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'],
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF101727),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['address'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4A5565),
                        ),
                      ),
                    ],
                  ),
                ),
                // 오른쪽 시계 아이콘
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: Color(0xFF9EA6B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditFavoritesDialog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FavoritesEditScreen(
          homeAddress: _homeAddress,
          workAddress: _workAddress,
          workLabel: _workLabel,
        ),
      ),
    );

    if (result != null && result is Map) {
      setState(() {
        _homeAddress = result['homeAddress'];
        _workAddress = result['workAddress'];
        _workLabel = result['workLabel'];
      });
    }
  }

  String _formatDistance(LatLng start, double endLat, double endLng) {
    double distanceInMeters = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      endLat,
      endLng,
    );

    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)}m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
    }
  }

  IconData _getCategoryIcon(String? categoryCode) {
    switch (categoryCode) {
      case 'MT1': // 대형마트
        return Icons.shopping_cart;
      case 'CS2': // 편의점
        return Icons.store;
      case 'PS3': // 어린이집, 유치원
        return Icons.child_care;
      case 'SC4': // 학교
        return Icons.school;
      case 'AC5': // 학원
        return Icons.menu_book;
      case 'PK6': // 주차장
        return Icons.local_parking;
      case 'OL7': // 주유소, 충전소
        return Icons.local_gas_station;
      case 'SW8': // 지하철역
        return Icons.subway;
      case 'BK9': // 은행
        return Icons.account_balance;
      case 'CT1': // 문화시설
        return Icons.theater_comedy;
      case 'AG2': // 중개업소
        return Icons.domain;
      case 'PO3': // 공공기관
        return Icons.location_city;
      case 'AT4': // 관광명소
        return Icons.attractions;
      case 'AD5': // 숙박
        return Icons.hotel;
      case 'FD6': // 음식점
        return Icons.restaurant;
      case 'CE7': // 카페
        return Icons.local_cafe;
      case 'HP8': // 병원
        return Icons.local_hospital;
      case 'PM9': // 약국
        return Icons.local_pharmacy;
      default:
        return Icons.location_on_outlined;
    }
  }
}
