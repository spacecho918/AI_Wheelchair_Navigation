"""
장애물 신고 및 AI 분석 라우터 (개선판)

흐름
----
1. POST /report/analyze
   - 이미지를 받아 Obstacle.pt로 장애물 감지
   - bbox가 그려진 이미지(base64)와 감지 목록을 앱에 반환
   - 앱이 해당 이미지를 보여주며 사용자에게 장애물 유형 확인

2. POST /report/submit
   - 이미지를 받아 Personal-Info.pt로 얼굴·번호판 블러 처리
   - 블러된 이미지를 Supabase Storage에 업로드
   - 블러 이미지 URL로 obstacles DB에 insert
   - 메모리 그래프에 장애물 즉시 반영
"""

from __future__ import annotations

import base64
import io
import logging
import os
import uuid
from datetime import datetime
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, BackgroundTasks, File, Form, HTTPException, Request, UploadFile
from dotenv import load_dotenv

load_dotenv()

# yolo_service는 algorithm_server/ 안에 있으므로 직접 import
try:
    from yolo_service import analyze_obstacle, blur_privacy
    YOLO_AVAILABLE = True
except ImportError as _e:
    logging.warning("yolo_service를 불러올 수 없습니다: %s", _e)
    YOLO_AVAILABLE = False

from obstacle_manager import ObstacleManager

router = APIRouter(prefix="/report", tags=["report"])
logger = logging.getLogger(__name__)

# 로컬 임시 저장 경로 (서버 static용)
UPLOAD_DIR = Path("static/uploads")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

# Supabase Storage 버킷 이름
STORAGE_BUCKET = "obstacle-images"


# ─────────────────────────────────────────────────────────────────────────────
# 헬퍼: Supabase Storage 업로드
# ─────────────────────────────────────────────────────────────────────────────

def _upload_to_supabase_storage(
    client,
    image_bytes: bytes,
    filename: str,
) -> Optional[str]:
    """
    image_bytes를 Supabase Storage STORAGE_BUCKET에 업로드하고
    공개 URL을 반환합니다. 실패하면 None.
    """
    try:
        client.storage.from_(STORAGE_BUCKET).upload(
            path=filename,
            file=image_bytes,
            file_options={"content-type": "image/jpeg", "upsert": "true"},
        )
        public_url = client.storage.from_(STORAGE_BUCKET).get_public_url(filename)
        return public_url
    except Exception as exc:
        logger.error("Supabase Storage 업로드 실패: %s", exc)
        return None


# ─────────────────────────────────────────────────────────────────────────────
# 1. POST /report/analyze
# ─────────────────────────────────────────────────────────────────────────────

@router.post("/analyze")
async def analyze_image(image: UploadFile = File(...)):
    """
    이미지를 받아 장애물을 감지합니다.

    Response
    --------
    {
        "success": true,
        "annotated_image": "<base64 JPEG>",   // bbox가 그려진 이미지
        "detections": [
            {"class": "stairs", "confidence": 0.87, "box": [x1,y1,x2,y2]},
            ...
        ],
        "detected_type": "stairs",   // 가장 신뢰도가 높은 클래스 (없으면 null)
        "message": "분석 완료: stairs"
    }
    """
    if not YOLO_AVAILABLE:
        raise HTTPException(status_code=503, detail="YOLO AI 모듈을 사용할 수 없습니다.")

    image_bytes = await image.read()

    try:
        annotated_bytes, detections = analyze_obstacle(image_bytes)
    except Exception as exc:
        logger.error("이미지 분석 실패: %s", exc)
        raise HTTPException(status_code=500, detail=f"이미지 분석 중 오류: {exc}")

    annotated_b64   = base64.b64encode(annotated_bytes).decode("utf-8")
    best_class      = detections[0]["class"] if detections else None

    return {
        "success":         True,
        "annotated_image": annotated_b64,
        "detections":      detections,
        "detected_type":   best_class,
        "message":         f"분석 완료: {best_class if best_class else '감지된 장애물 없음'}",
    }


# ─────────────────────────────────────────────────────────────────────────────
# 2. POST /report/submit
# ─────────────────────────────────────────────────────────────────────────────

