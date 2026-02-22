"""
휠체어 내비게이션 '길벗' - FastAPI 메인 서버
OSM 기반 경로 탐색 + 실시간 장애물 반영
"""
# 실행 방법:
# python -m uvicorn main_server:app --host 0.0.0.0 --port 8000 --reload
# 그래프 확인용 
# http://localhost:8000/graph
# 경로 확인용 
# http://localhost:8000/viewer

from fastapi import FastAPI, HTTPException, Request, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, HTMLResponse
from pydantic import BaseModel, Field
from typing import Optional, Literal, List, Tuple
import logging
import os
from pathlib import Path
from dotenv import load_dotenv

# .env 파일 로드
load_dotenv()

# 내부 모듈
from osm_parser import OSMGraphBuilder, KOREA_TECH_LAT, KOREA_TECH_LON, JEONGWANG_STATION_LAT, JEONGWANG_STATION_LON
from route_algorithm import RouteCalculator, RouteResult, WheelchairType
from obstacle_manager import ObstacleManager, Obstacle
from edge_data_loader import EdgeDataLoader
from dataclasses import asdict

# 라우터 임포트
from routers import report_router

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# FastAPI 앱 초기화
app = FastAPI(
    title="길벗 - 휠체어 내비게이션 API",
    description="OSM 기반 휠체어 전용 경로 탐색 시스템",
    version="0.1.0"
)

# 정적 파일 마운트 (이미지 제공용)
app.mount("/static", StaticFiles(directory="static"), name="static")

# 라우터 등록
app.include_router(report_router.router)

# CORS 설정 (Flutter 앱 연동용)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 전역 변수로 그래프 및 매니저 관리
graph_builder: Optional[OSMGraphBuilder] = None
route_calculator: Optional[RouteCalculator] = None  
obstacle_manager: Optional[ObstacleManager] = None
is_initialized = False
edge_data_source: str = "none"  # 경사도 데이터 소스: "database", "json", "none"

# Supabase 클라이언트 (report_router의 Storage 업로드에 공유)
try:
    from supabase import create_client as _create_supabase_client
    HAS_SUPABASE = True
except ImportError:
    HAS_SUPABASE = False


# ===== Pydantic 모델 =====

class RouteRequest(BaseModel):
    """경로 요청 모델"""
    start_lat: float = Field(..., description="출발점 위도", example=37.3401)
    start_lon: float = Field(..., description="출발점 경도", example=126.7315)
    end_lat: float = Field(..., description="도착점 위도", example=37.35166)
    end_lon: float = Field(..., description="도착점 경도", example=126.74279)
    mode: Literal["short", "safe", "optimal"] = Field(
        default="optimal",
        description="경로 모드: short(최단), safe(안전), optimal(최적)"
    )
    wheelchair_type: Literal["electric", "manual", "manual_with_helper", "none"] = Field(
        default="manual",
        description="휠체어 유형: electric(전동), manual(수동), manual_with_helper(수동+보호자), none(미사용)"
    )


class RouteResponse(BaseModel):
    """경로 응답 모델"""
    success: bool
    message: str
    route: Optional[dict] = None


class ObstacleRequest(BaseModel):
    """장애물 등록 요청 모델"""
    latitude: float = Field(..., description="위도")
    longitude: float = Field(..., description="경도")
    obstacle_type: str = Field(default="obstacle", description="장애물 유형")
    description: str = Field(default="", description="설명")
    radius: float = Field(default=15.0, description="영향 반경 (미터)")


class TestMsg(BaseModel):
    """테스트 메시지 모델"""
    message: str


# ===== 초기화 함수 =====

