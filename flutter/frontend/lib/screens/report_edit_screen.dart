import 'package:flutter/material.dart';
import 'package:gilbeot/screens/location_adjust_screen.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:gilbeot/widgets/custom_back_button.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gilbeot/screens/camera_screen.dart';
import 'package:gilbeot/widgets/common_toast.dart';

class ReportEditScreen extends StatefulWidget {
  final Map<String, dynamic> report;

  const ReportEditScreen({super.key, required this.report});

  @override
  State<ReportEditScreen> createState() => _ReportEditScreenState();
}

class _ReportEditScreenState extends State<ReportEditScreen> {
  // Colors
  final Color primaryGreen = const Color(0xFF00C853);
  final Color textDark = const Color(0xFF101727);
  final Color textGrey = const Color(0xFF9EA6B8);

  // State
  String _selectedReason = '해결됨'; // Default selection
  final List<String> _reasons = ['해결됨', '장애물 오류', '위치 오류', '기타'];

  // Controllers
  final TextEditingController _descriptionController = TextEditingController();

  // Dynamic Data
  String? _imagePath; // For photo evidence
  latlong.LatLng? _newLocation; // For location error
  String? _newAddress;

  bool get _isFormValid {
    switch (_selectedReason) {
      case '해결됨':
      case '장애물 오류':
        return _imagePath != null;
      case '위치 오류':
        return _newLocation != null;
      case '기타':
        return _descriptionController.text.isNotEmpty;
      default:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _submitRequest() {
    // TODO: Implement submission logic (API call or mock)
    // Validate inputs
    if ((_selectedReason == '해결됨' || _selectedReason == '장애물 오류') &&
        _imagePath == null) {
      CommonToast.show(context, '증빙 사진을 등록해주세요.');
      return;
    }
    if (_selectedReason == '기타' && _descriptionController.text.isEmpty) {
      CommonToast.show(context, '수정 사유를 입력해주세요.');
      return;
    }

    // Success
    CommonToast.show(context, '수정 요청이 접수되었습니다.');
    Navigator.pop(context);
  }

  Future<void> _pickImage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CameraScreen(fromConfirm: true),
      ),
    );

    if (result != null && result is Map && result['imagePath'] != null) {
      if (mounted) {
        setState(() {
          _imagePath = result['imagePath'];
        });
      }
    }
  }

  Future<void> _editLocation() async {
    // Mock initial location if report doesn't have coordinates
    // In real app, parse coordinates from report data
    final initialLocation = latlong.LatLng(37.5665, 126.9780);
    final initialAddress = widget.report['address'] ?? '주소 정보 없음';

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationAdjustScreen(
          savedLocation: _newLocation ?? initialLocation,
          savedAddress: _newAddress ?? initialAddress,
        ),
      ),
    );

    if (result != null && result is Map) {
      setState(() {
        _newLocation = result['latlng'];
        _newAddress = result['address'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: CustomBackButton(),
                  ),
                  Text(
                    '제보 수정 요청',
                    style: TextStyle(
                      color: textDark,
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Brief Report Info
                    _buildReportInfoCard(),
                    const SizedBox(height: 24),

                    // 2. Cancellation Reason
                    Text(
                      '수정 사유',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildReasonSelector(),
                    const SizedBox(height: 24),

                    // 3. Dynamic Content
                    _buildDynamicContent(),
                  ],
                ),
              ),
            ),

            // Bottom Button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isFormValid ? _submitRequest : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isFormValid
                        ? primaryGreen
                        : Colors.grey[300],
                    foregroundColor: _isFormValid ? Colors.white : textGrey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '수정 요청하기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Thumbnail
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
            // Use image if available in report
            child: const Icon(Icons.image, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: primaryGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.report['tag'] ?? '태그',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.report['content'] ?? '내용 없음',
                        style: TextStyle(
                          color: textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.report['address'] ?? '주소 없음',
                  style: TextStyle(color: textGrey, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonSelector() {
    return Column(
      children: _reasons.map((reason) {
        final isSelected = _selectedReason == reason;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedReason = reason;
              // Reset dynamic fields on change?
              // _imagePath = null;
              // _newLocation = null;
              // _descriptionController.clear();
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryGreen.withValues(alpha: 0.05)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? primaryGreen : Colors.grey.shade200,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected ? primaryGreen : textGrey,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  reason,
                  style: TextStyle(
                    color: isSelected ? textDark : const Color(0xFF4A5565),
                    fontSize: 15,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDynamicContent() {
    switch (_selectedReason) {
      case '해결됨':
      case '장애물 오류':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                text: '증빙 사진 ',
                style: TextStyle(
                  color: textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                children: const [
                  TextSpan(
                    text: '*',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _imagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _imagePath!.startsWith('assets/')
                            ? Image.asset(_imagePath!, fit: BoxFit.cover)
                            : kIsWeb
                            ? Image.network(_imagePath!, fit: BoxFit.cover)
                            : Image.file(File(_imagePath!), fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            color: textGrey,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '사진을 등록해주세요',
                            style: TextStyle(color: textGrey, fontSize: 14),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  '상세 설명 ',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '(선택사항)',
                  style: TextStyle(
                    color: textGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '내용을 입력해주세요.',
                hintStyle: TextStyle(color: textGrey),
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
        );
      case '위치 오류':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '현재 위치 정보',
              style: TextStyle(
                color: textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 20,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.report['address'] ?? '주소 정보 없음',
                      style: TextStyle(color: textDark, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_newAddress != null) ...[
              Text(
                '수정할 위치 정보',
                style: TextStyle(
                  color: primaryGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryGreen.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryGreen),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 20, color: primaryGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _newAddress!,
                        style: TextStyle(
                          color: textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _editLocation,
                icon: Icon(Icons.map, color: textDark),
                label: Text('위치 수정하기', style: TextStyle(color: textDark)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        );
      case '기타':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                text: '설명 ',
                style: TextStyle(
                  color: textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                children: const [
                  TextSpan(
                    text: '*',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '내용을 입력해주세요.',
                hintStyle: TextStyle(color: textGrey),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Text(
                  '사진 ',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '(선택사항)',
                  style: TextStyle(
                    color: textGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _imagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _imagePath!.startsWith('assets/')
                            ? Image.asset(_imagePath!, fit: BoxFit.cover)
                            : kIsWeb
                            ? Image.network(_imagePath!, fit: BoxFit.cover)
                            : Image.file(File(_imagePath!), fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            color: textGrey,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '사진 추가',
                            style: TextStyle(color: textGrey, fontSize: 14),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
