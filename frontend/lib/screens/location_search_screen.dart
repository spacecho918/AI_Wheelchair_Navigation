import 'package:flutter/material.dart';
import 'package:gilbeot/services/kakao_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:gilbeot/screens/location_adjust_screen.dart';

import 'package:gilbeot/widgets/custom_back_button.dart';

class LocationSearchScreen extends StatefulWidget {
  final LatLng? searchLocation;
  final LatLng? userLocation;
  final bool autofocus;

  const LocationSearchScreen({
    super.key,
    this.searchLocation,
    this.userLocation,
    this.autofocus = false,
  });

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isLoading = false;

  // Recent searches synced with SearchScreen
  List<Map<String, dynamic>> _recentSearches = [
    {'name': '집', 'address': '서울 성동구 성수동 123', 'type': 'saved'},
    {'name': '서울시청', 'address': '서울 중구 세종대로 110', 'type': 'recent'},
    {'name': '스타벅스', 'address': '서울 성동구 성수1가', 'type': 'recent'},
    {'name': '강남역', 'address': '서울 강남구 서초대로 396', 'type': 'recent'},
  ];

  @override
  void initState() {
    super.initState();
  }

  // Search logic (Kakao Local API)
  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Use searchLocation for sorting if available
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

  // Get Current Location
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permission denied.');
        }
      }

      Position position = await Geolocator.getCurrentPosition();

      // Reverse Geocoding via Kakao API
      String formattedAddress = await KakaoService.coord2Address(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        Navigator.pop(context, {
          'latlng': LatLng(position.latitude, position.longitude),
          'name': '현위치',
          'address': formattedAddress,
        });
      }
    } catch (e) {
      debugPrint("Location Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('위치를 가져올 수 없습니다: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    // Debounce logic could be added here similar to SearchScreen
    _searchPlaces(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // 1. Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const CustomBackButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(0x1A),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        autofocus: widget.autofocus,
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: '장소, 주소 검색',
                          hintStyle: const TextStyle(
                            color: Color(0xFF9EA6B8),
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.location_on_outlined,
                            color: Color(0xFF00C853),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Color(0xFF9EA6B8),
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 2. Action Buttons (Current Location, Map Select, Saved)
            // Only show if search is empty
            if (_searchController.text.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildActionButton(
                      icon: Icons.near_me_outlined,
                      label: '현위치',
                      color: const Color(0xFF00C853),
                      onTap: _getCurrentLocation,
                    ),
                    _buildActionButton(
                      icon: Icons.map_outlined,
                      label: '지도에서 선택',
                      color: const Color(0xFF2979FF),
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LocationAdjustScreen(
                              savedLocation: LatLng(
                                37.5665,
                                126.9780,
                              ), // Default to Seoul
                              savedAddress: '위치를 선택해주세요',
                            ),
                          ),
                        );

                        if (result != null && result is Map && mounted) {
                          // Return result to MyPlacesEditScreen
                          Navigator.pop(context, {
                            'latlng': result['latlng'],
                            'name':
                                '지도 선택', // Or fetch address name from result
                            'address': result['address'],
                          });
                        }
                      },
                    ),
                    _buildActionButton(
                      icon: Icons.bookmark_border,
                      label: '저장',
                      color: const Color(0xFFFFAB00),
                      onTap: () {
                        // TODO: Show saved
                      },
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),

            // 3. Content (Recent Searches or Search Results)
            Expanded(
              child: Container(
                color: Colors.white,
                child: _searchController.text.isEmpty
                    ? _buildRecentSearches()
                    : _buildSearchResults(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF101727),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearches() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '최근 검색',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF101727),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _recentSearches.clear();
                });
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                '모두 지우기',
                style: TextStyle(fontSize: 12, color: Color(0xFF9EA6B8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._recentSearches.map((item) => _buildRecentItem(item)),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final place = _searchResults[index];
        final name = place['name'];
        final address = place['address'];

        return Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
          ),
          child: Material(
            color: Colors.white,
            child: InkWell(
              onTap: () {
                final lat = place['lat'];
                final lon = place['lng'];
                Navigator.pop(context, {
                  'latlng': LatLng(lat, lon),
                  'name': name,
                  'address': address,
                });
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
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF101727),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
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
      },
    );
  }

  Widget _buildRecentItem(Map<String, dynamic> item) {
    bool isSaved = item['type'] == 'saved';

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: () {
            // Return selected item
            Navigator.pop(context, {
              'latlng': const LatLng(
                37.5665,
                126.9780,
              ), // Dummy coords for list items if real data missing
              'name': item['name'],
              'address': item['address'],
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Row(
              children: [
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
                              ? (item['name'] == '회사'
                                    ? Icons.work
                                    : Icons.school)
                              : (isSaved
                                    ? Icons.star
                                    : _getCategoryIcon(item['category']))),
                    color: isSaved
                        ? const Color(0xFFFBC02D)
                        : const Color(0xFF00C853),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item['name'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: Color(0xFF101727),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _recentSearches.remove(item);
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Color(0xFF9EA6B8),
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
