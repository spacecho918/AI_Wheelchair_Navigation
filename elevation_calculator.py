"""
고도 및 경사도 계산 모듈
DEM(Digital Elevation Model) 데이터를 활용하여 정밀한 경사도 측정
엣지 내 여러 구간으로 나눠 부분별 경사도 계산
"""

import math
import logging
from typing import List, Tuple, Optional, Dict
from dataclasses import dataclass
import networkx as nx

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class SlopeSegment:
    """경사 구간 데이터"""
    start_lat: float
    start_lon: float
    end_lat: float
    end_lon: float
    start_elevation: float  # 시작점 고도 (미터)
    end_elevation: float    # 끝점 고도 (미터)
    distance: float         # 구간 거리 (미터)
    grade_percent: float    # 경사도 (%)
    grade_degrees: float    # 경사도 (도)


class ElevationProvider:
    """
    고도 데이터 제공자 (추상 기본 클래스 역할)
    여러 소스를 지원할 수 있도록 설계
    """
    
    def get_elevation(self, lat: float, lon: float) -> float:
        """단일 좌표의 고도 반환 (미터)"""
        raise NotImplementedError
    
    def get_elevations(self, coordinates: List[Tuple[float, float]]) -> List[float]:
        """여러 좌표의 고도 반환"""
        return [self.get_elevation(lat, lon) for lat, lon in coordinates]


class OpenElevationProvider(ElevationProvider):
    """
    Open-Elevation API를 사용한 고도 데이터 제공자
    무료, 오픈소스, 전세계 커버리지
    https://open-elevation.com/
    """
    
    API_URL = "https://api.open-elevation.com/api/v1/lookup"
    
    def __init__(self):
        self._cache: Dict[Tuple[float, float], float] = {}
    
    def get_elevation(self, lat: float, lon: float) -> float:
        """단일 좌표의 고도 반환"""
        # 캐시 확인 (소수점 5자리로 반올림하여 키 생성)
        cache_key = (round(lat, 5), round(lon, 5))
        if cache_key in self._cache:
            return self._cache[cache_key]
        
        try:
            import requests
            response = requests.post(
                self.API_URL,
                json={"locations": [{"latitude": lat, "longitude": lon}]},
                timeout=10
            )
            response.raise_for_status()
            data = response.json()
            elevation = data["results"][0]["elevation"]
            self._cache[cache_key] = elevation
            return elevation
        except Exception as e:
            logger.warning(f"고도 조회 실패 ({lat}, {lon}): {e}")
            return 0.0
    
    def get_elevations(self, coordinates: List[Tuple[float, float]]) -> List[float]:
        """
        여러 좌표의 고도를 배치로 조회 (API 호출 최적화)
        """
        # 캐시에 없는 좌표만 필터링
        uncached = []
        uncached_indices = []
        results = [0.0] * len(coordinates)
        
        for i, (lat, lon) in enumerate(coordinates):
            cache_key = (round(lat, 5), round(lon, 5))
            if cache_key in self._cache:
                results[i] = self._cache[cache_key]
            else:
                uncached.append({"latitude": lat, "longitude": lon})
                uncached_indices.append(i)
        
        if not uncached:
            return results
        
        try:
            import requests
            
            # API는 한 번에 최대 100개 정도 처리 가능
            batch_size = 100
            for batch_start in range(0, len(uncached), batch_size):
                batch = uncached[batch_start:batch_start + batch_size]
                batch_indices = uncached_indices[batch_start:batch_start + batch_size]
                
                response = requests.post(
                    self.API_URL,
                    json={"locations": batch},
                    timeout=30
                )
                response.raise_for_status()
                data = response.json()
                
                for j, result in enumerate(data["results"]):
                    elevation = result["elevation"]
                    idx = batch_indices[j]
                    results[idx] = elevation
                    
                    # 캐시에 저장
                    lat, lon = coordinates[idx]
                    cache_key = (round(lat, 5), round(lon, 5))
                    self._cache[cache_key] = elevation
            
            return results
            
        except Exception as e:
            logger.error(f"배치 고도 조회 실패: {e}")
            return results


class SRTMElevationProvider(ElevationProvider):
    """
    SRTM (Shuttle Radar Topography Mission) 데이터 제공자
    로컬 파일 기반으로 더 빠른 처리 가능
    pip install elevation 또는 rasterio 필요
    """
    
    def __init__(self, srtm_dir: str = "./srtm_data"):
        self.srtm_dir = srtm_dir
        self._cache: Dict[Tuple[float, float], float] = {}
        self._raster = None
        
    def get_elevation(self, lat: float, lon: float) -> float:
        """SRTM 타일에서 고도 조회"""
        cache_key = (round(lat, 5), round(lon, 5))
        if cache_key in self._cache:
            return self._cache[cache_key]
        
        try:
            # srtm 패키지 사용 시도
            import srtm
            elevation_data = srtm.get_data()
            elevation = elevation_data.get_elevation(lat, lon)
            
            if elevation is None:
                elevation = 0.0
            
            self._cache[cache_key] = elevation
            return elevation
            
        except ImportError:
            logger.warning("srtm 패키지가 없습니다. pip install srtm.py")
            return 0.0
        except Exception as e:
            logger.warning(f"SRTM 고도 조회 실패: {e}")
            return 0.0


