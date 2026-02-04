"""
엣지 데이터 전처리 스크립트
OSM 그래프의 모든 엣지에 대해 정밀한 경사도 데이터를 계산하고
Supabase에 저장합니다.

사용법:
    python preprocess_edges.py

주의:
    - 한 번만 실행하면 됩니다 (데이터 변경 시 재실행)
    - 시간이 오래 걸릴 수 있습니다 (정확도 우선)
    - Supabase 연결 정보가 필요합니다
"""

import os
import json
import time
import logging
from typing import List, Dict, Optional, Tuple
from dataclasses import dataclass, asdict
from dotenv import load_dotenv

# 환경변수 로드
load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@dataclass
class EdgeData:
    """엣지 데이터 구조"""
    edge_id: str                    # 고유 ID (start_end_key)
    start_node_id: int
    end_node_id: int
    start_lat: float
    start_lon: float
    end_lat: float
    end_lon: float
    length: float                   # 거리 (m)
    grade: float                    # 대표 경사도 (도)
    max_grade: float                # 최대 경사도 (도)
    min_grade: float                # 최소 경사도 (도)
    avg_grade: float                # 평균 경사도 (도)
    grade_segments: int             # 측정 구간 수
    elevation_start: float          # 시작점 고도 (m)
    elevation_end: float            # 끝점 고도 (m)
    elevation_max: float            # 최대 고도 (m)
    elevation_min: float            # 최소 고도 (m)
    total_ascent: float             # 총 오르막 (m)
    total_descent: float            # 총 내리막 (m)
    surface_type: str               # 노면 타입
    surface_penalty: float          # 노면 패널티
    highway_type: str               # 도로 타입
    is_wheelchair_accessible: bool  # 휠체어 접근 가능 여부


