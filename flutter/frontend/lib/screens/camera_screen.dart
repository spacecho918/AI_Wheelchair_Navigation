import 'dart:typed_data';

import 'package:camera/camera.dart'; // 카메라 패키지
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart'; // 갤러리 접근용
import 'photo_confirmation_screen.dart';

class CameraScreen extends StatefulWidget {
  final bool fromConfirm;
  final bool fromNavigation;
  final bool fromNavigationEnd;

  const CameraScreen({
    super.key,
    this.fromConfirm = false,
    this.fromNavigation = false,
    this.fromNavigationEnd = false,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    // 웹/앱 모두 카메라 초기화 시도 (camera_web 지원 시 동작)
    _initCamera();
  }

  // 카메라 초기화 로직
  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final firstCamera = cameras.first;

      _controller = CameraController(
        firstCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      _initializeControllerFuture = _controller!.initialize();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('카메라 초기화 오류: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. 카메라 프리뷰 영역
          SizedBox.expand(
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return CameraPreview(_controller!);
                } else {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }
              },
            ),
          ),

          // 2. 3x3 격자
          const _GridOverlay(),

          // 3. 상단 및 하단 컨트롤
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Color(0xFF354152),
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                Container(
                  padding: const EdgeInsets.only(bottom: 30),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 40),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildGalleryButton(),
                            _buildShutterButton(),
                            _buildFlashButton(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '경로상의 장애물을 비춰주세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(
                              blurRadius: 4,
                              color: Colors.black,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 기존 UI 위젯들 ---

  Widget _buildGalleryButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        debugPrint("Gallery button tapped");
        try {
          final ImagePicker picker = ImagePicker();
          // 갤러리에서 이미지 선택 (AVIF/HEIF → JPEG 자동 변환)
          final XFile? image = await picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 85,
          );

          if (image != null && mounted) {
            // 웹 환경: bytes를 미리 읽어 전달 (blob URL 직접 표시 시 ImageCodecException 방지)
            Uint8List? bytes;
            if (kIsWeb) {
              bytes = await image.readAsBytes();
            }
            // 선택된 이미지로 확인 화면 이동
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PhotoConfirmationScreen(
                  imagePath: image.path,
                  imageBytes: bytes,
                  fromConfirm: widget.fromConfirm,
                  fromNavigation: widget.fromNavigation,
                  fromNavigationEnd: widget.fromNavigationEnd,
                ),
              ),
            );

            if (widget.fromConfirm && result != null && mounted) {
              Navigator.pop(context, result);
            }
          }
        } catch (e) {
          debugPrint("갤러리 접근 오류: $e");
        }
      },
      child: Container(
        width: 48,
        height: 48,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2939).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: SvgPicture.asset(
          'assets/gallery_icon.svg',
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      ),
    );
  }

  Widget _buildShutterButton() {
    return GestureDetector(
      onTap: () async {
        try {
          if (_controller != null && _controller!.value.isInitialized) {
            // 1. 사진 촬영
            final image = await _controller!.takePicture();
            debugPrint("사진 촬영 완료: ${image.path}");

            if (!mounted) return;

            // 2. 촬영된 사진 확인 화면으로 이동
            Uint8List? bytes;
            if (kIsWeb) bytes = await image.readAsBytes();

            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PhotoConfirmationScreen(
                  imagePath: image.path,
                  imageBytes: bytes,
                  fromConfirm: widget.fromConfirm,
                  fromNavigation: widget.fromNavigation,
                  fromNavigationEnd: widget.fromNavigationEnd,
                ),
              ),
            );

            if (widget.fromConfirm && result != null && mounted) {
              Navigator.pop(context, result);
            }
          }
        } catch (e) {
          debugPrint("카메라 촬영 오류: $e");
        }
      },
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF00C853), width: 4),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00C853).withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  // 플래시 버튼 - 기존 리셋 버튼 자리에 위치
  Widget _buildFlashButton() {
    return GestureDetector(
      onTap: () async {
        if (_controller == null) return;

        // 플래시 모드 토글 (off -> torch -> off)
        final currentMode = _controller!.value.flashMode;
        final newMode = currentMode == FlashMode.torch
            ? FlashMode.off
            : FlashMode.torch;

        try {
          await _controller!.setFlashMode(newMode);
          setState(() {}); // 아이콘 변경을 위해 상태 업데이트
        } catch (e) {
          debugPrint("플래시 모드 변경 오류: $e");
        }
      },
      child: Container(
        width: 48,
        height: 48,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2939).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Icon(
          _controller?.value.flashMode == FlashMode.torch
              ? Icons.flash_on
              : Icons.flash_off,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}

// 3x3 격자 무늬 위젯
class _GridOverlay extends StatelessWidget {
  const _GridOverlay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            const Spacer(),
            Divider(
              color: Colors.white.withValues(alpha: 0.3),
              thickness: 1,
              height: 1,
            ),
            const Spacer(),
            Divider(
              color: Colors.white.withValues(alpha: 0.3),
              thickness: 1,
              height: 1,
            ),
            const Spacer(),
          ],
        );
      },
    );
  }
}