class SlopeCalculator:
    """
    경사도 계산기
    엣지를 여러 구간으로 나눠 부분별 경사도 측정
    """
    
    # 기본 샘플링 간격 (미터)
    DEFAULT_SAMPLE_INTERVAL = 10.0
    
    # 최소 샘플 수
    MIN_SAMPLES = 2
    
    # 최대 샘플 수 (API 호출 제한)
    MAX_SAMPLES = 20
    
    def __init__(self, elevation_provider: Optional[ElevationProvider] = None):
        """
        Args:
            elevation_provider: 고도 데이터 제공자 (None이면 OpenElevation 사용)
        """
        if elevation_provider is None:
            self.elevation_provider = OpenElevationProvider()
        else:
            self.elevation_provider = elevation_provider
    
    @staticmethod
    def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """두 좌표 간 거리 (미터)"""
        R = 6371000  # 지구 반경
        
        lat1_rad = math.radians(lat1)
        lat2_rad = math.radians(lat2)
        delta_lat = math.radians(lat2 - lat1)
        delta_lon = math.radians(lon2 - lon1)
        
        a = (math.sin(delta_lat / 2) ** 2 +
             math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(delta_lon / 2) ** 2)
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        
        return R * c
    
    @staticmethod
    def interpolate_point(
        lat1: float, lon1: float,
        lat2: float, lon2: float,
        fraction: float
    ) -> Tuple[float, float]:
        """
        두 점 사이의 중간 좌표 계산
        
        Args:
            lat1, lon1: 시작점
            lat2, lon2: 끝점
            fraction: 0.0 ~ 1.0 사이의 비율
            
        Returns:
            (위도, 경도) 튜플
        """
        lat = lat1 + (lat2 - lat1) * fraction
        lon = lon1 + (lon2 - lon1) * fraction
        return (lat, lon)
    
    def sample_points_along_edge(
        self,
        start_lat: float, start_lon: float,
        end_lat: float, end_lon: float,
        sample_interval: float = DEFAULT_SAMPLE_INTERVAL
    ) -> List[Tuple[float, float]]:
        """
        엣지를 따라 샘플링 포인트 생성
        
        Args:
            start_lat, start_lon: 시작점
            end_lat, end_lon: 끝점
            sample_interval: 샘플링 간격 (미터)
            
        Returns:
            샘플링 포인트 리스트 [(lat, lon), ...]
        """
        distance = self.haversine_distance(start_lat, start_lon, end_lat, end_lon)
        
        # 샘플 수 계산
        num_samples = max(self.MIN_SAMPLES, int(distance / sample_interval) + 1)
        num_samples = min(num_samples, self.MAX_SAMPLES)
        
        points = []
        for i in range(num_samples):
            fraction = i / (num_samples - 1) if num_samples > 1 else 0
            point = self.interpolate_point(
                start_lat, start_lon,
                end_lat, end_lon,
                fraction
            )
            points.append(point)
        
        return points
    
    def calculate_segment_slopes(
        self,
        start_lat: float, start_lon: float,
        end_lat: float, end_lon: float,
        sample_interval: float = DEFAULT_SAMPLE_INTERVAL
    ) -> List[SlopeSegment]:
        """
        엣지 내 구간별 경사도 계산
        
        Args:
            start_lat, start_lon: 시작점
            end_lat, end_lon: 끝점
            sample_interval: 샘플링 간격 (미터)
            
        Returns:
            SlopeSegment 리스트
        """
        # 샘플링 포인트 생성
        points = self.sample_points_along_edge(
            start_lat, start_lon, end_lat, end_lon, sample_interval
        )
        
        if len(points) < 2:
            return []
        
        # 고도 일괄 조회
        elevations = self.elevation_provider.get_elevations(points)
        
        # 구간별 경사도 계산
        segments = []
        for i in range(len(points) - 1):
            p1_lat, p1_lon = points[i]
            p2_lat, p2_lon = points[i + 1]
            e1 = elevations[i]
            e2 = elevations[i + 1]
            
            seg_distance = self.haversine_distance(p1_lat, p1_lon, p2_lat, p2_lon)
            
            if seg_distance > 0:
                height_diff = e2 - e1
                grade_percent = (height_diff / seg_distance) * 100
                grade_degrees = math.degrees(math.atan(height_diff / seg_distance))
            else:
                grade_percent = 0.0
                grade_degrees = 0.0
            
            segment = SlopeSegment(
                start_lat=p1_lat,
                start_lon=p1_lon,
                end_lat=p2_lat,
                end_lon=p2_lon,
                start_elevation=e1,
                end_elevation=e2,
                distance=seg_distance,
                grade_percent=abs(grade_percent),
                grade_degrees=abs(grade_degrees)
            )
            segments.append(segment)
        
        return segments
    
    def calculate_edge_grade(
        self,
        start_lat: float, start_lon: float,
        end_lat: float, end_lon: float,
        sample_interval: float = DEFAULT_SAMPLE_INTERVAL,
        method: str = "max"
    ) -> Tuple[float, List[SlopeSegment]]:
        """
        엣지의 대표 경사도 계산
        
        Args:
            start_lat, start_lon: 시작점
            end_lat, end_lon: 끝점
            sample_interval: 샘플링 간격
            method: "max" (최대값) | "avg" (평균) | "weighted" (거리 가중 평균)
            
        Returns:
            (대표 경사도(도), 구간 목록)
        """
        segments = self.calculate_segment_slopes(
            start_lat, start_lon, end_lat, end_lon, sample_interval
        )
        
        if not segments:
            return 0.0, []
        
        if method == "max":
            # 최대 경사도 (가장 가파른 구간 기준 - 안전 우선)
            grade = max(seg.grade_degrees for seg in segments)
        
        elif method == "avg":
            # 단순 평균
            grade = sum(seg.grade_degrees for seg in segments) / len(segments)
        
        elif method == "weighted":
            # 거리 가중 평균
            total_distance = sum(seg.distance for seg in segments)
            if total_distance > 0:
                grade = sum(seg.grade_degrees * seg.distance for seg in segments) / total_distance
            else:
                grade = 0.0
        
        else:
            grade = max(seg.grade_degrees for seg in segments)
        
        return grade, segments


