import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart'; // rootBundle
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart'; // 위치 정보 패키지 추가
import 'package:flutter/foundation.dart'; // kIsWeb
import 'dart:convert'; // Encoding
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../widgets/side_drawer.dart';
import 'camera_screen.dart';
import 'search_screen.dart';
import 'community_screen.dart';
import 'community_detail_screen.dart';
import 'history_screen.dart';
import 'route_search_screen.dart'; // Import user's new screen
import 'package:latlong2/latlong.dart' as latlong;
import 'package:gilbeot/helpers/kakao_map_helper.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  WebViewController? _mapController;
  latlong.LatLng? _mapCenter;
  latlong.LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _initMapController();
  }

  String? _mapError;

  Future<void> _initMapController() async {
    try {
      final controller = WebViewController();

      if (!kIsWeb) {
        controller.setJavaScriptMode(JavaScriptMode.unrestricted);
        controller.setBackgroundColor(const Color(0x00000000));
        controller.addJavaScriptChannel(
          'MapChannel',
          onMessageReceived: (JavaScriptMessage message) {
            try {
              final data = json.decode(message.message);
              if (data['type'] == 'dragend') {
                setState(() {
                  _mapCenter = latlong.LatLng(data['lat'], data['lng']);
                });
                debugPrint("Map Center Updated: $_mapCenter");
              }
            } catch (e) {
              debugPrint("Error parsing map message: $e");
            }
          },
        );
      }

      _mapController = controller;

      // Start loading map immediately
      if (mounted) setState(() {});
      await _loadMap();

      // Get location in background
      _initCurrentLocation();
    } catch (e) {
      debugPrint("Error initializing map: $e");
      if (mounted) {
        setState(() {
          _mapError = e.toString();
        });
      }
    }
  }

  Future<void> _initCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = latlong.LatLng(
          position.latitude,
          position.longitude,
        );
        _mapCenter = _currentLocation; // Initial map center is current location
      });

      // On Web, passing via URL param in _loadMap won't work if map already loaded.
      // So we must use setCenter here.
      if (kIsWeb) {
        // Wait a bit for iframe to be ready if it just loaded
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      KakaoMapHelper.setCenter(
        _mapController,
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      debugPrint('Error getting initial location: $e');
    }
  }

  Future<void> _loadMap() async {
    if (_mapController == null) return;

    if (kIsWeb) {
      _mapController!.loadRequest(
        Uri.parse('${Uri.base.origin}/kakao_map.html'),
      );
    } else {
      String fileText = await rootBundle.loadString('assets/kakao_map.html');
      _mapController!.loadRequest(
        Uri.dataFromString(
          fileText,
          mimeType: 'text/html',
          encoding: Encoding.getByName('utf-8'),
        ),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  // 현재 위치로 이동하는 함수
  Future<void> _moveToCurrentLocation() async {
    debugPrint("Move to Current Location clicked");
    bool serviceEnabled;
    LocationPermission permission;

    // 1. 위치 서비스 활성화 여부 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('위치 서비스가 꺼져있습니다.')));
      }
      return;
    }

    // 2. 권한 확인
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions are denied');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('위치 권한이 거부되었습니다.')));
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 권한이 영구적으로 거부되었습니다. 설정에서 허용해주세요.')),
        );
      }
      return;
    }

    // 3. 현재 위치 가져오기 및 지도 이동
    try {
      Position position = await Geolocator.getCurrentPosition();
      debugPrint("Location found: ${position.latitude}, ${position.longitude}");
      KakaoMapHelper.setCenter(
        _mapController,
        position.latitude,
        position.longitude,
      );
      setState(() {
        _currentLocation = latlong.LatLng(
          position.latitude,
          position.longitude,
        );
        _mapCenter = _currentLocation;
      });
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const SideDrawer(), // 사이드 드로어 추가
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ---------------------------------------------------------
          // 1. 배경 지도 (Kakao Map via WebView)
          // ---------------------------------------------------------
          if (_mapError != null)
            Center(child: Text('지도 로드 실패: $_mapError'))
          else if (_mapController == null)
            const Center(child: CircularProgressIndicator())
          else
            Positioned.fill(child: WebViewWidget(controller: _mapController!)),

          // ---------------------------------------------------------
          // 3 & 4. 대시보드 및 신고 버튼
          // ---------------------------------------------------------
          DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.20,
            maxChildSize: 0.85,
            builder: (BuildContext context, ScrollController scrollController) {
              return PointerInterceptor(
                child: Stack(
                  children: [
                    // (1) 흰색 대시보드
                    Container(
                      margin: const EdgeInsets.only(top: 65), // 버튼과 대시보드 간격
                      decoration: const ShapeDecoration(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(28),
                            topRight: Radius.circular(28),
                          ),
                        ),
                        shadows: [
                          BoxShadow(
                            color: Color(0x19000000),
                            blurRadius: 20,
                            offset: Offset(0, -4),
                          ),
                        ],
                      ),
                      child: ListView(
                        controller: scrollController, // [수정 2] 드래그 연결 핵심
                        physics:
                            const ClampingScrollPhysics(), // [수정 2] 탭을 잡아도 창이 딸려오게 하는 물리 효과
                        padding: const EdgeInsets.fromLTRB(21, 10, 21, 30),
                        children: [
                          // Handle Bar
                          Center(
                            child: Container(
                              width: 42,
                              height: 5,
                              margin: const EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD1D5DC),
                                borderRadius: BorderRadius.circular(100),
                              ),
                            ),
                          ),

                          // 1. Recent Destinations
                          _buildSectionHeader('최근 목적지', () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HistoryScreen(),
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                          _buildRecentDestinationItem(
                            '집',
                            '서울시 서초구 서초동 567-89',
                            Icons.business_rounded,
                          ),
                          const SizedBox(height: 12),
                          _buildRecentDestinationItem(
                            '서울대학교병원',
                            '서울시 종로구 연건동 101',
                            Icons.local_hospital_rounded,
                          ),

                          const SizedBox(height: 32),

                          // 2. Community Latest Posts
                          _buildSectionHeader('커뮤니티 최신글', () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CommunityScreen(),
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                          _buildCommunityPostItem(
                            tag: '경사로',
                            time: '30분 전',
                            title: '강남역 2번 출구 경사로 너무 가파름',
                            location: '강남역 2번 출구',
                            likes: 24,
                            comments: 8,
                            author: '김철수',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CommunityDetailScreen(
                                    report: {
                                      'id': 101, // Dummy ID
                                      'tag': '경사로',
                                      'title': '강남역 2번 출구 경사로 너무 가파름',
                                      'location': '강남역 2번 출구',
                                      'likes': 24,
                                      'comments': 8,
                                      'author': '김철수',
                                      'timestamp': DateTime.now()
                                          .subtract(const Duration(minutes: 30))
                                          .millisecondsSinceEpoch,
                                      'description':
                                          '강남역 2번 출구 휠체어 리프트 이용이 어렵습니다. 경사로가 너무 가파릅니다.',
                                      'image': null,
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildCommunityPostItem(
                            tag: '엘리베이터',
                            time: '2시간 전',
                            title: '서울숲 입구 엘리베이터 고장',
                            location: '서울숲',
                            likes: 18,
                            comments: 5,
                            author: '이영희',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CommunityDetailScreen(
                                    report: {
                                      'id': 102, // Dummy ID
                                      'tag': '엘리베이터',
                                      'title': '서울숲 입구 엘리베이터 고장',
                                      'location': '서울숲',
                                      'likes': 18,
                                      'comments': 5,
                                      'author': '이영희',
                                      'timestamp': DateTime.now()
                                          .subtract(const Duration(hours: 2))
                                          .millisecondsSinceEpoch,
                                      'description':
                                          '서울숲 메인 입구 엘리베이터가 점검 중이라 작동하지 않습니다.',
                                      'image': null,
                                    },
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 32),

                          // Search Button
                          Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C853),
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF00C853,
                                  ).withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SearchScreen(
                                        searchLocation: _mapCenter,
                                        userLocation: _currentLocation,
                                      ),
                                    ),
                                  );
                                  if (result != null) {
                                    if (result is latlong.LatLng) {
                                      KakaoMapHelper.setCenter(
                                        _mapController,
                                        result.latitude,
                                        result.longitude,
                                      );
                                    } else if (result is Map &&
                                        result.containsKey('latlng')) {
                                      final latlng =
                                          result['latlng'] as latlong.LatLng;
                                      KakaoMapHelper.setCenter(
                                        _mapController,
                                        latlng.latitude,
                                        latlng.longitude,
                                      );
                                    }
                                  }
                                },
                                borderRadius: BorderRadius.circular(26),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(
                                      Icons.search,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      '새로운 목적지 검색',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
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

                    // (2) 신고 버튼 (왼쪽으로 이동)
                    Positioned(
                      left: 20,
                      top: 0,
                      child: Container(
                        height: 50, // 현위치 버튼과 동일
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C853),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CameraScreen(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(30),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 15,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SvgPicture.asset(
                                    'assets/camera_icon.svg',
                                    colorFilter: const ColorFilter.mode(
                                      Colors.white,
                                      BlendMode.srcIn,
                                    ),
                                    width: 24,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    '장애물 제보',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // (3) 현재 위치 버튼 (오른쪽으로 신규 추가)
                    Positioned(
                      right: 20,
                      top: 0,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _moveToCurrentLocation,
                            child: Center(
                              child: SvgPicture.asset(
                                'assets/target_icon.svg',
                                width: 18,
                                height: 18,
                                colorFilter: const ColorFilter.mode(
                                  Color(0xFF354152),
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // ---------------------------------------------------------
          // 2. 상단 검색바 (햄버거 아이콘 복구)
          // ---------------------------------------------------------
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: PointerInterceptor(
              child: Row(
                children: [
                  // [수정 1] 햄버거 버튼 (Icon 위젯으로 변경)
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
                        onTap: () {
                          // 햄버거 메뉴 클릭 시 드로어 열기
                          _scaffoldKey.currentState?.openDrawer();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: SvgPicture.asset(
                            'assets/burger_icon.svg',
                            width: 20,
                            height: 20,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // 검색창
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        // 검색 화면으로 이동
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SearchScreen(
                              searchLocation: _mapCenter,
                              userLocation: _currentLocation,
                            ),
                          ),
                        );

                        // 결과 처리 (Map or LatLng)
                        if (result != null) {
                          if (result is latlong.LatLng) {
                            KakaoMapHelper.setCenter(
                              _mapController,
                              result.latitude,
                              result.longitude,
                            );
                          } else if (result is Map &&
                              result.containsKey('latlng')) {
                            final latlng = result['latlng'] as latlong.LatLng;
                            KakaoMapHelper.setCenter(
                              _mapController,
                              latlng.latitude,
                              latlng.longitude,
                            );
                          }
                        }
                      },
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
                            const Expanded(
                              child: Text(
                                '주변 장소 검색...',
                                style: TextStyle(
                                  color: Color(0xFF717182),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 15),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // [New] 길찾기 버튼 (오른쪽 추가)
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
                        onTap: () {
                          // 길찾기 화면으로 이동
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RouteSearchScreen(
                                userLocation: _currentLocation,
                              ),
                            ),
                          );
                        },
                        child: const Icon(
                          Icons.directions, // 길찾기 아이콘
                          color: Color(0xFF00C853),
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF101727),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Row(
            children: const [
              Text(
                '전체보기',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              ),
              Icon(Icons.chevron_right, color: Color(0xFF6B7280), size: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentDestinationItem(
    String title,
    String address,
    IconData iconData,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF00C853),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(iconData, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF101727),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  style: const TextStyle(
                    color: Color(0xFF4A5565),
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.access_time, // Clock icon
            color: Color(0xFF9CA3AF),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityPostItem({
    required String tag,
    required String time,
    required String title,
    required String location,
    required int likes,
    required int comments,
    required String author,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      color: Color(0xFF4A5565),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  time,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF101727),
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 2),
                Text(
                  location,
                  style: const TextStyle(
                    color: Color(0xFF4A5565),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.thumb_up_outlined,
                  size: 14,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 4),
                Text(
                  '$likes',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.comment_outlined,
                  size: 14,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 4),
                Text(
                  '$comments',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '· $author',
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
