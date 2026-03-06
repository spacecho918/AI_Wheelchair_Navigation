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
import 'wheelchair_settings_screen.dart';
import 'package:gilbeot/app_route_observer.dart';
import '../services/api_service.dart';
import '../models/driving_history.dart';
import 'package:gilbeot/widgets/common_toast.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with RouteAware {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _routeObserverSubscribed = false;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  WebViewController? _mapController;
  latlong.LatLng? _mapCenter;
  latlong.LatLng? _currentLocation;

  // Dashboard data
  List<DrivingHistory> _recentDrives = [];
  List<Map<String, dynamic>> _latestPosts = [];
  bool _isDashboardLoading = true;

  @override
  void initState() {
    super.initState();
    _initMapController();
    _loadDashboardData();

    // Show wheelchair setting popup after frame load, only if not already set
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = await ApiService.getUserProfile();
      // Only show popup if user is not logged in or has no wheelchair_type in their Supabase metadata
      // 'None' is a valid explicit choice ("사용 안함"), so we should NOT trigger popup for it
      // We trigger if: no user profile OR wheelchairType is the default 'None' from User model default (meaning metadata was absent)
      // However, distinguishing between "user chose None" vs "metadata absent, defaulted to None" is tricky.
      // The safest approach: Only show popup if user is null.
      // If user exists (logged in), they can always change settings from the sidebar.
      if (user == null) {
        _showWheelchairSettingDialog();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_routeObserverSubscribed) {
      final route = ModalRoute.of(context);
      if (route != null) {
        routeObserver.subscribe(this, route);
        _routeObserverSubscribed = true;
      }
    }
  }

  @override
  void dispose() {
    if (_routeObserverSubscribed) {
      routeObserver.unsubscribe(this);
    }
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final drives = await ApiService.getUserHistory();
      final posts = await ApiService.getCommunityReports();
      if (!mounted) return;
      setState(() {
        _recentDrives = drives.take(2).toList();
        _latestPosts = posts.take(2).toList();
        _isDashboardLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDashboardLoading = false);
    }
  }

  String _formatTimeAgo(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);
      if (difference.inDays > 0) return '${difference.inDays}일 전';
      if (difference.inHours > 0) return '${difference.inHours}시간 전';
      if (difference.inMinutes > 0) return '${difference.inMinutes}분 전';
      return '방금 전';
    } catch (e) {
      return '알 수 없음';
    }
  }

  // Wheelchair Setting Popup
  void _showWheelchairSettingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(
        alpha: 0.5,
      ), // Semi-transparent black background
      builder: (context) {
        return PointerInterceptor(
          child: Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Close button
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: Color(0xFF101727),
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 20,
                      ),
                    ),

                    // Icon
                    Container(
                      width: 64,
                      height: 64,
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFF00C853),
                        shape: BoxShape.circle,
                      ),
                      child: SvgPicture.asset(
                        'assets/wheelchair_icon.svg',
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    const Text(
                      '휠체어 종류를 설정해주세요',
                      style: TextStyle(
                        fontSize: 18, // 20 might be too big, trying 18-20 range
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF101727),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    const Text(
                      '정확한 경로 안내를 위해\n사용 중인 휠체어 종류가 필요합니다',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280), // Grey text
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Buttons
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Close dialog first
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const WheelchairSettingsScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C853),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '지금 설정하기',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '나중에 설정하기',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF4B5563),
                            fontSize: 14,
                          ),
                        ),
                      ),
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

  String? _mapError;

  Future<void> _initMapController() async {
    try {
      final controller = WebViewController();

      if (!kIsWeb) {
        controller.setJavaScriptMode(JavaScriptMode.unrestricted);
        controller.setBackgroundColor(const Color(0x00000000));

        // Add navigation delegate for debugging
        controller.setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              debugPrint('WebView: Page started loading: $url');
            },
            onPageFinished: (String url) {
              debugPrint('WebView: Page finished loading: $url');
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint(
                'WebView Error: ${error.errorCode} - ${error.description}',
              );
              debugPrint('WebView Error URL: ${error.url}');
              debugPrint('WebView Error Type: ${error.errorType}');
            },
            onHttpError: (HttpResponseError error) {
              debugPrint('WebView HTTP Error: ${error.response?.statusCode}');
            },
          ),
        );

        controller.addJavaScriptChannel(
          'MapChannel',
          onMessageReceived: (JavaScriptMessage message) {
            try {
              final data = json.decode(message.message);
              if (data['type'] == 'dragend') {
                if (mounted) {
                  setState(() {
                    _mapCenter = latlong.LatLng(data['lat'], data['lng']);
                  });
                }
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
      if (!mounted) return;
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
      KakaoMapHelper.setCurrentLocation(
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
        Uri.parse(
          '${Uri.base.origin}/kakao_map.html?v=${DateTime.now().millisecondsSinceEpoch}',
        ),
      );
    } else {
      // Load HTML content with a base URL registered in Kakao Developer Console
      String htmlContent = await rootBundle.loadString('assets/kakao_map.html');

      // Use https://gilbeot.app as base URL (registered in Kakao console)
      await (_mapController as WebViewController).loadHtmlString(
        htmlContent,
        baseUrl: 'https://gilbeot.app',
      );
    }
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
        CommonToast.show(context, '위치 서비스가 꺼져있습니다.');
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
          CommonToast.show(context, '위치 권한이 거부되었습니다.');
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
      if (mounted) {
        CommonToast.show(context, '위치 권한이 영구적으로 거부되었습니다. 설정에서 허용해주세요.');
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
      KakaoMapHelper.setCurrentLocation(
        _mapController,
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
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
            controller: _sheetController,
            initialChildSize: 0.45,
            minChildSize: 0.20,
            maxChildSize: 0.85,
            snap: true,
            snapSizes: const [0.20, 0.45, 0.85],
            builder: (BuildContext context, ScrollController scrollController) {
              return PointerInterceptor(
                child: Stack(
                  children: [
                    // (1) 흰색 대시보드
                    Container(
                      margin: const EdgeInsets.only(top: 65), // 버튼과 대시보드 간격
                      decoration: ShapeDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).cardColor
                          : Colors.white,
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
                          // Handle Bar - Draggable
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragUpdate: (details) {
                              final screenHeight = MediaQuery.of(
                                context,
                              ).size.height;
                              final delta = -details.delta.dy / screenHeight;
                              final currentSize = _sheetController.size;
                              final newSize = (currentSize + delta).clamp(
                                0.20,
                                0.85,
                              );
                              _sheetController.jumpTo(newSize);
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Container(
                                  width: 42,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD1D5DC),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

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
                          if (_isDashboardLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF00C853),
                                ),
                              ),
                            )
                          else if (_recentDrives.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Theme.of(context).cardColor
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFF3F4F6),
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  '주행 기록이 없습니다.',
                                  style: TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            )
                          else
                            ...List.generate(_recentDrives.length, (i) {
                              final drive = _recentDrives[i];
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: i < _recentDrives.length - 1 ? 12 : 0,
                                ),
                                child: _buildRecentDestinationItem(
                                  drive.endLocation.isNotEmpty
                                      ? drive.endLocation
                                      : '목적지',
                                  drive.startLocation.isNotEmpty
                                      ? '출발: ${drive.startLocation}'
                                      : '출발지 정보 없음',
                                  Icons.place_rounded,
                                ),
                              );
                            }),

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
                          if (_isDashboardLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF00C853),
                                ),
                              ),
                            )
                          else if (_latestPosts.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Theme.of(context).cardColor
                                    : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFF3F4F6),
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  '게시글이 없습니다.',
                                  style: TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            )
                          else
                            ...List.generate(_latestPosts.length, (i) {
                              final post = _latestPosts[i];
                              final tag = post['tag'] ?? '';
                              final time = _formatTimeAgo(post['time'] ?? '');
                              final content = post['content'] ?? '';
                              final address = post['address'] ?? '위치 정보 없음';
                              final user = post['user'] ?? '알 수 없음';
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: i < _latestPosts.length - 1 ? 12 : 0,
                                ),
                                child: _buildCommunityPostItem(
                                  tag: tag,
                                  time: time,
                                  title: content.isNotEmpty
                                      ? content
                                      : '$tag 제보',
                                  location: address,
                                  likes: post['likes'] ?? 0,
                                  comments: post['comments'] ?? 0,
                                  author: user,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            CommunityDetailScreen(report: post),
                                      ),
                                    );
                                  },
                                ),
                              );
                            }),

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
                                  ).withValues(alpha: 0.3),
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
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Color(0xFF2A2A2A)
                              : Colors.white,
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
                                colorFilter: ColorFilter.mode(
                                  Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : Color(0xFF354152),
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
            top: MediaQuery.of(context).padding.top + 20,
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
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Color(0xFF2A2A2A)
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
                            colorFilter: ColorFilter.mode(
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                              BlendMode.srcIn,
                            ),
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
                              colorFilter: ColorFilter.mode(
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.grey,
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '주변 장소 검색...',
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : Color(0xFF717182),
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
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Color(0xFF2A2A2A)
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
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Color(0xFF101727),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Row(
            children: [
              Text(
                '전체보기',
                style: TextStyle(color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Color(0xFF6B7280), fontSize: 13),
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
        color: Theme.of(context).brightness == Brightness.dark
          ? Color(0xFF2A2A2A)
          : Colors.white,
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
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Color(0xFF101727),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF9CA3AF)
                        : Color(0xFF4A5565),
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
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2A2A2A)
              : Colors.white,
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
                    color: const Color(0xFF00C853),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF9CA3AF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Color(0xFF101727),
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Color(0xFF9CA3AF)
                      : Color(0xFF6B7280),
                ),
                const SizedBox(width: 2),
                Text(
                  location,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Color(0xFF9CA3AF)
                        : Color(0xFF4A5565),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.thumb_up_outlined,
                  size: 14,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Color(0xFF9CA3AF)
                      : Color(0xFF6B7280),
                ),
                const SizedBox(width: 4),
                Text(
                  '$likes',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Color(0xFF9CA3AF)
                        : Color(0xFF6B7280),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.comment_outlined,
                  size: 14,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Color(0xFF9CA3AF)
                      : Color(0xFF6B7280),
                ),
                const SizedBox(width: 4),
                Text(
                  '$comments',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Color(0xFF9CA3AF)
                        : Color(0xFF6B7280),
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
