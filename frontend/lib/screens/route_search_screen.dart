import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:gilbeot/screens/location_search_screen.dart'; // 장소 검색 화면
import 'package:gilbeot/screens/navigation_screen.dart';
import 'package:gilbeot/services/kakao_service.dart';
import 'package:latlong2/latlong.dart';

class RouteSearchScreen extends StatefulWidget {
  final LatLng? userLocation;
  final Map<String, dynamic>? destination;

  const RouteSearchScreen({super.key, this.userLocation, this.destination});

  @override
  State<RouteSearchScreen> createState() => _RouteSearchScreenState();
}

class _RouteSearchScreenState extends State<RouteSearchScreen> {
  // 장소 데이터 (이름, 주소, 좌표)
  Map<String, dynamic>? _startPlace;
  Map<String, dynamic>? _endPlace;

  // "현재 위치"를 나타내는 특수 상수
  final Map<String, dynamic> _currentLocationPlace = {
    'name': '현재 위치',
    'address': '',
    'isCurrentLocation': true,
  };

  int _selectedRouteIndex = 0; // 0: 추천, 1: 최단, 2: 안전
  PageController? _pageController;
  double? _currentViewportFraction;

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // 1. 출발지 기본 값은 현재위치
    _startPlace = _currentLocationPlace;
    _fetchCurrentAddress();

