import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gilbeot/services/kakao_service.dart';
import 'package:gilbeot/helpers/kakao_map_helper.dart';
import 'package:gilbeot/config/kakao_config.dart';
import 'dart:convert';

class LocationAdjustScreen extends StatefulWidget {
  final latlong.LatLng savedLocation;
  final String savedAddress;

  const LocationAdjustScreen({
    super.key,
    required this.savedLocation,
    required this.savedAddress,
  });

  @override
  State<LocationAdjustScreen> createState() => _LocationAdjustScreenState();
}

class _LocationAdjustScreenState extends State<LocationAdjustScreen> {
  WebViewController? _mapController;
  late latlong.LatLng _currentCenter;
  String _currentAddress = '현재 위치를 불러오는 중...';
  bool _isLoadingAddress = false;

  @override
  void initState() {
    super.initState();
    // Start with saved location as fallback
    _currentCenter = widget.savedLocation;
    _currentAddress = widget.savedAddress;
    // Then try to get current location
    _initWithCurrentLocation();
  }

  Future<void> _initWithCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Fall back to saved location
        _initMapController();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _initMapController();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _initMapController();
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition();
      _currentCenter = latlong.LatLng(position.latitude, position.longitude);

      // Get address for current location
      _getAddress(_currentCenter);

