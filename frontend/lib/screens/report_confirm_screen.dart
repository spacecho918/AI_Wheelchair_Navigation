import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gilbeot/screens/camera_screen.dart';
import 'package:gilbeot/screens/location_adjust_screen.dart';
import 'package:gilbeot/screens/obstacle_check_screen.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:gilbeot/helpers/kakao_map_helper.dart';

class ReportConfirmScreen extends StatefulWidget {
  final latlong.LatLng location;
  final String address;
  final String? imagePath;
  final String? obstacleType;
  final String? obstacleId;

  const ReportConfirmScreen({
    super.key,
    required this.location,
    required this.address,
    this.imagePath,
    this.obstacleType,
    this.obstacleId,
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
          '${Uri.base.origin}/kakao_map.html?lat=$lat&lng=$lng&marker=true',
        ),
      );
      Future.delayed(const Duration(milliseconds: 1000), () {
        KakaoMapHelper.setStaticMode(_mapController, true);
      });
    } else {
      String fileText = await rootBundle.loadString('assets/kakao_map.html');
      await _mapController!.loadRequest(
        Uri.dataFromString(
          fileText,
          mimeType: 'text/html',
          encoding: Encoding.getByName('utf-8'),
        ),
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
      backgroundColor: const Color(0xFFF0FDF4), // Light mint background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '제보 확인',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_currentImagePath != null) _buildPhotoCard(context),
              if (_currentImagePath != null) const SizedBox(height: 20),
              if (_currentObstacleType != null) _buildObstacleCard(context),
              if (_currentObstacleType != null) const SizedBox(height: 20),
              _buildLocationCard(context),
              const SizedBox(height: 20),
              _buildDescriptionCard(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
            ],
          ),
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
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    color: Colors.black87,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '촬영된 사진',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Edit Button for Photo (Text Button Overlay)
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: () => _editPhoto(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit,
                  size: 16,
                  color: Color(0xFF00C853),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObstacleCard(BuildContext context) {
    String imageAsset = 'assets/stairs.png'; // default
    if (_currentObstacleId != null) {
      final found = _obstacleData.firstWhere(
        (e) => e['id'] == _currentObstacleId,
        orElse: () => {},
      );
      if (found.isNotEmpty) {
        imageAsset = found['image']!;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFF00C853).withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(8),
            child: Image.asset(imageAsset),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '장애물 종류',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                Text(
                  _currentObstacleType ?? '알 수 없음',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
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
            color: Colors.black.withValues(alpha: 0.05),
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
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '위치',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.bold,
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
              color: Colors.black87,
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
            color: Colors.black.withValues(alpha: 0.05),
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
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(선택사항)',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '장애물에 대한 추가 정보(높이, 너비, 우회로 등)를 입력해주세요.',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
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

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: () {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('신고가 접수되었습니다.'),
            backgroundColor: Color(0xFF00C853),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00C853),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: const Text(
        '신고하기',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
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
}
