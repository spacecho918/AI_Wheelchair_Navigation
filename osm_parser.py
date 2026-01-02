"""
OSM 데이터 파싱 모듈
OpenStreetMap 데이터를 그래프 구조로 변환합니다.
한국공학대학교 ↔ 정왕역 범위로 제한
"""

import osmnx as ox
import networkx as nx
from typing import Tuple, Optional
import logging

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 한국공학대학교 ↔ 정왕역 영역 좌표 (바운딩 박스)
# 한국공학대학교: 약 37.3401, 126.7315
# 정왕역: 약 37.35166, 126.74279
KOREA_TECH_LAT = 37.3401
KOREA_TECH_LON = 126.7315
JEONGWANG_STATION_LAT = 37.35166
JEONGWANG_STATION_LON = 126.74279

# 바운딩 박스 (정왕역 포함을 위해 확장)
BBOX_NORTH = 37.360  # 북쪽 경계 (확장)
BBOX_SOUTH = 37.330  # 남쪽 경계 (확장)
BBOX_EAST = 126.750  # 동쪽 경계 (확장)
BBOX_WEST = 126.720  # 서쪽 경계 (확장)


class OSMGraphBuilder:
    """
    OSM 데이터를 NetworkX 그래프로 변환하는 클래스
    """
    
    def __init__(self):
        """OSMGraphBuilder 초기화"""
        # OSMnx 설정 - 캐시 사용
        ox.settings.use_cache = True
        ox.settings.log_console = True
        self.graph: Optional[nx.MultiDiGraph] = None
        
    def build_graph_from_bbox(
        self,
        north: float = BBOX_NORTH,
        south: float = BBOX_SOUTH,
        east: float = BBOX_EAST,
        west: float = BBOX_WEST,
        network_type: str = "walk"
    ) -> nx.MultiDiGraph:
        """
        바운딩 박스 좌표로 OSM 그래프 생성
        
        Args:
            north: 북쪽 경계 위도
            south: 남쪽 경계 위도
            east: 동쪽 경계 경도
            west: 서쪽 경계 경도
            network_type: 네트워크 타입 ("walk", "drive", "bike" 등)
            
        Returns:
            NetworkX MultiDiGraph 객체
        """
        logger.info(f"OSM 그래프 생성 중: 북{north}, 남{south}, 동{east}, 서{west}")
        
        try:
            # OSMnx 2.0+ 버전: bbox는 (left, bottom, right, top) 또는 (west, south, east, north) 튜플
            # 이전 버전: north=, south=, east=, west= 키워드 인수
            try:
                # 최신 버전 (2.0+) 시도
                # simplify=False로 변경: 모든 교차로 노드 유지 (경로 정확도 향상)
                self.graph = ox.graph_from_bbox(
                    bbox=(west, south, east, north),  # (left, bottom, right, top)
                    network_type=network_type,
                    simplify=False
                )
            except TypeError:
                # 이전 버전 폴백
                self.graph = ox.graph_from_bbox(
                    north=north,
                    south=south,
                    east=east,
                    west=west,
                    network_type=network_type,
                    simplify=False
                )
            logger.info(f"그래프 생성 완료: 노드 {self.graph.number_of_nodes()}개, 엣지 {self.graph.number_of_edges()}개")
            return self.graph
            
        except Exception as e:
            logger.error(f"그래프 생성 실패: {e}")
            raise
    
    def build_graph_from_location(
        self,
        location: str = "시흥시, 경기도, 대한민국",
        network_type: str = "walk"
    ) -> nx.MultiDiGraph:
        """
        지역명으로 OSM 그래프 생성
        
        Args:
            location: 지역명 (예: "시흥시, 경기도, 대한민국")
            network_type: 네트워크 타입
            
        Returns:
            NetworkX MultiDiGraph 객체
        """
        logger.info(f"OSM 그래프 생성 중: {location}")
        
        try:
            self.graph = ox.graph_from_place(
                location,
                network_type=network_type,
                simplify=False
            )
            logger.info(f"그래프 생성 완료: 노드 {self.graph.number_of_nodes()}개, 엣지 {self.graph.number_of_edges()}개")
            return self.graph
            
        except Exception as e:
            logger.error(f"그래프 생성 실패: {e}")
            raise
    
    def filter_wheelchair_accessible(self, graph: nx.MultiDiGraph) -> nx.MultiDiGraph:
        """
        휠체어 통행 불가능한 엣지 필터링
        - 계단(steps) 제거
        - 경사도 높은 구간 필터링
        - 비포장도로 필터링
        
        Args:
            graph: 원본 그래프
            
        Returns:
            필터링된 그래프
        """
        logger.info("휠체어 통행 불가능 구간 필터링 중...")
        
        # 필터링할 highway 타입
        inaccessible_types = {'steps', 'escalator', 'construction'}
        
        edges_to_remove = []
        
        for u, v, key, data in graph.edges(keys=True, data=True):
            highway = data.get('highway', '')
            
            # highway가 리스트인 경우 처리
            if isinstance(highway, list):
                highway_set = set(highway)
            else:
                highway_set = {highway}
            
            # 통행 불가능 타입 체크
            if highway_set & inaccessible_types:
                edges_to_remove.append((u, v, key))
                continue
            
            # 계단 태그 체크
            if data.get('stairs') == 'yes':
                edges_to_remove.append((u, v, key))
                continue
                
            # 휠체어 접근 불가 태그 체크
            wheelchair = data.get('wheelchair', '')
            if wheelchair in ['no', 'limited']:
                edges_to_remove.append((u, v, key))
        
        # 엣지 제거
        for u, v, key in edges_to_remove:
            graph.remove_edge(u, v, key)
        
        logger.info(f"필터링 완료: {len(edges_to_remove)}개 엣지 제거")
        
        # 고립된 노드 제거
        isolated_nodes = list(nx.isolates(graph))
        graph.remove_nodes_from(isolated_nodes)
        logger.info(f"고립 노드 {len(isolated_nodes)}개 제거")
        
        return graph
    
    def get_nearest_node(
        self,
        lat: float,
        lon: float,
        graph: Optional[nx.MultiDiGraph] = None
    ) -> int:
        """
        좌표에서 가장 가까운 노드 ID 반환
        
        Args:
            lat: 위도
            lon: 경도
            graph: 그래프 (None이면 self.graph 사용)
            
        Returns:
            가장 가까운 노드 ID
        """
        if graph is None:
            graph = self.graph
            
        if graph is None:
            raise ValueError("그래프가 생성되지 않았습니다.")
        
        return ox.distance.nearest_nodes(graph, lon, lat)
    
    def get_nearest_edge(
        self,
        lat: float,
        lon: float,
        graph: Optional[nx.MultiDiGraph] = None
    ) -> Tuple[int, int, int]:
        """
        좌표에서 가장 가까운 엣지 반환
        
        Args:
            lat: 위도
            lon: 경도
            graph: 그래프 (None이면 self.graph 사용)
            
        Returns:
            (시작노드, 끝노드, 키) 튜플
        """
        if graph is None:
            graph = self.graph
            
        if graph is None:
            raise ValueError("그래프가 생성되지 않았습니다.")
        
        return ox.distance.nearest_edges(graph, lon, lat)
    
    def add_edge_weights(self, graph: Optional[nx.MultiDiGraph] = None) -> nx.MultiDiGraph:
        """
        엣지에 기본 가중치 정보 추가
        - length: 거리 (미터)
        - grade: 경사도 (OSM에서 가져오거나 0으로 초기화)
        - surface_penalty: 노면 상태 패널티
        
        Args:
            graph: 그래프 (None이면 self.graph 사용)
            
        Returns:
            가중치가 추가된 그래프
        """
        if graph is None:
            graph = self.graph
            
        if graph is None:
            raise ValueError("그래프가 생성되지 않았습니다.")
        
        # 노면 상태별 패널티
        surface_penalties = {
            'asphalt': 1.0,        # 아스팔트 - 최적
            'paved': 1.0,          # 포장
            'concrete': 1.0,       # 콘크리트
            'paving_stones': 1.2,  # 블록
            'cobblestone': 1.5,    # 돌길
            'gravel': 1.8,         # 자갈
            'unpaved': 2.0,        # 비포장
            'ground': 2.0,         # 흙길
            'grass': 2.5,          # 잔디
            'sand': 3.0,           # 모래
        }
        
        for u, v, key, data in graph.edges(keys=True, data=True):
            # 거리 (이미 있으면 유지)
            if 'length' not in data:
                data['length'] = 0
            
            # 경사도 (OSM에 있으면 사용, 없으면 0)
            incline = data.get('incline', '0')
            if isinstance(incline, str):
                # "5%" 형식 파싱
                incline = incline.replace('%', '').replace('°', '')
                try:
                    data['grade'] = abs(float(incline))
                except ValueError:
                    data['grade'] = 0.0
            else:
                data['grade'] = abs(float(incline)) if incline else 0.0
            
            # 노면 상태 패널티
            surface = data.get('surface', 'paved')
            if isinstance(surface, list):
                surface = surface[0]
            data['surface_penalty'] = surface_penalties.get(surface, 1.3)
            
            # 장애물 가중치 (기본값 1.0, 장애물 있으면 무한대)
            if 'obstacle_weight' not in data:
                data['obstacle_weight'] = 1.0
        
        logger.info("엣지 가중치 추가 완료 (기본값)")
        return graph
    
    def add_elevation_data(
        self,
        graph: Optional[nx.MultiDiGraph] = None,
        sample_interval: float = 10.0,
        use_api: bool = True
    ) -> nx.MultiDiGraph:
        """
        DEM 데이터를 사용하여 정밀한 경사도 계산
        각 엣지를 sample_interval 간격으로 나눠 구간별 경사도 측정
        
        Args:
            graph: 그래프 (None이면 self.graph 사용)
            sample_interval: 샘플링 간격 (미터), 기본 10m
            use_api: True면 Open-Elevation API 사용, False면 SRTM 로컬 데이터 사용
            
        Returns:
            경사도가 추가된 그래프
        """
        if graph is None:
            graph = self.graph
            
        if graph is None:
            raise ValueError("그래프가 생성되지 않았습니다.")
        
        # elevation_calculator 모듈 임포트
        try:
            from elevation_calculator import (
                SlopeCalculator,
                OpenElevationProvider,
                SRTMElevationProvider
            )
        except ImportError:
            logger.error("elevation_calculator 모듈을 찾을 수 없습니다.")
            logger.info("기본 경사도(0)를 사용합니다.")
            return graph
        
        # 고도 제공자 선택
        if use_api:
            logger.info("Open-Elevation API를 사용하여 고도 데이터 조회")
            provider = OpenElevationProvider()
        else:
            logger.info("SRTM 로컬 데이터를 사용하여 고도 데이터 조회")
            provider = SRTMElevationProvider()
        
        slope_calculator = SlopeCalculator(provider)
        
        total_edges = graph.number_of_edges()
        processed = 0
        
        logger.info(f"DEM 기반 경사도 계산 시작: {total_edges}개 엣지, 샘플링 간격 {sample_interval}m")
        
        for u, v, key, data in graph.edges(keys=True, data=True):
            # 노드 좌표 가져오기
            u_data = graph.nodes[u]
            v_data = graph.nodes[v]
            
            start_lat = u_data.get('y', 0)
            start_lon = u_data.get('x', 0)
            end_lat = v_data.get('y', 0)
            end_lon = v_data.get('x', 0)
            
            try:
                # 경사도 계산 (최대값 사용 - 가장 가파른 구간 기준)
                grade, segments = slope_calculator.calculate_edge_grade(
                    start_lat, start_lon, end_lat, end_lon,
                    sample_interval=sample_interval,
                    method="max"  # 최대 경사도 사용 (안전 우선)
                )
                
                data['grade'] = grade  # 대표 경사도 (도)
                data['grade_segments'] = len(segments)
                data['grade_source'] = 'dem'
                
                # 최대 경사 구간 정보 저장
                if segments:
                    max_seg = max(segments, key=lambda s: s.grade_degrees)
                    data['max_grade'] = max_seg.grade_degrees
                    data['max_grade_elevation_diff'] = abs(max_seg.end_elevation - max_seg.start_elevation)
                    
            except Exception as e:
                logger.warning(f"경사도 계산 실패 (엣지 {u}-{v}): {e}")
                data['grade'] = 0.0
                data['grade_source'] = 'fallback'
            
            processed += 1
            if processed % 50 == 0:
                logger.info(f"경사도 계산 진행: {processed}/{total_edges} ({processed*100//total_edges}%)")
        
        logger.info(f"DEM 기반 경사도 계산 완료: {total_edges}개 엣지")
        return graph
    
    def save_graph(self, filepath: str, graph: Optional[nx.MultiDiGraph] = None):
        """그래프를 파일로 저장"""
        if graph is None:
            graph = self.graph
        ox.save_graphml(graph, filepath)
        logger.info(f"그래프 저장: {filepath}")
    
    def load_graph(self, filepath: str) -> nx.MultiDiGraph:
        """저장된 그래프 불러오기"""
        self.graph = ox.load_graphml(filepath)
        logger.info(f"그래프 로드: {filepath}")
        return self.graph


# 테스트 및 예시 실행
if __name__ == "__main__":
    builder = OSMGraphBuilder()
    
    # 한국공학대 ↔ 정왕역 범위로 그래프 생성
    print("=== OSM 그래프 생성 테스트 ===")
    graph = builder.build_graph_from_bbox()
    
    # 휠체어 접근 불가 구간 필터링
    graph = builder.filter_wheelchair_accessible(graph)
    
    # 가중치 추가
    graph = builder.add_edge_weights(graph)
    
    print(f"\n최종 그래프 정보:")
    print(f"  - 노드 수: {graph.number_of_nodes()}")
    print(f"  - 엣지 수: {graph.number_of_edges()}")
    
    # 한국공학대에서 가장 가까운 노드
    nearest = builder.get_nearest_node(KOREA_TECH_LAT, KOREA_TECH_LON)
    print(f"  - 한국공학대 가장 가까운 노드: {nearest}")
    
    # 정왕역에서 가장 가까운 노드
    nearest = builder.get_nearest_node(JEONGWANG_STATION_LAT, JEONGWANG_STATION_LON)
    print(f"  - 정왕역 가장 가까운 노드: {nearest}")