      // Now initialize the map with current location
      _initMapController();
    } catch (e) {
      debugPrint('Error getting current location: $e');
      // Fall back to saved location
      _initMapController();
    }
  }

  Future<void> _initMapController() async {
    try {
      final controller = WebViewController();

      if (!kIsWeb) {
        controller.setJavaScriptMode(JavaScriptMode.unrestricted);
        controller.setBackgroundColor(const Color(0x00000000));
      }

      // JavaScript channel only works on mobile, skip on web
      if (!kIsWeb) {
        controller.addJavaScriptChannel(
          'MapChannel',
          onMessageReceived: (JavaScriptMessage message) {
            try {
              final data = jsonDecode(message.message);
              if (data['type'] == 'dragend') {
                final lat = data['lat'];
                final lng = data['lng'];
                final newCenter = latlong.LatLng(lat, lng);
                setState(() {
                  _currentCenter = newCenter;
                });
                _getAddress(newCenter);
              }
            } catch (e) {
              debugPrint('Error parsing MapChannel message: $e');
            }
          },
        );
      } else {
        // On Web, use postMessage listener
        KakaoMapHelper.listenForMapEvents((type, lat, lng) {
          if (type == 'dragend') {
            final newCenter = latlong.LatLng(lat, lng);
            setState(() {
              _currentCenter = newCenter;
            });
            _getAddress(newCenter);
          }
        });
      }

      _mapController = controller;

      // Trigger rebuild first so WebView can render
      if (mounted) setState(() {});

      // Then load map content
      await _loadMap();
    } catch (e) {
      debugPrint('Error initializing map controller: $e');
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadMap() async {
    if (_mapController == null) return;

    try {
      // Navigation delegate only works reliably on mobile
      if (!kIsWeb) {
        await _mapController!.setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              debugPrint('Kakao Map Loaded: $url');
              KakaoMapHelper.setCenter(
                _mapController,
                _currentCenter.latitude,
                _currentCenter.longitude,
              );
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('WebResourceError: ${error.description}');
            },
          ),
        );
      }

      if (kIsWeb) {
        final lat = _currentCenter.latitude;
        final lng = _currentCenter.longitude;
        final jsKey = KakaoConfig.jsAppKey;
        debugPrint('Loading web map with initial center: $lat, $lng');

        await _mapController!.loadRequest(
          Uri.parse(
            '${Uri.base.origin}/kakao_map.html?appkey=$jsKey&v=${DateTime.now().millisecondsSinceEpoch}&lat=$lat&lng=$lng',
          ),
        );

        // Still keep the delayed setCenter calls as backup, just in case
        debugPrint('Will force set center to: $lat, $lng');

        Future.delayed(const Duration(milliseconds: 1000), () {
          debugPrint('Setting center (1s): $lat, $lng');
          KakaoMapHelper.setCenter(_mapController, lat, lng);
        });
        Future.delayed(const Duration(milliseconds: 2000), () {
          debugPrint('Setting center (2s): $lat, $lng');
          KakaoMapHelper.setCenter(_mapController, lat, lng);
        });
        Future.delayed(const Duration(milliseconds: 3000), () {
          debugPrint('Setting center (3s): $lat, $lng');
          KakaoMapHelper.setCenter(_mapController, lat, lng);
        });
      } else {
        final lat = _currentCenter.latitude;
        final lng = _currentCenter.longitude;
        String fileText = await rootBundle.loadString('assets/kakao_map.html');
        fileText = fileText.replaceAll('__KAKAO_KEY__', KakaoConfig.jsAppKey);
        await _mapController!.loadHtmlString(
          fileText,
          baseUrl:
              'https://gilbeot.app/?lat=$lat&lng=$lng&v=${DateTime.now().millisecondsSinceEpoch}',
        );
      }
    } catch (e) {
      debugPrint('Error loading map: $e');
    }
  }

  Future<void> _getAddress(latlong.LatLng point) async {
    setState(() {
      _isLoadingAddress = true;
    });

    try {
      final address = await KakaoService.coord2Address(
        point.latitude,
        point.longitude,
      );
      setState(() {
        _currentAddress = address;
      });
    } catch (e) {
      debugPrint('Error getting address: $e');
      setState(() {
        _currentAddress = '주소 변환 오류';
      });
    } finally {
      setState(() {
        _isLoadingAddress = false;
      });
    }
  }

  Future<void> _moveToCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition();
    final newCenter = latlong.LatLng(position.latitude, position.longitude);

    KakaoMapHelper.setCenter(
      _mapController,
      newCenter.latitude,
      newCenter.longitude,
    );

    setState(() {
      _currentCenter = newCenter;
    });
    _getAddress(newCenter);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Container(
              height: 56,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).cardColor
                  : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF354152)),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  Text(
                    '위치 수정',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Color(0xFF354152),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(color: const Color(0xFFF0F2F5), height: 1.0),

            Expanded(
              child: Stack(
                children: [
                  if (_mapController == null)
                    const Center(child: CircularProgressIndicator())
                  else
                    Positioned.fill(
                      child: WebViewWidget(controller: _mapController!),
                    ),
                  // Center Pin
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: 35,
                      ), // Adjust for pin tip
                      child: Icon(
                        Icons.location_on,
                        size: 40,
                        color: Color(0xFF00C853),
                      ),
                    ),
                  ),

                  // Floating Bottom Card
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        bottom: 30,
                        left: 20,
                        right: 20,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            PointerInterceptor(
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF2A2A2A)
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.15,
                                      ),
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
                                              : const Color(0xFF354152),
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            PointerInterceptor(
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Theme.of(context).scaffoldBackgroundColor
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(
                                    24,
                                  ), // Full rounded corners
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '이 위치가 맞나요?',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white
                                            : Color(0xFF101727),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? const Color(0xFF2A2A2A)
                                            : const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.location_on_outlined,
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? const Color(0xFF9CA3AF)
                                                : const Color(0xFF9EA6B8),
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              _currentAddress,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Theme.of(context).brightness == Brightness.dark
                                                    ? Colors.white
                                                    : Color(0xFF4A5565),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton(
                                      onPressed: _isLoadingAddress
                                          ? null
                                          : () {
                                              Navigator.pop(context, {
                                                'latlng': _currentCenter,
                                                'address': _currentAddress,
                                              });
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF00C853,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: const Text(
                                        '위치 설정 완료',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
          ],
        ),
      ),
    );
  }
}
