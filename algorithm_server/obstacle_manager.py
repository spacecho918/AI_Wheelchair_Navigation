"""
장애물 관리 모듈
Supabase에서 장애물 데이터를 가져와 그래프 가중치에 반영
"""

import networkx as nx
from typing import List, Dict, Tuple, Optional
from dataclasses import dataclass
import logging
import math

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class Obstacle:
    """장애물 데이터 클래스"""
    id: str
    latitude: float
    longitude: float
    obstacle_type: str  # "stairs", "construction", "pothole", "steep_slope", etc.
    description: str
    radius: float = 10.0  # 영향 반경 (미터)
    severity: str = "high"  # "low", "medium", "high"
    is_active: bool = True


class ObstacleManager:
    """
    장애물 관리 클래스
    - Supabase에서 장애물 데이터 조회
    - 좌표 기반 인근 OSM 엣지 탐색
    - 장애물 구간 가중치 무한대 설정
    """
    
    # 장애물 기본 영향 반경 (미터)
    DEFAULT_RADIUS = 15.0
    
    def __init__(self, supabase_url: str = "", supabase_key: str = ""):
        """
        Args:
            supabase_url: Supabase 프로젝트 URL
            supabase_key: Supabase API 키 (anon 또는 service role)
        """
        self.supabase_url = supabase_url
        self.supabase_key = supabase_key
        self.client = None
        self.obstacles: List[Obstacle] = []
        
        if supabase_url and supabase_key:
            self._init_supabase_client()
    
    def _init_supabase_client(self):
        """Supabase 클라이언트 초기화"""
        try:
            from supabase import create_client
            self.client = create_client(self.supabase_url, self.supabase_key)
            logger.info("Supabase 클라이언트 초기화 완료")
        except ImportError:
            logger.warning("supabase 패키지가 설치되지 않았습니다. pip install supabase")
        except Exception as e:
            logger.error(f"Supabase 연결 실패: {e}")
    
    def fetch_obstacles(self, table_name: str = "obstacles") -> List[Obstacle]:
        """
        Supabase에서 활성화된 장애물 목록 조회
        
        Args:
            table_name: 장애물 테이블 이름
            
        Returns:
            Obstacle 객체 리스트
        """
        if not self.client:
            logger.warning("Supabase 클라이언트가 초기화되지 않았습니다.")
            return []
        
        try:
            response = self.client.table(table_name).select("*").eq("is_active", True).execute()
            
            self.obstacles = []
            for row in response.data:
                obstacle = Obstacle(
                    id=row.get("id", ""),
                    latitude=float(row.get("latitude", 0)),
                    longitude=float(row.get("longitude", 0)),
                    obstacle_type=row.get("obstacle_type", "unknown"),
                    description=row.get("description", ""),
                    radius=float(row.get("radius", self.DEFAULT_RADIUS)),
                    severity=row.get("severity", "high"),
                    is_active=row.get("is_active", True)
                )
                self.obstacles.append(obstacle)
            
            logger.info(f"장애물 {len(self.obstacles)}개 조회 완료")
            return self.obstacles
            
        except Exception as e:
            logger.error(f"장애물 조회 실패: {e}")
            return []
    
    def add_obstacle_manually(
        self,
        latitude: float,
        longitude: float,
        obstacle_type: str = "obstacle",
        description: str = "",
        radius: float = DEFAULT_RADIUS
    ) -> Obstacle:
        """
        수동으로 장애물 추가 (테스트용)
        
        Args:
            latitude: 위도
            longitude: 경도
            obstacle_type: 장애물 유형
            description: 설명
            radius: 영향 반경 (미터)
            
        Returns:
            생성된 Obstacle 객체
        """
        obstacle = Obstacle(
            id=f"manual_{len(self.obstacles)}",
            latitude=latitude,
            longitude=longitude,
            obstacle_type=obstacle_type,
            description=description,
            radius=radius,
            severity="high",
            is_active=True
        )
        self.obstacles.append(obstacle)
        logger.info(f"장애물 수동 추가: ({latitude}, {longitude})")
        return obstacle
    
    @staticmethod
    def haversine_distance(
        lat1: float, lon1: float,
        lat2: float, lon2: float
    ) -> float:
        """
        두 좌표 간 거리 계산 (Haversine 공식, 미터 단위)
        
        Args:
            lat1, lon1: 첫 번째 좌표
            lat2, lon2: 두 번째 좌표
            
        Returns:
            거리 (미터)
        """
        R = 6371000  # 지구 반지름 (미터)
        
        lat1_rad = math.radians(lat1)
        lat2_rad = math.radians(lat2)
        delta_lat = math.radians(lat2 - lat1)
        delta_lon = math.radians(lon2 - lon1)
        
        a = (math.sin(delta_lat / 2) ** 2 +
             math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(delta_lon / 2) ** 2)
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        
        return R * c
    
    @staticmethod
    def point_to_segment_distance(
        point_lat: float, point_lon: float,
        seg_start_lat: float, seg_start_lon: float,
        seg_end_lat: float, seg_end_lon: float
    ) -> float:
        """
        점에서 선분까지의 최단 거리 계산 (미터)
        
        실제 경로(선분) 위에 장애물이 있는 경우만 정확히 감지
        
        Args:
            point_lat, point_lon: 점(장애물) 좌표
            seg_start_lat, seg_start_lon: 선분 시작점 좌표
            seg_end_lat, seg_end_lon: 선분 끝점 좌표
            
        Returns:
            점에서 선분까지의 최단 거리 (미터)
        """
        # 좌표를 미터 단위 평면 좌표로 근사 변환 (작은 영역에서 유효)
        # 위도 1도 ≈ 111km, 경도 1도 ≈ 111km * cos(위도)
        avg_lat = (seg_start_lat + seg_end_lat) / 2
        lat_to_m = 111000  # 위도 1도 → 미터
        lon_to_m = 111000 * math.cos(math.radians(avg_lat))  # 경도 1도 → 미터
        
        # 미터 좌표로 변환
        px = (point_lon - seg_start_lon) * lon_to_m
        py = (point_lat - seg_start_lat) * lat_to_m
        
        sx = 0  # 시작점 기준
        sy = 0
        
        ex = (seg_end_lon - seg_start_lon) * lon_to_m
        ey = (seg_end_lat - seg_start_lat) * lat_to_m
        
        # 선분 벡터
        dx = ex - sx
        dy = ey - sy
        
        # 선분 길이의 제곱
        len_sq = dx * dx + dy * dy
        
        if len_sq == 0:
            # 선분이 점인 경우
            return math.sqrt(px * px + py * py)
        
        # 점을 선분에 투영한 위치 (0~1 범위)
        t = max(0, min(1, (px * dx + py * dy) / len_sq))
        
        # 투영점 좌표
        proj_x = sx + t * dx
        proj_y = sy + t * dy
        
        # 점에서 투영점까지의 거리
        dist = math.sqrt((px - proj_x) ** 2 + (py - proj_y) ** 2)
        
        return dist
    
    def find_affected_edges(
        self,
        graph: nx.MultiDiGraph,
        obstacle: Obstacle
    ) -> List[Tuple[int, int, int]]:
        """
        장애물이 실제로 경로 위에 있는 엣지만 찾기
        
        개선된 로직:
        - 점(장애물)에서 선분(엣지)까지의 최단 거리 계산
        - 실제로 경로를 지나는 장애물만 감지
        - 엣지 끝점 근처에 있지만 경로를 막지 않는 장애물은 제외
        
        Args:
            graph: OSM 그래프
            obstacle: 장애물 객체
            
        Returns:
            영향받는 엣지 리스트 [(u, v, key), ...]
        """
        affected_edges = []
        
        for u, v, key, data in graph.edges(keys=True, data=True):
            # 엣지의 시작/끝 노드 좌표
            u_data = graph.nodes[u]
            v_data = graph.nodes[v]
            
            u_lat, u_lon = u_data.get('y', 0), u_data.get('x', 0)
            v_lat, v_lon = v_data.get('y', 0), v_data.get('x', 0)
            
            # 점(장애물)에서 선분(엣지)까지의 최단 거리 계산
            dist = self.point_to_segment_distance(
                obstacle.latitude, obstacle.longitude,
                u_lat, u_lon,
                v_lat, v_lon
            )
            
            # 최단 거리가 반경 내이면 = 실제로 경로 위에 장애물 있음
            if dist <= obstacle.radius:
                affected_edges.append((u, v, key))
        
        return affected_edges
    
    def apply_obstacles_to_graph(
        self,
        graph: nx.MultiDiGraph,
        obstacles: Optional[List[Obstacle]] = None
    ) -> Tuple[nx.MultiDiGraph, int]:
        """
        장애물 데이터를 그래프 가중치에 반영
        영향받는 엣지의 obstacle_weight를 무한대로 설정
        
        Args:
            graph: OSM 그래프
            obstacles: 장애물 리스트 (None이면 self.obstacles 사용)
            
        Returns:
            (수정된 그래프, 영향받은 엣지 수)
        """
        if obstacles is None:
            obstacles = self.obstacles
        
        total_affected = 0
        affected_edges_set = set()
        
        for obstacle in obstacles:
            if not obstacle.is_active:
                continue
            
            affected = self.find_affected_edges(graph, obstacle)
            
            for u, v, key in affected:
                if (u, v, key) not in affected_edges_set:
                    affected_edges_set.add((u, v, key))
                    
                    # 가중치를 무한대로 설정
                    graph[u][v][key]['obstacle_weight'] = float('inf')
                    graph[u][v][key]['obstacle_type'] = obstacle.obstacle_type
                    graph[u][v][key]['obstacle_id'] = obstacle.id
                    
                    total_affected += 1
        
        logger.info(f"장애물 {len(obstacles)}개로 인해 {total_affected}개 엣지 차단됨")
        
        return graph, total_affected
    
    def clear_obstacles_from_graph(self, graph: nx.MultiDiGraph) -> nx.MultiDiGraph:
        """
        그래프에서 장애물 가중치 초기화
        
        Args:
            graph: OSM 그래프
            
        Returns:
            초기화된 그래프
        """
        for u, v, key, data in graph.edges(keys=True, data=True):
            data['obstacle_weight'] = 1.0
            if 'obstacle_type' in data:
                del data['obstacle_type']
            if 'obstacle_id' in data:
                del data['obstacle_id']
        
        logger.info("그래프 장애물 가중치 초기화 완료")
        return graph
    
    def get_obstacles_near_route(
        self,
        geometry: List[Tuple[float, float]],
        search_radius: float = 50.0
    ) -> List[Obstacle]:
        """
        경로 근처의 장애물 목록 반환 (경고용)
        
        Args:
            geometry: 경로 좌표 리스트
            search_radius: 검색 반경 (미터)
            
        Returns:
            경로 근처 장애물 리스트
        """
        nearby_obstacles = []
        
        for obstacle in self.obstacles:
            for lat, lon in geometry:
                dist = self.haversine_distance(
                    obstacle.latitude, obstacle.longitude,
                    lat, lon
                )
                if dist <= search_radius:
                    if obstacle not in nearby_obstacles:
                        nearby_obstacles.append(obstacle)
                    break
        
        return nearby_obstacles


# 테스트
if __name__ == "__main__":
    print("=== 장애물 관리자 테스트 ===")
    
    # Supabase 없이 테스트
    manager = ObstacleManager()
    
    # 테스트 장애물 추가
    manager.add_obstacle_manually(
        latitude=37.3410,
        longitude=126.7320,
        obstacle_type="stairs",
        description="테스트 계단 장애물",
        radius=15.0
    )
    
    manager.add_obstacle_manually(
        latitude=37.3450,
        longitude=126.7360,
        obstacle_type="construction",
        description="공사 구간",
        radius=20.0
    )
    
    print(f"\n등록된 장애물 수: {len(manager.obstacles)}")
    for obs in manager.obstacles:
        print(f"  - {obs.obstacle_type}: ({obs.latitude}, {obs.longitude}), 반경 {obs.radius}m")
    
    # 거리 계산 테스트
    dist = manager.haversine_distance(37.3401, 126.7315, 37.35166, 126.74279)
    print(f"\n테스트 구간 거리: {dist:.1f}m")
    
    print("\n(그래프 적용 테스트는 osm_parser 모듈이 필요합니다)")
