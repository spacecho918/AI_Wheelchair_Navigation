import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/SideDrawer.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const SideDrawer(), // 사이드 드로어 추가
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ---------------------------------------------------------
          // 1. 배경 지도
          // ---------------------------------------------------------
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(37.5445, 127.0560), // 성수역
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.gilbeot.app',
              ),
            ],
          ),

          // ---------------------------------------------------------
          // 3 & 4. 대시보드 및 신고 버튼
          // ---------------------------------------------------------
          DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.20,
            maxChildSize: 0.85,
            builder: (BuildContext context, ScrollController scrollController) {
              return Stack(
                children: [
                  // (1) 흰색 대시보드
                  Container(
                    margin: const EdgeInsets.only(top: 50), // 버튼 자리 확보
                    decoration: const ShapeDecoration(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                      ),
                      shadows: [
                        BoxShadow(
                          color: Color(0x19000000),
                          blurRadius: 20,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    child: ListView(
                      controller: scrollController, // [수정 2] 드래그 연결 핵심
                      physics:
                          const ClampingScrollPhysics(), // [수정 2] 탭을 잡아도 창이 딸려오게 하는 물리 효과
                      padding: const EdgeInsets.fromLTRB(21, 10, 21, 30),
                      children: [
                        // 손잡이 바
                        Center(
                          child: Container(
                            width: 42,
                            height: 5,
                            margin: const EdgeInsets.only(bottom: 21),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1D5DC),
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        ),

                        // 헤더
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Nearby Safe Places',
                                  style: TextStyle(
                                    color: Color(0xFF101727),
                                    fontSize: 17.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 3.5),
                                Text(
                                  'Wheelchair accessible locations',
                                  style: TextStyle(
                                    color: Color(0xFF697282),
                                    fontSize: 12.25,
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () => print("View All 클릭됨"),
                              child: const Text(
                                'View All',
                                style: TextStyle(
                                  color: Color(0xFF00C853),
                                  fontSize: 12.25,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // [수정 3] 리스트 아이템들 (클릭 가능하게 변경)
                        _buildDashboardItem(
                          title: "Seongsu Station",
                          type: "Transit",
                          distance: "350m",
                          time: "5 min walk",
                          iconPath: "assets/place_icon.svg",
                          onTap: () => print("성수역 선택됨"),
                        ),
                        const SizedBox(height: 10),
                        _buildDashboardItem(
                          title: "Home",
                          type: "Saved Place",
                          distance: "1.2km",
                          time: "15 min",
                          iconPath: "assets/home_icon.svg",
                          onTap: () => print("집 선택됨"),
                        ),
                        const SizedBox(height: 10),
                        _buildDashboardItem(
                          title: "Cafe Onion",
                          type: "Restaurant",
                          distance: "580m",
                          time: "8 min walk",
                          iconPath: "assets/cafe_icon.svg",
                          onTap: () => print("카페 어니언 선택됨"),
                        ),
                        const SizedBox(height: 10),
                        _buildDashboardItem(
                          title: "Seoul Forest",
                          type: "Park",
                          distance: "920m",
                          time: "12 min",
                          iconPath: "assets/building_icon.svg",
                          onTap: () => print("서울숲 선택됨"),
                        ),

                        const SizedBox(height: 30),

                        // 검색 버튼
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00C853),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x19000000),
                                blurRadius: 15,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Material(
                            // 클릭 효과를 위해 Material 추가
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => print("목적지 검색 클릭"),
                              borderRadius: BorderRadius.circular(20),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(
                                    'assets/search_icon.svg',
                                    width: 14,
                                    colorFilter: const ColorFilter.mode(
                                      Colors.white,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Search New Destination',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.25,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // (2) 신고 버튼 (대시보드 머리 위 + 클릭 가능)
                  Positioned(
                    right: 20,
                    top: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C853),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        // [수정 3] 클릭 효과 추가
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => print("장애물 신고 클릭"),
                          borderRadius: BorderRadius.circular(30),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Report Obstacle',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // ---------------------------------------------------------
          // 2. 상단 검색바 (햄버거 아이콘 복구)
          // ---------------------------------------------------------
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Row(
              children: [
                // [수정 1] 햄버거 버튼 (Icon 위젯으로 변경)
                Container(
                  width: 50,
                  height: 50,
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
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        // 햄버거 메뉴 클릭 시 드로어 열기
                        _scaffoldKey.currentState?.openDrawer();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: SvgPicture.asset(
                          'assets/burger_icon.svg',
                          width: 20,
                          height: 20,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // 검색창
                Expanded(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 15),
                        SvgPicture.asset(
                          'assets/search_icon.svg',
                          width: 20,
                          colorFilter: const ColorFilter.mode(
                            Colors.grey,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search accessible places...',
                              hintStyle: TextStyle(
                                color: Color(0xFF717182),
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              isDense: true,
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                      ],
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

  // [수정 3] 클릭 기능을 위해 onTap 추가
  Widget _buildDashboardItem({
    required String title,
    required String type,
    required String distance,
    required String time,
    required String iconPath,
    required VoidCallback onTap, // 클릭 함수 받기
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(width: 1.09, color: const Color(0xFFF2F4F6)),
        borderRadius: BorderRadius.circular(14),
      ),
      // Material & InkWell로 감싸서 클릭 효과 구현
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap, // 클릭 시 실행할 동작 연결
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853),
                    borderRadius: BorderRadius.circular(12.75),
                  ),
                  child: SvgPicture.asset(
                    iconPath,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF101727),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3.5),
                      Row(
                        children: [
                          Text(
                            type,
                            style: const TextStyle(
                              color: Color(0xFF697282),
                              fontSize: 10.5,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4.4),
                            child: Text(
                              '•',
                              style: TextStyle(
                                color: Color(0xFF99A1AE),
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                          Text(
                            distance,
                            style: const TextStyle(
                              color: Color(0xFF697282),
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.5,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF495565),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        time,
                        style: const TextStyle(
                          color: Color(0xFF495565),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