def initialize_system():
    """시스템 초기화 - 그래프 로드 및 설정"""
    global graph_builder, route_calculator, obstacle_manager, is_initialized, edge_data_source
    
    if is_initialized:
        return True
    
    try:
        logger.info("=== 시스템 초기화 시작 ===")
        
        # 환경변수 로드
        supabase_url = os.getenv("SUPABASE_URL", "")
        supabase_key = os.getenv("SUPABASE_KEY", "")
        
        # 1. OSM 그래프 빌더 초기화
        graph_builder = OSMGraphBuilder()
        
        # 2. 바운딩 박스 범위로 그래프 생성
        logger.info("OSM 그래프 생성 중 (바운딩 박스 범위)...")
        graph = graph_builder.build_graph_from_bbox()
        
        # 3. 휠체어 접근 불가 구간 필터링
        graph = graph_builder.filter_wheelchair_accessible(graph)
        
        # 4. 엣지 가중치 추가 (기본값)
        graph = graph_builder.add_edge_weights(graph)
        
        # 5. 사전 계산된 경사도 데이터 로드 (DB 또는 JSON)
        # 이 방식이 실시간 API 호출보다 훨씬 빠릅니다
        use_precomputed = os.getenv("USE_PRECOMPUTED_EDGES", "true").lower() == "true"
        
        if use_precomputed:
            logger.info("사전 계산된 경사도 데이터 로드 중...")
            try:
                from edge_data_loader import EdgeDataLoader
                
                edge_loader = EdgeDataLoader(supabase_url, supabase_key)
                edges = edge_loader.load(
                    prefer_db=True,  # DB 우선, 실패 시 JSON
                    json_path="edges_data.json"
                )
                
                if edges:
                    graph, applied = edge_loader.apply_to_graph(graph)
                    edge_data_source = edge_loader.last_source  # 데이터 소스 저장
                    logger.info(f"사전 계산된 경사도 데이터 적용: {applied}개 엣지 (소스: {edge_data_source})")
                else:
                    edge_data_source = "none"
                    logger.warning("사전 계산된 데이터 없음. 먼저 preprocess_edges.py 실행 필요")
                    logger.info("기본 경사도(0)를 사용합니다.")
                    
            except ImportError:
                logger.warning("edge_data_loader 모듈을 찾을 수 없습니다.")
            except Exception as e:
                logger.warning(f"사전 계산 데이터 로드 실패: {e}")
        else:
            # 실시간 DEM 계산 (비활성화됨, 전처리 방식 권장)
            use_dem = os.getenv("USE_DEM_ELEVATION", "false").lower() == "true"
            if use_dem:
                sample_interval = float(os.getenv("DEM_SAMPLE_INTERVAL", "10"))
                logger.info(f"실시간 DEM 경사도 계산 (샘플링 간격: {sample_interval}m)")
                try:
                    graph = graph_builder.add_elevation_data(graph, sample_interval, use_api=True)
                except Exception as e:
                    logger.warning(f"DEM 경사도 계산 실패: {e}")
        
        # 6. 경로 계산기 초기화
        route_calculator = RouteCalculator(graph)
        
        # 7. 장애물 관리자 초기화
        obstacle_manager = ObstacleManager(supabase_url, supabase_key)
        
        # 8. Supabase에서 장애물 로드 (연결된 경우)
        if supabase_url and supabase_key:
            obstacle_manager.fetch_obstacles()
            obstacle_manager.apply_obstacles_to_graph(graph)
        
        # 앱 상태에 저장 (라우터에서 접근 가능하도록)
        app.state.graph_builder = graph_builder
        app.state.route_calculator = route_calculator
        app.state.obstacle_manager = obstacle_manager

        # Supabase 클라이언트 공유 (report_router: Storage 업로드 + obstacles insert)
        # service_role 키가 있으면 사용 → Storage RLS 통과로 업로드 실패 방지, 다른 사용자에게도 이미지 표시 가능
        supabase_service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        report_key = supabase_service_key if supabase_service_key else supabase_key
        if HAS_SUPABASE and supabase_url and report_key:
            try:
                app.state.supabase_client = _create_supabase_client(supabase_url, report_key)
                logger.info(
                    "Supabase 클라이언트 초기화 완료 (report: %s)",
                    "service_role" if supabase_service_key else "anon",
                )
            except Exception as _sc_e:
                logger.warning("Supabase 클라이언트 초기화 실패: %s", _sc_e)
                app.state.supabase_client = None
        else:
            app.state.supabase_client = None
        
        is_initialized = True
        logger.info("=== 시스템 초기화 완료 ===")
        return True
        
    except Exception as e:
        logger.error(f"시스템 초기화 실패: {e}")
        return False


# ===== API 엔드포인트 =====

@app.on_event("startup")
async def startup_event():
    """서버 시작 시 초기화"""
    logger.info("서버 시작 중... 시스템 초기화를 수행합니다.")
    # 즉시 초기화 수행 (라우터들이 의존하는 객체들을 준비하기 위함)
    if not initialize_system():
        logger.error("시스템 초기화 실패")
    else:
        logger.info("시스템 초기화 완료")


@app.get("/")
async def root():
    """루트 - 카카오맵 경로 뷰어로 리다이렉트"""
    """루트 - 카카오맵 경로 뷰어로 리다이렉트"""
    with open("route_viewer_kakao.html", "r", encoding="utf-8") as f:
        content = f.read()
    
    # API 키 주입
    kakao_key = os.getenv("KAKAO_JAVASCRIPT_KEY", "")
    content = content.replace("__KAKAO_KEY__", kakao_key)
    
    return HTMLResponse(content=content)


