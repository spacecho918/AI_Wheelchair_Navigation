import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart'; // 좌표 전달용
import 'package:gilbeot/screens/favorites_edit_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

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
  String _homeName = '집';
  String _homeAddress = '서울 성동구 성수동 123';
  String _workLabel = '회사'; // Can be '회사' or '학교'
  String _workAddress = '서울 중구 세종대로 110';
  bool _isWorkLabelCompany = true; // Toggle state

  @override
  void initState() {
    super.initState();
    // 화면이 열리면 바로 키보드 띄우기 (UX 편의성)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  // 검색 로직 (Nominatim API)
  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=$query&format=json&polygon_geojson=1&addressdetails=1&accept-language=ko',
    );

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'GilbeotApp/1.0 (com.example.gilbeot)'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _searchResults = json.decode(response.body);
          _isLoading = false;
        });
      }
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
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 10),
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
                  color: Colors.black54,
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
                  const Icon(
                    Icons.search,
                    color: Colors.grey,
                    size: 24,
                  ), // SvgPicture 대신 Icon 사용 (일관성)
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: '장소 검색...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF717182),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.grey,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        // 상단 칩 버튼 (집, 회사, 편집)
        Row(
          children: [
            _buildChip(
              icon: Icons.star_border,
              label: _homeName,
              color: const Color(0xFF00C853),
            ),
            const SizedBox(width: 8),
            _buildChip(
              icon: Icons.star_border,
              label: _workLabel,
              color: const Color(0xFF00C853),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _showEditFavoritesDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '편집',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 30),

        // 최근 검색어 헤더
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '최근 검색',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            GestureDetector(
              onTap: () {
                // 모두 지우기 로직 (여기서는 더미 초기화 안함, 실제 구현 시 리스트 비우기)
                debugPrint("모두 지우기 클릭");
              },
              child: Text(
                '모두 지우기',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
              color: Colors.black87,
            ),
          ),
        ),

        // 결과 리스트 (카드 스타일 적용)
        ..._searchResults.map((place) {
          final name = place['display_name'].split(',')[0]; // 앞부분만
          final fullAddress = place['display_name'];

          return GestureDetector(
            onTap: () {
              final lat = double.parse(place['lat']);
              final lon = double.parse(place['lon']);
              Navigator.pop(context, {
                'latlng': LatLng(lat, lon),
                'name': name,
                'address': fullAddress,
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8FDF0), // 연두색 배경
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFF00C853), // 메인 그린 색상
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
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fullAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
                ],
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
    return GestureDetector(
      onTap: () => debugPrint("$label 클릭됨"),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
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
    );
  }

  Widget _buildRecentItem(Map<String, dynamic> item) {
    bool isSaved = item['type'] == 'saved'; // 저장은 노란별, 최근은 초록핀

    return GestureDetector(
      onTap: () => debugPrint("${item['name']} 선택됨"),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
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
                isSaved ? Icons.star : Icons.location_on_outlined,
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
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['address'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            // 오른쪽 시계 아이콘
            Icon(Icons.access_time, size: 16, color: Colors.grey[400]),
          ],
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
        _isWorkLabelCompany = (_workLabel == '회사');
      });
    }
  }
}