def add_elevation_data_to_graph(
    graph: nx.MultiDiGraph,
    slope_calculator: Optional[SlopeCalculator] = None,
    sample_interval: float = 10.0,
    grade_method: str = "max"
) -> nx.MultiDiGraph:
    """
    그래프의 모든 엣지에 경사도 정보 추가
    
    Args:
        graph: OSM 그래프
        slope_calculator: 경사도 계산기 (None이면 새로 생성)
        sample_interval: 샘플링 간격 (미터)
        grade_method: 경사도 계산 방법 ("max", "avg", "weighted")
        
    Returns:
        경사도가 추가된 그래프
    """
    if slope_calculator is None:
        slope_calculator = SlopeCalculator()
    
    total_edges = graph.number_of_edges()
    processed = 0
    
    logger.info(f"경사도 계산 시작: {total_edges}개 엣지")
    
    for u, v, key, data in graph.edges(keys=True, data=True):
        # 노드 좌표 가져오기
        u_data = graph.nodes[u]
        v_data = graph.nodes[v]
        
        start_lat = u_data.get('y', 0)
        start_lon = u_data.get('x', 0)
        end_lat = v_data.get('y', 0)
        end_lon = v_data.get('x', 0)
        
        # 경사도 계산
        grade, segments = slope_calculator.calculate_edge_grade(
            start_lat, start_lon, end_lat, end_lon,
            sample_interval=sample_interval,
            method=grade_method
        )
        
        # 그래프에 저장
        data['grade'] = grade  # 대표 경사도 (도)
        data['grade_segments'] = len(segments)  # 세그먼트 수
        
        # 최대 경사 구간 정보
        if segments:
            max_segment = max(segments, key=lambda s: s.grade_degrees)
            data['max_grade'] = max_segment.grade_degrees
            data['max_grade_location'] = (max_segment.start_lat, max_segment.start_lon)
        
        processed += 1
        if processed % 100 == 0:
            logger.info(f"경사도 계산 진행: {processed}/{total_edges}")
    
    logger.info(f"경사도 계산 완료: {total_edges}개 엣지")
    return graph


# 테스트
if __name__ == "__main__":
    print("=== 경사도 계산 테스트 ===")
    
    # 테스트 구간
    start_point = (37.3401, 126.7315)
    end_point = (37.35166, 126.74279)
    
    calculator = SlopeCalculator()
    
    print(f"\n테스트 구간: 시작점 → 끝점")
    print(f"시작점: {start_point}")
    print(f"끝점: {end_point}")
    
    # 샘플 포인트 생성
    points = calculator.sample_points_along_edge(
        start_point[0], start_point[1],
        end_point[0], end_point[1],
        sample_interval=50  # 50m 간격
    )
    print(f"\n샘플링 포인트 수: {len(points)}")
    
    # 경사도 계산
    print("\n경사도 계산 중 (API 호출)...")
    grade, segments = calculator.calculate_edge_grade(
        start_point[0], start_point[1],
        end_point[0], end_point[1],
        sample_interval=100,  # 100m 간격으로 테스트
        method="max"
    )
    
    print(f"\n=== 결과 ===")
    print(f"대표 경사도 (최대): {grade:.2f}°")
    print(f"측정 구간 수: {len(segments)}")
    
    if segments:
        print(f"\n구간별 경사도:")
        for i, seg in enumerate(segments):
            print(f"  구간 {i+1}: {seg.grade_degrees:.2f}° "
                  f"(고도 {seg.start_elevation:.1f}m → {seg.end_elevation:.1f}m, "
                  f"거리 {seg.distance:.1f}m)")