@app.get("/viewer")
async def route_viewer():
    """경로 뷰어 (Kakao Maps)"""
    """경로 뷰어 (Kakao Maps)"""
    with open("route_viewer_kakao.html", "r", encoding="utf-8") as f:
        content = f.read()
    
    # API 키 주입
    kakao_key = os.getenv("KAKAO_JAVASCRIPT_KEY", "")
    content = content.replace("__KAKAO_KEY__", kakao_key)
    
    return HTMLResponse(content=content)


@app.get("/graph")
async def graph_viewer():
    """전체 그래프 뷰어 (Kakao Maps)"""
    with open("graph_viewer.html", "r", encoding="utf-8") as f:
        content = f.read()
    
    # API 키 주입
    kakao_key = os.getenv("KAKAO_JAVASCRIPT_KEY", "")
    content = content.replace("__KAKAO_KEY__", kakao_key)
    
    return HTMLResponse(content=content)


@app.get("/edges_data.json")
async def edges_data():
    """엣지 데이터 JSON - DB 우선, JSON 폴백"""
    try:
        loader = EdgeDataLoader()
        edges_map = loader.load(prefer_db=True)
        
        result = [asdict(edge) for edge in edges_map.values()]
        return result
    except Exception as e:
        logger.error(f"엣지 데이터 로드 실패: {e}")
        return []


@app.get("/api/edges")
async def get_edges_from_db():
    """엣지 데이터 API - DB(Supabase)에서 직접 조회 (실패시 에러 반환)"""
    try:
        loader = EdgeDataLoader()
        
        # Supabase DB에서만 조회 시도
        edges_map = loader.load_from_supabase()
        
        if edges_map:
            result = [asdict(edge) for edge in edges_map.values()]
            return {
                "success": True,
                "source": "database",
                "count": len(result),
                "edges": result
            }
        else:
            # DB에서 데이터를 못 가져온 경우
            return {
                "success": False,
                "source": "none",
                "message": "DB에서 데이터를 가져올 수 없습니다",
                "edges": []
            }
    except Exception as e:
        logger.error(f"DB 엣지 데이터 조회 실패: {e}")
        return {
            "success": False,
            "source": "error",
            "message": str(e),
            "edges": []
        }


@app.get("/api")
async def api_info():
    """API 정보"""
    return {
        "service": "길벗 - 휠체어 내비게이션 API",
        "version": "0.1.0",
        "status": "running",
        "initialized": is_initialized,
        "viewers": {
            "kakao": "/viewer",
            "osm": "/viewer/osm",
            "graph": "/graph"
        }
    }


@app.get("/health")
async def health_check():
    """헬스 체크"""
    return {"status": "healthy", "initialized": is_initialized}


@app.post("/initialize")
async def initialize():
    """시스템 수동 초기화"""
    success = initialize_system()
    if success:
        return {"status": "success", "message": "시스템 초기화 완료"}
    else:
        raise HTTPException(status_code=500, detail="시스템 초기화 실패")


@app.post("/route", response_model=RouteResponse)
async def find_route(request: RouteRequest):
    """
    경로 탐색 
    
    3가지 모드 지원:
    - short: 최단 거리 (약간의 불편함 허용)
    - safe: 안전 우선 (경사도/노면 민감)
    - optimal: 균형 잡힌 최적 경로
    
    모든 모드에서 장애물 구간은 완전히 회피됩니다.
    """
    global is_initialized
    
    # 지연 초기화
    if not is_initialized:
        logger.info("첫 요청으로 시스템 초기화 시작...")
        if not initialize_system():
            raise HTTPException(status_code=500, detail="시스템 초기화 실패")
    
    try:
        # 경로 탐색 (모드 + 휠체어 유형 적용)
        result: RouteResult = route_calculator.find_route(
            start_lat=request.start_lat,
            start_lon=request.start_lon,
            end_lat=request.end_lat,
            end_lon=request.end_lon,
            mode=request.mode,
            wheelchair_type=request.wheelchair_type
        )
        
        if result.success:
            return RouteResponse(
                success=True,
                message=result.message,
                route={
                    "distance": result.distance,
                    "estimated_time": result.estimated_time,
                    "geometry": result.geometry,
                    "instructions": result.instructions,
                    "avoided_obstacles": result.avoided_obstacles,
                    "mode": result.mode,
                    "wheelchair_type": request.wheelchair_type,
                    "total_weight": result.total_weight,
                    "edge_data_source": edge_data_source  # 경사도 데이터 소스
                }
            )
        else:
            return RouteResponse(
                success=False,
                message=result.message,
                route=None
            )
            
    except Exception as e:
        logger.error(f"경로 탐색 오류: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/route/compare")
