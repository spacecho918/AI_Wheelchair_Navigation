import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'obstacle_check_screen.dart';

/// 촬영·선택한 사진을 확인하는 화면
///
/// 웹 환경 이슈:
///   blob URL을 Image.network()에 직접 쓰면 브라우저 미디어 API가
///   ImageCodecException을 발생시킨다.
///   → camera_screen에서 XFile.readAsBytes()로 bytes를 미리 읽어
///     imageBytes로 전달받아 data URI로 표시한다.
class PhotoConfirmationScreen extends StatelessWidget {
  final String imagePath;
  final bool fromConfirm;
  final bool fromNavigation;
  final bool fromNavigationEnd;
  /// 웹 전용: camera_screen에서 pre-read한 raw bytes
  final Uint8List? imageBytes;

  const PhotoConfirmationScreen({
    super.key,
    required this.imagePath,
    this.imageBytes,
    this.fromConfirm = false,
    this.fromNavigation = false,
    this.fromNavigationEnd = false,
  });

  /// bytes 헤더를 보고 실제 이미지 MIME 타입을 반환한다.
  /// 잘못된 MIME 을 쓰면 브라우저 ImageDecoder 가 실패한다.
  static String _detectMimeType(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 12) {
      // ftyp box: offset 4~7 == 'ftyp', offset 8~11 == brand
      final ftyp = String.fromCharCodes(bytes.sublist(4, 8));
      if (ftyp == 'ftyp') {
        final brand = String.fromCharCodes(bytes.sublist(8, 12));
        if (brand.startsWith('avif') || brand.startsWith('avis')) {
          return 'image/avif';
        }
        if (brand.startsWith('heic') ||
            brand.startsWith('heis') ||
            brand.startsWith('mif1')) {
          return 'image/heif';
        }
      }
    }
    return 'image/jpeg'; // fallback
  }

  Widget _buildPreview() {
    if (kIsWeb && imageBytes != null) {
      // 실제 포맷을 감지해 올바른 MIME 타입으로 data URI 생성
      final mime = _detectMimeType(imageBytes!);
      final dataUri = 'data:$mime;base64,${base64Encode(imageBytes!)}';
      return Image.network(dataUri, fit: BoxFit.contain);
    }
    if (kIsWeb) {
      return Image.network(imagePath, fit: BoxFit.contain);
    }
    return Image.file(File(imagePath), fit: BoxFit.contain);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. 이미지 미리보기
          Positioned.fill(child: _buildPreview()),

          // 2. 하단 컨트롤러 (재촬영 / 사용하기)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 재촬영 버튼
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      '재촬영',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // 사진 사용 버튼
                  ElevatedButton(
                    onPressed: () async {
                      if (fromConfirm) {
                        Navigator.pop(context, {'imagePath': imagePath});
                        return;
                      }

                      // ObstacleCheckScreen으로 이동 (자동으로 AI 분석 실행)
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ObstacleCheckScreen(
                            imagePath: imagePath,
                            initialObstacle: '',
                            fromConfirm: fromConfirm,
                            fromNavigation: fromNavigation,
                            fromNavigationEnd: fromNavigationEnd,
                            imageBytes: imageBytes, // 웹에서 analyze API 첨부용
                          ),
                        ),
                      );

                      if (fromConfirm && result != null && context.mounted) {
                        Navigator.pop(context, result);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      '사진 사용',
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

          // 3. 상단 뒤로가기
          Positioned(
            left: 0,
            top: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 20, left: 20),
                child: GestureDetector(
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
                      color: Colors.black87,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
