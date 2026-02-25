"""
경로 탐색 알고리즘 모듈
3가지 모드(최단/안전/최적)에 따른 Dijkstra 알고리즘 구현
휠체어 유형별 가중치 적용 지원
"""

import heapq
import networkx as nx
from typing import Dict, List, Tuple, Optional, Literal
from dataclasses import dataclass
import logging
import math

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 경로 모드 타입
RouteMode = Literal["short", "safe", "optimal"]

# 휠체어 유형 타입
WheelchairType = Literal["electric", "manual", "manual_with_helper", "none"]

# Flutter → 서버 내부 값 변환용 매핑
WHEELCHAIR_TYPE_MAPPING = {
    "Electric": "electric",
    "Manual": "manual",
    "CaregiverManual": "manual_with_helper",
    "None": "none",
}

@dataclass
class RouteResult:
    """경로 탐색 결과"""
    success: bool
    distance: float  # 총 거리 (미터)
    estimated_time: int  # 예상 시간 (분)
    node_path: List[int]  # 노드 ID 경로
    geometry: List[Tuple[float, float]]  # (위도, 경도) 좌표 리스트
    instructions: List[Dict[str, str]]  # 턴바이턴 안내 메시지 리스트 [{"instruction": "...", "distance": "..."}]
    avoided_obstacles: int  # 회피한 장애물 수
    total_weight: float  # 총 가중치
    mode: str  # 사용된 모드
    message: str  # 결과 메시지


