import 'dart:async';
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
  final List<Map<String, String>>? instructions;
  final int avoidedObstacles;
  final String startLocationName;
  final String endLocationName;

  const NavigationScreen({
    super.key,
    required this.routeType,
    required this.estimatedTime,
    required this.totalDistance,
    this.startLocation,
    this.endLocation,
    this.routeGeometry,
    this.instructions,
    this.avoidedObstacles = 0,
    this.startLocationName = '출발지',
    this.endLocationName = '도착지',
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  WebViewController? _mapController;
  bool _isEndNavPressed = false;
  LatLng? _currentLiveLocation;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _currentLiveLocation = widget.startLocation;
    _initMapController();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  void _startLocationTracking() {
    // 3초마다 현재 위치를 확인하여 지도 업데이트
    _locationTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        if (!mounted) return;

        final newLocation = LatLng(position.latitude, position.longitude);

        setState(() {
          _currentLiveLocation = newLocation;
        });

        _updateNavigationProgress(newLocation);

        if (_mapController != null) {
          // 마커 위치 업데이트
          KakaoMapHelper.setMarker(
            _mapController,
            position.latitude,
            position.longitude,
            mapId: 'navigation',
          );
          // NOTE: 지도 중심 이동(setCenter)은 사용자가 전체 경로를 볼 수 있도록 제거함
        }
      } catch (e) {
        debugPrint("Location tracking error: $e");
      }
    });
  }

  void _updateNavigationProgress(LatLng currentLocation) {
    if (widget.instructions == null || widget.instructions!.isEmpty) return;
    if (_currentInstructionIndex >= widget.instructions!.length) return;

    // 1. 현재 안내 단계에 해당하는 대략적인 목표 위경도를 찾습니다.
    // (실제 프로덕션에서는 경로의 각 노드 중 현재 구간의 끝점을 매핑해야 함)
    // 현재는 단순 데모이므로, widget.routeGeometry의 노드들을 순회해서 도달 체크를 하거나
    // 가상의 거리를 줄이는 방식을 쓸 수 있습니다.

    // 단순 시뮬레이션: 안내 메시지에 남은 거리가 있다면, 여기서 실제 GPS로 거리를 재계산
    if (widget.routeGeometry != null && widget.routeGeometry!.isNotEmpty) {
      // 다음 주요 회전 구간을 찾기 위해 현재 인덱스에 매칭되는 대략적인 좌표를 가져옵니다.
      // 실제로는 API에서 회전 노드의 정확한 인덱스를 줘야 하지만 임시 계산합니다.
      int targetIndex =
          (_currentInstructionIndex *
                  (widget.routeGeometry!.length / widget.instructions!.length))
              .round();
      if (targetIndex >= widget.routeGeometry!.length) {
        targetIndex = widget.routeGeometry!.length - 1;
      }

      final targetLat = widget.routeGeometry![targetIndex][0];
      final targetLng = widget.routeGeometry![targetIndex][1];

      const distance = Distance();
      final meter = distance(currentLocation, LatLng(targetLat, targetLng));

      // 15미터 이내로 다음 회전 구간에 접근하면 다음 안내로 넘어감
      if (meter < 15.0) {
        setState(() {
          _currentInstructionIndex++;
        });
      }
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

      // 출발지(현재위치)로 센터 이동 + 마커 표시
      final startLoc = _currentLiveLocation ?? widget.startLocation;
      if (startLoc != null) {
        KakaoMapHelper.setCenter(
          _mapController,
          startLoc.latitude,
          startLoc.longitude,
          mapId: mapId,
        );
        KakaoMapHelper.setMarker(
          _mapController,
          startLoc.latitude,
          startLoc.longitude,
          mapId: mapId,
        );
        KakaoMapHelper.setLevel(
          _mapController,
          1, // 최대 상세 (1단계)
          mapId: mapId,
        );
      }

      // 경로 그리기 (전체 경로 자동 맞춤 비활성화)
      if (widget.routeGeometry != null && widget.routeGeometry!.isNotEmpty) {
        KakaoMapHelper.drawRoute(
          _mapController,
          widget.routeGeometry!,
          showFullRoute: false,
          mapId: mapId,
        );
      }
    });
  }

  Future<void> _loadMap() async {
    if (_mapController == null) return;

    final startLoc = _currentLiveLocation ?? widget.startLocation;
    final lat = startLoc?.latitude ?? 37.5445;
    final lng = startLoc?.longitude ?? 127.0560;

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
      await _mapController!.loadHtmlString(
        fileText,
        baseUrl: 'https://gilbeot.app',
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
          startLocationName: widget.startLocationName,
          endLocationName: widget.endLocationName,
          startLat: widget.startLocation?.latitude,
          startLon: widget.startLocation?.longitude,
          endLat: widget.endLocation?.latitude,
          endLon: widget.endLocation?.longitude,
        ),
      ),
    );
  }

  int _currentInstructionIndex = 1; // 0은 '안내를 시작합니다'

  /// 경로 안내 정보 계산
  Map<String, dynamic> _getCurrentDirection() {
    String instructionText = '${widget.routeType} 안내 중';
    String detailText = '${widget.totalDistance} 남음';
    IconData icon = Icons.navigation_rounded;

    if (widget.instructions != null &&
        widget.instructions!.isNotEmpty &&
        _currentInstructionIndex < widget.instructions!.length) {
      final currentStep = widget.instructions![_currentInstructionIndex];
      instructionText = currentStep['instruction'] ?? instructionText;
      detailText = '${currentStep['distance']} 앞';

      // 방위에 따른 아이콘 변경
      if (instructionText.contains('좌회전') ||
          instructionText.contains('좌측 방향')) {
        icon = Icons.turn_left_rounded;
      } else if (instructionText.contains('우회전') ||
          instructionText.contains('우측 방향')) {
        icon = Icons.turn_right_rounded;
      } else if (instructionText.contains('유턴')) {
        icon = Icons.u_turn_left_rounded;
      } else if (instructionText.contains('도달') ||
          instructionText.contains('도착')) {
        icon = Icons.flag_rounded;
      } else {
        icon = Icons.straight_rounded;
      }
    }

    return {
      'icon': icon,
      'instruction': instructionText,
      'detail': detailText,
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
                              widthFactor:
                                  (widget.instructions != null &&
                                      widget.instructions!.isNotEmpty)
                                  ? (_currentInstructionIndex /
                                            widget.instructions!.length)
                                        .clamp(0.0, 1.0)
                                  : 0.0,
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
