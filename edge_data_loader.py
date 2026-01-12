"""
엣지 데이터 로더 모듈
Supabase 또는 로컬 JSON에서 사전 계산된 엣지 데이터를 로드합니다.
"""

import os
import json
import logging
import networkx as nx
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class EdgeInfo:
    """엣지 정보 구조체"""
    edge_id: str
    start_node_id: int
    end_node_id: int
    start_lat: float
    start_lon: float
    end_lat: float
    end_lon: float
    length: float
    grade: float
    max_grade: float
    surface_penalty: float
    highway_type: str
    is_wheelchair_accessible: bool
    total_ascent: float = 0.0
    total_descent: float = 0.0


class EdgeDataLoader:
    """
    사전 계산된 엣지 데이터 로더
    Supabase DB 또는 로컬 JSON 파일에서 데이터 로드
    """
    
    def __init__(self, supabase_url: str = "", supabase_key: str = ""):
        self.supabase_url = supabase_url or os.getenv("SUPABASE_URL", "")
        self.supabase_key = supabase_key or os.getenv("SUPABASE_KEY", "")
        self.client = None
        self.edges_data: Dict[str, EdgeInfo] = {}
        self.last_source: str = "none"  # 데이터 소스 추적: "database", "json", "none"
        
        if self.supabase_url and self.supabase_key:
            self._init_supabase()
    
    def _init_supabase(self):
        """Supabase 클라이언트 초기화"""
        try:
            from supabase import create_client
            self.client = create_client(self.supabase_url, self.supabase_key)
            logger.info("Supabase 클라이언트 연결 성공")
        except ImportError:
            logger.warning("supabase 패키지가 없습니다. pip install supabase")
        except Exception as e:
            logger.error(f"Supabase 연결 실패: {e}")
    
    def load_from_supabase(self, table_name: str = "edges") -> Dict[str, EdgeInfo]:
        """
        Supabase에서 엣지 데이터 로드
        
        Returns:
            엣지 ID를 키로 하는 EdgeInfo 딕셔너리
        """
        if not self.client:
            logger.warning("Supabase 클라이언트가 없습니다.")
            return {}
        
        try:
            logger.info("Supabase에서 엣지 데이터 로드 중...")
            
            # 페이지네이션으로 전체 데이터 로드
            all_data = []
            page_size = 1000
            offset = 0
            
            while True:
                response = self.client.table(table_name).select("*").range(offset, offset + page_size - 1).execute()
                data = response.data
                
                if not data:
                    break
                
                all_data.extend(data)
                offset += page_size
                
                if len(data) < page_size:
                    break
            
            logger.info(f"Supabase에서 {len(all_data)}개 엣지 로드 완료")
            
            # EdgeInfo 변환
            for row in all_data:
                edge_info = EdgeInfo(
                    edge_id=row.get("edge_id", ""),
                    start_node_id=int(row.get("start_node_id", 0)),
                    end_node_id=int(row.get("end_node_id", 0)),
                    start_lat=float(row.get("start_lat", 0)),
                    start_lon=float(row.get("start_lon", 0)),
                    end_lat=float(row.get("end_lat", 0)),
                    end_lon=float(row.get("end_lon", 0)),
                    length=float(row.get("length", 0)),
                    grade=float(row.get("grade", 0)),
                    max_grade=float(row.get("max_grade", 0)),
                    surface_penalty=float(row.get("surface_penalty", 1.0)),
                    highway_type=row.get("highway_type", "unknown"),
                    is_wheelchair_accessible=row.get("is_wheelchair_accessible", True),
                    total_ascent=float(row.get("total_ascent", 0)),
                    total_descent=float(row.get("total_descent", 0))
                )
                self.edges_data[edge_info.edge_id] = edge_info
            
            self.last_source = "database"
            return self.edges_data
            
        except Exception as e:
            logger.error(f"Supabase 로드 실패: {e}")
            return {}
    
    def load_from_json(self, filepath: str = "edges_data.json") -> Dict[str, EdgeInfo]:
        """
        로컬 JSON 파일에서 엣지 데이터 로드
        
        Args:
            filepath: JSON 파일 경로
            
        Returns:
            엣지 ID를 키로 하는 EdgeInfo 딕셔너리
        """
        if not os.path.exists(filepath):
            logger.warning(f"파일이 존재하지 않습니다: {filepath}")
            return {}
        
        try:
            logger.info(f"JSON 파일에서 엣지 데이터 로드 중: {filepath}")
            
            with open(filepath, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            for row in data:
                edge_info = EdgeInfo(
                    edge_id=row.get("edge_id", ""),
                    start_node_id=int(row.get("start_node_id", 0)),
                    end_node_id=int(row.get("end_node_id", 0)),
                    start_lat=float(row.get("start_lat", 0)),
                    start_lon=float(row.get("start_lon", 0)),
                    end_lat=float(row.get("end_lat", 0)),
                    end_lon=float(row.get("end_lon", 0)),
                    length=float(row.get("length", 0)),
                    grade=float(row.get("grade", 0)),
                    max_grade=float(row.get("max_grade", 0)),
                    surface_penalty=float(row.get("surface_penalty", 1.0)),
                    highway_type=row.get("highway_type", "unknown"),
                    is_wheelchair_accessible=row.get("is_wheelchair_accessible", True),
                    total_ascent=float(row.get("total_ascent", 0)),
                    total_descent=float(row.get("total_descent", 0))
                )
                self.edges_data[edge_info.edge_id] = edge_info
            
            logger.info(f"JSON에서 {len(self.edges_data)}개 엣지 로드 완료")
            self.last_source = "json"
            return self.edges_data
            
        except Exception as e:
            logger.error(f"JSON 로드 실패: {e}")
            return {}
    
    def load(self, prefer_db: bool = True, json_path: str = "edges_data.json") -> Dict[str, EdgeInfo]:
        """
        엣지 데이터 로드 (DB 우선, 실패 시 JSON)
        
        Args:
            prefer_db: True면 DB 먼저 시도
            json_path: JSON 파일 경로
            
        Returns:
            엣지 데이터 딕셔너리
        """
        if prefer_db and self.client:
            edges = self.load_from_supabase()
            if edges:
                return edges
            logger.info("DB 로드 실패, JSON 파일로 폴백")
        
        return self.load_from_json(json_path)
    
    def apply_to_graph(self, graph: nx.MultiDiGraph) -> Tuple[nx.MultiDiGraph, int]:
        """
        로드된 엣지 데이터를 그래프에 적용
        
        Args:
            graph: NetworkX 그래프
            
        Returns:
            (수정된 그래프, 적용된 엣지 수)
        """
        if not self.edges_data:
            logger.warning("적용할 엣지 데이터가 없습니다.")
            return graph, 0
        
        applied = 0
        
        for u, v, key, data in graph.edges(keys=True, data=True):
            edge_id = f"{u}_{v}_{key}"
            
            if edge_id in self.edges_data:
                edge_info = self.edges_data[edge_id]
                
                # 경사도 데이터 적용
                data['grade'] = edge_info.grade
                data['max_grade'] = edge_info.max_grade
                data['surface_penalty'] = edge_info.surface_penalty
                data['is_wheelchair_accessible'] = edge_info.is_wheelchair_accessible
                data['total_ascent'] = edge_info.total_ascent
                data['total_descent'] = edge_info.total_descent
                data['grade_source'] = 'precomputed'
                
                applied += 1
        
        logger.info(f"그래프에 {applied}개 엣지 데이터 적용 완료")
        return graph, applied
    
    def get_edge_grade(self, start_node: int, end_node: int, key: int = 0) -> Optional[float]:
        """특정 엣지의 경사도 조회"""
        edge_id = f"{start_node}_{end_node}_{key}"
        edge_info = self.edges_data.get(edge_id)
        return edge_info.grade if edge_info else None


# 테스트
if __name__ == "__main__":
    from dotenv import load_dotenv
    load_dotenv()
    
    print("=== 엣지 데이터 로더 테스트 ===")
    
    loader = EdgeDataLoader()
    
    # JSON 로드 테스트
    edges = loader.load(prefer_db=False, json_path="edges_data.json")
    
    if edges:
        print(f"\n로드된 엣지 수: {len(edges)}")
        
        # 첫 5개 엣지 출력
        for i, (edge_id, info) in enumerate(list(edges.items())[:5]):
            print(f"\n엣지 {i+1}: {edge_id}")
            print(f"  경사도: {info.grade:.2f}° (최대: {info.max_grade:.2f}°)")
            print(f"  거리: {info.length:.1f}m")
            print(f"  휠체어 접근: {'가능' if info.is_wheelchair_accessible else '불가'}")
    else:
        print("엣지 데이터 없음. 먼저 preprocess_edges.py를 실행하세요.")
