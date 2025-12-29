import 'package:camera/camera.dart'; // 카메라 패키지
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  // 카메라 초기화 로직
  Future<void> _initCamera() async {
    try {
      // 1. 기기에서 사용 가능한 카메라 목록을 가져옵니다.
      final cameras = await availableCameras();

      // 2. 카메라가 있다면 첫 번째 카메라(보통 후면)를 선택합니다.
      final firstCamera = cameras.first;

      // 3. 컨트롤러를 생성합니다. (해상도는 높게 설정)
      _controller = CameraController(
        firstCamera,
        ResolutionPreset.high,
        enableAudio: false, // 단순 사진 촬영이면 오디오 불필요
      );

      // 4. 컨트롤러를 초기화합니다.
      _initializeControllerFuture = _controller!.initialize();

      // 5. 화면 갱신
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('카메라 초기화 오류: $e');
    }
  }

  @override
  void dispose() {
    // 위젯이 종료될 때 컨트롤러를 반드시 해제해야 메모리 누수가 없습니다.
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. 카메라 프리뷰 영역 (실제 카메라 화면)
          SizedBox.expand(
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  // 초기화가 완료되면 미리보기(Preview)를 보여줍니다.
                  // CameraPreview를 사용하여 비율을 맞춥니다.
                  return CameraPreview(_controller!);
                } else {
                  // 로딩 중일 때는 검은 화면에 로딩 인디케이터
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }
              },
            ),
          ),

          // 2. 3x3 격자 (Grid Lines)
          const _GridOverlay(),

          // 3. 상단 및 하단 UI 컨트롤 (기존 디자인 유지)
          SafeArea(
            child: Column(
              children: [
                // 상단 바 (닫기, 플래시)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTopIconBtn(
                        iconPath: 'assets/x_icon.svg',
                        onTap: () => Navigator.pop(context),
                      ),
                      _buildTopIconBtn(
                        iconPath: 'assets/flash_icon.svg',
                        onTap: () {
                          // 플래시 토글 기능 추가 가능
                        },
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // 하단 컨트롤 영역
                Container(
                  padding: const EdgeInsets.only(bottom: 30),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildGalleryButton(),
                            _buildShutterButton(),
                            _buildRotateButton(),
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

  // --- 아래는 기존 UI 위젯들 (Stateless 때와 동일) ---

  Widget _buildTopIconBtn({
    required String iconPath,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        color: Colors.transparent,
        child: SvgPicture.asset(
          iconPath,
          width: 24,
          height: 24,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      ),
    );
  }

  Widget _buildGalleryButton() {
    return Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2939).withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: SvgPicture.asset(
        'assets/gallery_icon.svg',
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      ),
    );
  }

  Widget _buildShutterButton() {
    return GestureDetector(
      onTap: () async {
        // 사진 촬영 로직 예시
        try {
          if (_controller != null && _controller!.value.isInitialized) {
            final image = await _controller!.takePicture();
            print("사진 촬영 완료: ${image.path}");
            // 여기서 찍은 사진을 처리하는 로직 추가
          }
        } catch (e) {
          print(e);
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
              color: const Color(0xFF00C853).withOpacity(0.5),
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

  Widget _buildRotateButton() {
    return SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: SvgPicture.asset(
            'assets/return_icon.svg',
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
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
              color: Colors.white.withOpacity(0.3),
              thickness: 1,
              height: 1,
            ),
            const Spacer(),
            Divider(
              color: Colors.white.withOpacity(0.3),
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
