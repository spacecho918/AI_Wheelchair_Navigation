import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

import 'package:gilbeot/screens/location_adjust_screen.dart';
import 'package:gilbeot/screens/report_confirm_screen.dart';
import 'package:gilbeot/services/api_service.dart';
import 'package:latlong2/latlong.dart' as latlong;

/// 장애물 유형 확인 화면
///
/// 흐름
/// ----
/// 1. 화면 진입 시 /report/analyze를 호출하여 bbox 표시 이미지와 감지 클래스를 받음
/// 2. bbox가 그려진 이미지를 배경에 표시하고, AI 감지 클래스를 자동 선택
/// 3. 사용자가 유형 확인/수정 후 "선택하기"
class ObstacleCheckScreen extends StatefulWidget {
  final String imagePath; // 촬영된 사진 경로
  final String initialObstacle; // AI 예측 외 초기값 (fallback)
  final bool fromConfirm;
  final bool fromNavigation;
  final bool fromNavigationEnd;

  /// 서버 analyze를 이미 완료한 경우 bbox 이미지(bytes)를 바로 넘겨받을 수 있음
  final Uint8List? annotatedImageBytes;

  /// 웹에서 갤러리로 선택한 이미지 bytes (analyze API 첨부용)
  final Uint8List? imageBytes;

  const ObstacleCheckScreen({
    super.key,
    required this.imagePath,
    this.initialObstacle = '',
    this.fromConfirm = false,
    this.fromNavigation = false,
    this.fromNavigationEnd = false,
    this.annotatedImageBytes,
    this.imageBytes,
  });

  @override
  State<ObstacleCheckScreen> createState() => _ObstacleCheckScreenState();
}

class _ObstacleCheckScreenState extends State<ObstacleCheckScreen> {
  static const Color _mainColor = Color(0xFF00C853);

  // ── 상태 ──────────────────────────────────────────────────────────────────
  bool _isAnalyzing = true;
  Uint8List? _annotatedImageBytes;
  List<String> _serverDetectedTypes = [];

  late Set<String> _selectedIds;
  final List<TextEditingController> _otherControllers = [];

  // ── 장애물 데이터 ──────────────────────────────────────────────────────────
  final List<Map<String, String>> obstacles = [
    {'id': 'stairs', 'label': '계단', 'image': 'assets/stairs.png'},
    {'id': 'cone', 'label': '라바콘', 'image': 'assets/traffic_cone.png'},
    {'id': 'bollard', 'label': '볼라드', 'image': 'assets/bollards.png'},
    {'id': 'slope', 'label': '경사로', 'image': 'assets/slope.png'},
    {'id': 'curb', 'label': '턱', 'image': 'assets/curb.png'},
    {'id': 'tree', 'label': '나무', 'image': 'assets/tree.png'},
    {'id': 'other', 'label': '기타', 'image': 'assets/pencil.png'},
  ];

  // 서버 class 이름 → obstacle id 매핑 (단수/복수 모두 처리)
  static const Map<String, String> _classToId = {
    'stair': 'stairs', // YOLO 모델이 단수형 반환
    'stairs': 'stairs',
    'cone': 'cone',
    'bollard': 'bollard',
    'slope': 'slope',
    'curb': 'curb',
    'tree': 'tree',
  };

  @override
  void initState() {
    super.initState();
    _selectedIds = {};
    _addOtherInput();

    if (widget.annotatedImageBytes != null) {
      // 이미 bbox 이미지가 제공된 경우 (부모에서 analyze 완료 후 전달)
      _annotatedImageBytes = widget.annotatedImageBytes;
      _isAnalyzing = false;
      _applyInitialObstacle(widget.initialObstacle);
    } else {
      // analyze API 호출
      _runAnalysis();
    }
  }

