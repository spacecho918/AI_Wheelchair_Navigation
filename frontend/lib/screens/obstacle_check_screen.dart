import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:gilbeot/screens/location_adjust_screen.dart';
import 'package:gilbeot/screens/report_confirm_screen.dart';
import 'package:latlong2/latlong.dart' as latlong;

class ObstacleCheckScreen extends StatefulWidget {
  final String imagePath; // 촬영된 사진 경로
  final String initialObstacle; // AI가 예측한 장애물 (예: 'stairs')
  final bool fromConfirm; // 제보 확인 화면에서 수정하러 왔는지 여부
  final bool fromNavigation;

  const ObstacleCheckScreen({
    super.key,
    required this.imagePath,
    this.initialObstacle = 'stairs',
    this.fromConfirm = false,
    this.fromNavigation = false,
  });

  @override
  State<ObstacleCheckScreen> createState() => _ObstacleCheckScreenState();
}

class _ObstacleCheckScreenState extends State<ObstacleCheckScreen> {
  static const Color _mainColor = Color(0xFF00C853);

  // 현재 선택된 장애물 IDs
  late Set<String> _selectedIds;

  // 기타 입력 관리
  final List<TextEditingController> _otherControllers = [];

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
    // 초기 선택값 설정
    _selectedIds = {};

    // 기본적으로 기타 입력창 하나 추가
    _addOtherInput();

