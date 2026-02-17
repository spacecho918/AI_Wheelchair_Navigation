import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:gilbeot/helpers/kakao_map_helper.dart';
import 'camera_screen.dart';
import 'navigation_end_screen.dart';

class NavigationScreen extends StatefulWidget {
  final String routeType; // '추천', '최단', '안전'
  final String estimatedTime;
  final String totalDistance;
  final LatLng? startLocation;
  final LatLng? endLocation;
  final List<List<double>>? routeGeometry;
  final int avoidedObstacles;

  const NavigationScreen({
    super.key,
    required this.routeType,
    required this.estimatedTime,
    required this.totalDistance,
    this.startLocation,
    this.endLocation,
    this.routeGeometry,
    this.avoidedObstacles = 0,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  WebViewController? _mapController;

  bool _isEndNavPressed = false;

  @override
  void initState() {
    super.initState();
    _initMapController();
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

        // 지도 로드 완료 시 출발지 중심으로 이동
        controller.setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (url) {
              _onMapReady();
            },
          ),
        );
      }

      _mapController = controller;

      if (mounted) setState(() {});
      await _loadMap();
    } catch (e) {
      debugPrint("Error initializing map: $e");
    }
  }

  /// 지도 로드 완료 후 출발지 중심 + 경로 표시
  void _onMapReady() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted || _mapController == null) return;

      const mapId = 'navigation';

      // 출발지로 센터 이동 + 마커 표시
      if (widget.startLocation != null) {
        KakaoMapHelper.setCenter(
          _mapController,
          widget.startLocation!.latitude,
          widget.startLocation!.longitude,
          mapId: mapId,
        );
        KakaoMapHelper.setMarker(
          _mapController,
          widget.startLocation!.latitude,
          widget.startLocation!.longitude,
          mapId: mapId,
        );
      }

      // 경로 그리기
      if (widget.routeGeometry != null) {
        KakaoMapHelper.drawRoute(
          _mapController,
          widget.routeGeometry!,
          mapId: mapId,
        );
      }
    });
  }

  Future<void> _loadMap() async {
    if (_mapController == null) return;

    final lat = widget.startLocation?.latitude ?? 37.5445;
    final lng = widget.startLocation?.longitude ?? 127.0560;

    if (kIsWeb) {
      // 웹: URL 파라미터로 초기화 + 캐시 방지
      // level=1 (최대 확대), mapId=navigation (iframe 식별용)
      var url =
          '${Uri.base.origin}/kakao_map.html?lat=$lat&lng=$lng&marker=true&level=1&mapId=navigation&t=${DateTime.now().millisecondsSinceEpoch}';

      _mapController!.loadRequest(Uri.parse(url));

      // 웹에서도 _onMapReady 호출하여 경로 그리기 (URL 길이 제한 회피를 위해 postMessage 사용)
      Future.delayed(const Duration(milliseconds: 1000), () {
        _onMapReady();
      });
    } else {
      // 모바일: HTML 직접 로드 후 onPageFinished에서 _onMapReady 호출
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

  Future<void> _moveToCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      KakaoMapHelper.setCenter(
        _mapController,
        position.latitude,
        position.longitude,
        mapId: 'navigation',
      );
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  void _endNavigation() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'navigation_end'),
        builder: (context) => NavigationEndScreen(
          routeType: widget.routeType,
          estimatedTime: widget.estimatedTime,
          totalDistance: widget.totalDistance,
        ),
      ),
    );
  }

  /// 경로 안내 정보 계산
  Map<String, dynamic> _getCurrentDirection() {
    return {
      'icon': Icons.navigation_rounded,
      'instruction': '${widget.routeType} 안내 중',
      'detail': '${widget.totalDistance} 남음',
      'tag': widget.avoidedObstacles > 0
          ? '장애물 ${widget.avoidedObstacles}개 회피'
          : null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentDirection = _getCurrentDirection();
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

          // 3. 하단 UI (플로팅 버튼 + 정보창)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: PointerInterceptor(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 플로팅 버튼들 (장애물 제보 + 현위치)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 장애물 제보 버튼
                        Container(
                          height: 50,
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
                                    builder: (context) => const CameraScreen(
                                      fromNavigation: true,
                                    ),
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

                        // 현위치 버튼
                        Container(
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
                      ],
                    ),
                  ),

                  const SizedBox(height: 16), // 버튼과 정보창 사이 고정 간격
                  // 하단 정보창
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: MediaQuery.of(context).padding.bottom + 16,
                    ),
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
                              widthFactor: 0.0, // 출발 시작 0%
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
                              widget.routeType,
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9EA6B8),
                              ),
                            ),
                            const SizedBox(width: 16),
                            if (widget.avoidedObstacles > 0) ...[
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '장애물 ${widget.avoidedObstacles}개 회피',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9EA6B8),
                                ),
                              ),
                            ] else ...[
                              Icon(
                                Icons.accessible,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '장애물 없음',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9EA6B8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
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
}
