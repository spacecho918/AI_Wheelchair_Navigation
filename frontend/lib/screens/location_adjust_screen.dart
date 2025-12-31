import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // OSM 지도 패키지
import 'package:latlong2/latlong.dart'; // 좌표 패키지
import 'report_confirm_screen.dart';

class LocationAdjustScreen extends StatefulWidget {
  final String obstacleType; // 이전 화면에서 선택한 장애물 (예: 'stairs')
  final String imagePath;
  final String obstacleLabel;

  const LocationAdjustScreen({
    super.key,
    required this.obstacleType,
    required this.imagePath,
    required this.obstacleLabel,
  });

  @override
  State<LocationAdjustScreen> createState() => _LocationAdjustScreenState();
}

class _LocationAdjustScreenState extends State<LocationAdjustScreen> {
  // OSM 지도 컨트롤러
  final MapController _mapController = MapController();

  // 현재 중심 좌표 (기본값: 서울 시청)
  LatLng _center = const LatLng(37.5665, 126.9780);

  // 현재 주소 텍스트
  String _currentAddress = "위치 확인 중...";

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    // 실제 앱에서는 Geolocator 패키지로 현위치를 가져오세요.
    // 여기서는 시뮬레이션으로 서울 시청 좌표로 이동합니다.
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _center = const LatLng(37.5665, 126.9780);
        _currentAddress = "서울시 중구 세종대로 110";
      });
      // 지도가 로드된 후 이동
      _mapController.move(_center, 18.0);
    }
  }

  // 지도가 멈췄을 때 호출 (주소 갱신 로직)
  void _onMapIdle() {
    // OSM의 경우 'Nominatim' API를 사용해 무료로 주소 변환(Reverse Geocoding)이 가능합니다.
    // 여기서는 UI 테스트를 위해 좌표만 갱신합니다.
    debugPrint("현재 중심 좌표: ${_center.latitude}, ${_center.longitude}");
    setState(() {
      _currentAddress =
          "조정된 위치 (${_center.latitude.toStringAsFixed(4)}, ${_center.longitude.toStringAsFixed(4)})";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. OSM 지도 영역
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center, // 시작 위치
              initialZoom: 18.0, // 줌 레벨
              // 지도가 움직일 때마다 중심 좌표 갱신
              onPositionChanged: (MapCamera camera, bool hasGesture) {
                _center = camera.center;
              },
              // 움직임이 멈췄을 때 주소 찾기 (InteractionEnd)
              onMapEvent: (MapEvent event) {
                if (event is MapEventMoveEnd ||
                    event is MapEventFlingAnimationEnd) {
                  _onMapIdle();
                }
              },
              interactionOptions: const InteractionOptions(
                flags:
                    InteractiveFlag.all &
                    ~InteractiveFlag.rotate, // 회전 막기 (선택사항)
              ),
            ),
            children: [
              // 오픈스트리트맵 타일 레이어 (무료 사용)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.gilbeot', // 본인의 앱 패키지명 입력
              ),

              // (선택) OSM 저작권 표시는 앱 설정 메뉴 등에 넣는 것을 권장합니다.
              // RichAttributionWidget(...)
            ],
          ),

          // 2. 화면 중앙 고정 핀 (기준점)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 35), // 핀 끝이 중앙에 오도록 조정
              child: Icon(
                Icons.location_on,
                size: 50,
                color: Color(0xFF00C853), // Gilbeot Green
              ),
            ),
          ),

          // 3. 상단 헤더 (뒤로가기)
          Positioned(
            top: 50,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back, color: Colors.black87),
              ),
            ),
          ),

          // 4. 현위치 이동 버튼
          Positioned(
            right: 20,
            bottom: 240, // 하단 패널 높이 고려
            child: FloatingActionButton(
              onPressed: () {
                // 현위치로 이동 (여기선 서울 시청으로 고정)
                const myLocation = LatLng(37.5665, 126.9780);
                _mapController.move(myLocation, 18.0);

                setState(() {
                  _center = myLocation;
                  _currentAddress = "현위치로 이동됨";
                });
              },
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.black87),
            ),
          ),

          // 5. 하단 정보 패널
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x19000000),
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 정보 요약
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8FDF0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.check_circle_outline,
                          size: 20,
                          color: Color(0xFF00C853),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "선택된 위치",
                              style: TextStyle(
                                color: Color(0xFF697282),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentAddress, // 동적으로 바뀌는 주소
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF101727),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 좌표 정보
                  Text(
                    "GPS: ${_center.latitude.toStringAsFixed(6)}, ${_center.longitude.toStringAsFixed(6)}",
                    style: const TextStyle(
                      color: Color(0xFF99A1AE),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 확정 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        debugPrint("신고 위치 확정: $_center");
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReportConfirmScreen(
                              imagePath: widget.imagePath,
                              obstacleType: widget.obstacleType,
                              obstacleLabel: widget.obstacleLabel,
                              location: _center,
                              address: _currentAddress,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "이 위치로 확정하기",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      "지도를 움직여 핀을 장애물 위치에 맞춰주세요.",
                      style: TextStyle(color: Color(0xFF99A1AE), fontSize: 11),
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
