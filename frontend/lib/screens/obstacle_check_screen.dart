import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:gilbeot/screens/location_adjust_screen.dart';

class ObstacleCheckScreen extends StatefulWidget {
  final String imagePath; // 촬영된 사진 경로
  final String initialObstacle; // AI가 예측한 장애물 (예: 'stairs')

  const ObstacleCheckScreen({
    super.key,
    required this.imagePath,
    this.initialObstacle = 'stairs',
  });

  @override
  State<ObstacleCheckScreen> createState() => _ObstacleCheckScreenState();
}

class _ObstacleCheckScreenState extends State<ObstacleCheckScreen> {
  static const Color _mainColor = Color(0xFF00C853);

  // 현재 선택된 장애물 ID
  late String selectedId;
  final TextEditingController _textController = TextEditingController();

  // 장애물 데이터 리스트 (파일명과 라벨 매칭)
  final List<Map<String, String>> obstacles = [
    {'id': 'stairs', 'label': '계단', 'image': 'assets/stairs.png'},
    {'id': 'cone', 'label': '라바콘', 'image': 'assets/traffic_cone.png'},
    {
      'id': 'bollard',
      'label': '볼라드',
      'image': 'assets/bollards.png',
    }, // s 붙은 파일명 주의
    {'id': 'slope', 'label': '경사로', 'image': 'assets/slope.png'},
    {'id': 'curb', 'label': '턱', 'image': 'assets/curb.png'},
    {'id': 'other', 'label': '기타', 'image': 'assets/pencil.png'},
  ];

  @override
  void initState() {
    super.initState();
    // 초기 선택값 설정 (목록에 없으면 첫 번째 값)
    final exists = obstacles.any((e) => e['id'] == widget.initialObstacle);
    selectedId = exists ? widget.initialObstacle : 'stairs';
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 배경색은 사진이 없을 경우를 대비해 검은색으로 설정
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. 촬영된 사진 배경 (전체 화면)
          Positioned.fill(
            child: widget.imagePath.isNotEmpty
                ? (kIsWeb
                      ? Image.network(widget.imagePath, fit: BoxFit.cover)
                      : Image.file(File(widget.imagePath), fit: BoxFit.cover))
                : Container(color: Colors.black), // 사진 없을 때
          ),

          // 2. 검은색 반투명 오버레이 (바텀 시트가 올라올 때 뒤를 살짝 어둡게 하려면 추가)
          // Positioned.fill(child: Container(color: Colors.black.withOpacity(0.3))),

          // 3. 위아래로 움직이는 대시보드 (DraggableSheet)
          DraggableScrollableSheet(
            initialChildSize: 0.75, // 처음 보여질 높이 비율 (75% - 버튼까지 보이도록)
            minChildSize: 0.2, // 최소 높이 (더 아래로 내려가도록 수정)
            maxChildSize: 0.95, // 최대 높이
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x3F000000),
                      blurRadius: 50,
                      offset: Offset(0, -10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 핸들 바 (회색 막대)
                      Container(
                        width: 42,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D5DC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),

                      // 타이틀
                      Text(
                        '이 장애물이 ${_getLabel(selectedId)}인가요?', // 동적 타이틀
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF101727),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'AI가 감지한 결과입니다. 맞는지 확인하거나 선택해주세요.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF697282),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 선택지 그리드 (GridView)
                      GridView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true, // ScrollView 안에 있으므로 필수
                        physics:
                            const NeverScrollableScrollPhysics(), // 스크롤 막음 (바깥 스크롤 사용)
                        itemCount: obstacles.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2, // 2열
                              childAspectRatio: 1.8, // 카드의 가로세로 비율 (납작하게)
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                        itemBuilder: (context, index) {
                          final item = obstacles[index];
                          final isSelected = selectedId == item['id'];

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedId = item['id']!;
                                // 기타가 아닌 다른 것 선택 시 텍스트 필드 초기화 (선택 사항)
                                if (selectedId != 'other') {
                                  _textController.clear();
                                }
                              });
                            },
                            child: _buildOptionCard(item, isSelected),
                          );
                        },
                      ),

                      // 기타 선택 시 입력창 표시
                      if (selectedId == 'other') ...[
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _mainColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '장애물 설명', // Describe the obstacle
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _textController,
                                decoration: InputDecoration(
                                  hintText: '예: 파손된 보도블록, 쓰러진 나무 등',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 14,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF3F4F6),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '장애물의 종류를 간략하게 설명해주세요.',
                                style: TextStyle(
                                  color: Color(0xFF1F2937),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 30),

                      // 확인 버튼
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            if (selectedId == 'other') {
                              final text = _textController.text.trim();
                              if (text.isEmpty) {
                                // 입력값이 없으면 스낵바 등으로 알림
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('장애물 설명을 입력해주세요.'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
                              debugPrint('최종 선택 (기타): $text');
                            } else {
                              debugPrint('최종 선택: $selectedId');
                            }
                            // 공통: 위치 조정 화면으로 이동
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LocationAdjustScreen(
                                  obstacleType: selectedId, // 선택한 장애물 정보 넘겨주기
                                  imagePath: widget.imagePath,
                                  obstacleLabel: selectedId == 'other'
                                      ? _textController.text
                                      : _getLabel(selectedId),
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _mainColor, // Gilbeot Green
                            elevation: 5,
                            shadowColor: const Color(0x3F00C853),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            '선택하기',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      const Text(
                        '여러분의 제보가 모두에게 안전한 길을 만듭니다.',
                        style: TextStyle(
                          color: Color(0xFF99A1AE),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 4. 뒤로가기 버튼 (상단 왼쪽)
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

  // 선택 카드 위젯
  Widget _buildOptionCard(Map<String, String> item, bool isSelected) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFE8FDF0)
            : Colors.white, // 선택 시 배경 연두색
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          // 선택 시 테두리 초록색, 아니면 회색
          color: isSelected ? _mainColor : const Color(0xFFD0D5DB),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          // 내용물 (아이콘 + 텍스트)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // PNG 이미지 아이콘
                Image.asset(
                  item['image']!,
                  width: 32, // 아이콘 크기 조절
                  height: 32,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8),
                Text(
                  item['label']!,
                  style: TextStyle(
                    color: isSelected ? _mainColor : const Color(0xFF354152),
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // 체크 아이콘 (선택되었을 때만 우측 상단 표시)
          if (isSelected)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: _mainColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  String _getLabel(String id) {
    return obstacles.firstWhere((e) => e['id'] == id)['label']!;
  }
}