    // 2. 도착지가 전달되었으면 설정
    if (widget.destination != null) {
      _endPlace = widget.destination;
    }
  }

  Future<void> _fetchCurrentAddress() async {
    if (widget.userLocation != null) {
      try {
        String address = await KakaoService.coord2Address(
          widget.userLocation!.latitude,
          widget.userLocation!.longitude,
        );
        if (mounted) {
          setState(() {
            _startPlace!['address'] = address;
          });
        }
      } catch (e) {
        debugPrint('Error fetching address: $e');
      }
    }
  }

  // 장소 선택 화면으로 이동
  Future<void> _selectLocation(bool isStart) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationSearchScreen(
          userLocation: widget.userLocation,
          autofocus: true, // 바로 입력 가능하도록 설정
        ),
      ),
    );

    if (result != null && result is Map) {
      setState(() {
        if (isStart) {
          _startPlace = result.cast<String, dynamic>();
        } else {
          _endPlace = result.cast<String, dynamic>();
        }
      });
    }
  }

  // 출발지-도착지 교환
  void _swapLocations() {
    setState(() {
      final temp = _startPlace;
      _startPlace = _endPlace;
      _endPlace = temp;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 반응형 ViewportFraction 계산
    final screenWidth = MediaQuery.of(context).size.width;
    final targetCardWidth = 320.0;
    // 카드 3개 너비(320*3) + 간격(12*3) + 여유공간(40) = 1036
    final useRowLayout = screenWidth > 1036;
    final fraction = (targetCardWidth / screenWidth).clamp(0.2, 0.85);

    if (!useRowLayout &&
        (_pageController == null ||
            (_currentViewportFraction != null &&
                (fraction - _currentViewportFraction!).abs() > 0.001))) {
      _pageController?.dispose();
      _pageController = PageController(
        viewportFraction: fraction,
        initialPage: _selectedRouteIndex,
      );
      _currentViewportFraction = fraction;
    }

    return Scaffold(
      backgroundColor: Colors.white, // 배경색 (흰색)
      body: SafeArea(
        child: Column(
          children: [
            // 상단 입력 카드 영역
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Column(
                              children: [
                                // 출발지 입력 필드
                                _buildLocationField(
                                  isStart: true,
                                  place: _startPlace,
                                  onTap: () => _selectLocation(true),
                                ),
                                const SizedBox(height: 8),
                                // 도착지 입력 필드
                                _buildLocationField(
                                  isStart: false,
                                  place: _endPlace,
                                  onTap: () => _selectLocation(false),
                                ),
                              ],
                            ),

                            // 3. switch 아이콘 (오른쪽 떠있는 버튼)
                            Positioned(
                              right: 24,
                              top: 31, // 상하 중앙 정렬 (출발지+도착지 필드 중앙)
                              child: Container(
                                width: 36, // 조금 더 키움
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.grey[300]!),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: _swapLocations,
                                    child: Center(
                                      child: Icon(
                                        Icons.swap_vert,
                                        color: Colors.grey[600],
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 4. x 아이콘 (닫기)
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.black54),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 최근 검색 (더미 UI)
            // 조건부 렌더링: 출발지/도착지 모두 설정되면 경로 카드 표시
            // 그렇지 않으면 최근 검색 표시
            if (_startPlace != null && _endPlace != null)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // 고정 높이 350px 기준으로 비율 계산
                    // 가로 넓은 화면에서도 최소한 버튼이 보이도록 최소값 보장
                    final fixedHeight = 350.0;
                    final initialSize = (fixedHeight / constraints.maxHeight)
                        .clamp(0.4, 0.9); // 최소 40%는 보이도록
                    final minSize = (250.0 / constraints.maxHeight).clamp(
                      0.35, // 최소 35% 보장
                      0.5,
                    );

                    return DraggableScrollableSheet(
                      initialChildSize: initialSize,
                      minChildSize: minSize,
                      maxChildSize: 0.95,
                      snap: true,
                      snapSizes: [minSize, initialSize, 0.8],
                      builder: (context, scrollController) {
                        return Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 20,
                                offset: Offset(0, -5),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            controller: scrollController,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                // Handle Bar
                                Center(
                                  child: Container(
                                    width: 40,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Title & Subtitle
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '경로 선택',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF101727),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '휠체어 접근 가능한 경로를 선택하세요',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(
                                            0xFF4A5565,
                                          ), // Unified textGrey
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // 경로 카드 캐러셀
                                Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: SizedBox(
                                    height: 140,
                                    child: useRowLayout
                                        ? Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: List.generate(3, (index) {
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                    ),
                                                child: SizedBox(
                                                  width: 320,
                                                  child:
                                                      _buildSelectableRouteCard(
                                                        index,
                                                      ),
                                                ),
                                              );
                                            }),
                                          )
                                        : ScrollConfiguration(
                                            behavior:
                                                ScrollConfiguration.of(
                                                  context,
                                                ).copyWith(
                                                  dragDevices: {
                                                    PointerDeviceKind.touch,
                                                    PointerDeviceKind.mouse,
                                                  },
                                                ),
                                            child: PageView.builder(
                                              controller: _pageController,
                                              padEnds: false, // 왼쪽 정렬
                                              physics:
                                                  const BouncingScrollPhysics(),
                                              itemCount: 3,
                                              onPageChanged: (index) {
                                                setState(() {
                                                  _selectedRouteIndex = index;
                                                });
                                              },
                                              itemBuilder: (context, index) {
                                                return _buildSelectableRouteCard(
                                                  index,
                                                );
                                              },
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // 인디케이터 (Dots)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(3, (index) {
                                    return AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _selectedRouteIndex == index
                                            ? const Color(0xFF00C853)
                                            : Colors.grey[300],
                                      ),
                                    );
                                  }),
                                ),

                                const SizedBox(height: 12),

                                // 경로 안내 시작 버튼
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    height: 50, // 높이 약간 줄임
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00C853),
                                      borderRadius: BorderRadius.circular(25),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF00C853,
                                          ).withValues(alpha: 0.3),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(25),
                                        onTap: () {
                                          // 네비게이션 시작
                                          String routeType;
                                          String time;
                                          String distance;

                                          if (_selectedRouteIndex == 0) {
                                            routeType = '추천 경로';
                                            time = '15분';
                                            distance = '2.4km';
                                          } else if (_selectedRouteIndex == 1) {
                                            routeType = '최단 경로';
                                            time = '12분';
                                            distance = '1.8km';
                                          } else {
                                            routeType = '안전 경로';
                                            time = '18분';
                                            distance = '3.1km';
                                          }

                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  NavigationScreen(
                                                    routeType: routeType,
                                                    estimatedTime: time,
                                                    totalDistance: distance,
                                                    startLocation:
                                                        _startPlace?['latlng']
                                                            as LatLng?,
                                                    endLocation:
                                                        _endPlace?['latlng']
                                                            as LatLng?,
                                                  ),
                                              settings: const RouteSettings(
                                                name: 'navigation',
                                              ),
                                            ),
                                          );
                                        },
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Icon(
                                              Icons.navigation_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              '경로 안내 시작',
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
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              )
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '최근 검색',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF101727),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            '모두 지우기',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9EA6B8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // 여기에 최근 검색 목록 추가 가능
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationField({
    required bool isStart,
    required Map<String, dynamic>? place,
    required VoidCallback onTap,
  }) {
    String text;
    Color textColor;

    if (place != null) {
      if (place['isCurrentLocation'] == true &&
          place['address'] != null &&
          place['address'].isNotEmpty) {
        text = '현위치: ${place['address']}';
      } else {
        text = place['name'];
      }
      textColor = Colors.black87;
    } else {
      text = isStart ? '출발지를 입력하세요' : '도착지를 입력하세요';
      textColor = const Color(0xFF9EA6B8);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
            // 점 아이콘 (출발: 초록, 도착: 빨강)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isStart
                    ? const Color(0xFF00C853)
                    : const Color(0xFFFF5252), // 디자인 시안 색상 참고
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: place != null
                      ? FontWeight.w500
                      : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 스왑 버튼 공간 확보를 위해 패딩
            const SizedBox(width: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard({
    required bool isSelected,
    required String title,
    required IconData icon,
    required Color themeColor,
    required String time,
    required String distance,
    required int obstacleCount,
    required List<String> tags,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(16), // 패딩 늘림
      decoration: BoxDecoration(
        color: isSelected
            ? Color.lerp(Colors.white, themeColor, 0.05)!
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? themeColor : const Color(0xFFF3F4F6),
          width: 1.5,
        ),
        boxShadow: [
          if (isSelected) ...[
            BoxShadow(
              color: themeColor.withValues(alpha: 0.1), // 0.15 -> 0.1
              blurRadius: 6,
              spreadRadius: -1,
              offset: Offset.zero,
            ),
            BoxShadow(
              color: themeColor.withValues(alpha: 0.05), // 0.1 -> 0.05
              blurRadius: 4,
              spreadRadius: -1,
              offset: Offset.zero,
            ),
          ] else ...[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              spreadRadius: -1,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              spreadRadius: -1,
              offset: const Offset(0, 2),
            ),
          ],
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center, // 수직 중앙 정렬
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: themeColor, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF101727),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: themeColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 12),
                ),
            ],
          ),
          const SizedBox(height: 10), // 간격 통일 (8 -> 10)
          // Info Info
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Color(0xFF4A5565)),
              const SizedBox(width: 4),
              Text(
                time,
                style: const TextStyle(
                  color: Color(0xFF4A5565), // Unified textGrey
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.route_outlined,
                size: 14,
                color: Color(0xFF4A5565),
              ),
              const SizedBox(width: 4),
              Text(
                distance,
                style: const TextStyle(
                  color: Color(0xFF4A5565), // Unified textGrey
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: Color(0xFFFF9800),
              ),
              const SizedBox(width: 4),
              Text(
                '$obstacleCount',
                style: const TextStyle(
                  color: Color(0xFFFF9800),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10), // 간격 통일 (6 -> 10)
          // Tags
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getRouteInfo(int index) {
    if (index == 0) {
      return {
        'title': '추천 경로',
        'icon': Icons.star_outline_rounded,
        'themeColor': const Color(0xFF00C853),
        'time': '15분',
        'distance': '2.4km',
        'obstacleCount': 1,
        'tags': ['넓은 인도', '경사로 있음', '횡단보도 많음'],
      };
    } else if (index == 1) {
      return {
        'title': '최단 경로',
        'icon': Icons.bolt_rounded,
        'themeColor': const Color(0xFF2979FF),
        'time': '12분',
        'distance': '1.8km',
        'obstacleCount': 3,
        'tags': ['좁은 구간 있음', '계단 우회 필요'],
      };
    } else {
      return {
        'title': '안전 경로',
        'icon': Icons.accessible_forward,
        'themeColor': const Color(0xFF9C27B0),
        'time': '18분',
        'distance': '3.1km',
        'obstacleCount': 0,
        'tags': ['장애물 없음', '평평한 길', '넓은 인도'],
      };
    }
  }

  Widget _buildSelectableRouteCard(int index) {
    final info = _getRouteInfo(index);
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRouteIndex = index;
        });
        if (_pageController != null && _pageController!.hasClients) {
          _pageController!.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      child: _buildRouteCard(
        isSelected: _selectedRouteIndex == index,
        title: info['title'] as String,
        icon: info['icon'] as IconData,
        themeColor: info['themeColor'] as Color,
        time: info['time'] as String,
        distance: info['distance'] as String,
        obstacleCount: info['obstacleCount'] as int,
        tags: info['tags'] as List<String>,
      ),
    );
  }
}
