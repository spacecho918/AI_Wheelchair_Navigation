import 'dart:ui';

import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // rootBundle
import 'package:webview_flutter/webview_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
// Import conditional helper
import 'package:gilbeot/helpers/kakao_map_helper.dart';
import 'package:gilbeot/config/kakao_config.dart';

import 'package:gilbeot/screens/location_search_screen.dart'; // 장소 검색 화면
import 'package:gilbeot/screens/navigation_screen.dart';
import 'package:gilbeot/services/kakao_service.dart';
import 'package:gilbeot/services/api_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gilbeot/widgets/common_toast.dart';

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
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  // 경로 비교 데이터
  Map<String, dynamic>? _comparisonData; // /route/compare 결과
  bool _isLoadingRoutes = false;
  String? _routeError;
  String? _mapInitError;

  // 지도 컨트롤러 및 ID
  WebViewController? _mapController;
  // 각 인스턴스마다 고유 ID 생성 (타임스탬프 활용)
  final String _mapId =
      'route_preview_${DateTime.now().millisecondsSinceEpoch}';

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
    
    // 초기 진입 시 userLocation이 null인 경우를 대비해 비동기 수집 실행
    _fetchCurrentLocationIfNull();

    // 2. 도착지가 전달되었으면 설정
    if (widget.destination != null) {
      _endPlace = widget.destination;
    }

    // 3. 지도 로드
    _loadMap();

    // 4. 출발지+도착지 모두 있으면 경로 비교 자동 조회
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryFetchRouteComparison();
    });
  }

  Future<void> _loadMap() async {
    try {
      // 웹뷰 컨트롤러 초기화
      final controller = WebViewController();

      if (!kIsWeb) {
        controller
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000))
          ..addJavaScriptChannel(
            'MapChannel',
            onMessageReceived: (JavaScriptMessage message) {
              // 필요 시 메시지 처리
            },
          );
      }

      _mapController = controller;

      // IMPORTANT: setState FIRST to add WebViewWidget to the widget tree,
      // creating the iframe in DOM. Then load the URL.
      // (MapScreen does this same pattern and it works.)
      if (mounted) setState(() {});

      // Small delay to let the iframe element be created in DOM
      await Future.delayed(const Duration(milliseconds: 100));

      if (kIsWeb) {
        // 웹: URL 파라미터로 초기화
        // mapId 전달, level=3 적당한 줌
        final jsKey = KakaoConfig.jsAppKey;
        var url =
            '${Uri.base.origin}/kakao_map.html?appkey=$jsKey&v=${DateTime.now().millisecondsSinceEpoch}&mapId=$_mapId&level=3';

        // 출발지 좌표가 있으면 거기를 중심으로 (없으면 기본 서울)
        final startLatLng = _getPlaceLatLng(_startPlace);
        if (startLatLng != null) {
          url += '&lat=${startLatLng.latitude}&lng=${startLatLng.longitude}';
        }

        debugPrint('Map URL: $url');
        _mapController!.loadRequest(Uri.parse(url));
      } else {
        // 모바일: HTML 직접 로드
        controller.setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              debugPrint('WebView: Page started loading: $url');
            },
            onPageFinished: (String url) {
              debugPrint('WebView: Page finished loading: $url');
              _updateMapMarkers();
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('WebView Error: ${error.description}');
            },
          ),
        );

        String fileText = await rootBundle.loadString('assets/kakao_map.html');
        fileText = fileText.replaceAll('__KAKAO_KEY__', KakaoConfig.jsAppKey);

        // 모바일 환경에서 Seongsu Station 디폴트 좌표를 출발지(현재위치) 좌표로 동적 치환
        final startLatLng = _getPlaceLatLng(_startPlace);
        if (startLatLng != null) {
          fileText = fileText.replaceAll('37.5445', startLatLng.latitude.toString());
          fileText = fileText.replaceAll('127.0560', startLatLng.longitude.toString());
        }

        await _mapController!.loadHtmlString(
          fileText,
          baseUrl: 'https://gilbeot.app',
        );
      }
    } catch (e) {
      debugPrint('Map Init Error: $e');
      if (mounted) {
        setState(() {
          _mapInitError = e.toString();
        });
      }
    }
  }

  /// 지도 그리기 헬퍼
  Widget _buildMap() {
    if (_mapController == null) {
      if (_mapInitError != null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                '지도 초기화 오류\n$_mapInitError',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: WebViewWidget(controller: _mapController!),
    );
  }

  /// 선택된 경로를 지도에 그리기 (모든 경로를 동시에 표시)
  void _drawRoute(int index) {
    debugPrint('>>> _drawRoute called with index=$index');
    if (_comparisonData == null || _mapController == null) {
      debugPrint(
        '>>> _drawRoute ABORTED: comparisonData=${_comparisonData != null}, controller=${_mapController != null}',
      );
      return;
    }

    final modes = ['optimal', 'short', 'safe'];
    final colors = [
      '#00C853', // Optimal - Green
      '#2979FF', // Short - Blue
      '#9C27B0', // Safe - Purple
    ];

    // Build route data for ALL 3 routes
    final List<Map<String, dynamic>> allRoutes = [];
    for (int i = 0; i < modes.length; i++) {
      final mode = modes[i];
      final routeData = _comparisonData![mode];

      List<List<double>> path = [];
      if (routeData != null && routeData['geometry'] != null) {
        try {
          final rawGeometry = routeData['geometry'] as List;
          path = rawGeometry
              .map((coord) {
                final c = (coord as List)
                    .map((e) => (e as num).toDouble())
                    .toList();
                if (c.length >= 2) {
                  return [c[0], c[1]];
                }
                return null;
              })
              .whereType<List<double>>()
              .toList();
        } catch (e) {
          debugPrint('Error parsing route $mode geometry: $e');
        }
      }

      allRoutes.add({'path': path, 'color': colors[i]});
      debugPrint('>>> Route $mode: ${path.length} points, color=${colors[i]}');
    }

    debugPrint(
      '>>> Sending drawAllRoutes with selectedIndex=$index, mapId=$_mapId',
    );
    KakaoMapHelper.drawAllRoutes(
      _mapController,
      allRoutes,
      index,
      mapId: _mapId,
    );
  }

  void _updateMapMarkers() {
    if (_mapController == null) return;

    final startLatLng = _getPlaceLatLng(_startPlace);
    final endLatLng = _getPlaceLatLng(_endPlace);

    if (startLatLng != null || endLatLng != null) {
      KakaoMapHelper.setStartEndMarkers(
        _mapController,
        startLatLng?.latitude,
        startLatLng?.longitude,
        endLatLng?.latitude,
        endLatLng?.longitude,
        mapId: _mapId,
      );
    }
  }

  Future<void> _fetchCurrentAddress() async {
    final latLng = _getPlaceLatLng(_startPlace);
    if (latLng != null) {
      try {
        String address = await KakaoService.coord2Address(
          latLng.latitude,
          latLng.longitude,
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

  // userLocation이 초기 null일 때 비동기로 현재 위치를 받아 보완하는 로직
  Future<void> _fetchCurrentLocationIfNull() async {
    if (widget.userLocation == null) {
      try {
        Position? position;
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 3),
          );
        } catch (_) {
          position = await Geolocator.getLastKnownPosition();
        }

        if (position != null && mounted) {
          setState(() {
            _startPlace = {
              'latlng': LatLng(position!.latitude, position!.longitude),
              'name': '현재 위치',
              'address': '',
            };
          });
          await _fetchCurrentAddress();
          _updateMapMarkers();

          if (_mapController != null) {
            // 모바일 HTML 37.5445, 127.0560 교체 로직은 HTML 로드 시 적용되므로,
            // 이미 로드된 맵은 setCenter로 다시 이동시켜줍니다.
            KakaoMapHelper.setCenter(
              _mapController!,
              position.latitude,
              position.longitude,
              mapId: _mapId,
            );
          }
        }
      } catch (e) {
        debugPrint('Error fetching location dynamically: $e');
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
      // 장소 변경 시 경로 비교 자동 조회
      _tryFetchRouteComparison();

      // 마커 업데이트
      _updateMapMarkers();

      // 지도 이동 로직: setCenter + panTo로 맵 뷰포트를 새 위치로 확실히 이동
      final latLng = _getPlaceLatLng(isStart ? _startPlace : _endPlace);
      if (latLng != null && _mapController != null) {
        KakaoMapHelper.setCenter(
          _mapController!,
          latLng.latitude,
          latLng.longitude,
          mapId: _mapId,
        );
        KakaoMapHelper.panTo(
          _mapController!,
          latLng.latitude,
          latLng.longitude,
          mapId: _mapId,
        );
      }
    }
  }

  // 출발지-도착지 교환
  void _swapLocations() {
    setState(() {
      final temp = _startPlace;
      _startPlace = _endPlace;
      _endPlace = temp;
    });
    _updateMapMarkers();
    _tryFetchRouteComparison();
  }

  /// 출발지/도착지 좌표 추출 헬퍼
  LatLng? _getPlaceLatLng(Map<String, dynamic>? place) {
    if (place == null) return null;

    // latlng 객체가 있는 경우
    if (place['latlng'] != null) {
      return place['latlng'] as LatLng;
    }
    // lat / lng 필드가 있는 경우 (SavedPlaces용)
    if (place['lat'] != null && place['lng'] != null) {
      return LatLng(
        (place['lat'] as num).toDouble(),
        (place['lng'] as num).toDouble(),
      );
    }
    // 현재 위치
    if (place['isCurrentLocation'] == true && widget.userLocation != null) {
      return widget.userLocation!;
    }
    return null;
  }

  /// 출발지+도착지 모두 설정되면 경로 비교 API 호출
  Future<void> _tryFetchRouteComparison() async {
    final startLatLng = _getPlaceLatLng(_startPlace);
    final endLatLng = _getPlaceLatLng(_endPlace);
    if (startLatLng == null || endLatLng == null) return;

    setState(() {
      _isLoadingRoutes = true;
      _routeError = null;
      _comparisonData = null;
    });

    try {
      final user = await ApiService.getUserProfile();

      String wheelchairType = user?.wheelchairType ?? 'Manual';

      // 서버용 값으로 변환
      switch (wheelchairType) {
        case 'Electric':
          wheelchairType = 'electric';
          break;
        case 'Manual':
          wheelchairType = 'manual';
          break;
        case 'CaregiverManual':
          wheelchairType = 'manual_with_helper';
          break;
        case 'None':
          wheelchairType = 'none';
          break;
        default:
          wheelchairType = 'manual';
      }

      final result = await ApiService.compareRoutes(
        startLat: startLatLng.latitude,
        startLon: startLatLng.longitude,
        endLat: endLatLng.latitude,
        endLon: endLatLng.longitude,
        wheelchairType: wheelchairType,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _comparisonData = result['comparison'] as Map<String, dynamic>?;
          _isLoadingRoutes = false;
        });
        // 결과 나오면 현재 선택된 인덱스 경로 그리기
        Future.delayed(const Duration(milliseconds: 500), () {
          _drawRoute(_selectedRouteIndex);
        });
      } else {
        setState(() {
          _routeError = result['message'] ?? '경로 조회 실패';
          _isLoadingRoutes = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _routeError = '경로 조회 중 오류 발생';
        _isLoadingRoutes = false;
      });
    }
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
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. Map Layer (Background)
          // Use Positioned.fill ensures it covers the area
          // 1. Map Layer (Background)
          Positioned.fill(child: _buildMap()),
          // 2. UI Layer
          SafeArea(
            child: Column(
              children: [
                // Top Fixed Inputs
                PointerInterceptor(
                  child: Container(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).scaffoldBackgroundColor
                        : Colors.white,
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
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

                                    // switch 아이콘
                                    Positioned(
                                      right: 24,
                                      top: 31,
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.grey[300]!,
                                          ),
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
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
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
                              // x 아이콘 (닫기)
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.black54,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                style: IconButton.styleFrom(
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Draggable Sheet Area
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Start/End are set? Show dashboard.
                      final hasRoute = _startPlace != null && _endPlace != null;

                      if (!hasRoute) return const SizedBox.shrink();

                      // 목적 높이: 드래그 핸들(~40) + 캐러셀(124) + 인디케이터(~20) + 버튼(~50) + 최소 패딩 = 약 270px
                      final double targetHeight = 270.0;
                      final double ratio =
                          (targetHeight / constraints.maxHeight).clamp(
                            0.15,
                            1.0,
                          );

                      // Draggable Sheet Logic
                      return DraggableScrollableSheet(
                        controller: _sheetController,
                        initialChildSize: hasRoute ? ratio : 0.4,
                        minChildSize: 0.15,
                        maxChildSize: hasRoute ? ratio : 1.0,
                        snap: true,
                        snapSizes: hasRoute
                            ? [0.15, ratio]
                            : const [0.15, 0.6, 1.0],
                        builder: (context, scrollController) {
                          return PointerInterceptor(
                            child: Container(
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
                                controller: scrollController,
                                physics: const ClampingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  21,
                                  10,
                                  21,
                                  0,
                                ),
                                children: [
                                  // Drag Handle
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onVerticalDragUpdate: (details) {
                                      // Custom drag logic
                                      final sheetHeight = constraints.maxHeight;
                                      final delta =
                                          -details.delta.dy / sheetHeight;
                                      final currentSize = _sheetController.size;
                                      final newSize = (currentSize + delta)
                                          .clamp(0.15, hasRoute ? ratio : 1.0);
                                      _sheetController.jumpTo(newSize);
                                    },
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 42,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFD1D5DC),
                                            borderRadius: BorderRadius.circular(
                                              100,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Content
                                  if (!hasRoute)
                                    // Empty state or History
                                    Column(
                                      children: [
                                        // History logic here
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
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
                                              child: const Text(
                                                '모두 지우기',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF9EA6B8),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        // TODO: Recent searches list
                                      ],
                                    )
                                  else if (_isLoadingRoutes)
                                    const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(40.0),
                                        child: CircularProgressIndicator(),
                                      ),
                                    )
                                  else if (_routeError != null)
                                    Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Text(
                                        _routeError!,
                                        style: const TextStyle(
                                          color: Colors.red,
                                        ),
                                      ),
                                    )
                                  else if (_comparisonData != null)
                                    // Route Carousel & Button
                                    Column(
                                      children: [
                                        // Carousel
                                        SizedBox(
                                          height: 124,
                                          child: useRowLayout
                                              ? Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: List.generate(3, (
                                                    index,
                                                  ) {
                                                    return Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                          ),
                                                      child: SizedBox(
                                                        width: 320,
                                                        child: GestureDetector(
                                                          onTap: () {
                                                            setState(() {
                                                              _selectedRouteIndex =
                                                                  index;
                                                            });
                                                            _drawRoute(index);
                                                            if (!useRowLayout &&
                                                                _pageController !=
                                                                    null) {
                                                              _pageController!.animateToPage(
                                                                index,
                                                                duration:
                                                                    const Duration(
                                                                      milliseconds:
                                                                          300,
                                                                    ),
                                                                curve: Curves
                                                                    .easeInOut,
                                                              );
                                                            }
                                                          },
                                                          child:
                                                              _buildSelectableRouteCard(
                                                                index,
                                                              ),
                                                        ),
                                                      ),
                                                    );
                                                  }),
                                                )
                                              : PageView.builder(
                                                  controller: _pageController,
                                                  padEnds: false,
                                                  itemCount: 3,
                                                  onPageChanged: (index) {
                                                    setState(() {
                                                      _selectedRouteIndex =
                                                          index;
                                                    });
                                                    _drawRoute(index);
                                                  },
                                                  itemBuilder: (context, index) {
                                                    return SizedBox(
                                                      width: 320,
                                                      child: GestureDetector(
                                                        onTap: () {
                                                          setState(() {
                                                            _selectedRouteIndex =
                                                                index;
                                                          });
                                                          _drawRoute(index);
                                                          if (_pageController !=
                                                              null) {
                                                            _pageController!
                                                                .animateToPage(
                                                                  index,
                                                                  duration:
                                                                      const Duration(
                                                                        milliseconds:
                                                                            300,
                                                                      ),
                                                                  curve: Curves
                                                                      .easeInOut,
                                                                );
                                                          }
                                                        },
                                                        child:
                                                            _buildSelectableRouteCard(
                                                              index,
                                                            ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                        ),
                                        const SizedBox(height: 12),
                                        // Dots
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: List.generate(3, (index) {
                                            return AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 300,
                                              ),
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                  ),
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color:
                                                    _selectedRouteIndex == index
                                                    ? const Color(0xFF00C853)
                                                    : Colors.grey[300],
                                              ),
                                            );
                                          }),
                                        ),
                                        const SizedBox(height: 12),
                                        // Start Navigation Button
                                        _buildStartNavigationButton(),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartNavigationButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF00C853),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00C853).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(25),
            onTap: _onStartNavigation,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.navigation_rounded, color: Colors.white, size: 20),
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
    );
  }

  Future<void> _onStartNavigation() async {
    if (_startPlace == null || _endPlace == null) {
      CommonToast.show(context, '출발지와 도착지를 모두 설정해주세요.');
      return;
    }

    final startLatLng = _getPlaceLatLng(_startPlace);
    final endLatLng = _getPlaceLatLng(_endPlace);
    if (startLatLng == null || endLatLng == null) {
      CommonToast.show(context, '위치 정보를 불러올 수 없습니다.');
      return;
    }

    final startLat = startLatLng.latitude;
    final startLon = startLatLng.longitude;
    final endLat = endLatLng.latitude;
    final endLon = endLatLng.longitude;

    String mode;
    if (_selectedRouteIndex == 0)
      mode = 'optimal';
    else if (_selectedRouteIndex == 1)
      mode = 'short';
    else
      mode = 'safe';

    int avoidedObstacles = 0;
    if (_comparisonData != null) {
      final modes = ['optimal', 'short', 'safe'];
      final modeData = _comparisonData![modes[_selectedRouteIndex]];
      if (modeData != null) {
        avoidedObstacles = modeData['avoided_obstacles'] ?? 0;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = await ApiService.getUserProfile();

      String wheelchairType = user?.wheelchairType ?? 'Manual';

      // 서버용 값으로 변환
      switch (wheelchairType) {
        case 'Electric':
          wheelchairType = 'electric';
          break;
        case 'Manual':
          wheelchairType = 'manual';
          break;
        case 'CaregiverManual':
          wheelchairType = 'manual_with_helper';
          break;
        case 'None':
          wheelchairType = 'none';
          break;
        default:
          wheelchairType = 'manual';
      }

      final result = await ApiService.findRoute(

        startLat: startLat,
        startLon: startLon,
        endLat: endLat,
        endLon: endLon,
        mode: mode,
        wheelchairType: wheelchairType,
      );

      if (context.mounted) Navigator.pop(context);

      if (result['success'] == true) {
        final routeData = result['route'] ?? result;
        final time = '${routeData['estimated_time']}분';
        final distance =
            '${(routeData['distance'] / 1000).toStringAsFixed(1)}km';
        final geometry = (routeData['geometry'] as List)
            .map((e) => (e as List).map((c) => c as double).toList())
            .toList();

        final instructions =
            (routeData['instructions'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];

        String routeTitle = _selectedRouteIndex == 0
            ? '추천 경로'
            : _selectedRouteIndex == 1
            ? '최단 경로'
            : '안전 경로';

        if (mounted) {
          // 장소 이름 추출 (표시용 및 저장용)
          final startName = _startPlace?['isCurrentLocation'] == true
              ? (_startPlace?['address'] != null &&
                        _startPlace!['address'].toString().isNotEmpty
                    ? _startPlace!['address']
                    : '현재 위치')
              : (_startPlace?['name'] ?? '출발지');

          final endName = _endPlace?['isCurrentLocation'] == true
              ? (_endPlace?['address'] != null &&
                        _endPlace!['address'].toString().isNotEmpty
                    ? _endPlace!['address']
                    : '현재 위치')
              : (_endPlace?['name'] ?? '도착지');

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NavigationScreen(
                routeType: routeTitle,
                estimatedTime: time,
                totalDistance: distance,
                startLocation: LatLng(startLat, startLon),
                endLocation: LatLng(endLat, endLon),
                routeGeometry: geometry,
                instructions: instructions,
                avoidedObstacles: avoidedObstacles,
                startLocationName: startName,
                endLocationName: endName,
              ),
              settings: const RouteSettings(name: 'navigation'),
            ),
          );
        }
      } else {
        if (context.mounted) {
          CommonToast.show(context, '경로 탐색 실패: ${result['message']}');
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        CommonToast.show(context, '오류 발생: $e');
      }
    }
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
      textColor = Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : Colors.black87;
    } else {
      text = isStart ? '출발지를 입력하세요' : '도착지를 입력하세요';
      textColor = Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : const Color(0xFF9EA6B8);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
      padding: const EdgeInsets.all(12), // 패딩 줄임 (16 -> 12)
      decoration: BoxDecoration(
        color: isSelected
            ? Color.lerp(
          Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E1E1E)
              : Colors.white,
          themeColor,
          0.05,
        )!
            : Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? themeColor
              : Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2C2C2C)
              : const Color(0xFFF3F4F6),
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
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Color(0xFF101727),
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
          const SizedBox(height: 8), // 간격 축소 (10 -> 8)
          // Info Info
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: Theme.of(context).brightness == Brightness.dark
                  ? Color(0xFF9CA3AF)
                  : Color(0xFF4A5565)),
              const SizedBox(width: 4),
              Text(
                time,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Color(0xFF9CA3AF)
                      : Color(0xFF4A5565), // Unified textGrey
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.route_outlined,
                size: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Color(0xFF9CA3AF)
                    : Color(0xFF4A5565),
              ),
              const SizedBox(width: 4),
              Text(
                distance,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Color(0xFF9CA3AF)
                      : Color(0xFF4A5565), // Unified textGrey
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
          const SizedBox(height: 8), // 간격 축소 (10 -> 8)
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
    // 모드 매핑: 0=optimal(추천), 1=short(최단), 2=safe(안전)
    final modes = ['optimal', 'short', 'safe'];
    final titles = ['추천 경로', '최단 경로', '안전 경로'];
    final icons = [
      Icons.star_outline_rounded,
      Icons.bolt_rounded,
      Icons.accessible_forward,
    ];
    final colors = [
      const Color(0xFF00C853),
      const Color(0xFF2979FF),
      const Color(0xFF9C27B0),
    ];

    String time = '--분';
    String distance = '--km';
    int obstacleCount = 0;
    List<String> tags = [];

    if (_comparisonData != null) {
      final modeKey = modes[index];
      final modeData = _comparisonData![modeKey];
      if (modeData != null && modeData['success'] == true) {
        final estTime = modeData['estimated_time'];
        final dist = modeData['distance'];
        obstacleCount = modeData['avoided_obstacles'] ?? 0;

        if (estTime != null) time = '${estTime}분';
        if (dist != null) {
          distance = '${(dist / 1000).toStringAsFixed(1)}km';
        }

        // 태그 생성
        if (obstacleCount == 0) {
          tags.add('장애물 없음');
        } else {
          tags.add('장애물 $obstacleCount개 회피');
        }
        if (index == 2) tags.add('안전 우선');
        if (index == 1) tags.add('최단 거리');
        if (index == 0) tags.add('균형 잡힌 경로');
      } else {
        tags.add('경로 없음');
      }
    } else if (_isLoadingRoutes) {
      tags.add('조회 중...');
    } else {
      tags.add('경로 미조회');
    }

    return {
      'title': titles[index],
      'icon': icons[index],
      'themeColor': colors[index],
      'time': time,
      'distance': distance,
      'obstacleCount': obstacleCount,
      'tags': tags,
    };
  }

  Widget _buildSelectableRouteCard(int index) {
    final info = _getRouteInfo(index);
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRouteIndex = index;
        });
        _drawRoute(index);
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
