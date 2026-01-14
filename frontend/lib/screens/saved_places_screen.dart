import 'package:flutter/material.dart';
import 'package:gilbeot/screens/location_search_screen.dart';

class SavedPlacesScreen extends StatefulWidget {
  final int initialTabIndex;

  const SavedPlacesScreen({super.key, this.initialTabIndex = 0});

  @override
  State<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends State<SavedPlacesScreen> {
  // 0: 전체, 1: 내 장소, 2: 즐겨찾기
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex;
  }

  // Mock Data
  final List<Map<String, dynamic>> _allPlaces = [
    {
      'type': 'home',
      'name': '집',
      'address': '서울시 강남구 역삼동 123-45',
      'icon': 'assets/home_icon.svg',
    },
    {
      'type': 'work',
      'name': '회사',
      'address': '서울시 서초구 서초동 567-89',
      'icon':
          'assets/document_icon.svg', // Using document as placeholder for work if no suitcase
    },
    {'type': 'saved', 'name': '강남역', 'address': '서울시 강남구 강남대로 지하 396'},
    {'type': 'saved', 'name': '코엑스몰', 'address': '서울시 강남구 영동대로 513'},
    {'type': 'saved', 'name': '서울대학교병원', 'address': '서울시 종로구 연건동 101'},
    {'type': 'saved', 'name': '한강공원', 'address': '서울시 영등포구 여의도동'},
    {'type': 'saved', 'name': '국립중앙박물관', 'address': '서울시 용산구 서빙고로 137'},
  ];

  @override
  Widget build(BuildContext context) {
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
                        });
                      });
                      _showToast('장소가 추가되었습니다.');
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

  void _deletePlace(Map<String, dynamic> place) {
    setState(() {
      if (place['type'] == 'home' || place['type'] == 'work') {
        final index = _allPlaces.indexOf(place);
        if (index != -1) {
          _allPlaces[index] = {...place, 'address': ''};
        }
      } else {
        _allPlaces.remove(place);
      }
    });

    _showToast('장소가 삭제되었습니다.');
  }

  void _showToast(String message) {
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100.0,
        left: 0.0,
        right: 0.0,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
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

    return Container(
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
                  : const Color(0xFFE8FDF0), // Yellow (Saved) vs Green (Others)
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
                if (isSaved && place['type'] == 'work')
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        place['name'] = place['name'] == '회사' ? '학교' : '회사';
                      });
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
                if (place['address'] != null && place['address'].isNotEmpty)
                  Text(
                    place['address'],
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
                      bool isHomeOrWork =
                          place['type'] == 'home' || place['type'] == 'work';
                      _allPlaces[index] = {
                        ...place,
                        'name': isHomeOrWork ? place['name'] : result['name'],
                        'address': result['address'],
                      };
                    }
                  });
                  _showToast('장소가 수정되었습니다.');
                }
              },
              icon: const Icon(Icons.edit, color: Color(0xFF9EA6B8)),
            ),
          // Delete Button
          if (place['type'] == 'saved')
            IconButton(
              onPressed: () => _deletePlace(place),
              icon: const Icon(Icons.close, color: Color(0xFF9EA6B8)),
            ),
        ],
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
