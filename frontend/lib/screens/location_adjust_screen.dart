import 'dart:convert'; // JSON 파싱
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // OSM 지도 패키지
import 'package:latlong2/latlong.dart'; // 좌표 패키지
import 'package:http/http.dart' as http; // HTTP 요청
import 'package:geolocator/geolocator.dart'; // 위치 정보
import 'report_confirm_screen.dart';
import 'package:gilbeot/widgets/custom_back_button.dart';

class LocationAdjustScreen extends StatefulWidget {
  final String? obstacleType;
  final String? imagePath;
  final String? obstacleLabel;
  final bool isSelectionMode;

  const LocationAdjustScreen({
    super.key,
    this.obstacleType,
    this.imagePath,
    this.obstacleLabel,
    this.isSelectionMode = false,
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
  bool _isLocationLoading = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // 현위치 가져오기 로직
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocationLoading = true;
    });

    try {
      Position position = await _determinePosition();

      if (mounted) {
        final newCenter = LatLng(position.latitude, position.longitude);
        setState(() {
          _center = newCenter;
          _isLocationLoading = false;
        });

        // 지도가 로드된 후 이동
        _mapController.move(_center, 18.0);
        // 초기 위치 주소 가져오기
        _getAddressFromLatLng(_center);
      }
    } catch (e) {
      debugPrint("Location error: $e");
      if (mounted) {
        setState(() {
          _isLocationLoading = false;
          _currentAddress = "현재 위치를 가져올 수 없습니다.";
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("위치 정보를 가져오는 데 실패했습니다: $e")));
      }
    }
  }

  // 위치 권한 확인 및 위치 가져오기
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. 위치 서비스 활성화 여부 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('위치 서비스가 비활성화되어 있습니다.');
    }

    // 2. 권한 확인
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('위치 권한이 거부되었습니다.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.');
    }

    // 3. 현재 위치 가져오기
    return await Geolocator.getCurrentPosition();
  }

  // 좌표로 주소 가져오기 (Nominatim API)
  Future<void> _getAddressFromLatLng(LatLng latlng) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=json&lat=${latlng.latitude}&lon=${latlng.longitude}&zoom=18&addressdetails=1&accept-language=ko',
    );

    debugPrint("주소 변환 요청 시작: $url");

    try {
      // 타임아웃 10초 설정
      final response = await http
          .get(
            url,
            headers: {'User-Agent': 'GilbeotApp/1.0 (com.example.gilbeot)'},
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint("주소 변환 타임아웃!");
              throw Exception('요청 시간 초과');
            },
          );

      debugPrint("주소 변환 응답 코드: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];

        if (address != null) {
          String displayAddress = "";
          String subInfo = "";

          // 1순위: 도로명 추출
          String road = address['road'] ?? "";
          String houseNumber = address['house_number'] ?? "";

          if (road.isNotEmpty) {
            // 도로명 주소 구성 (예: 세종대로 110)
            displayAddress = "$road $houseNumber".trim();
          } else {
            // 도로명이 없으면 지번 주소 사용
            // 행정구역 순서대로 키 확인하여 존재하는 값 수집
            List<String> validKeys = [
              'province', 'city', // 광역 자치단체
              'borough', 'district', 'county', // 기초 자치단체
              'town', 'suburb', // 읍/면
              'quarter', 'neighbourhood', 'village', 'hamlet', // 동/리
            ];

            List<String> parts = [];
            Set<String> addedParts = {}; // 중복 제거용

            for (String key in validKeys) {
              String? value = address[key];
              if (value != null &&
                  value.isNotEmpty &&
                  !addedParts.contains(value)) {
                parts.add(value);
                addedParts.add(value);
              }
            }

            displayAddress = parts.join(" ").trim();
          }

          // 건물명/장소명 추출
          String placeName = "";
          List<String> poiKeys = [
            'building',
            'amenity',
            'office',
            'shop',
            'leisure',
            'tourism',
            'historic',
            'city_hall',
            'library',
          ];
          for (var key in poiKeys) {
            if (address.containsKey(key)) {
              placeName = address[key];
              break;
            }
          }

          // 사용자가 요청한 로직: 건물명이나 장소명이 도로명과 다를 때만 괄호 안에 표기
          if (placeName.isNotEmpty && placeName != road) {
            subInfo = "($placeName)";
          }

          // 최종 포맷팅: "$displayAddress $subInfo"
          String formattedAddress = "$displayAddress $subInfo".trim();

          // 국가명 ("대한민국") 제거
          if (formattedAddress.startsWith('대한민국')) {
            formattedAddress = formattedAddress.replaceFirst('대한민국', '').trim();
          }

          // 혹시라도 값이 비었다면 display_name 사용
          if (formattedAddress.isEmpty) {
            formattedAddress = data['display_name'] ?? "주소 없음";
            // 여기도 국가명 제거 적용
            if (formattedAddress.startsWith('대한민국')) {
              formattedAddress = formattedAddress
                  .replaceFirst('대한민국', '')
                  .trim();
            }
          }

          if (mounted) {
            setState(() {
              _currentAddress = formattedAddress;
            });
          }
        }
      } else {
        debugPrint("주소 변환 실패 - 상태 코드: ${response.statusCode}");
        if (mounted) {
          setState(() {
            _currentAddress = "주소 정보를 불러올 수 없습니다. (${response.statusCode})";
          });
        }
      }
    } catch (e) {
      debugPrint("주소 변환 오류: $e");
      if (mounted) {
        setState(() {
          // 사용자 친화적인 에러 메시지
          _currentAddress = "주소를 불러올 수 없습니다. 네트워크를 확인해주세요.";
        });
      }
    }
  }

  // 지도가 멈췄을 때 호출 (주소 갱신 로직)
  void _onMapIdle() {
    debugPrint("현재 중심 좌표: ${_center.latitude}, ${_center.longitude}");
    _getAddressFromLatLng(_center);
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
            top: 0,
            left: 20,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: const CustomBackButton(),
              ),
            ),
          ),

          // 4. 현위치 이동 버튼
          Positioned(
            right: 20,
            bottom: 240, // 하단 패널 높이 고려
            child: FloatingActionButton(
              onPressed: () {
                _getCurrentLocation(); // 현위치 재탐색
              },
              backgroundColor: Colors.white,
              child: _isLocationLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF00C853),
                      ),
                    )
                  : const Icon(Icons.my_location, color: Colors.black87),
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
                        if (widget.isSelectionMode) {
                          Navigator.pop(context, {
                            'latlng': _center,
                            'address': _currentAddress,
                          });
                        } else {
                          debugPrint("신고 위치 확정: $_center");
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReportConfirmScreen(
                                imagePath: widget.imagePath!,
                                obstacleType: widget.obstacleType!,
                                obstacleLabel: widget.obstacleLabel!,
                                location: _center,
                                address: _currentAddress,
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        widget.isSelectionMode ? "이 위치로 선택하기" : "이 위치로 확정하기",
                        style: const TextStyle(
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