  /// 서버에 analyze 요청 → bbox 이미지 + detected_type
  Future<void> _runAnalysis() async {
    if (!mounted) return;
    setState(() => _isAnalyzing = true);

    try {
      final result = await ApiService.analyzeImage(
        widget.imagePath,
        imageBytes: widget.imageBytes, // 웹에서 bytes로 직접 전달
      );

      if (!mounted) return;

      Uint8List? newBytes;
      String? detectedType;

      if (result['success'] == true) {
        // bbox 이미지 디코딩
        final b64 = result['annotated_image'] as String?;
        if (b64 != null && b64.isNotEmpty) {
          newBytes = base64Decode(b64);
        }
        // AI 감지 클래스
        detectedType = result['detected_type'] as String?;
      }

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          if (newBytes != null) _annotatedImageBytes = newBytes;

          final detectionsList = result['detections'] as List?;
          if (detectionsList != null && detectionsList.isNotEmpty) {
            for (final d in detectionsList) {
              final type = d['class'] as String?;
              if (type != null) {
                if (!_serverDetectedTypes.contains(type)) {
                  _serverDetectedTypes.add(type);
                }
                _applyInitialObstacle(type);
              }
            }
          } else {
            if (detectedType != null) {
              _serverDetectedTypes.add(detectedType!);
              _applyInitialObstacle(detectedType);
            } else if (widget.initialObstacle.isNotEmpty) {
              _applyInitialObstacle(widget.initialObstacle);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('분석 오류: $e');
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  /// 감지된 클래스로 선택 설정
  /// - 클래스가 알려진 것이면 자동 선택
  /// - 모르거나 비어있으면 선택 안 함 (null 전달 시 아무것도 선택 안 됨)
  void _applyInitialObstacle(String? rawClass) {
    if (rawClass == null || rawClass.trim().isEmpty) return;

    final cleanClass = rawClass.trim().toLowerCase();
    String? matchedId = _classToId[cleanClass];

    // AI 영문 클래스에서 매칭되지 않았다면, 한글 라벨이나 직접 ID 매칭 시도 (fallback)
    if (matchedId == null) {
      try {
        final match = obstacles.firstWhere(
          (e) => e['id'] == cleanClass || e['label'] == rawClass.trim(),
        );
        matchedId = match['id'];
      } catch (_) {
        matchedId = null; // 매칭 실패
      }
    }

    if (matchedId != null) {
      _selectedIds.add(matchedId);
    }
    // 인식 실패시는 자동 선택 안 함
  }

  void _addOtherInput() {
    final c = TextEditingController()..addListener(_onTextChanged);
    setState(() => _otherControllers.add(c));
  }

  void _removeOtherInput(int index) {
    if (_otherControllers.length > 1) {
      _otherControllers[index]
        ..removeListener(_onTextChanged)
        ..dispose();
      setState(() => _otherControllers.removeAt(index));
    } else {
      _otherControllers[0].clear();
    }
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    for (final c in _otherControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ── 배경 이미지 위젯 ───────────────────────────────────────────────────────

  /// bytes 헤더를 보고 실제 이미지 MIME 타입을 반환한다.
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
    return 'image/jpeg';
  }

  // 서버 감지 타입(영문) -> 한글 라벨 변환
  String _getLocalizedLabel(String serverType) {
    if (serverType.isEmpty) return serverType;
    final id = _classToId[serverType.toLowerCase()] ?? serverType;
    // obstacles 리스트에서 id가 일치하는 항목 찾기
    final match = obstacles.firstWhere(
      (e) => e['id'] == id,
      orElse: () => {'label': serverType}, // 없으면 원본 반환
    );
    return match['label']!;
  }

  Widget _buildBackground() {
    // 1순위: bbox 이미지 (bytes)
    if (_annotatedImageBytes != null) {
      if (kIsWeb) {
        // 웹: 실제 포맷 감지 후 올바른 MIME 타입으로 data URI 생성
        final mime = _detectMimeType(_annotatedImageBytes!);
        final dataUri =
            'data:$mime;base64,${base64Encode(_annotatedImageBytes!)}';
        return Image.network(dataUri, fit: BoxFit.contain);
      }
      return Image.memory(_annotatedImageBytes!, fit: BoxFit.contain);
    }
    // 2순위: 원본 이미지 (파일 or blob URL)
    if (widget.imagePath.isNotEmpty) {
      if (kIsWeb) {
        return Image.network(widget.imagePath, fit: BoxFit.contain);
      } else {
        return Image.file(File(widget.imagePath), fit: BoxFit.contain);
      }
    }
    return Container(color: Colors.black);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── 배경 이미지 ─────────────────────────────────────────────────
          Positioned.fill(child: _buildBackground()),

          // ── 분석 중 오버레이 ────────────────────────────────────────────
          if (_isAnalyzing)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(_mainColor),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'AI가 장애물을 분석하고 있습니다...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── 드래거블 시트 ────────────────────────────────────────────────
          if (!_isAnalyzing)
            DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.2,
              maxChildSize: 0.68,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).scaffoldBackgroundColor
                        : Colors.white,
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
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                      },
                    ),
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 핸들 바
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
                            _serverDetectedTypes.isNotEmpty
                                ? '장애물을 확인해주세요'
                                : '어떤 장애물인가요?',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : const Color(0xFF101727),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // 서브타이틀
                          Text(
                            _serverDetectedTypes.isNotEmpty
                                ? '실제와 다르다면 수정할 수 있어요. 해당하는 장애물을 모두 선택해주세요.'
                                : '해당하는 장애물을 모두 선택해주세요',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF9CA3AF)
                                  : Color(0xFF697282),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // 선택지 그리드 ('기타' 제외)
                          GridView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: obstacles.length - 1, // 마지막 '기타' 항목 제외
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      MediaQuery.of(context).size.width > 600
                                      ? 3
                                      : 2,
                                  mainAxisExtent: 76,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                            itemBuilder: (context, index) {
                              final item = obstacles[index];
                              final isSelected = _selectedIds.contains(
                                item['id'],
                              );
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedIds.remove(item['id']);
                                    } else {
                                      _selectedIds.add(item['id']!);
                                    }
                                  });
                                },
                                child: _buildOptionCard(item, isSelected),
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          // '기타' 항목 (가로 꽉 채우기)
                          Builder(
                            builder: (context) {
                              final item = obstacles.last; // '기타'
                              final isSelected = _selectedIds.contains(
                                item['id'],
                              );
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedIds.remove(item['id']);
                                    } else {
                                      _selectedIds.add(item['id']!);
                                    }
                                  });
                                },
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 76,
                                  child: _buildOptionCard(item, isSelected),
                                ),
                              );
                            },
                          ),

                          // 기타 입력창
                          if (_selectedIds.contains('other')) ...[
                            const SizedBox(height: 20),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Theme.of(context).cardColor
                                    : Colors.white,
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
                                      Text(
                                        '장애물 설명',
                                        style: TextStyle(
                                          color:
                                              Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: _addOtherInput,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _mainColor.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
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
                                  ...List.generate(_otherControllers.length, (
                                    i,
                                  ) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 8.0,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: _otherControllers[i],
                                              onChanged: (_) => setState(() {}),
                                              decoration: InputDecoration(
                                                hintText:
                                                    '예: 파손된 보도블록, 쓰러진 나무 등',
                                                hintStyle: TextStyle(
                                                  color:
                                                      Theme.of(
                                                            context,
                                                          ).brightness ==
                                                          Brightness.dark
                                                      ? const Color(0xFF697282)
                                                      : const Color(0xFF9CA3AF),
                                                  fontSize: 14,
                                                ),
                                                filled: true,
                                                fillColor:
                                                    Theme.of(
                                                          context,
                                                        ).brightness ==
                                                        Brightness.dark
                                                    ? const Color(0xFF2A2A2A)
                                                    : const Color(0xFFF3F4F6),
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
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          if (_otherControllers.length > 1)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 8.0,
                                              ),
                                              child: GestureDetector(
                                                onTap: () =>
                                                    _removeOtherInput(i),
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
                                  Text(
                                    '장애물의 종류를 입력해 주세요.',
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFF9CA3AF)
                                          : const Color(0xFF1F2937),
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
                                  : _onConfirm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _mainColor,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF9CA3AF)
                                    : const Color(0xFFF3F4F6),
                                disabledForegroundColor:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF2A2A2A)
                                    : const Color(0xFF9CA3AF),
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
                  ), // ScrollConfiguration
                );
              },
            ),

          // ── 뒤로가기 버튼 ────────────────────────────────────────────────
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

  // ── 확인 버튼 콜백 ─────────────────────────────────────────────────────────
  Future<void> _onConfirm() async {
    final finalIds = <String>[];
    final finalLabels = <String>[];

    for (final id in _selectedIds) {
      if (id == 'other') {
        for (final c in _otherControllers) {
          if (c.text.trim().isNotEmpty) {
            finalIds.add('other');
            finalLabels.add(c.text.trim());
          }
        }
      } else {
        finalIds.add(id);
        final label = obstacles.firstWhere((e) => e['id'] == id)['label']!;
        finalLabels.add(label);
      }
    }

    final joinedIds = finalIds.join(', ');
    final joinedLabels = finalLabels.join(', ');

    // 제보 확인 화면에서 수정하러 온 경우
    if (widget.fromConfirm) {
      Navigator.pop(context, {
        'imagePath': widget.imagePath,
        'obstacleType': joinedLabels,
        'obstacleId': joinedIds,
      });
      return;
    }

    // 위치 조정 화면으로 이동
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LocationAdjustScreen(
          savedLocation: latlong.LatLng(37.5665, 126.9780),
          savedAddress: '위치를 선택해주세요',
        ),
      ),
    );

    if (result != null && result is Map && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReportConfirmScreen(
            location: result['latlng'],
            address: result['address'],
            imagePath: widget.imagePath,
            obstacleType: joinedLabels,
            obstacleId: joinedIds,
            fromNavigation: widget.fromNavigation,
            fromNavigationEnd: widget.fromNavigationEnd,
          ),
        ),
      );
    }
  }

  bool _isSubmitDisabled() {
    if (_selectedIds.isEmpty) return true;
    if (_selectedIds.contains('other')) {
      return !_otherControllers.any((c) => c.text.trim().isNotEmpty);
    }
    return false;
  }

  Widget _buildOptionCard(Map<String, String> item, bool isSelected) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFE8FDF0)
            : Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2A2A)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? _mainColor : const Color(0xFFD0D5DB),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  item['image']!,
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 2),
                Text(
                  item['label']!,
                  style: TextStyle(
                    color: isSelected
                        ? _mainColor
                        : Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF354152),
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
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
