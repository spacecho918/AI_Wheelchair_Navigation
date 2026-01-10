import 'package:flutter/material.dart';

class SavedPlacesScreen extends StatefulWidget {
  const SavedPlacesScreen({super.key});

  @override
  State<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends State<SavedPlacesScreen> {
  // 0: 전체, 1: 즐겨찾기, 2: 저장됨
  int _selectedTabIndex = 0;

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
    {
      'type': 'saved',
      'name': '강남역',
      'address': '서울시 강남구 강남대로 지하 396',
      'time': '2시간 전',
    },
    {
      'type': 'saved',
      'name': '코엑스몰',
      'address': '서울시 강남구 영동대로 513',
      'time': '1일 전',
    },
    {
      'type': 'saved',
      'name': '서울대학교병원',
      'address': '서울시 종로구 연건동 101',
      'time': '5일 전',
    },
    {
      'type': 'saved',
      'name': '한강공원',
      'address': '서울시 영등포구 여의도동',
      'time': '5일 전',
    },
    {
      'type': 'saved',
      'name': '국립중앙박물관',
      'address': '서울시 용산구 서빙고로 137',
      'time': '7일 전',
    },
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
                  _buildTabButton(1, '즐겨찾기'),
                  const SizedBox(width: 8),
                  _buildTabButton(2, '저장됨'),
                ],
              ),
            ),

            // List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _filteredPlaces().length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
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
                  onPressed: () {
                    // TODO: Implement add place logic
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
                        '새 장소 추가',
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
                Text(
                  place['name'],
                  style: const TextStyle(
                    color: Color(0xFF101727),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  place['address'],
                  style: const TextStyle(
                    color: Color(0xFF4A5565),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (place['time'] != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    place['time'],
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Arrow
          const Icon(Icons.chevron_right, color: Color(0xFF9EA6B8), size: 20),
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
        return Icons.bookmark;
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