@router.post("/submit")
async def submit_report(
    request:       Request,
    latitude:      float           = Form(...),
    longitude:     float           = Form(...),
    obstacle_type: str             = Form(...),
    description:   str             = Form(""),
    image:         Optional[UploadFile] = File(None),
    address:       Optional[str]   = Form(None),
    reported_by:   Optional[str]   = Form(None),
    reporter_name: Optional[str]   = Form(None),
):
    """
    장애물 제보를 접수합니다.

    이미지가 첨부된 경우
    --------------------
    1. Personal-Info.pt로 얼굴·번호판 블러 처리
    2. 블러된 이미지를 Supabase Storage에 업로드
    3. 블러 이미지 공개 URL을 DB에 저장

    Response
    --------
    {
        "success": true,
        "message": "신고 접수 완료. 3개 경로가 즉시 차단되었습니다.",
        "obstacle_id": "...",
        "image_url": "https://...supabase.../blurred_..."
    }
    """
    # ── 앱 상태에서 글로벌 인스턴스 가져오기 ────────────────────────────────
    try:
        obstacle_manager  = request.app.state.obstacle_manager
        route_calculator  = request.app.state.route_calculator
        supabase_client   = request.app.state.supabase_client
    except AttributeError:
        raise HTTPException(status_code=503, detail="시스템이 초기화되지 않았습니다.")

    if obstacle_manager is None:
        raise HTTPException(status_code=503, detail="시스템이 초기화되지 않았습니다.")

    image_url: Optional[str] = None

    # ── 이미지 처리 ─────────────────────────────────────────────────────────
    if image:
        raw_bytes = await image.read()

        # 1) 블러 처리
        if YOLO_AVAILABLE:
            try:
                blurred_bytes = blur_privacy(raw_bytes)
                logger.info("블러 처리 완료 (원본 %d B → 블러 %d B)", len(raw_bytes), len(blurred_bytes))
            except Exception as exc:
                logger.warning("블러 처리 실패, 원본 이미지 사용: %s", exc)
                blurred_bytes = raw_bytes
        else:
            logger.warning("YOLO 불가 — 원본 이미지 그대로 사용")
            blurred_bytes = raw_bytes

        # 2) Supabase Storage 업로드
        timestamp  = datetime.now().strftime("%Y%m%d_%H%M%S")
        unique_id  = uuid.uuid4().hex[:8]
        safe_name  = Path(image.filename or "photo.jpg").stem
        filename   = f"blurred_{timestamp}_{unique_id}_{safe_name}.jpg"

        if supabase_client:
            image_url = _upload_to_supabase_storage(supabase_client, blurred_bytes, filename)

        # Supabase Storage 업로드 실패 시 로컬 static에 폴백
        if not image_url:
            local_path = UPLOAD_DIR / filename
            local_path.write_bytes(blurred_bytes)
            image_url  = f"/static/uploads/{filename}"
            logger.warning("Supabase Storage 업로드 실패, 로컬 저장: %s", local_path)

    # ── 메모리 그래프 업데이트 ───────────────────────────────────────────────
    try:
        new_obstacle = obstacle_manager.add_obstacle_manually(
            latitude=latitude,
            longitude=longitude,
            obstacle_type=obstacle_type,
            description=description,
            radius=15.0,
        )

        blocked_count = 0
        if route_calculator and route_calculator.graph:
            _, blocked_count = obstacle_manager.apply_obstacles_to_graph(
                route_calculator.graph,
                [new_obstacle],
            )

        # ── Supabase DB Insert ───────────────────────────────────────────────
        full_description = ""
        if address:
            full_description += f"[Location: {address}]\n"
        if reporter_name:
            full_description += f"[User: {reporter_name}]\n"
        full_description += description

        if supabase_client:
            db_data = {
                "latitude":      latitude,
                "longitude":     longitude,
                "obstacle_type": obstacle_type,
                "description":   full_description,
                "image_url":     image_url,
                "is_active":     True,
                "radius":        15.0,
                "severity":      "high",
                "reported_by":   reported_by,
            }
            try:
                supabase_client.table("obstacles").insert(db_data).execute()
            except Exception as db_exc:
                logger.error("DB 저장 실패: %s", db_exc)
        elif obstacle_manager.client:
            # obstacle_manager가 직접 supabase client를 가진 경우 폴백
            db_data = {
                "latitude":      latitude,
                "longitude":     longitude,
                "obstacle_type": obstacle_type,
                "description":   full_description,
                "image_url":     image_url,
                "is_active":     True,
                "radius":        15.0,
                "severity":      "high",
                "reported_by":   reported_by,
            }
            try:
                obstacle_manager.client.table("obstacles").insert(db_data).execute()
            except Exception as db_exc:
                logger.error("DB 저장 실패 (fallback): %s", db_exc)

        return {
            "success":     True,
            "message":     f"신고가 접수되었습니다. {blocked_count}개 경로가 즉시 차단되었습니다.",
            "obstacle_id": new_obstacle.id,
            "image_url":   image_url,
        }

    except Exception as exc:
        logger.error("신고 접수 실패: %s", exc)
        raise HTTPException(status_code=500, detail=str(exc))
