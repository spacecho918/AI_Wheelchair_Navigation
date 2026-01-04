import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:gilbeot/screens/location_adjust_screen.dart';

import 'package:gilbeot/widgets/custom_back_button.dart';

class LocationSearchScreen extends StatefulWidget {
  const LocationSearchScreen({super.key});

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isLoading = false;

  // Recent searches synced with SearchScreen
  final List<Map<String, dynamic>> _recentSearches = [
    {'name': '집', 'address': '서울 성동구 성수동 123', 'type': 'saved'},
    {'name': '서울시청', 'address': '서울 중구 세종대로 110', 'type': 'recent'},
    {'name': '스타벅스', 'address': '서울 성동구 성수1가', 'type': 'recent'},
    {'name': '강남역', 'address': '서울 강남구 서초대로 396', 'type': 'recent'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  // Search logic (Nominatim) - Reused from SearchScreen
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

  // Get Current Location
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied)
          throw Exception('Permission denied.');
      }

      Position position = await Geolocator.getCurrentPosition();

      // Reverse Geocoding via Nominatim
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1&accept-language=ko',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'GilbeotApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final addressObj = data['address'];

        String formattedAddress = data['display_name'] ?? '주소 없음';

        // Parse City Gu Dong
        if (addressObj != null) {
          String city = addressObj['city'] ?? addressObj['province'] ?? '';
          String district =
              addressObj['borough'] ?? addressObj['district'] ?? '';
          String dong =
              addressObj['quarter'] ?? addressObj['neighbourhood'] ?? '';

          if (city.isNotEmpty || district.isNotEmpty || dong.isNotEmpty) {
            formattedAddress = "$city $district $dong".trim();
          }
        }

        if (mounted) {
          Navigator.pop(context, {
            'latlng': LatLng(position.latitude, position.longitude),
            'name': '현위치',
            'address': formattedAddress,
          });
        }
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
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: '장소, 주소 검색',
                          hintStyle: const TextStyle(
                            color: Colors.grey,
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
                                    color: Colors.grey,
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

            const SizedBox(height: 24),

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
                              isSelectionMode: true,
                            ),
                          ),
                        );

                        if (result != null && result is Map && mounted) {
                          // Return result to FavoritesEditScreen
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

            const SizedBox(height: 24),

            // 3. Content (Recent Searches or Search Results)
            Expanded(
              child: Container(
                color: const Color(
                  0xFFF9FAFB,
                ), // Light background for list area
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
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '최근 검색',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF101727),
              ),
            ),
            TextButton(
              onPressed: () {
                debugPrint("모두 지우기 클릭");
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                '모두 지우기',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
        final name = place['display_name'].split(',')[0];
        final address = place['display_name'];

        return InkWell(
          onTap: () {
            final lat = double.parse(place['lat']);
            final lon = double.parse(place['lon']);
            Navigator.pop(context, {
              'latlng': LatLng(lat, lon),
              'name': name,
              'address': address,
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.grey, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
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
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentItem(Map<String, dynamic> item) {
    bool isSaved = item['type'] == 'saved';

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
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSaved
                        ? const Color(0xFFFFF9C4)
                        : const Color(0xFFE8FDF0),
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
                Icon(Icons.access_time, size: 16, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
