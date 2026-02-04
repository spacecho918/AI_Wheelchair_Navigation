import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:gilbeot/helpers/kakao_map_helper.dart';
import 'dart:convert';
import 'camera_screen.dart';
import 'navigation_end_screen.dart';

class NavigationScreen extends StatefulWidget {
  final String routeType; // '추천', '최단', '안전'
  final String estimatedTime;
  final String totalDistance;
  final LatLng? startLocation;
  final LatLng? endLocation;
  final List<dynamic>? routeGeometry; // [[lat, lng], [lat, lng], ...]

  const NavigationScreen({
    super.key,
    required this.routeType,
    required this.estimatedTime,
    required this.totalDistance,
    this.startLocation,
    this.endLocation,
    this.routeGeometry,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  WebViewController? _mapController;

  // 더미 안내 데이터
  final List<Map<String, dynamic>> _directions = [
    {
      'icon': Icons.turn_left,
      'instruction': '좌회전',
      'detail': '엘리베이터까지 50m',
      'tag': '앞쪽 경사로 이용',
    },
    {
      'icon': Icons.straight,
      'instruction': '직진',
      'detail': '300m 직진',
      'tag': null,
    },
    {
      'icon': Icons.turn_right,
      'instruction': '우회전',
      'detail': '목적지까지 100m',
      'tag': null,
    },
  ];

  final int _currentDirectionIndex = 0;
  bool _isEndNavPressed = false;

  @override
  void initState() {
    super.initState();
    _initMapController();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      await Geolocator.getCurrentPosition();
      // Location retrieved successfully
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

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
                // Handle map drag if needed
              }
            } catch (e) {
              debugPrint("Error parsing map message: $e");
            }
          },
        );
      }

      _mapController = controller;

      if (mounted) setState(() {});
      await _loadMap();
    } catch (e) {
      debugPrint("Error initializing map: $e");
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

    // Center on start location or current location
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (widget.startLocation != null) {
        KakaoMapHelper.setCenter(
          _mapController,
          widget.startLocation!.latitude,
          widget.startLocation!.longitude,
        );
      }
      
      // Draw Route if geometry exists
      if (widget.routeGeometry != null && widget.routeGeometry!.isNotEmpty) {
        _drawRoute();
      }
    });
  }
  
  void _drawRoute() {
    if (_mapController == null) return;
    
    // Construct JSON message
    // HTML expects: { "action": "drawRoute", "path": [[lat, lng], ...] }
    final message = jsonEncode({
      "action": "drawRoute",
      "path": widget.routeGeometry,
    });
    
    // Send message to WebView
    if (kIsWeb) {
      // For web, we might use a different approach or verify if runJavaScript works for posting message.
      // Usually WebViewController.runJavaScript works on Flutter Web too.
      // Alternatively, access the iframe contentWindow.postMessage via js interactions.
      // But standard way:
      _mapController!.runJavaScript('window.postMessage($message, "*")');
    } else {
       _mapController!.runJavaScript('window.postMessage($message, "*")');
    }
  }

  Future<void> _moveToCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      KakaoMapHelper.setCenter(
        _mapController,
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  void _endNavigation() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => NavigationEndScreen(
          routeType: widget.routeType,
          estimatedTime: widget.estimatedTime,
          totalDistance: widget.totalDistance,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentDirection = _directions[_currentDirectionIndex];

    return Scaffold(
      body: Stack(
        children: [
          // 1. 지도 영역
          if (_mapController == null)
            const Center(child: CircularProgressIndicator())
          else
            Positioned.fill(child: WebViewWidget(controller: _mapController!)),

          // 2. 상단 안내 카드
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: PointerInterceptor(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 뒤로가기 버튼
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00C853),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          currentDirection['icon'] as IconData,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 안내 텍스트
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentDirection['instruction'] as String,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF101727),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentDirection['detail'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF4A5565),
                            ),
                          ),
                          if (currentDirection['tag'] != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8FDF0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                currentDirection['tag'] as String,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF00C853),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. 하단 플로팅 버튼들
          Positioned(
            left: 16,
            bottom: 150, // 간격 줄임
            child: PointerInterceptor(
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
                          builder: (context) =>
                              const CameraScreen(fromNavigation: true),
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
          ),

          // 현위치 버튼
          Positioned(
            right: 16,
            bottom: 150, // 간격 줄임
            child: PointerInterceptor(
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
          ),

          // 4. 하단 정보 바
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: PointerInterceptor(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 시간/거리 + 안내 종료 버튼
                    Row(
                      children: [
                        // 남은 시간
                        Text(
                          widget.estimatedTime,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF101727),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // 남은 거리
                        Text(
                          widget.totalDistance,
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF4A5565),
                          ),
                        ),
                        const Spacer(),
                        // 안내 종료 버튼
                        GestureDetector(
                          onTapDown: (_) =>
                              setState(() => _isEndNavPressed = true),
                          onTapUp: (_) =>
                              setState(() => _isEndNavPressed = false),
                          onTapCancel: () =>
                              setState(() => _isEndNavPressed = false),
                          onTap: _endNavigation,
                          child: Row(
                            children: [
                              Icon(
                                Icons.close,
                                size: 16,
                                color: _isEndNavPressed
                                    ? const Color(0xFFFF3B30)
                                    : Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '안내 종료',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _isEndNavPressed
                                      ? const Color(0xFFFF3B30)
                                      : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Progress Bar
                    Stack(
                      children: [
                        Container(
                          height: 6,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: 0.35, // 35% 진행 상태 예시
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C853),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 요약 정보
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '3번 회전 남음',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9EA6B8),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.accessible,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '숲 알뜰 경사로 2개',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9EA6B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
