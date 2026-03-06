import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gilbeot/services/kakao_service.dart';
import 'package:latlong2/latlong.dart'; // 좌표 전달용
import 'package:gilbeot/screens/saved_places_screen.dart';
import 'package:gilbeot/screens/route_search_screen.dart';
import 'package:geolocator/geolocator.dart';
import '../services/recent_searches_service.dart';
import 'package:gilbeot/widgets/common_toast.dart';
import '../services/auth_service.dart';

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

  bool _isLoading = false;
  Timer? _debounce;

  // Favorites Data
  final String _homeName = '집';
  String _homeAddress = '';
  String _workLabel = '회사'; // Can be '회사' or '학교'
  String _workAddress = '';

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _loadSavedPlaces();
    // 화면이 열리면 바로 키보드 띄우기 (UX 편의성)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  Future<void> _loadSavedPlaces() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    final metadata = user.userMetadata;
    final savedPlaces = metadata?['saved_places'] as List<dynamic>?;

    if (savedPlaces != null) {
      for (var place in savedPlaces) {
        if (place['type'] == 'home') {
          setState(() {
            _homeAddress = place['address'] ?? '';
          });
        } else if (place['type'] == 'work') {
          setState(() {
            _workLabel = place['name'] ?? '회사';
            if (_workLabel == '회사') {
              _workAddress = place['company_address'] ?? '';
            } else {
              _workAddress = place['school_address'] ?? '';
            }
          });
        }
      }
    }
  }

  Future<void> _loadRecentSearches() async {
    await RecentSearchesService.reload();
    if (mounted) {
      setState(() {});
    }
  }

  // 검색 로직 (Kakao Local API)
  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() => _searchResults = []);
      return;
    }

    if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error: $e");
      if (!mounted) return;
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
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).scaffoldBackgroundColor
          : Colors.white, // 전체 배경 흰색
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
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).scaffoldBackgroundColor
          : Colors.white, // 배경색 유지
      child: Row(
        children: [
          // 뒤로가기 버튼 (맵 화면의 햄버거 버튼 스타일과 통일)
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2A2A2A)
                  : Colors.white,
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
                child: Icon(
                  Icons.arrow_back,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF9CA3AF)
                      : Color(0xFF354152),
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
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2A2A2A)
                    : Colors.white,
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
                        hintStyle: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF9EA6B8),
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
                      style: TextStyle(fontSize: 14, color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black),
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
              onTap: () {
                if (_homeAddress.isNotEmpty) {
                  _showPlaceDetailSheet(context, {
                    'name': _homeName,
                    'address': _homeAddress,
                    'lat': 37.5445,
                    'lng': 127.0560,
                    'category': 'ETC',
                    'phone': '',
                    'url': '',
                  });
                }
              },
            ),
            const SizedBox(width: 8),
            _buildChip(
              icon: _workLabel == '회사' ? Icons.work : Icons.school,
              label: _workLabel,
              color: const Color(0xFF00C853),
              onTap: () {
                if (_workAddress.isNotEmpty) {
                  _showPlaceDetailSheet(context, {
                    'name': _workLabel,
                    'address': _workAddress,
                    'lat': 37.5665,
                    'lng': 126.9780,
                    'category': _workLabel == '회사' ? 'PO3' : 'SC4',
                    'phone': '',
                    'url': '',
                  });
                }
              },
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
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(
                '최근 검색',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF101727),
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                await RecentSearchesService.clearAll();
                setState(() {});
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

        // 최근 검색어 리스트
        ...RecentSearchesService.recentSearches.map(
          (item) => _buildRecentItem(item),
        ),
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
        Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            '검색 결과',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Color(0xFF101727),
            ),
          ),
        ),

        // 결과 리스트 (카드 스타일 적용)
        ..._searchResults.map((place) {
          final name = place['name'];
          final fullAddress = place['address'];

          return Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
            ),
            child: Material(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).cardColor
                  : Colors.white,
              child: InkWell(
                onTap: () async {
                  await RecentSearchesService.addSearch(place);
                  _showPlaceDetailSheet(context, place);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8FDF0), // 연두색 배경
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getCategoryIcon(place['category']),
                          color: const Color(0xFF00C853), // 메인 그린 색상
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Color(0xFF101727),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              fullAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF9CA3AF)
                                    : Colors.grey,
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
                      const SizedBox(width: 8),
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
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap ?? () => debugPrint("$label 클릭됨"),
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
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: Material(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).cardColor
            : Colors.white,
        child: InkWell(
          onTap: () => _showPlaceDetailSheet(context, item),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 4, // 리스트 형태라 패딩 조절
              vertical: 12,
            ),
            child: Row(
              children: [
                // 아이콘 원형 배경
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSaved
                        ? const Color(0xFFFFF9C4)
                        : const Color(0xFFE8FDF0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item['name'] == '집'
                        ? Icons.home_rounded
                        : (item['name'] == '회사' || item['name'] == '학교'
                              ? (_workLabel == '회사' ? Icons.work : Icons.school)
                              : (isSaved
                                    ? Icons.star
                                    : Icons.location_on_outlined)),
                    color: isSaved
                        ? const Color(0xFFFBC02D)
                        : const Color(0xFF00C853),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                // 텍스트 정보
                Expanded(
                  child: Text(
                    item['name'],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Color(0xFF101727),
                    ),
                  ),
                ),
                // 삭제 버튼 (X 아이콘)
                InkWell(
                  onTap: () async {
                    await RecentSearchesService.removeSearch(item);
                    setState(() {});
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : const Color(0xFF9EA6B8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditFavoritesDialog() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SavedPlacesScreen(initialTabIndex: 1),
      ),
    );
    // Since SavedPlacesScreen modifies local state via database or global state (assuming integration later),
    // and this prototype used local variables, we might simply refresh or rely on the fact that for now we are just switching screens.
    // However, the current SearchScreen uses _homeName, _homeAddress etc variables.
    // To properly reflect changes, we would need a callback or state management.
    // For now, as per instruction, we just navigate.
    // Ideally, we would reload data here.
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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      if (mounted) {
        CommonToast.show(context, '링크를 열 수 없습니다.');
      }
    }
  }

  void _showPlaceDetailSheet(BuildContext context, Map<String, dynamic> place) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).cardColor
                        : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row with Name and Close Button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category Icon
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8FDF0),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getCategoryIcon(place['category']),
                              color: const Color(0xFF00C853),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Name & Category
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  place['name'],
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white
                                        : const Color(0xFF101727),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _getCategoryName(place['category']),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF9CA3AF)
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Close Button
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Icon(
                              Icons.close,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF9CA3AF)
                                  : Color(0xFF9CA3AF),
                              size: 24,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Address
                      _buildDetailRow(
                        Icons.location_on_outlined,
                        place['address'] ?? '',
                      ),

                      // Distance (if available)
                      if (widget.userLocation != null &&
                          place['lat'] != null &&
                          place['lng'] != null) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          Icons.directions_walk,
                          '${_formatDistance(widget.userLocation!, place['lat'], place['lng'])} 거리',
                        ),
                      ],

                      // Phone (if available)
                      if (place['phone'] != null &&
                          place['phone'].isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          Icons.phone_outlined,
                          place['phone'],
                          isLink: true,
                          onTap: () {
                            _launchUrl('tel:${place['phone']}');
                          },
                        ),
                      ],

                      // URL (if available)
                      if (place['url'] != null && place['url'].isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          Icons.language,
                          '장소 상세 정보 보기',
                          isLink: true,
                          onTap: () {
                            _launchUrl(place['url']);
                          },
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Select Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RouteSearchScreen(
                                  userLocation: widget.userLocation,
                                  destination: {
                                    'name': place['name'],
                                    'address': place['address'],
                                    'latlng': LatLng(
                                      place['lat'] ?? 0.0,
                                      place['lng'] ?? 0.0,
                                    ),
                                  },
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C853),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            '도착지로 선택',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String text, {
    bool isLink = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: isLink ? onTap : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF9EA6B8)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: isLink
                    ? const Color(0xFF2979FF)
                    : Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : const Color(0xFF4A5565),
                decoration: isLink ? TextDecoration.underline : null,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryName(String? code) {
    switch (code) {
      case 'MT1':
        return '대형마트';
      case 'CS2':
        return '편의점';
      case 'PS3':
        return '어린이집/유치원';
      case 'SC4':
        return '학교';
      case 'AC5':
        return '학원';
      case 'PK6':
        return '주차장';
      case 'OL7':
        return '주유소/충전소';
      case 'SW8':
        return '지하철역';
      case 'BK9':
        return '은행';
      case 'CT1':
        return '문화시설';
      case 'AG2':
        return '중개업소';
      case 'PO3':
        return '공공기관';
      case 'AT4':
        return '관광명소';
      case 'AD5':
        return '숙박';
      case 'FD6':
        return '음식점';
      case 'CE7':
        return '카페';
      case 'HP8':
        return '병원';
      case 'PM9':
        return '약국';
      default:
        return '장소';
    }
  }
}