class WeightCalculator:
    """
    3가지 모드별 + 4가지 휠체어 유형별 가중치 계산 클래스
    
    모든 모드에서 장애물(obstacle_weight=inf)은 무조건 차단됩니다.
    차이점은 경사도, 노면 상태 등에 대한 민감도입니다.
    
    휠체어 유형:
    - electric: 전동휠체어 - 모터로 경사 극복 쉬움
    - manual: 수동휠체어 - 사용자가 직접 조작, 경사/노면에 매우 민감
    - manual_with_helper: 수동휠체어+보호자 - 보호자 도움으로 경사 극복 가능
    - none: 휠체어 미사용 - 일반 보행, 거의 제한 없음
    """
    
    # 모드별 패널티 가중치 설정
    # 숫자가 낮을수록 해당 요소에 덜 민감 (허용 범위 넓음)
    MODE_CONFIG = {
        "short": {
            "grade_multiplier": 0.3,      # 경사도 패널티 낮음 (거리 우선)
            "surface_multiplier": 0.3,    # 노면 패널티 낮음
            "distance_weight": 1.0,       # 거리 가중치 높음
            "safety_weight": 0.1,         # 안전 가중치 낮음
        },
        "safe": {
            "grade_multiplier": 2.0,      # 경사도 패널티 높음 (안전 우선)
            "surface_multiplier": 2.0,    # 노면 패널티 높음
            "distance_weight": 0.5,       # 거리 가중치 낮음
            "safety_weight": 1.0,         # 안전 가중치 높음
        },
        "optimal": {
            "grade_multiplier": 1.0,      # 경사도 패널티 중간 (균형)
            "surface_multiplier": 1.0,    # 노면 패널티 중간
            "distance_weight": 0.7,       # 거리 가중치 중간
            "safety_weight": 0.4,         # 안전 가중치 중간
        }
    }
    
    # 휠체어 유형별 가중치 설정
    # 경사도와 노면에 대한 민감도 배율
    WHEELCHAIR_CONFIG = {
        "electric": {
            "grade_sensitivity": 0.5,      # 전동: 경사도에 덜 민감 (모터 있음)
            "surface_sensitivity": 0.8,    # 전동: 노면에 약간 민감
            "description": "전동휠체어"
        },
        "manual": {
            "grade_sensitivity": 1.5,      # 수동: 경사도에 매우 민감
            "surface_sensitivity": 1.5,    # 수동: 노면에 민감
            "description": "수동휠체어"
        },
        "manual_with_helper": {
            "grade_sensitivity": 1.0,      # 수동+보호자: 경사도 중간
            "surface_sensitivity": 1.0,    # 수동+보호자: 노면 중간
            "description": "수동휠체어+보호자"
        },
        "none": {
            "grade_sensitivity": 0,      # 미사용: 경사도에 민감하지 않음
            "surface_sensitivity": 0,    # 미사용: 노면에 민감하지 않음
            "description": "휠체어 미사용"
        }
    }
    
    # 경로 모드별 경사도 임계값 (도)
    GRADE_THRESHOLDS = {
        "short": 15.0,   # 15도까지 허용 (급경사 허용)
        "safe": 8.0,      # 8도 이상이면 높은 패널티
        "optimal": 10.0,     # 10도 기준
    }
    
    # 휠체어 유형별 경사도 한계값 (도) - 이 값 초과 시 매우 높은 패널티
    WHEELCHAIR_GRADE_LIMITS = {
        "electric": 20.0,          # 전동: 20도까지 통행 가능
        "manual": 10.0,             # 수동: 10도 초과 시 매우 힘듦
        "manual_with_helper": 18.0, # 수동+보호자: 18도까지 가능
        "none": 99.0,              # 미사용: 계단 아닌 이상 대부분 가능
    }
    
    @classmethod
    def calculate_weight(
        cls,
        edge_data: dict,
        mode: RouteMode = "optimal",
        wheelchair_type: WheelchairType = "manual"
    ) -> float:
        """
        엣지 가중치 계산 (경로 모드 + 휠체어 유형 고려)
        
        Args:
            edge_data: 엣지 속성 딕셔너리
            mode: 경로 모드 ("short", "safe", "optimal")
            wheelchair_type: 휠체어 유형 ("electric", "manual", "manual_with_helper", "none")
            
        Returns:
            계산된 가중치 (float)
            장애물이 있으면 무한대 반환
        """
        # Flutter 값 → 서버 내부 값으로 변환
        wheelchair_type = WHEELCHAIR_TYPE_MAPPING.get(
            wheelchair_type, wheelchair_type
    )
        # 장애물 체크 - 모든 모드에서 무조건 차단
        obstacle_weight = edge_data.get('obstacle_weight', 1.0)
        if obstacle_weight == float('inf') or obstacle_weight > 1e10:
            return float('inf')
        
        # === 계단 체크 ===
        # 계단인지 확인 (is_stairs 플래그 또는 highway_type으로 판단)
        is_stairs = edge_data.get('is_stairs', False)
        highway_type = edge_data.get('highway_type', edge_data.get('highway', ''))
        if isinstance(highway_type, list):
            highway_type = highway_type[0] if highway_type else ''
        
        if is_stairs or highway_type == 'steps':
            # 휠체어 사용자는 계단 통과 불가
            if wheelchair_type in ['electric', 'manual', 'manual_with_helper']:
                return float('inf')
            # 휠체어 미사용자는 계단 통과 가능 (약간의 패널티)
            # none: 계단 허용
        
        # === 휠체어 제한 구간 체크 ===
        # is_wheelchair_accessible (JSON 필드) 또는 wheelchair 태그 확인
        wheelchair_restricted = edge_data.get('wheelchair_restricted', False)
        wheelchair_tag = edge_data.get('wheelchair', '')
        is_accessible = edge_data.get('is_wheelchair_accessible', True)  # 기본값 True
        
        if wheelchair_restricted or wheelchair_tag in ['no', 'limited'] or is_accessible == False:
            if wheelchair_type in ['electric', 'manual', 'manual_with_helper']:
                return float('inf')
            # 휠체어 미사용(none)은 통과 가능
        
        # 모드별 설정 가져오기
        mode_config = cls.MODE_CONFIG.get(mode, cls.MODE_CONFIG["optimal"])
        
        # 휠체어 유형별 설정 가져오기
        wheelchair_config = cls.WHEELCHAIR_CONFIG.get(wheelchair_type, cls.WHEELCHAIR_CONFIG["manual"])
        
        # 기본 거리
        length = edge_data.get('length', 0)
        if length == 0:
            return 0.0
        
        # === 경사도 패널티 계산 ===
        grade = edge_data.get('grade', 0)
        mode_threshold = cls.GRADE_THRESHOLDS.get(mode, 8.0)
        wheelchair_limit = cls.WHEELCHAIR_GRADE_LIMITS.get(wheelchair_type, 10.0)
        
        # 휠체어 유형별 경사도 민감도 적용
        grade_sensitivity = wheelchair_config["grade_sensitivity"]
        
        if grade > wheelchair_limit:
            # 휠체어 한계 경사 초과 시 매우 높은 패널티
            grade_penalty = 1 + mode_config["grade_multiplier"] * grade_sensitivity * ((grade - wheelchair_limit) ** 2 / 5)
        elif grade > mode_threshold:
            # 모드 임계값 초과 시 기하급수적 패널티 (휠체어 민감도 적용)
            grade_penalty = 1 + mode_config["grade_multiplier"] * grade_sensitivity * ((grade - mode_threshold) ** 1.5 / 10)
        else:
            # 임계값 이하 시 선형 패널티 (휠체어 민감도 적용)
            grade_penalty = 1 + mode_config["grade_multiplier"] * grade_sensitivity * (grade / mode_threshold) * 0.2
        
        # === 노면 상태 패널티 계산 ===
        surface_penalty = edge_data.get('surface_penalty', 1.0)
        surface_sensitivity = wheelchair_config["surface_sensitivity"]
        
        # 휠체어 유형별 노면 민감도 적용
        surface_factor = 1 + (surface_penalty - 1) * mode_config["surface_multiplier"] * surface_sensitivity
        
        # === 최종 가중치 계산 ===
        # 거리 * 경사도_패널티 * 노면_패널티 * 장애물_가중치
        weight = length * grade_penalty * surface_factor * obstacle_weight
        
        return weight


