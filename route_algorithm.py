"""
경로 탐색 알고리즘 모듈
3가지 모드(최단/안전/최적)에 따른 Dijkstra 알고리즘 구현
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


@dataclass
class RouteResult:
    """경로 탐색 결과"""
    success: bool
    distance: float  # 총 거리 (미터)
    estimated_time: int  # 예상 시간 (분)
    node_path: List[int]  # 노드 ID 경로
    geometry: List[Tuple[float, float]]  # (위도, 경도) 좌표 리스트
    avoided_obstacles: int  # 회피한 장애물 수
    total_weight: float  # 총 가중치
    mode: str  # 사용된 모드
    message: str  # 결과 메시지


class WeightCalculator:
    """
    3가지 모드별 가중치 계산 클래스
    
    모든 모드에서 장애물(obstacle_weight=inf)은 무조건 차단됩니다.
    차이점은 경사도, 노면 상태 등에 대한 민감도입니다.
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
            "distance_weight": 0.3,       # 거리 가중치 낮음
            "safety_weight": 1.0,         # 안전 가중치 높음
        },
        "optimal": {
            "grade_multiplier": 1.0,      # 경사도 패널티 중간 (균형)
            "surface_multiplier": 1.0,    # 노면 패널티 중간
            "distance_weight": 0.6,       # 거리 가중치 중간
            "safety_weight": 0.4,         # 안전 가중치 중간
        }
    }
    
    # 경사도 임계값 (도)
    GRADE_THRESHOLDS = {
        "short": 12.0,   # 12도까지 허용 (급경사 허용)
        "safe": 5.0,      # 5도 이상이면 높은 패널티
        "optimal": 8.0,     # 8도 기준
    }
    
    @classmethod
    def calculate_weight(
        cls,
        edge_data: dict,
        mode: RouteMode = "optimal"
    ) -> float:
        """
        엣지 가중치 계산
        
        Args:
            edge_data: 엣지 속성 딕셔너리
            mode: 경로 모드 ("short", "safe", "optimal")
            
        Returns:
            계산된 가중치 (float)
            장애물이 있으면 무한대 반환
        """
        # 장애물 체크 - 모든 모드에서 무조건 차단
        obstacle_weight = edge_data.get('obstacle_weight', 1.0)
        if obstacle_weight == float('inf') or obstacle_weight > 1e10:
            return float('inf')
        
        config = cls.MODE_CONFIG.get(mode, cls.MODE_CONFIG["optimal"])
        
        # 기본 거리
        length = edge_data.get('length', 0)
        if length == 0:
            return 0.0
        
        # 경사도 패널티 계산
        grade = edge_data.get('grade', 0)
        threshold = cls.GRADE_THRESHOLDS.get(mode, 8.0)
        
        if grade > threshold:
            # 임계값 초과 시 기하급수적 패널티
            grade_penalty = 1 + config["grade_multiplier"] * ((grade - threshold) ** 1.5 / 10)
        else:
            # 임계값 이하 시 선형 패널티
            grade_penalty = 1 + config["grade_multiplier"] * (grade / threshold) * 0.2
        
        # 노면 상태 패널티
        surface_penalty = edge_data.get('surface_penalty', 1.0)
        surface_factor = 1 + (surface_penalty - 1) * config["surface_multiplier"]
        
        # 최종 가중치 계산
        # 거리 * 경사도_패널티 * 노면_패널티 * 장애물_가중치
        weight = length * grade_penalty * surface_factor * obstacle_weight
        
        return weight


class RouteCalculator:
    """
    Dijkstra 알고리즘 기반 경로 탐색 클래스
    """
    
    # 휠체어 평균 속도 (m/min)
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
        mode: RouteMode = "optimal"
    ) -> RouteResult:
        """
        Dijkstra 알고리즘으로 최적 경로 탐색
        
        Args:
            start_node: 출발 노드 ID
            end_node: 도착 노드 ID
            mode: 경로 모드
            
        Returns:
            RouteResult 객체
        """
        logger.info(f"경로 탐색 시작: {start_node} -> {end_node} (모드: {mode})")
        
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
                
                # 가중치 계산
                weight = self.weight_calculator.calculate_weight(data, mode)
                
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
        
        # 예상 시간 계산 (분)
        estimated_time = int(total_dist / self.WHEELCHAIR_SPEED) + 1
        
        logger.info(f"경로 탐색 완료: 거리 {total_dist:.1f}m, 예상시간 {estimated_time}분")
        
        return RouteResult(
            success=True,
            distance=round(total_dist, 1),
            estimated_time=estimated_time,
            node_path=path,
            geometry=geometry,
            avoided_obstacles=avoided_count,
            total_weight=round(total_weight, 2),
            mode=mode,
            message="경로 탐색 성공"
        )
    
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
        mode: RouteMode = "optimal"
    ) -> RouteResult:
        """
        좌표로 경로 탐색 (편의 메서드)
        
        Args:
            start_lat, start_lon: 출발점 좌표
            end_lat, end_lon: 도착점 좌표
            mode: 경로 모드
            
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
        
        return self.dijkstra_route(start_node, end_node, mode)
    
    def compare_routes(
        self,
        start_node: int,
        end_node: int
    ) -> Dict[str, RouteResult]:
        """
        3가지 모드의 경로 비교
        
        Args:
            start_node: 출발 노드 ID
            end_node: 도착 노드 ID
            
        Returns:
            모드별 RouteResult 딕셔너리
        """
        results = {}
        for mode in ["short", "safe", "optimal"]:
            results[mode] = self.dijkstra_route(start_node, end_node, mode)
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
    
    for i, edge in enumerate(test_edges):
        print(f"\n엣지 {i+1}: {edge}")
        for mode in ["short", "safe", "optimal"]:
            weight = WeightCalculator.calculate_weight(edge, mode)
            print(f"  {mode}: {weight:.2f}")
    
    print("\n=== 경로 탐색 테스트 ===")
    print("(실제 OSM 데이터로 테스트하려면 osm_parser 모듈이 필요합니다)")
