import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gilbeot/screens/camera_screen.dart';
import 'package:gilbeot/screens/location_adjust_screen.dart';
import 'package:gilbeot/screens/report_success_screen.dart';
import 'package:gilbeot/screens/obstacle_check_screen.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';

import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:gilbeot/helpers/kakao_map_helper.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'package:gilbeot/widgets/common_toast.dart';

class ReportConfirmScreen extends StatefulWidget {
  final latlong.LatLng location;
  final String address;
  final String? imagePath;
  final String? obstacleType;
  final String? obstacleId;
  final bool fromNavigation;
  final bool fromNavigationEnd;

  const ReportConfirmScreen({
    super.key,
    required this.location,
    required this.address,
    this.imagePath,
    this.obstacleType,
    this.obstacleId,
    this.fromNavigation = false,
    this.fromNavigationEnd = false,
  });

  @override
  State<ReportConfirmScreen> createState() => _ReportConfirmScreenState();
}

class _ReportConfirmScreenState extends State<ReportConfirmScreen> {
  WebViewController? _mapController;
  final TextEditingController _descriptionController = TextEditingController();

  late latlong.LatLng _currentLocation;
  late String _currentAddress;
  String? _currentImagePath;
  String? _currentObstacleType;
  String? _currentObstacleId;

  final List<Map<String, String>> _obstacleData = [
    {'id': 'stairs', 'label': '계단', 'image': 'assets/stairs.png'},
    {'id': 'cone', 'label': '라바콘', 'image': 'assets/traffic_cone.png'},
    {'id': 'bollard', 'label': '볼라드', 'image': 'assets/bollards.png'},
    {'id': 'slope', 'label': '경사로', 'image': 'assets/slope.png'},
    {'id': 'curb', 'label': '턱', 'image': 'assets/curb.png'},
    {'id': 'other', 'label': '기타', 'image': 'assets/pencil.png'},
  ];

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.location;
    _currentAddress = widget.address;
    _currentImagePath = widget.imagePath;
    _currentObstacleType = widget.obstacleType;
    _currentObstacleId = widget.obstacleId;
    _initMapController();
  }

  Future<void> _initMapController() async {
    final controller = WebViewController();
    if (!kIsWeb) {
      controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      controller.setBackgroundColor(const Color(0x00000000));
    }
    _mapController = controller;
    if (mounted) setState(() {});
    await _loadMap();
  }

  Future<void> _loadMap() async {
    if (_mapController == null) return;

    if (kIsWeb) {
      final lat = _currentLocation.latitude;
      final lng = _currentLocation.longitude;
      await _mapController!.loadRequest(
        Uri.parse(
          '${Uri.base.origin}/kakao_map.html?v=${DateTime.now().millisecondsSinceEpoch}&lat=$lat&lng=$lng&marker=true',
        ),
      );
      Future.delayed(const Duration(milliseconds: 1000), () {
        KakaoMapHelper.setStaticMode(_mapController, true);
      });
    } else {
      String fileText = await rootBundle.loadString('assets/kakao_map.html');
      await _mapController!.loadHtmlString(
        fileText,
        baseUrl: 'https://gilbeot.app',
      );
    }

    _mapController!.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (String url) {
          KakaoMapHelper.setCenter(
            _mapController,
            _currentLocation.latitude,
            _currentLocation.longitude,
          );
          KakaoMapHelper.setMarker(
            _mapController,
            _currentLocation.latitude,
            _currentLocation.longitude,
          );
          KakaoMapHelper.setStaticMode(_mapController, true);
        },
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Container(
              height: 56,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF354152),
                      ),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  const Text(
                    '제보 확인',
                    style: TextStyle(
                      color: Color(0xFF354152),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(color: const Color(0xFFF0F2F5), height: 1.0),

            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_currentImagePath != null)
                            _buildPhotoCard(context),
                          if (_currentImagePath != null)
                            const SizedBox(height: 20),
                          if (_currentObstacleType != null)
                            _buildObstacleCard(context),
                          if (_currentObstacleType != null)
                            const SizedBox(height: 20),
                          _buildLocationCard(context),
                          const SizedBox(height: 20),
                          _buildDescriptionCard(),
                          const SizedBox(height: 32),
                          _buildSubmitButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoCard(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.black, // Placeholder for image bg
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: kIsWeb
                ? Image.network(
                    _currentImagePath!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  )
                : Image.file(
                    File(_currentImagePath!),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: () => _editPhoto(context),
              behavior: HitTestBehavior.translucent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 16,
                      color: Color(0xFF101727),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '재촬영',
                      style: TextStyle(
                        fontSize: 12,
                        // fontWeight: FontWeight.w600,
                        color: Color(0xFF101727),
                      ),
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

  Widget _buildObstacleCard(BuildContext context) {
    List<String> ids = [];
    if (_currentObstacleId != null && _currentObstacleId!.isNotEmpty) {
      ids = _currentObstacleId!.split(',').map((e) => e.trim()).toList();
    } else {
      ids.add('stairs'); // default
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Render icons (max 3 with overlapping logic or +N)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ids.length <= 3)
                ...ids.map((id) => _buildIconContainer(id))
              else ...[
                _buildIconContainer(ids[0]),
                _buildIconContainer(ids[1]),
                _buildPlusContainer(ids.length - 2),
              ],
            ],
          ),

          const SizedBox(width: 8), // Adjusted spacing

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '장애물 종류',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9EA6B8)),
                ),
                Text(
                  _currentObstacleType ?? '알 수 없음',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF101727),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _editObstacle(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Icon(Icons.edit, size: 16, color: Color(0xFF00C853)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFF00C853),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '위치',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9EA6B8),
                      // fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _editLocation(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Icon(
                    Icons.edit,
                    size: 16,
                    color: Color(0xFF00C853),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            _currentAddress,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF101727),
            ),
          ),
          const SizedBox(height: 16),
          // Map Preview
          Container(
            height: 80,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.black, // fallback
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _mapController == null
                  ? const Center(child: CircularProgressIndicator())
                  : WebViewWidget(controller: _mapController!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '상세 설명',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF101727),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(선택사항)',
                style: TextStyle(fontSize: 12, color: Color(0xFF9EA6B8)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '장애물에 대한 추가 정보(높이, 너비, 우회로 등)를 입력해주세요.',
              hintStyle: TextStyle(color: Color(0xFF9EA6B8), fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  bool _isLoading = false;

  Future<void> _submitReport() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final user = AuthService.currentUser;
    if (user == null) {
      if (mounted) {
        CommonToast.show(context, '제보를 하려면 로그인이 필요합니다.');
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      // 웹에서 이미지 바이트 다운로드
      Uint8List? imageBytes;
      if (kIsWeb &&
          _currentImagePath != null &&
          _currentImagePath!.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(_currentImagePath!));
          if (response.statusCode == 200) {
            imageBytes = response.bodyBytes;
          }
        } catch (e) {
          debugPrint('Web image download failed: $e');
        }
      }

      final result = await ApiService.submitReport(
        latitude: _currentLocation.latitude,
        longitude: _currentLocation.longitude,
        obstacleType: _currentObstacleType ?? '알 수 없음',
        description: _descriptionController.text,
        imagePath: _currentImagePath,
        address: _currentAddress,
        imageBytes: imageBytes,
        imageName: 'report_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      if (result['success'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ReportSuccessScreen(
              fromNavigation: widget.fromNavigation,
              fromNavigationEnd: widget.fromNavigationEnd,
            ),
          ),
        );
      } else {
        CommonToast.show(context, result['message'] ?? '제보 제출에 실패했습니다.');
      }
    } catch (e) {
      if (!mounted) return;
      CommonToast.show(context, '오류가 발생했습니다: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitReport,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00C853),
          disabledBackgroundColor: const Color(
            0xFF00C853,
          ).withValues(alpha: 0.6),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                '제보하기',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Future<void> _editPhoto(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CameraScreen(fromConfirm: true),
      ),
    );

    if (result != null && result is Map && mounted) {
      setState(() {
        _currentImagePath = result['imagePath'];
        if (result['obstacleType'] != null) {
          _currentObstacleType = result['obstacleType'];
        }
        if (result['obstacleId'] != null) {
          _currentObstacleId = result['obstacleId'];
        }
      });
    }
  }

  Future<void> _editObstacle(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ObstacleCheckScreen(
          imagePath: _currentImagePath!,
          initialObstacle: _currentObstacleId ?? 'stairs',
          fromConfirm: true,
        ),
      ),
    );

    if (result != null && result is Map && mounted) {
      setState(() {
        _currentImagePath = result['imagePath'];
        _currentObstacleType = result['obstacleType'];
        _currentObstacleId = result['obstacleId'];
      });
    }
  }

  Future<void> _editLocation(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationAdjustScreen(
          savedLocation: _currentLocation,
          savedAddress: _currentAddress,
        ),
      ),
    );

    if (result != null && result is Map && mounted) {
      setState(() {
        _currentLocation = result['latlng'];
        _currentAddress = result['address'];
      });
      if (_mapController != null) {
        await _loadMap();
      }
    }
  }

  Widget _buildIconContainer(String id) {
    String imageAsset = 'assets/stairs.png'; // fallback
    final found = _obstacleData.firstWhere(
      (e) => e['id'] == id,
      orElse: () => {},
    );
    if (found.isNotEmpty) {
      imageAsset = found['image']!;
    }
    return Container(
      width: 50,
      height: 50,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFF00C853).withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(8),
      child: Image.asset(imageAsset),
    );
  }

  Widget _buildPlusContainer(int count) {
    return Container(
      width: 50,
      height: 50,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        border: Border.all(
          color: const Color(0xFF00C853).withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          '+$count',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00C853),
          ),
        ),
      ),
    );
  }
}