class RouteCalculator:
    """
    Dijkstra 알고리즘 기반 경로 탐색 클래스
    휠체어 유형별 경로 탐색 지원
    """
    
    # 휠체어 유형별 평균 속도 (m/min)
    WHEELCHAIR_SPEEDS = {
        "electric": 100,          # 전동: 6km/h
        "manual": 50,             # 수동: 3km/h
        "manual_with_helper": 58, # 수동+보호자: 3.5km/h
        "none": 75,               # 일반 보행: 4.5km/h
    }
    
    # 기본 속도 (하위 호환용)
    WHEELCHAIR_SPEED = 60  # 약 3.6km/h
    
    def __init__(self, graph: nx.MultiDiGraph):
        """
        Args:
            graph: OSM에서 변환된 NetworkX 그래프
        """
        self.graph = graph
        self.weight_calculator = WeightCalculator()
    
    def dijkstra_route(
        self,
        start_node: int,
        end_node: int,
        mode: RouteMode = "optimal",
        wheelchair_type: WheelchairType = "manual"
    ) -> RouteResult:
        """
        Dijkstra 알고리즘으로 최적 경로 탐색
        
        Args:
            start_node: 출발 노드 ID
            end_node: 도착 노드 ID
            mode: 경로 모드 ("short", "safe", "optimal")
            wheelchair_type: 휠체어 유형 ("electric", "manual", "manual_with_helper", "none")
            
        Returns:
            RouteResult 객체
        """
        # Flutter 값 → 서버 내부 값으로 변환
        wheelchair_type = WHEELCHAIR_TYPE_MAPPING.get(
            wheelchair_type, wheelchair_type
        )
        
        wheelchair_desc = WeightCalculator.WHEELCHAIR_CONFIG.get(wheelchair_type, {}).get("description", wheelchair_type)
        logger.info(f"경로 탐색 시작: {start_node} -> {end_node} (모드: {mode}, 휠체어: {wheelchair_desc})")
        
        if start_node not in self.graph:
            return RouteResult(
                success=False, distance=0, estimated_time=0,
                node_path=[], geometry=[], avoided_obstacles=0,
                total_weight=0, mode=mode, message="출발 노드를 찾을 수 없습니다."
            )
        
        if end_node not in self.graph:
            return RouteResult(
                success=False, distance=0, estimated_time=0,
                node_path=[], geometry=[], avoided_obstacles=0,
                total_weight=0, mode=mode, message="도착 노드를 찾을 수 없습니다."
            )
        
        # Dijkstra 알고리즘
        # distances[node] = (최소 가중치, 이전 노드, 실제 거리)
        distances: Dict[int, Tuple[float, Optional[int], float]] = {
            start_node: (0, None, 0)
        }
        
        # 우선순위 큐: (가중치, 노드ID)
        pq = [(0, start_node)]
        visited = set()
        avoided_count = 0
        
        while pq:
            current_weight, current_node = heapq.heappop(pq)
            
            if current_node in visited:
                continue
            visited.add(current_node)
            
            # 도착점에 도달
            if current_node == end_node:
                break
            
            # 현재 노드의 실제 거리
            current_dist = distances[current_node][2]
            
            # 인접 노드 탐색
            for neighbor in self.graph.neighbors(current_node):
                if neighbor in visited:
                    continue
                
                # 엣지 데이터 가져오기 (여러 엣지 중 첫 번째)
                edge_data = self.graph.get_edge_data(current_node, neighbor)
                if edge_data is None:
                    continue
                
                # MultiDiGraph에서 첫 번째 엣지 사용
                edge_key = list(edge_data.keys())[0]
                data = edge_data[edge_key]
                
                # 가중치 계산 (모드 + 휠체어 유형 적용)
                weight = self.weight_calculator.calculate_weight(data, mode, wheelchair_type)
                
                # 장애물로 인한 무한대 가중치 = 회피
                if weight == float('inf'):
                    avoided_count += 1
                    continue
                
                # 실제 거리
                edge_length = data.get('length', 0)
                
                new_weight = current_weight + weight
                new_dist = current_dist + edge_length
                
                if neighbor not in distances or new_weight < distances[neighbor][0]:
                    distances[neighbor] = (new_weight, current_node, new_dist)
                    heapq.heappush(pq, (new_weight, neighbor))
        
        # 경로 재구성
        if end_node not in distances:
            return RouteResult(
                success=False, distance=0, estimated_time=0,
                node_path=[], geometry=[], avoided_obstacles=avoided_count,
                total_weight=0, mode=mode,
                message="도착점까지의 경로를 찾을 수 없습니다. 장애물로 인해 모든 경로가 차단되었을 수 있습니다."
            )
        
        # 경로 역추적
        path = []
        current = end_node
        while current is not None:
            path.append(current)
            current = distances[current][1]
        path.reverse()
        
        # 총 거리 및 가중치
        total_dist = distances[end_node][2]
        total_weight = distances[end_node][0]
        
        # 좌표 경로 생성
        geometry = self._get_route_geometry(path)
        
        # 예상 시간 계산 (분) - 휠체어 유형별 속도 적용
        wheelchair_speed = self.WHEELCHAIR_SPEEDS.get(wheelchair_type, self.WHEELCHAIR_SPEED)
        estimated_time = int(total_dist / wheelchair_speed) + 1
        
        instructions = self._generate_instructions(geometry)

        logger.info(f"경로 탐색 완료: 거리 {total_dist:.1f}m, 예상시간 {estimated_time}분")
        
        return RouteResult(
            success=True,
            distance=round(total_dist, 1),
            estimated_time=estimated_time,
            node_path=path,
            geometry=geometry,
            instructions=instructions,
            avoided_obstacles=avoided_count,
            total_weight=round(total_weight, 2),
            mode=mode,
            message="경로 탐색 성공"
        )
    
    def _calculate_bearing(self, lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """두 좌표 사이의 방위각(Bearing)을 계산"""
        lat1, lon1 = math.radians(lat1), math.radians(lon1)
        lat2, lon2 = math.radians(lat2), math.radians(lon2)
        dLon = lon2 - lon1
        y = math.sin(dLon) * math.cos(lat2)
        x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon)
        bearing = math.atan2(y, x)
        bearing = math.degrees(bearing)
        return (bearing + 360) % 360

    def _haversine_distance(self, lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """두 좌표 사이의 거리 계산 (미터 단위)"""
        R = 6371000 # 지구 반경 (미터)
        phi1 = math.radians(lat1)
        phi2 = math.radians(lat2)
        delta_phi = math.radians(lat2 - lat1)
        delta_lambda = math.radians(lon2 - lon1)
        a = math.sin(delta_phi/2.0)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda/2.0)**2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
        return R * c

    def _get_turn_direction(self, bearing_diff: float) -> str:
        """방위각 차이를 기반으로 방향 텍스트 반환"""
        if bearing_diff > 180:
            bearing_diff -= 360
        elif bearing_diff < -180:
            bearing_diff += 360
            
        if -20 <= bearing_diff <= 20:
            return "직진"
        elif 20 < bearing_diff <= 60:
            return "우측 방향"
        elif 60 < bearing_diff <= 120:
            return "우회전"
        elif 120 < bearing_diff <= 160:
            return "크게 우회전"
        elif -60 <= bearing_diff < -20:
            return "좌측 방향"
        elif -120 <= bearing_diff < -60:
            return "좌회전"
        elif -160 <= bearing_diff < -120:
            return "크게 좌회전"
        else:
            return "유턴"

    def _generate_instructions(self, geometry: List[Tuple[float, float]]) -> List[Dict[str, str]]:
        """geometry를 기반으로 턴바이턴 안내 메시지 생성"""
        if len(geometry) < 2:
            return [{"instruction": "도착지에 도달했습니다", "distance": "0m"}]

        instructions = []
        current_distance = 0.0
        
        # 첫 번째 방향 (출발)
        bearing = self._calculate_bearing(geometry[0][0], geometry[0][1], geometry[1][0], geometry[1][1])
        instructions.append({"instruction": "안내를 시작합니다", "distance": "0m"})

        for i in range(1, len(geometry) - 1):
            p1 = geometry[i-1]
            p2 = geometry[i]
            p3 = geometry[i+1]
            
            seg_dist = self._haversine_distance(p1[0], p1[1], p2[0], p2[1])
            current_distance += seg_dist
            
            bearing1 = self._calculate_bearing(p1[0], p1[1], p2[0], p2[1])
            bearing2 = self._calculate_bearing(p2[0], p2[1], p3[0], p3[1])
            
            bearing_diff = bearing2 - bearing1
            turn_dir = self._get_turn_direction(bearing_diff)
            
            # 직진이 아닌 유의미한 회전이 발생한 경우 명령 추가
            if turn_dir != "직진":
                instructions.append({
                    "instruction": turn_dir,
                    "distance": f"{int(current_distance)}m"
                })
                current_distance = 0.0 # 회전 후 누적 거리 초기화
                
        # 목적지 도착 안내
        final_seg_dist = self._haversine_distance(geometry[-2][0], geometry[-2][1], geometry[-1][0], geometry[-1][1])
        current_distance += final_seg_dist
        instructions.append({
            "instruction": "목적지에 도착했습니다",
            "distance": f"{int(current_distance)}m"
        })
        
        return instructions    
    def _get_route_geometry(self, node_path: List[int]) -> List[Tuple[float, float]]:
        """
        노드 경로를 좌표 리스트로 변환
        
        Args:
            node_path: 노드 ID 리스트
            
        Returns:
            (위도, 경도) 튜플 리스트
        """
        geometry = []
        for node_id in node_path:
            node_data = self.graph.nodes[node_id]
            lat = node_data.get('y', 0)
            lon = node_data.get('x', 0)
            geometry.append((lat, lon))
        return geometry
    
    def find_route(
        self,
        start_lat: float,
        start_lon: float,
        end_lat: float,
        end_lon: float,
        mode: RouteMode = "optimal",
        wheelchair_type: WheelchairType = "manual"
    ) -> RouteResult:
        """
        좌표로 경로 탐색 (편의 메서드)
        
        Args:
            start_lat, start_lon: 출발점 좌표
            end_lat, end_lon: 도착점 좌표
            mode: 경로 모드 ("short", "safe", "optimal")
            wheelchair_type: 휠체어 유형 ("electric", "manual", "manual_with_helper", "none")
            
        Returns:
            RouteResult 객체
        """
        import osmnx as ox
        
        try:
            start_node = ox.distance.nearest_nodes(self.graph, start_lon, start_lat)
            end_node = ox.distance.nearest_nodes(self.graph, end_lon, end_lat)
        except Exception as e:
            return RouteResult(
                success=False, distance=0, estimated_time=0,
                node_path=[], geometry=[], avoided_obstacles=0,
                total_weight=0, mode=mode,
                message=f"좌표에서 가장 가까운 노드를 찾을 수 없습니다: {e}"
            )
        
        return self.dijkstra_route(start_node, end_node, mode, wheelchair_type)
    
    def compare_routes(
        self,
        start_node: int,
        end_node: int,
        wheelchair_type: WheelchairType = "manual"
    ) -> Dict[str, RouteResult]:
        """
        3가지 모드의 경로 비교
        
        Args:
            start_node: 출발 노드 ID
            end_node: 도착 노드 ID
            wheelchair_type: 휠체어 유형 ("electric", "manual", "manual_with_helper", "none")
            
        Returns:
            모드별 RouteResult 딕셔너리
        """
        results = {}
        for mode in ["short", "safe", "optimal"]:
            results[mode] = self.dijkstra_route(start_node, end_node, mode, wheelchair_type)
        return results
    
    def compare_wheelchair_types(
        self,
        start_node: int,
        end_node: int,
        mode: RouteMode = "optimal"
    ) -> Dict[str, RouteResult]:
        """
        4가지 휠체어 유형별 경로 비교
        
        Args:
            start_node: 출발 노드 ID
            end_node: 도착 노드 ID
            mode: 경로 모드
            
        Returns:
            휠체어 유형별 RouteResult 딕셔너리
        """
        results = {}
        for wheelchair_type in ["electric", "manual", "manual_with_helper", "none"]:
            results[wheelchair_type] = self.dijkstra_route(start_node, end_node, mode, wheelchair_type)
        return results


