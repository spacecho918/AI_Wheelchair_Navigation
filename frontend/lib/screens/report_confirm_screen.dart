import 'dart:io';
import 'package:flutter/foundation.dart'; // 웹/앱 구분용
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ReportConfirmScreen extends StatefulWidget {
  final String imagePath; // 촬영된 이미지 경로
  final String obstacleType; // 장애물 종류 (예: 'stairs')
  final String obstacleLabel; // 장애물 이름 (예: '계단')
  final LatLng location; // 확정된 좌표
  final String address; // 확정된 주소

  const ReportConfirmScreen({
    super.key,
    required this.imagePath,
    required this.obstacleType,
    required this.obstacleLabel,
    required this.location,
    required this.address,
  });

  @override
  State<ReportConfirmScreen> createState() => _ReportConfirmScreenState();
}

class _ReportConfirmScreenState extends State<ReportConfirmScreen> {
  // 추가 설명 입력 컨트롤러
  final TextEditingController _descriptionController = TextEditingController();

  // 장애물 종류에 따른 이미지 매핑
  String _getObstacleImage(String type) {
    // 실제 파일명에 맞춰서 매핑 (업로드해주신 파일 목록 참고)
    switch (type) {
      case 'stairs':
        return 'assets/stairs.png';
      case 'cone':
        return 'assets/traffic_cone.png';
      case 'bollard':
        return 'assets/bollards.png';
      case 'slope':
        return 'assets/slope.png';
      case 'curb':
        return 'assets/curb.png';
      default:
        return 'assets/etc.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 배경색 (Figma 그라데이션 적용을 위해 컨테이너로 감쌈)
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0FDF4), Color(0xFFEBFCF4)],
          ),
        ),
        child: Column(
          children: [
            // 1. 커스텀 앱바
            _buildAppBar(context),

            // 2. 스크롤 가능한 본문
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    // (1) 촬영된 사진 카드
                    _buildPhotoCard(),
                    const SizedBox(height: 20),

                    // (2) 장애물 종류 카드
                    _buildObstacleTypeCard(context),
                    const SizedBox(height: 20),

                    // (3) 위치 정보 카드 (지도 포함)
                    _buildLocationCard(context),
                    const SizedBox(height: 20),

                    // (4) 추가 설명 입력 카드
                    _buildDescriptionCard(),
                    const SizedBox(height: 20),

                    // (5) 제출 버튼
                    _buildSubmitButton(context),

                    const SizedBox(height: 10),
                    // 하단 안내 문구
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '신고를 제출함으로써, 지역 사회의 이동 편의성을 개선하기 위해 해당 정보를 공유하는 것에 동의하게 됩니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF697282),
                          fontSize: 10.5,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 위젯 빌더 함수들 ---

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 14,
        left: 14,
        right: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.arrow_back, color: Colors.black87),
            ),
          ),
          Expanded(
            child: Column(
              children: const [
                Text(
                  '신고 확인',
                  style: TextStyle(
                    color: Color(0xFF101727),
                    fontSize: 17.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '내용을 확인하고 제출해주세요',
                  style: TextStyle(color: Color(0xFF6A7282), fontSize: 12.25),
                ),
              ],
            ),
          ),
          const SizedBox(width: 40), // 타이틀 중앙 정렬을 위한 더미
        ],
      ),
    );
  }

  Widget _buildPhotoCard() {
    return Container(
      width: double.infinity,
      height: 168,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 촬영된 이미지 표시
          widget.imagePath.isNotEmpty
              ? (kIsWeb
                    ? Image.network(widget.imagePath, fit: BoxFit.cover)
                    : Image.file(File(widget.imagePath), fit: BoxFit.cover))
              : Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image),
                ),

          // 좌측 상단 뱃지
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: const [
                  Icon(Icons.camera_alt, size: 14, color: Colors.black87),
                  SizedBox(width: 6),
                  Text(
                    '촬영된 사진',
                    style: TextStyle(
                      color: Color(0xFF101727),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

  Widget _buildObstacleTypeCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // 아이콘 박스
              Container(
                width: 42,
                height: 42,
                padding: const EdgeInsets.all(4), // 이미지 패딩
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF00C853)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Image.asset(_getObstacleImage(widget.obstacleType)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '장애물 종류',
                    style: TextStyle(
                      color: Color(0xFF697282),
                      fontSize: 11,
                    ), // 폰트 사이즈 조정
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.obstacleLabel, // 예: 계단
                    style: const TextStyle(
                      color: Color(0xFF101727),
                      fontSize: 16, // 강조
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Edit 버튼
          _buildEditButton(() {
            // 종류 선택 화면으로 돌아가기
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          }),
        ],
      ),
    );
  }

  Widget _buildLocationCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8FDF0), // 연한 초록 배경
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Color(0xFF00C853),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '위치',
                        style: TextStyle(
                          color: Color(0xFF697282),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.address,
                        style: const TextStyle(
                          color: Color(0xFF101727),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.location.latitude.toStringAsFixed(6)}, ${widget.location.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(
                          color: Color(0xFF697282),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Edit 버튼
              _buildEditButton(() {
                // 위치 조정 화면으로 돌아가기
                Navigator.pop(context);
              }),
            ],
          ),
          const SizedBox(height: 14),

          // 지도 미리보기 (검정 화면 대체)
          Container(
            height: 112,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            clipBehavior: Clip.antiAlias,
            // 터치 이벤트 무시 (미리보기용)
            child: IgnorePointer(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: widget.location,
                  initialZoom: 17.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ), // 조작 금지
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.gilbeot',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: widget.location,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: Color(0xFF00C853),
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text(
                '추가 설명',
                style: TextStyle(
                  color: Color(0xFF101727),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              SizedBox(width: 8),
              Text(
                '(선택 사항)',
                style: TextStyle(color: Color(0xFF697282), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 입력창
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F3F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _descriptionController,
              maxLines: 3,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '장애물에 대한 상세 정보를 입력해주세요.\n예: 높이, 폭, 우회 경로 등',
                hintStyle: TextStyle(color: Color(0xFF99A1AE), fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 파란색 팁 박스
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF), // 아주 연한 파랑
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // warning_icon.svg 사용
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: SvgPicture.asset(
                    'assets/warning_icon.svg',
                    width: 14,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF193BB8),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '팁: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                              '장애물의 크기나 난이도, 혹은 주변의 랜드마크 정보를 포함하면 다른 사용자들에게 큰 도움이 됩니다.',
                        ),
                      ],
                      style: TextStyle(color: Color(0xFF193BB8), fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          // TODO: 최종 서버 전송 로직
          debugPrint("--- 최종 신고 데이터 ---");
          debugPrint("종류: ${widget.obstacleType}");
          debugPrint("위치: ${widget.location}");
          debugPrint("설명: ${_descriptionController.text}");

          // 완료 후 메인으로 이동
          Navigator.of(context).popUntil((route) => route.isFirst);

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('신고가 성공적으로 접수되었습니다!')));
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00C853),
          elevation: 5,
          shadowColor: const Color(0x3F00C853),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // send_icon.svg 사용
            SvgPicture.asset(
              'assets/send_icon.svg',
              width: 16,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '신고 접수하기',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Edit 버튼 공통 위젯
  Widget _buildEditButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: const Text(
          '수정',
          style: TextStyle(
            color: Color(0xFF00C853),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // 카드 공통 스타일
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 15,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
