import 'dart:async';
import 'dart:math' as math;
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
import 'package:gilbeot/services/api_service.dart';
import 'package:gilbeot/services/navigation_state_service.dart';
import 'package:gilbeot/app_route_observer.dart';
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

class _NavigationScreenState extends State<NavigationScreen> with RouteAware {
  WebViewController? _mapController;
  bool _isEndNavPressed = false;
  LatLng? _currentLiveLocation;
  Timer? _locationTimer;
  bool _isRerouting = false;

  // 재탐색 시 갱신 가능한 경로 데이터 (초기값은 widget에서 복사)
  late List<List<double>>? _routeGeometry;
  late List<Map<String, String>>? _instructions;
  late String _estimatedTime;
  late String _totalDistance;
  late int _avoidedObstacles;

  @override
  void initState() {
    super.initState();
    _currentLiveLocation = widget.startLocation;
    _routeGeometry = widget.routeGeometry;
    _instructions = widget.instructions;
    _estimatedTime = widget.estimatedTime;
    _totalDistance = widget.totalDistance;
    _avoidedObstacles = widget.avoidedObstacles;
    _initMapController();
    _startLocationTracking();
    // 웹 새로고침 복원을 위해 경로 상태 저장
    _saveNavigationState();
  }

  void _saveNavigationState() {
    if (widget.startLocation == null || widget.endLocation == null) return;
    NavigationStateService.save(
      routeType: widget.routeType,
      estimatedTime: widget.estimatedTime,
      totalDistance: widget.totalDistance,
      startLat: widget.startLocation!.latitude,
      startLon: widget.startLocation!.longitude,
      endLat: widget.endLocation!.latitude,
      endLon: widget.endLocation!.longitude,
      routeGeometry: widget.routeGeometry ?? [],
      instructions: widget.instructions ?? [],
      avoidedObstacles: widget.avoidedObstacles,
      startLocationName: widget.startLocationName,
      endLocationName: widget.endLocationName,
    );
  }

