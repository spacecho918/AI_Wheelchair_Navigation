import 'package:flutter/material.dart';
import 'package:gilbeot/widgets/custom_back_button.dart';

class TermsScreen extends StatelessWidget {
  final bool isPrivacyPolicy;

  const TermsScreen({super.key, this.isPrivacyPolicy = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
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
                    isPrivacyPolicy ? '개인정보 처리방침' : '이용약관',
                    style: const TextStyle(
                      color: Color(0xFF354152),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(color: const Color(0xFFF0F2F5), height: 1.0),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Last Updated
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '최종 수정일: 2026년 1월 1일',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (isPrivacyPolicy) ...[
                      _buildPrivacyPolicyContent(),
                    ] else ...[
                      _buildTermsContent(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('제1조 (목적)'),
        const SizedBox(height: 12),
        _buildParagraph(
          '본 약관은 길벗(이하 "회사")이 제공하는 휠체어 내비게이션 서비스(이하 "서비스")의 이용조건 및 절차, 회사와 회원 간의 권리, 의무 및 책임사항을 규정함을 목적으로 합니다.',
        ),

        const SizedBox(height: 24),

        _buildSectionTitle('제2조 (정의)'),
        const SizedBox(height: 12),
        _buildParagraph(
          '① "서비스"란 회사가 제공하는 휠체어 사용자를 위한 경로 안내, 장애물 제보, 커뮤니티 등 관련 제반 서비스를 의미합니다.\n\n'
          '② "회원"이란 본 약관에 동의하고 회사와 이용계약을 체결하여 서비스를 이용하는 자를 말합니다.\n\n'
          '③ "제보"란 회원이 서비스 내에서 장애물 정보를 등록하는 것을 말합니다.',
        ),

        const SizedBox(height: 24),

        _buildSectionTitle('제3조 (약관의 효력 및 변경)'),
        const SizedBox(height: 12),
        _buildParagraph(
          '① 본 약관은 서비스 이용을 희망하는 모든 회원에게 효력이 발생합니다.\n\n'
          '② 회사는 필요한 경우 관련 법령을 위배하지 않는 범위에서 본 약관을 변경할 수 있습니다.\n\n'
          '③ 변경된 약관은 적용일자 7일 전부터 공지하며, 회원에게 불리한 변경의 경우 30일 전부터 공지합니다.',
        ),

        const SizedBox(height: 24),

        _buildSectionTitle('제4조 (서비스의 제공)'),
        const SizedBox(height: 12),
        _buildParagraph(
          '회사는 다음과 같은 서비스를 제공합니다:\n\n'
          '① 휠체어 사용자를 위한 최적 경로 안내 서비스\n'
          '② 장애물 제보 및 공유 서비스\n'
          '③ 커뮤니티 서비스\n'
          '④ 기타 회사가 정하는 서비스',
        ),

        const SizedBox(height: 24),

        _buildSectionTitle('제5조 (회원의 의무)'),
        const SizedBox(height: 12),
        _buildParagraph(
          '① 회원은 서비스 이용 시 관련 법령, 본 약관, 서비스 이용안내 등을 준수해야 합니다.\n\n'
          '② 회원은 허위정보를 제공하거나 타인의 정보를 도용해서는 안 됩니다.\n\n'
          '③ 회원은 서비스를 이용하여 얻은 정보를 회사의 동의 없이 상업적 목적으로 이용할 수 없습니다.',
        ),

        const SizedBox(height: 24),

        _buildSectionTitle('제6조 (서비스 이용의 제한)'),
        const SizedBox(height: 12),
        _buildParagraph(
          '회사는 회원이 다음 각 호에 해당하는 행위를 했을 경우 서비스 이용을 제한할 수 있습니다:\n\n'
          '① 허위 제보를 반복적으로 등록하는 경우\n'
          '② 타인을 비방하거나 불쾌감을 주는 내용을 게시하는 경우\n'
          '③ 서비스 운영을 방해하는 행위를 하는 경우',
        ),

        const SizedBox(height: 24),

        _buildSectionTitle('제7조 (면책조항)'),
        const SizedBox(height: 12),
        _buildParagraph(
          '① 회사는 무료로 제공되는 서비스에 관하여 회원에게 어떠한 손해가 발생하더라도 책임을 지지 않습니다.\n\n'
          '② 회사는 회원이 서비스를 통해 얻은 정보의 정확성, 완전성에 대해 보증하지 않습니다.\n\n'
          '③ 회사는 회원 상호간 또는 회원과 제3자 간의 분쟁에 개입할 의무가 없습니다.',
        ),

        const SizedBox(height: 40),

        // Contact Info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '문의처',
                style: TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '이메일: support@gilbeot.app\n전화: 02-1234-5678',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildPrivacyPolicyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('1. 개인정보의 수집 및 이용 목적'),
        const SizedBox(height: 12),
        _buildParagraph(
          '길벗(이하 "회사")은 다음의 목적을 위하여 개인정보를 수집 및 이용합니다:\n\n'
          '① 회원 가입 및 관리: 회원 식별, 본인 확인, 서비스 제공\n'
          '② 서비스 제공: 경로 안내, 장애물 제보, 커뮤니티 서비스 제공\n'
          '③ 서비스 개선: 이용 통계 분석, 서비스 품질 향상',
        ),

        const SizedBox(height: 24),

        _buildSectionTitle('2. 수집하는 개인정보 항목'),
        const SizedBox(height: 12),
        _buildParagraph(
          '회사는 서비스 제공을 위해 다음과 같은 개인정보를 수집합니다:\n\n'
          '① 필수항목: 이메일 주소, 비밀번호, 닉네임\n'
          '② 선택항목: 프로필 사진, 휠체어 종류\n'
          '③ 자동 수집 항목: 위치정보(서비스 이용 시), 기기 정보, 서비스 이용 기록',
        ),

        const SizedBox(height: 24),

        _buildSectionTitle('3. 개인정보의 보유 및 이용기간'),
        const SizedBox(height: 12),
        _buildParagraph(
          '회사는 개인정보 수집 및 이용 목적이 달성된 후에는 해당 정보를 지체 없이 파기합니다.\n\n'
          '① 회원 정보: 회원 탈퇴 시까지\n'
          '② 제보 정보: 제보 삭제 요청 시까지\n'
          '③ 관련 법령에 따른 보관: 전자상거래법 등 관련 법률에서 정한 기간',
        ),

        const SizedBox(height: 24),

        _buildSectionTitle('4. 개인정보의 제3자 제공'),
        const SizedBox(height: 12),
        _buildParagraph(
          '회사는 원칙적으로 회원의 개인정보를 제3자에게 제공하지 않습니다. 다만, 다음의 경우에는 예외로 합니다:\n\n'
          '① 회원이 사전에 동의한 경우\n'
          '② 법령의 규정에 의거하거나, 수사 목적으로 법령에 정해진 절차와 방법에 따라 수사기관의 요구가 있는 경우',
        ),

        const SizedBox(height: 24),

        _buildSectionTitle('5. 개인정보의 파기 절차 및 방법'),
        const SizedBox(height: 12),
        _buildParagraph(
          '① 파기 절차: 보유기간이 만료된 개인정보는 목적 달성 후 별도의 DB로 옮겨져 내부 규정에 따라 일정 기간 저장된 후 파기됩니다.\n\n'
          '② 파기 방법: 전자적 파일 형태의 정보는 복구가 불가능한 방법으로 영구 삭제합니다.',
        ),

        const SizedBox(height: 24),

        _buildSectionTitle('6. 이용자의 권리'),
        const SizedBox(height: 12),
        _buildParagraph(
          '회원은 언제든지 다음과 같은 권리를 행사할 수 있습니다:\n\n'
          '① 개인정보 열람 요청\n'
          '② 오류 등이 있을 경우 정정 요청\n'
          '③ 삭제 요청\n'
          '④ 처리 정지 요청',
        ),

        const SizedBox(height: 24),

        _buildSectionTitle('7. 개인정보 보호책임자'),
        const SizedBox(height: 12),
        _buildParagraph(
          '회사는 개인정보 처리에 관한 업무를 총괄해서 책임지고, 개인정보 처리와 관련한 정보주체의 불만처리 및 피해구제 등을 위하여 아래와 같이 개인정보 보호책임자를 지정하고 있습니다.',
        ),

        const SizedBox(height: 16),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '개인정보 보호책임자',
                style: TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '성명: 홍길동\n직책: 개인정보 보호책임자\n이메일: privacy@gilbeot.app\n전화: 02-1234-5678',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF1F2937),
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF4B5563),
        fontSize: 14,
        height: 1.7,
      ),
    );
  }
}
