import 'package:flutter/material.dart';
import 'package:gilbeot/screens/location_search_screen.dart';
import 'package:gilbeot/widgets/common_toast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class SavedPlacesScreen extends StatefulWidget {
  final int initialTabIndex;

  const SavedPlacesScreen({super.key, this.initialTabIndex = 0});

  @override
  State<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends State<SavedPlacesScreen> {
  // 0: 전체, 1: 내 장소, 2: 즐겨찾기
  int _selectedTabIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex;
    _loadSavedPlaces();
  }

  // Saved places data (initialized empty, loaded from server)
  List<Map<String, dynamic>> _allPlaces = [];

  Future<void> _loadSavedPlaces() async {
    final user = AuthService.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final metadata = user.userMetadata;
    final savedPlaces = metadata?['saved_places'] as List<dynamic>?;

    if (savedPlaces != null) {
      setState(() {
        _allPlaces = savedPlaces.map((e) {
          final map = Map<String, dynamic>.from(e);

          // 기존 work 데이터 마이그레이션 처리
          if (map['type'] == 'work') {
            map.putIfAbsent('company_address', () => map['address'] ?? '');
            map.putIfAbsent('company_lat', () => map['lat']);
            map.putIfAbsent('company_lng', () => map['lng']);
            map.putIfAbsent('school_address', () => '');
            map.putIfAbsent('school_lat', () => null);
            map.putIfAbsent('school_lng', () => null);
          }

          return map;
        }).toList();

        _isLoading = false;
      });
    } else {
      setState(() {
        _allPlaces = [
          {'type': 'home', 'name': '집', 'address': ''},
          {
            'type': 'work',
            'name': '회사',
            'company_address': '',
            'company_lat': null,
            'company_lng': null,
            'school_address': '',
            'school_lat': null,
            'school_lng': null,
          },
        ];
        _isLoading = false;
      });
    }
  }

  Future<void> _savePlacesToServer() async {
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'saved_places': _allPlaces}),
      );
    } catch (e) {
      debugPrint('Error saving places: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF354152)),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          '저장된 장소',
          style: TextStyle(
            color: Color(0xFF101727),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  minimumSize: const Size(64, 32),
                ),
                child: const Text('저장'),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  _buildTabButton(0, '전체'),
                  const SizedBox(width: 8),
                  _buildTabButton(1, '내 장소'),
                  const SizedBox(width: 8),
                  _buildTabButton(2, '즐겨찾기'),
                ],
              ),
            ),

            // List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _filteredPlaces().length,
                separatorBuilder: (context, index) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Divider(height: 1, color: Color(0xFFE5E7EB)),
                ),
                itemBuilder: (context, index) =>
                    _buildPlaceItem(_filteredPlaces()[index]),
              ),
            ),

            // Add Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LocationSearchScreen(),
                      ),
                    );

                    if (result != null && result is Map) {
                      setState(() {
                        _allPlaces.add({
                          'type': 'saved',
                          'name': result['name'],
                          'address': result['address'],
                          'lat': result['latlng']?.latitude,
                          'lng': result['latlng']?.longitude,
                        });
                      });
                      await _savePlacesToServer();
                      CommonToast.show(context, '장소가 추가되었습니다.');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        '새 즐겨찾기 추가',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePlace(Map<String, dynamic> place) async {
    setState(() {
      final index = _allPlaces.indexOf(place);
      if (index == -1) return;

      if (place['type'] == 'home') {
        _allPlaces[index] = {
          ...place,
          'address': '',
          'lat': null,
          'lng': null,
        };
      }
      else if (place['type'] == 'work') {
        _allPlaces[index] = {
          ...place,
          'company_address': '',
          'company_lat': null,
          'company_lng': null,
          'school_address': '',
          'school_lat': null,
          'school_lng': null,
        };
      }
      else {
        _allPlaces.remove(place);
      }
    });

    await _savePlacesToServer();
    CommonToast.show(context, '장소가 삭제되었습니다.');
  }

  Widget _buildTabButton(int index, String text) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF00C853)
                : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF6B7280),
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceItem(Map<String, dynamic> place) {
    bool isSaved =
        place['type'] == 'home' ||
        place['type'] == 'work' ||
        place['type'] == 'saved';

    // 학교 , 회사 분리
    String address = '';
    double? lat;
    double? lng;
    if (place['type'] == 'work') {
      if (place['name'] == '회사') {
        address = place['company_address'] ?? '';
        lat = place['company_lat'];
        lng = place['company_lng'];
      } else {
        address = place['school_address'] ?? '';
        lat = place['school_lat'];
        lng = place['school_lng'];
      }
    } else {
      address = place['address'] ?? '';
      lat = place['lat'];
      lng = place['lng'];
    }

    return InkWell(
      onTap: () {
        // Only return if the place has an address
        if (address.isNotEmpty) {
          Navigator.pop(context, {
            'name': place['name'],
            'address': address,
            'lat': lat,
            'lng': lng,
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Icon Box
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSaved
                    ? const Color(0xFFFFF9C4)
                    : const Color(
                        0xFFE8FDF0,
                      ), // Yellow (Saved) vs Green (Others)
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIconData(place),
                color: isSaved
                    ? const Color(0xFFFBC02D)
                    : const Color(0xFF00C853),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 회사, 학교 토글
                  if (isSaved && place['type'] == 'work')
                    GestureDetector(
                      onTap: () async {
                        setState(() {
                          place['name'] =
                          place['name'] == '회사' ? '학교' : '회사';
                        });
                        await _savePlacesToServer();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            place['name'],
                            style: const TextStyle(
                              color: Color(0xFF101727),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.swap_horiz,
                            size: 14,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      place['name'],
                      style: const TextStyle(
                        color: Color(0xFF101727),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                  const SizedBox(height: 2),

                  if (address.isNotEmpty)
                    Text(
                      address,
                      style: const TextStyle(
                        color: Color(0xFF4A5565),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Edit Button
            if (place['type'] == 'home' || place['type'] == 'work')
              IconButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LocationSearchScreen(),
                    ),
                  );

                  if (result != null && result is Map) {
                    setState(() {
                      final index = _allPlaces.indexOf(place);
                      if (index != -1) {

                        if (place['type'] == 'work') {
                          if (place['name'] == '회사') {
                            _allPlaces[index] = {
                              ...place,
                              'company_address': result['address'],
                              'company_lat': result['latlng']?.latitude,
                              'company_lng': result['latlng']?.longitude,
                            };
                          } else {
                            _allPlaces[index] = {
                              ...place,
                              'school_address': result['address'],
                              'school_lat': result['latlng']?.latitude,
                              'school_lng': result['latlng']?.longitude,
                            };
                          }
                        } else {
                          _allPlaces[index] = {
                            ...place,
                            'address': result['address'],
                            'lat': result['latlng']?.latitude,
                            'lng': result['latlng']?.longitude,
                          };
                        }
                      }
                    });

                    await _savePlacesToServer();
                    CommonToast.show(context, '장소가 수정되었습니다.');
                  }
                },
                icon: const Icon(Icons.edit, color: Color(0xFF9EA6B8)),
              ),

            if (place['type'] == 'saved')
              IconButton(
                onPressed: () => _deletePlace(place),
                icon: const Icon(Icons.close, color: Color(0xFF9EA6B8)),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(Map<String, dynamic> place) {
    switch (place['type']) {
      case 'home':
        return Icons.home;
      case 'work':
        return Icons.work;
      case 'saved':
        return Icons.star;
      default:
        return Icons.location_on_outlined;
    }
  }

  List<Map<String, dynamic>> _filteredPlaces() {
    if (_selectedTabIndex == 0) return _allPlaces;
    if (_selectedTabIndex == 1) {
      // Favorites: home and work only
      return _allPlaces
          .where((p) => p['type'] == 'home' || p['type'] == 'work')
          .toList();
    }
    if (_selectedTabIndex == 2) {
      // Saved: everything else (bookmark)
      return _allPlaces.where((p) => p['type'] == 'saved').toList();
    }
    return [];
  }
}