  bool _routeObserverSubscribed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_routeObserverSubscribed) {
      final route = ModalRoute.of(context);
      if (route is PageRoute) {
        routeObserver.subscribe(this, route);
        _routeObserverSubscribed = true;
      }
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    if (_routeObserverSubscribed) {
      routeObserver.unsubscribe(this);
    }
    super.dispose();
  }

  @override
  void didPopNext() {
    // 다른 화면에서 돌아왔을 때 지도 복원
    _refreshMapAfterReturn();
  }

  void _refreshMapAfterReturn() {
    if (_mapController == null) return;
    
    if (kIsWeb) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted || _mapController == null) return;
        _onMapReady(); 
      });
    } else {
      if (!mounted) return;
      _onMapReady();
    }
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
          KakaoMapHelper.setCurrentLocation(
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

  // ===== 장애물 제보 후 재탐색 관련 =====

  /// 점(장애물)에서 선분(경로 세그먼트)까지의 최단 거리 계산 (미터)
  double _pointToSegmentDistance(
    double pLat, double pLon,
    double sLat, double sLon,
    double eLat, double eLon,
  ) {
    const latToM = 111000.0;
    final lonToM = 111000.0 * math.cos((sLat + eLat) / 2 * math.pi / 180);

    final px = (pLon - sLon) * lonToM;
    final py = (pLat - sLat) * latToM;
    final ex = (eLon - sLon) * lonToM;
    final ey = (eLat - sLat) * latToM;

    final lenSq = ex * ex + ey * ey;
    if (lenSq == 0) return math.sqrt(px * px + py * py);

    final t = ((px * ex + py * ey) / lenSq).clamp(0.0, 1.0);
    final projX = t * ex;
    final projY = t * ey;
    return math.sqrt((px - projX) * (px - projX) + (py - projY) * (py - projY));
  }

  /// 장애물이 남은 경로와 겹치는지 확인
  bool _isObstacleOnRoute(double obsLat, double obsLon, double obsRadius) {
    if (_routeGeometry == null || _routeGeometry!.isEmpty) return false;

    double minDist = double.infinity;
    int minSegIdx = 0;

    for (int i = 0; i < _routeGeometry!.length - 1; i++) {
      final seg1 = _routeGeometry![i];
      final seg2 = _routeGeometry![i + 1];
      final dist = _pointToSegmentDistance(
        obsLat, obsLon,
        seg1[0], seg1[1],
        seg2[0], seg2[1],
      );
      if (dist < minDist) {
        minDist = dist;
        minSegIdx = i;
      }
    }

    debugPrint('=== 장애물-경로 거리 판정 ===');
    debugPrint('장애물 좌표: ($obsLat, $obsLon)');
    debugPrint('판정 반경: ${obsRadius}m');
    debugPrint('가장 가까운 세그먼트: #$minSegIdx');
    debugPrint('최소 거리: ${minDist.toStringAsFixed(1)}m');
    debugPrint('결과: ${minDist <= obsRadius ? "경로 겹침 → 재탐색" : "경로 밖 → 유지"}');
    debugPrint('=============================');

    return minDist <= obsRadius;
  }

  /// 현재 위치부터 도착지까지 경로 재탐색
  Future<void> _rerouteFromCurrentLocation() async {
    if (_isRerouting || widget.endLocation == null) return;

    final currentLoc = _currentLiveLocation ?? widget.startLocation;
    if (currentLoc == null) return;

    setState(() => _isRerouting = true);

    try {
      // 모드 결정
      String mode;
      if (widget.routeType.contains('추천')) {
        mode = 'optimal';
      } else if (widget.routeType.contains('최단')) {
        mode = 'short';
      } else if (widget.routeType.contains('안전')) {
        mode = 'safe';
      } else {
        mode = 'optimal';
      }

      final result = await ApiService.findRoute(
        startLat: currentLoc.latitude,
        startLon: currentLoc.longitude,
        endLat: widget.endLocation!.latitude,
        endLon: widget.endLocation!.longitude,
        mode: mode,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final routeData = result['route'] ?? result;
        final newGeometry = (routeData['geometry'] as List)
            .map((e) => (e as List).map((c) => (c as num).toDouble()).toList())
            .toList();
        final newInstructions = (routeData['instructions'] as List?)
                ?.map((e) => Map<String, String>.from(e as Map))
                .toList() ??
            [];

        setState(() {
          _routeGeometry = newGeometry;
          _instructions = newInstructions;
          _estimatedTime = '${routeData['estimated_time']}분';
          _totalDistance =
              '${((routeData['distance'] as num).toDouble() / 1000).toStringAsFixed(1)}km';
          _avoidedObstacles = routeData['avoided_obstacles'] ?? 0;
          _currentInstructionIndex = 1;
          _isRerouting = false;
        });

        // 지도에 새 경로 그리기
        if (_mapController != null) {
          KakaoMapHelper.drawRoute(
            _mapController,
            _routeGeometry!,
            showFullRoute: false,
            mapId: 'navigation',
          );
        }

        // 장애물 마커 다시 로드
        _loadObstacleMarkers();

        debugPrint('경로 재탐색 성공: 새 경로 ${newGeometry.length}개 노드');
      } else {
        setState(() => _isRerouting = false);
        debugPrint('경로 재탐색 실패: ${result['message']}');
      }
    } catch (e) {
      if (mounted) setState(() => _isRerouting = false);
      debugPrint('경로 재탐색 오류: $e');
    }
  }

  /// 장애물 제보 후 복귀 시 호출
  Future<void> _handleObstacleReported() async {
    final obstacle = LastReportedObstacle.consume();
    if (obstacle == null) return;

    final obsLat = obstacle['lat']!;
    final obsLon = obstacle['lon']!;
    final obsRadius = obstacle['radius']!;

    // 장애물 마커 갱신
    _loadObstacleMarkers();

    // 장애물이 현재 경로와 겹치는지 확인
    if (_isObstacleOnRoute(obsLat, obsLon, obsRadius)) {
      debugPrint('장애물이 경로 위에 있음 → 재탐색 시작');
      await _rerouteFromCurrentLocation();
    } else {
      debugPrint('장애물이 경로 밖에 있음 → 기존 경로 유지');
    }
  }

  void _updateNavigationProgress(LatLng currentLocation) {
    if (_instructions == null || _instructions!.isEmpty) return;
    if (_currentInstructionIndex >= _instructions!.length) return;

    // 1. 현재 안내 단계에 해당하는 대략적인 목표 위경도를 찾습니다.
    // (실제 프로덕션에서는 경로의 각 노드 중 현재 구간의 끝점을 매핑해야 함)
    // 현재는 단순 데모이므로, _routeGeometry의 노드들을 순회해서 도달 체크를 하거나
    // 가상의 거리를 줄이는 방식을 쓸 수 있습니다.

    // 단순 시뮬레이션: 안내 메시지에 남은 거리가 있다면, 여기서 실제 GPS로 거리를 재계산
    if (_routeGeometry != null && _routeGeometry!.isNotEmpty) {
      // 다음 주요 회전 구간을 찾기 위해 현재 인덱스에 매칭되는 대략적인 좌표를 가져옵니다.
      // 실제로는 API에서 회전 노드의 정확한 인덱스를 줘야 하지만 임시 계산합니다.
      int targetIndex =
          (_currentInstructionIndex *
                  (_routeGeometry!.length / _instructions!.length))
              .round();
      if (targetIndex >= _routeGeometry!.length) {
        targetIndex = _routeGeometry!.length - 1;
      }

      final targetLat = _routeGeometry![targetIndex][0];
      final targetLng = _routeGeometry![targetIndex][1];

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

      // 1. 경로 그리기 (전체 경로 자동 맞춤 비활성화)
      if (_routeGeometry != null && _routeGeometry!.isNotEmpty) {
        KakaoMapHelper.drawRoute(
          _mapController,
          _routeGeometry!,
          showFullRoute: false,
          mapId: mapId,
        );
      }

      final startLoc = _currentLiveLocation ?? widget.startLocation;
      if (startLoc != null) {
        // 2. 출발지/도착지 핀 표시
        if (widget.startLocation != null && widget.endLocation != null) {
          KakaoMapHelper.setStartEndMarkers(
            _mapController,
            widget.startLocation!.latitude,
            widget.startLocation!.longitude,
            widget.endLocation!.latitude,
            widget.endLocation!.longitude,
            mapId: mapId,
          );
        }

        // 3. 현재 위치 오버레이 표시
        KakaoMapHelper.setCurrentLocation(
          _mapController,
          startLoc.latitude,
          startLoc.longitude,
          mapId: mapId,
        );

        // 4. 지도 중심 현위치로 강제 + 최대 확대 적용
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted || _mapController == null) return;
          KakaoMapHelper.setCenter(
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
        });
      }

      // 5. 장애물 마커 표시
      _loadObstacleMarkers();
    });
  }

  /// 활성 장애물을 Supabase에서 가져와 네비게이션 지도에 표시
  Future<void> _loadObstacleMarkers() async {
    try {
      final obstacles = await ApiService.getActiveObstacles();
      if (!mounted || _mapController == null) return;

      KakaoMapHelper.setObstacleMarkers(
        _mapController,
        obstacles,
        mapId: 'navigation',
      );
    } catch (e) {
      debugPrint('Error loading obstacle markers: $e');
    }
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
          '${Uri.base.origin}/kakao_map.html?lat=$lat&lng=$lng&marker=false&level=1&mapId=navigation&t=${DateTime.now().millisecondsSinceEpoch}';

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
    // 사용자가 직접 안내를 종료할 때만 저장 상태 삭제
    NavigationStateService.clear();
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
    String detailText = '$_totalDistance 남음';
    IconData icon = Icons.navigation_rounded;

    if (_instructions != null &&
        _instructions!.isNotEmpty &&
        _currentInstructionIndex < _instructions!.length) {
      final currentStep = _instructions![_currentInstructionIndex];
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
      'tag': _avoidedObstacles > 0
          ? '장애물 $_avoidedObstacles개 회피'
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
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).cardColor
                      : Colors.white,
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
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Color(0xFF101727),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentDirection['detail'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Color(0xFF9CA3AF)
                                  : Color(0xFF4A5565),
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
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Color(0xFF2A2A2A)
                                    : const Color(0xFFE8FDF0),
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
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const CameraScreen(
                                      fromNavigation: true,
                                    ),
                                  ),
                                );
                                // 제보 완료 후 복귀 → 재탐색 판단
                                if (mounted) {
                                  _handleObstacleReported();
                                }
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
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).cardColor
                          : Colors.white,
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
                              _estimatedTime,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Color(0xFF101727),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // 남은 거리
                            Text(
                              _totalDistance,
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Color(0xFF9CA3AF)
                                    : Color(0xFF4A5565),
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
                                  (_instructions != null &&
                                      _instructions!.isNotEmpty)
                                  ? (_currentInstructionIndex /
                                            _instructions!.length)
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
                            if (_avoidedObstacles > 0) ...[
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '장애물 $_avoidedObstacles개 회피',
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