# 테스트
if __name__ == "__main__":
    from osm_parser import OSMGraphBuilder, KOREA_TECH_LAT, KOREA_TECH_LON, JEONGWANG_STATION_LAT, JEONGWANG_STATION_LON
    
    print("=== 가중치 계산 테스트 ===")
    
    # 테스트 엣지 데이터
    test_edges = [
        {"length": 100, "grade": 0, "surface_penalty": 1.0, "obstacle_weight": 1.0},
        {"length": 100, "grade": 10, "surface_penalty": 1.0, "obstacle_weight": 1.0},
        {"length": 100, "grade": 0, "surface_penalty": 2.0, "obstacle_weight": 1.0},
        {"length": 100, "grade": 0, "surface_penalty": 1.0, "obstacle_weight": float('inf')},  # 장애물
    ]
    
    wheelchair_types = ["electric", "manual", "manual_with_helper", "none"]
    
    for i, edge in enumerate(test_edges):
        print(f"\n엣지 {i+1}: {edge}")
        for mode in ["short", "safe", "optimal"]:
            print(f"  [{mode}]")
            for wc_type in wheelchair_types:
                weight = WeightCalculator.calculate_weight(edge, mode, wc_type)
                wc_desc = WeightCalculator.WHEELCHAIR_CONFIG[wc_type]["description"]
                print(f"    {wc_desc}: {weight:.2f}")
    
    print("\n=== 경로 탐색 테스트 ===")
    print("(실제 OSM 데이터로 테스트하려면 osm_parser 모듈이 필요합니다)")