class EdgePreprocessor:
    """
    엣지 데이터 전처리 클래스
    정밀한 경사도 계산 후 Supabase 저장
    """
    
    # 정밀 측정을 위한 설정
    SAMPLE_INTERVAL = 5.0  # 5m 간격으로 샘플링 (매우 정밀)
    API_DELAY = 0.1        # API 호출 간 딜레이 (초) - rate limit 방지
    BATCH_SIZE = 50        # Supabase 배치 저장 크기
    
    def __init__(self):
        self.supabase_url = os.getenv("SUPABASE_URL", "")
        self.supabase_key = os.getenv("SUPABASE_KEY", "")
        self.client = None
        self.edge_data_list: List[EdgeData] = []
        
        # 노면 패널티 맵
        self.surface_penalties = {
            'asphalt': 1.0,
            'paved': 1.0,
            'concrete': 1.0,
            'paving_stones': 1.2,
            'cobblestone': 1.5,
            'gravel': 1.8,
            'unpaved': 2.0,
            'ground': 2.0,
            'grass': 2.5,
            'sand': 3.0,
        }
        
        # 휠체어 통행 불가 도로 타입
        self.inaccessible_types = {'steps', 'escalator', 'construction'}
    
    def init_supabase(self) -> bool:
        """Supabase 클라이언트 초기화"""
        if not self.supabase_url or not self.supabase_key:
            logger.error("Supabase URL 또는 Key가 설정되지 않았습니다.")
            logger.error("'.env' 파일에 SUPABASE_URL과 SUPABASE_KEY를 설정하세요.")
            return False
        
        try:
            from supabase import create_client
            self.client = create_client(self.supabase_url, self.supabase_key)
            logger.info("Supabase 연결 성공")
            return True
        except Exception as e:
            logger.error(f"Supabase 연결 실패: {e}")
            return False
    
    def build_osm_graph(self):
        """OSM 그래프 생성"""
        from osm_parser import OSMGraphBuilder
        
        logger.info("OSM 그래프 생성 중...")
        builder = OSMGraphBuilder()
        graph = builder.build_graph_from_bbox()
        
        # 휠체어 접근 불가 구간은 필터링하지 않고, 대신 플래그로 표시
        # (나중에 참고용으로 사용)
        
        logger.info(f"그래프 생성 완료: {graph.number_of_nodes()}개 노드, {graph.number_of_edges()}개 엣지")
        return graph, builder
    
    def calculate_precise_elevation(
        self,
        start_lat: float, start_lon: float,
        end_lat: float, end_lon: float
    ) -> Dict:
        """
        정밀한 고도/경사도 계산
        5m 간격으로 샘플링하여 모든 굴곡 감지
        """
        from elevation_calculator import SlopeCalculator, OpenElevationProvider
        
        provider = OpenElevationProvider()
        calculator = SlopeCalculator(provider)
        
        # 샘플 포인트 생성 (5m 간격)
        points = calculator.sample_points_along_edge(
            start_lat, start_lon, end_lat, end_lon,
            sample_interval=self.SAMPLE_INTERVAL
        )
        
        if len(points) < 2:
            return {
                'grade': 0.0, 'max_grade': 0.0, 'min_grade': 0.0, 'avg_grade': 0.0,
                'grade_segments': 0,
                'elevation_start': 0.0, 'elevation_end': 0.0,
                'elevation_max': 0.0, 'elevation_min': 0.0,
                'total_ascent': 0.0, 'total_descent': 0.0
            }
        
        # 고도 조회
        elevations = provider.get_elevations(points)
        
        # API rate limit 방지
        time.sleep(self.API_DELAY)
        
        # 구간별 경사도 계산
        grades = []
        total_ascent = 0.0
        total_descent = 0.0
        
        for i in range(len(points) - 1):
            p1_lat, p1_lon = points[i]
            p2_lat, p2_lon = points[i + 1]
            e1 = elevations[i]
            e2 = elevations[i + 1]
            
            seg_dist = calculator.haversine_distance(p1_lat, p1_lon, p2_lat, p2_lon)
            
            if seg_dist > 0:
                import math
                height_diff = e2 - e1
                grade_deg = abs(math.degrees(math.atan(height_diff / seg_dist)))
                grades.append(grade_deg)
                
                if height_diff > 0:
                    total_ascent += height_diff
                else:
                    total_descent += abs(height_diff)
        
        if not grades:
            grades = [0.0]
        
        return {
            'grade': max(grades),  # 대표값 = 최대 경사도 (안전 기준)
            'max_grade': max(grades),
            'min_grade': min(grades),
            'avg_grade': sum(grades) / len(grades),
            'grade_segments': len(grades),
            'elevation_start': elevations[0] if elevations else 0.0,
            'elevation_end': elevations[-1] if elevations else 0.0,
            'elevation_max': max(elevations) if elevations else 0.0,
            'elevation_min': min(elevations) if elevations else 0.0,
            'total_ascent': total_ascent,
            'total_descent': total_descent
        }
    
    def process_all_edges(self, graph) -> List[EdgeData]:
        """모든 엣지 처리"""
        total = graph.number_of_edges()
        processed = 0
        failed = 0
        
        logger.info(f"=== 엣지 전처리 시작: 총 {total}개 ===")
        logger.info(f"샘플링 간격: {self.SAMPLE_INTERVAL}m (정밀 모드)")
        
        start_time = time.time()
        
        for u, v, key, data in graph.edges(keys=True, data=True):
            try:
                # 노드 좌표
                u_data = graph.nodes[u]
                v_data = graph.nodes[v]
                
                start_lat = u_data.get('y', 0)
                start_lon = u_data.get('x', 0)
                end_lat = v_data.get('y', 0)
                end_lon = v_data.get('x', 0)
                
                # 경사도 계산
                elev_data = self.calculate_precise_elevation(
                    start_lat, start_lon, end_lat, end_lon
                )
                
                # 도로 타입
                highway = data.get('highway', 'unknown')
                if isinstance(highway, list):
                    highway = highway[0]
                
                # 노면 타입
                surface = data.get('surface', 'paved')
                if isinstance(surface, list):
                    surface = surface[0]
                
                # 휠체어 접근성 체크
                is_accessible = True
                if highway in self.inaccessible_types:
                    is_accessible = False
                if data.get('stairs') == 'yes':
                    is_accessible = False
                if data.get('wheelchair') in ['no', 'limited']:
                    is_accessible = False
                
                # EdgeData 생성
                edge_data = EdgeData(
                    edge_id=f"{u}_{v}_{key}",
                    start_node_id=u,
                    end_node_id=v,
                    start_lat=start_lat,
                    start_lon=start_lon,
                    end_lat=end_lat,
                    end_lon=end_lon,
                    length=data.get('length', 0),
                    grade=elev_data['grade'],
                    max_grade=elev_data['max_grade'],
                    min_grade=elev_data['min_grade'],
                    avg_grade=elev_data['avg_grade'],
                    grade_segments=elev_data['grade_segments'],
                    elevation_start=elev_data['elevation_start'],
                    elevation_end=elev_data['elevation_end'],
                    elevation_max=elev_data['elevation_max'],
                    elevation_min=elev_data['elevation_min'],
                    total_ascent=elev_data['total_ascent'],
                    total_descent=elev_data['total_descent'],
                    surface_type=surface,
                    surface_penalty=self.surface_penalties.get(surface, 1.3),
                    highway_type=highway,
                    is_wheelchair_accessible=is_accessible
                )
                
                self.edge_data_list.append(edge_data)
                processed += 1
                
                # 진행 상황 출력
                if processed % 10 == 0:
                    elapsed = time.time() - start_time
                    rate = processed / elapsed if elapsed > 0 else 0
                    eta = (total - processed) / rate if rate > 0 else 0
                    logger.info(
                        f"진행: {processed}/{total} ({processed*100//total}%) | "
                        f"속도: {rate:.1f}개/초 | 남은 시간: {eta/60:.1f}분"
                    )
                    
            except Exception as e:
                logger.warning(f"엣지 처리 실패 ({u}-{v}): {e}")
                failed += 1
        
        elapsed = time.time() - start_time
        logger.info(f"=== 전처리 완료 ===")
        logger.info(f"성공: {processed}개, 실패: {failed}개")
        logger.info(f"소요 시간: {elapsed/60:.1f}분")
        
        return self.edge_data_list
    
    def save_to_supabase(self, edge_data_list: List[EdgeData]) -> bool:
        """Supabase에 저장"""
        if not self.client:
            logger.error("Supabase 클라이언트가 초기화되지 않았습니다.")
            return False
        
        logger.info(f"Supabase에 {len(edge_data_list)}개 엣지 데이터 저장 중...")
        
        try:
            # 기존 데이터 삭제 (덮어쓰기)
            logger.info("기존 데이터 삭제 중...")
            self.client.table("edges").delete().neq("id", 0).execute()
            
            # 배치 저장
            total = len(edge_data_list)
            saved = 0
            
            for i in range(0, total, self.BATCH_SIZE):
                batch = edge_data_list[i:i + self.BATCH_SIZE]
                batch_dicts = [asdict(e) for e in batch]
                
                self.client.table("edges").insert(batch_dicts).execute()
                saved += len(batch)
                logger.info(f"저장 진행: {saved}/{total}")
            
            logger.info(f"Supabase 저장 완료: {saved}개 엣지")
            return True
            
        except Exception as e:
            logger.error(f"Supabase 저장 실패: {e}")
            return False
    
    def save_to_json(self, edge_data_list: List[EdgeData], filepath: str = "edges_data.json"):
        """로컬 JSON 파일로 저장 (백업용)"""
        logger.info(f"로컬 파일로 저장: {filepath}")
        
        data = [asdict(e) for e in edge_data_list]
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        
        logger.info(f"JSON 저장 완료: {len(data)}개 엣지")
    
    def run(self, save_to_db: bool = True, save_to_file: bool = True):
        """전체 전처리 파이프라인 실행"""
        logger.info("=" * 50)
        logger.info("엣지 데이터 전처리 시작")
        logger.info("=" * 50)
        
        # 1. OSM 그래프 생성
        graph, builder = self.build_osm_graph()
        
        # 2. 모든 엣지 처리
        edge_data_list = self.process_all_edges(graph)
        
        # 3. JSON 파일로 저장 (백업)
        if save_to_file:
            self.save_to_json(edge_data_list)
        
        # 4. Supabase에 저장
        if save_to_db:
            if self.init_supabase():
                self.save_to_supabase(edge_data_list)
            else:
                logger.warning("Supabase 저장 건너뜀 (연결 실패)")
        
        logger.info("=" * 50)
        logger.info("전처리 완료!")
        logger.info("=" * 50)
        
        return edge_data_list


def main():
    """메인 함수"""
    import argparse
    
    parser = argparse.ArgumentParser(description="엣지 데이터 전처리")
    parser.add_argument("--no-db", action="store_true", help="Supabase 저장 건너뜀")
    parser.add_argument("--no-file", action="store_true", help="JSON 파일 저장 건너뜀")
    args = parser.parse_args()
    
    preprocessor = EdgePreprocessor()
    preprocessor.run(
        save_to_db=not args.no_db,
        save_to_file=not args.no_file
    )


if __name__ == "__main__":
    main()
