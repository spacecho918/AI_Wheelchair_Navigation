"""
장애물 신고 및 AI 분석 라우터
"""

from fastapi import APIRouter, File, UploadFile, Form, HTTPException, BackgroundTasks, Request
from typing import Optional
import shutil
import os
import sys
from datetime import datetime
from pathlib import Path
import logging

# YOLO 모듈 경로 추가 (상위 디렉토리의 yolo 폴더)
sys.path.append(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "yolo"))

try:
    from yolo_detect import detect_image
    YOLO_AVAILABLE = True
except ImportError:
    logging.warning("YOLO 모듈을 찾을 수 없습니다. AI 분석 기능을 사용할 수 없습니다.")
    YOLO_AVAILABLE = False

from obstacle_manager import ObstacleManager
# from main_server import obstacle_manager, route_calculator, graph_builder  <-- Circular import removed

router = APIRouter(prefix="/report", tags=["report"])
logger = logging.getLogger(__name__)

# 이미지 저장 경로 설정
UPLOAD_DIR = Path("static/uploads")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

# YOLO 모델 경로
YOLO_MODEL_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "yolo", "Obstacle.pt")


@router.post("/analyze")
async def analyze_image(image: UploadFile = File(...)):
    """
    이미지를 업로드받아 YOLO로 장애물을 분석하고 결과를 반환합니다.
    """
    if not YOLO_AVAILABLE:
        raise HTTPException(status_code=503, detail="YOLO AI 모듈을 사용할 수 없습니다.")

    if not os.path.exists(YOLO_MODEL_PATH):
        raise HTTPException(status_code=500, detail=f"YOLO 모델 파일을 찾을 수 없습니다: {YOLO_MODEL_PATH}")

    # 1. 이미지 임시 저장
    temp_filename = f"temp_{datetime.now().strftime('%Y%m%d%H%M%S')}_{image.filename}"
    temp_path = UPLOAD_DIR / temp_filename
    
    try:
        with open(temp_path, "wb") as buffer:
            shutil.copyfileobj(image.file, buffer)
            
        # 2. YOLO 추론 실행
        # detect_image가 이제 구조화된 리스트를 반환함
        detections = detect_image(
            source=str(temp_path),
            model_path=YOLO_MODEL_PATH,
            conf=0.25, # 신뢰도 임계값
            save=False  # 분석용이므로 결과 이미지 저장은 스킵 (필요시 True)
        )
        
        # 3. 결과 정리
        # 가장 신뢰도가 높은 객체 하나를 추천하거나 리스트 전체 반환
        # 여기서는 가장 높은 신뢰도의 객체를 메인으로 반환하고 나머지는 리스트로
        
        best_detection = None
        if detections:
            # 신뢰도순 정렬
            detections.sort(key=lambda x: x['confidence'], reverse=True)
            best_detection = detections[0]['class']
            
        return {
            "success": True,
            "detected_type": best_detection,
            "all_detections": detections,
            "message": f"분석 완료: {best_detection if best_detection else '감지된 장애물 없음'}"
        }

    except Exception as e:
        logger.error(f"이미지 분석 실패: {e}")
        raise HTTPException(status_code=500, detail=f"이미지 분석 중 오류 발생: {str(e)}")
        
    finally:
        # 임시 파일 삭제
        if os.path.exists(temp_path):
            os.remove(temp_path)


@router.post("/submit")
async def submit_report(
    request: Request,
    latitude: float = Form(...),
    longitude: float = Form(...),
    obstacle_type: str = Form(...),
    description: str = Form(""),
    image: Optional[UploadFile] = File(None),
    address: Optional[str] = Form(None),
    reported_by: Optional[str] = Form(None),
    reporter_name: Optional[str] = Form(None)
):
    """
    장애물 신고를 접수합니다. 이미지는 선택사항입니다.
    데이터베이스에 저장하고, 실시간 그래프에 반영합니다.
    """
    # 앱 상태에서 글로벌 인스턴스 가져오기
    try:
        obstacle_manager = request.app.state.obstacle_manager
        route_calculator = request.app.state.route_calculator
    except AttributeError:
        raise HTTPException(status_code=503, detail="시스템이 초기화되지 않았습니다.")
    
    if obstacle_manager is None:
        raise HTTPException(status_code=503, detail="시스템이 초기화되지 않았습니다.")

    image_url = None
    
    # 1. 이미지 저장 (저장할 경우)
    if image:
        filename = f"{datetime.now().strftime('%Y%m%d%H%M%S')}_{image.filename}"
        file_path = UPLOAD_DIR / filename
        
        try:
            with open(file_path, "wb") as buffer:
                shutil.copyfileobj(image.file, buffer)
            
            # 접근 가능한 URL 생성 (실제 배포환경에선 도메인 필요, 여기선 상대 경로)
            # 클라이언트가 static으로 접근 가능한 경로
            image_url = f"/static/uploads/{filename}"
            
        except Exception as e:
            logger.error(f"이미지 저장 실패: {e}")
            # 이미지가 실패해도 텍스트 신고는 진행
    
    try:
        # 2. Supabase에 저장 (obstacle_manager 확장 필요)
        # 현재 obstacle_manager는 조회 위주이므로, 여기서 직접 insert하거나 manager에 메서드 추가
        # 여기서는 Manager에 로직이 있다고 가정하거나 직접 구현해야 함.
        # 일단 Manager에 add_manual_obstacle이 있으니 그걸 활용하되, DB 저장은 별도 로직 필요.
        
        # 2-1. 메모리 상 그래프 업데이트 (즉시 반영)
        new_obstacle = obstacle_manager.add_obstacle_manually(
            latitude=latitude,
            longitude=longitude,
            obstacle_type=obstacle_type,
            description=description,
            radius=15.0 # 기본 반경
        )
        
        # 2-2. 그래프에 장애물 가중치 적용
        count = 0
        if route_calculator and route_calculator.graph:
            _, count = obstacle_manager.apply_obstacles_to_graph(
                route_calculator.graph, 
                [new_obstacle]
            )

        # 2-3. DB 저장 (Supabase)
        # 메타데이터를 description에 추가 (getCommunityReports에서 파싱함)
        full_description = ""
        if address:
            full_description += f"[Location: {address}]\n"
        if reporter_name:
            full_description += f"[User: {reporter_name}]\n"
        full_description += description

        if obstacle_manager.client:
            data = {
                "latitude": latitude,
                "longitude": longitude,
                "obstacle_type": obstacle_type,
                "description": full_description,
                "image_url": image_url,
                "is_active": True,
                "radius": 15.0,
                "severity": "high",
                "reported_by": reported_by
            }
            # Supabase Insert
            try:
                res = obstacle_manager.client.table("obstacles").insert(data).execute()
                # 생성된 ID 업데이트 등
            except Exception as db_e:
                logger.error(f"DB 저장 실패: {db_e}")
                # DB 저장이 실패해도 메모리엔 반영됨

        return {
            "success": True,
            "message": f"신고가 접수되었습니다. {count}개 경로가 즉시 차단되었습니다.",
            "obstacle_id": new_obstacle.id,
            "image_url": image_url
        }

    except Exception as e:
        logger.error(f"신고 접수 실패: {e}")
        raise HTTPException(status_code=500, detail=str(e))