async def compare_routes(request: RouteRequest):
    """
    3가지 모드 경로 비교 API
    동일한 출발/도착점에 대해 3가지 모드의 결과를 모두 반환
    """
    global is_initialized
    
    if not is_initialized:
        if not initialize_system():
            raise HTTPException(status_code=500, detail="시스템 초기화 실패")
    
    try:
        import osmnx as ox
        
        start_node = ox.distance.nearest_nodes(
            route_calculator.graph,
            request.start_lon,
            request.start_lat
        )
        end_node = ox.distance.nearest_nodes(
            route_calculator.graph,
            request.end_lon,
            request.end_lat
        )
        
        results = route_calculator.compare_routes(start_node, end_node, request.wheelchair_type)
        
        return {
            "success": True,
            "comparison": {
                mode: {
                    "success": result.success,
                    "distance": result.distance,
                    "estimated_time": result.estimated_time,
                    "geometry": result.geometry,
                    "instructions": result.instructions,
                    "avoided_obstacles": result.avoided_obstacles,
                    "total_weight": result.total_weight
                }
                for mode, result in results.items()
            }
        }
        
    except Exception as e:
        logger.error(f"경로 비교 오류: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/obstacle")
async def add_obstacle(request: ObstacleRequest):
    """
    장애물 수동 등록 API
    (실제로는 Supabase에 저장하고 그래프에 반영)
    """
    global is_initialized
    
    if not is_initialized:
        if not initialize_system():
            raise HTTPException(status_code=500, detail="시스템 초기화 실패")
    
    try:
        # 장애물 추가
        obstacle = obstacle_manager.add_obstacle_manually(
            latitude=request.latitude,
            longitude=request.longitude,
            obstacle_type=request.obstacle_type,
            description=request.description,
            radius=request.radius
        )
        
        # 그래프에 반영
        _, affected_count = obstacle_manager.apply_obstacles_to_graph(
            route_calculator.graph,
            [obstacle]
        )
        
        return {
            "success": True,
            "message": f"장애물 등록 완료. {affected_count}개 경로 구간에 영향",
            "obstacle_id": obstacle.id
        }
        
    except Exception as e:
        logger.error(f"장애물 등록 오류: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/obstacles")
async def get_obstacles():
    """등록된 장애물 목록 조회"""
    global is_initialized
    
    if not is_initialized:
        return {"obstacles": [], "count": 0}
    
    return {
        "obstacles": [
            {
                "id": obs.id,
                "latitude": obs.latitude,
                "longitude": obs.longitude,
                "type": obs.obstacle_type,
                "description": obs.description,
                "radius": obs.radius
            }
            for obs in obstacle_manager.obstacles
        ],
        "count": len(obstacle_manager.obstacles)
    }


@app.delete("/obstacles/clear")
async def clear_obstacles():
    """모든 장애물 가중치 초기화 (테스트용)"""
    global is_initialized
    
    if not is_initialized:
        return {"success": True, "message": "시스템이 초기화되지 않음"}
    
    obstacle_manager.obstacles.clear()
    obstacle_manager.clear_obstacles_from_graph(route_calculator.graph)
    
    return {"success": True, "message": "장애물 가중치 초기화 완료"}


@app.get("/graph/info")
async def get_graph_info():
    """그래프 정보 조회"""
    global is_initialized
    
    if not is_initialized:
        return {"initialized": False}
    
    return {
        "initialized": True,
        "nodes": route_calculator.graph.number_of_nodes(),
        "edges": route_calculator.graph.number_of_edges(),
        "bounds": {
            "korea_tech": {"lat": KOREA_TECH_LAT, "lon": KOREA_TECH_LON},
            "jeongwang_station": {"lat": JEONGWANG_STATION_LAT, "lon": JEONGWANG_STATION_LON}
        }
    }


@app.post("/test")
async def test_endpoint(msg: TestMsg):
    """테스트 엔드포인트 (기존 호환성)"""
    print(f"앱에서 받은 메시지: {msg.message}")
    return {"status": "success", "echo": msg.message}


# ===== 계정 삭제 =====
PROFILE_IMAGE_BUCKET = "profile_image"