    final exists = obstacles.any((e) => e['id'] == widget.initialObstacle);
    if (exists) {
      _selectedIds.add(widget.initialObstacle);
    } else {
      if (widget.initialObstacle.isNotEmpty) {
        _selectedIds.add('stairs');
      }
    }
    if (!exists) {
      _selectedIds.add('stairs');
    }
  }

  void _addOtherInput() {
    final controller = TextEditingController();
    controller.addListener(_onTextChanged);
    setState(() {
      _otherControllers.add(controller);
    });
  }

  void _removeOtherInput(int index) {
    if (_otherControllers.length > 1) {
      final controller = _otherControllers[index];
      controller.removeListener(_onTextChanged);
      controller.dispose();
      setState(() {
        _otherControllers.removeAt(index);
      });
    } else {
      // 하나 남았을 때는 내용만 지움? 아니면 삭제 불가?
      // 보통 하나는 남겨둠.
      _otherControllers[0].clear();
    }
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    for (var controller in _otherControllers) {
      controller.dispose();
    }
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

          // 2. 검은색 반투명 오버레이
          // Positioned.fill(child: Container(color: Colors.black.withOpacity(0.3))),

          // 3. 위아래로 움직이는 대시보드 (DraggableSheet)
          DraggableScrollableSheet(
            initialChildSize: 0.65, // 하단 텍스트가 딱 보일 정도의 높이
            minChildSize: 0.2, // 최소 높이
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
                      const Text(
                        '해당하는 장애물을 선택해주세요',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF101727),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Subtitle removed or kept? "AI가 감지한 결과입니다..." might not fit "Multi-select".
                      // Keeping it generic or removing.
                      // Let's keep a generic instruction.
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
                        physics: const NeverScrollableScrollPhysics(), // 스크롤 막음
                        itemCount: obstacles.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              MediaQuery.of(context).size.width > 600 ? 3 : 2,
                          mainAxisExtent: 90, // 고정 높이
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemBuilder: (context, index) {
                          final item = obstacles[index];
                          final isSelected = _selectedIds.contains(item['id']);

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedIds.remove(item['id']);
                                } else {
                                  _selectedIds.add(item['id']!);
                                }

                                // 기타 해제 시 텍스트 필드 클리어? (Optional, maybe keep it)
                                if (item['id'] == 'other' && isSelected) {
                                  // removed other
                                  // _textController.clear(); // Keep text just in case user re-selects
                                }
                              });
                            },
                            child: _buildOptionCard(item, isSelected),
                          );
                        },
                      ),

                      // 기타 선택 시 입력창 표시
                      if (_selectedIds.contains('other')) ...[
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
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    '장애물 설명', // Describe the obstacle
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  // 추가 버튼
                                  GestureDetector(
                                    onTap: _addOtherInput,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _mainColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(
                                            Icons.add,
                                            size: 14,
                                            color: _mainColor,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            '추가',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: _mainColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // 입력창 리스트
                              ...List.generate(_otherControllers.length, (
                                index,
                              ) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _otherControllers[index],
                                          onChanged: (_) => setState(() {}),
                                          decoration: InputDecoration(
                                            hintText: '예: 파손된 보도블록, 쓰러진 나무 등',
                                            hintStyle: const TextStyle(
                                              color: Color(0xFF9CA3AF),
                                              fontSize: 14,
                                            ),
                                            filled: true,
                                            fillColor: const Color(0xFFF3F4F6),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide.none,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 12,
                                                ),
                                          ),
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      if (_otherControllers.length > 1)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 8.0,
                                          ),
                                          child: GestureDetector(
                                            onTap: () =>
                                                _removeOtherInput(index),
                                            child: const Icon(
                                              Icons.remove_circle_outline,
                                              color: Color(0xFF9CA3AF),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }),

                              const SizedBox(height: 4),
                              const Text(
                                '장애물의 종류를 입력해 주세요.',
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
                          onPressed: _isSubmitDisabled()
                              ? null
                              : () async {
                                  // Construct final types and IDs

                                  // IDs
                                  final List<String> finalIds = [];
                                  final List<String> finalLabels = [];

                                  for (String id in _selectedIds) {
                                    if (id == 'other') {
                                      //Add each non-empty custom input
                                      for (var controller
                                          in _otherControllers) {
                                        if (controller.text.trim().isNotEmpty) {
                                          finalIds.add('other');
                                          finalLabels.add(
                                            controller.text.trim(),
                                          );
                                        }
                                      }
                                    } else {
                                      finalIds.add(id);
                                      final label = obstacles.firstWhere(
                                        (e) => e['id'] == id,
                                      )['label']!;
                                      finalLabels.add(label);
                                    }
                                  }

                                  final String joinedIds = finalIds.join(', ');
                                  final String joinedLabels = finalLabels.join(
                                    ', ',
                                  );

                                  debugPrint(
                                    '최종 선택: $joinedLabels ($joinedIds)',
                                  );

                                  // 제보 확인 화면에서 왔다면 결과 반환하고 종료
                                  if (widget.fromConfirm) {
                                    Navigator.pop(context, {
                                      'imagePath': widget.imagePath,
                                      'obstacleType': joinedLabels,
                                      'obstacleId': joinedIds,
                                    });
                                    return;
                                  }

                                  // 1. 위치 조정 화면으로 이동하여 위치 선택 대기
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const LocationAdjustScreen(
                                            savedLocation: latlong.LatLng(
                                              37.5665,
                                              126.9780,
                                            ), // Default to Seoul
                                            savedAddress: '위치를 선택해주세요',
                                          ),
                                    ),
                                  );

                                  // 2. 위치 선택 완료 시 신고 확인 화면으로 이동
                                  if (result != null && result is Map) {
                                    if (!mounted) return;

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ReportConfirmScreen(
                                              location: result['latlng'],
                                              address: result['address'],
                                              imagePath: widget.imagePath,
                                              obstacleType: joinedLabels,
                                              obstacleId: joinedIds,
                                              fromNavigation:
                                                  widget.fromNavigation,
                                            ),
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _mainColor, // Gilbeot Green
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFF3F4F6),
                            disabledForegroundColor: const Color(0xFF9CA3AF),
                            elevation: _isSubmitDisabled() ? 0 : 5,
                            shadowColor: const Color(0x3F00C853),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            '선택하기',
                            style: TextStyle(
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

          // 4. 뒤로가기 버튼
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
                          color: Colors.black.withOpacity(0.1),
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

  bool _isSubmitDisabled() {
    if (_selectedIds.isEmpty) return true;
    if (_selectedIds.contains('other')) {
      // Check if ALL text fields are empty
      // Actually, we require AT LEAST ONE if 'other' is selected?
      // Let's say if 'other' is selected, at least one text field must have content.
      bool hasContent = false;
      for (var c in _otherControllers) {
        if (c.text.trim().isNotEmpty) {
          hasContent = true;
          break;
        }
      }
      if (!hasContent) return true;
    }
    return false;
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
}