def _get_supabase_admin_client():
    """계정 삭제용 Supabase Admin 클라이언트 (SUPABASE_SERVICE_ROLE_KEY 사용)"""
    url = os.getenv("SUPABASE_URL", "")
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
    if not url or not key:
        return None
    if not HAS_SUPABASE:
        return None
    try:
        return _create_supabase_client(url, key)
    except Exception as e:
        logger.warning("Supabase Admin 클라이언트 초기화 실패: %s", e)
        return None


def _storage_path_from_profile_image_url(url: str, bucket: str) -> Optional[str]:
    """
    profile_image_url에서 Storage 객체 경로 추출.
    예: https://xxx.supabase.co/storage/v1/object/public/profile_image/user_id/file.jpg
    -> user_id/file.jpg
    """
    if not url or bucket not in url:
        return None
    try:
        # .../profile_image/ 이후 부분이 객체 경로
        idx = url.find(f"/{bucket}/")
        if idx == -1:
            return None
        path = url[idx + len(f"/{bucket}/") :].strip()
        # 쿼리 스트링 제거
        if "?" in path:
            path = path.split("?")[0]
        return path if path else None
    except Exception:
        return None


@app.delete("/delete-account")
async def delete_account(authorization: Optional[str] = Header(None)):
    """
    로그인한 사용자 계정 삭제.
    - Authorization: Bearer <access_token> 필요
    - 장애물/댓글 익명 처리, 개인 데이터 삭제, user_profiles 삭제, 프로필 이미지 Storage 삭제, auth.users 삭제
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Authorization Bearer 토큰이 필요합니다")
    token = authorization[7:].strip()
    if not token:
        raise HTTPException(status_code=401, detail="토큰이 비어 있습니다")

    admin = _get_supabase_admin_client()
    if not admin:
        raise HTTPException(
            status_code=503,
            detail="계정 삭제 서비스를 사용할 수 없습니다. SUPABASE_SERVICE_ROLE_KEY를 확인하세요.",
        )

    try:
        # JWT 검증 및 user_id 조회
        user_response = admin.auth.get_user(jwt=token)
        user = user_response.user
        user_id = str(user.id)
    except Exception as e:
        logger.warning("delete-account: JWT 검증 실패: %s", e)
        raise HTTPException(status_code=401, detail="유효하지 않거나 만료된 토큰입니다")

    # 삭제 전 프로필 이미지 URL 조회 (user_profiles 삭제 후에는 못 가져옴)
    profile_image_url = None
    try:
        r = admin.table("user_profiles").select("profile_image_url").eq("user_id", user_id).execute()
        if r.data and len(r.data) > 0 and r.data[0].get("profile_image_url"):
            profile_image_url = r.data[0]["profile_image_url"]
    except Exception as e:
        logger.warning("delete-account: profile_image_url 조회 실패: %s", e)

    try:
        # 1) 장애물 익명 처리 (reported_by)
        admin.table("obstacles").update({"reported_by": None}).eq("reported_by", user_id).execute()

        # 2) 댓글 익명 처리 (user_id SET NULL)
        admin.table("comments").update({"user_id": None}).eq("user_id", user_id).execute()

        # 3) likes 삭제
        admin.table("likes").delete().eq("user_id", user_id).execute()

        # 4) 개인 데이터 삭제
        admin.table("drive_logs").delete().eq("user_id", user_id).execute()
        admin.table("favorites").delete().eq("user_id", user_id).execute()
        admin.table("recent_searches").delete().eq("user_id", user_id).execute()
        admin.table("edit_requests").delete().eq("requester_id", user_id).execute()
        admin.table("notifications").delete().eq("user_id", user_id).execute()

        # 5) user_profiles 삭제
        admin.table("user_profiles").delete().eq("user_id", user_id).execute()

        # 6) 프로필 이미지 Storage 삭제
        if profile_image_url:
            path = _storage_path_from_profile_image_url(profile_image_url, PROFILE_IMAGE_BUCKET)
            if path:
                try:
                    admin.storage.from_(PROFILE_IMAGE_BUCKET).remove([path])
                except Exception as storage_err:
                    logger.warning("delete-account: 프로필 이미지 Storage 삭제 실패: %s", storage_err)

        # 7) auth.users 삭제 (Supabase Admin API)
        admin.auth.admin.delete_user(user_id)

    except Exception as e:
        logger.exception("delete-account: 삭제 중 오류: %s", e)
        raise HTTPException(status_code=500, detail="계정 삭제 처리 중 오류가 발생했습니다")

    return {"success": True, "message": "계정이 삭제되었습니다"}


# ===== 서버 실행 =====
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)



