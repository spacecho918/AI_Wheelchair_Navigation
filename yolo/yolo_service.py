"""
yolo_service.py - 길벗 서버 전용 YOLO 서비스 모듈

두 YOLO 모델을 프로세스당 한 번만 로드(싱글톤)하여 재사용합니다.

주요 기능
---------
analyze_obstacle(image_bytes)
    Obstacle.pt로 장애물을 감지하고, bbox가 그려진 주석 이미지(JPEG bytes)와
    감지 목록(List[dict])을 반환합니다.

blur_privacy(image_bytes)
    Personal-Info.pt로 얼굴·번호판을 감지한 뒤 GaussianBlur를 적용한
    이미지(JPEG bytes)를 반환합니다.
"""

from __future__ import annotations

import logging
import os
from pathlib import Path
from typing import Optional

import cv2
import numpy as np

logger = logging.getLogger(__name__)

# ───────────────────────────────────────────────
# 모델 파일 경로 (이 파일과 같은 디렉터리 기준)
# ───────────────────────────────────────────────
_HERE = Path(__file__).parent
OBSTACLE_MODEL_PATH = str(_HERE / "Obstacle.pt")
PRIVACY_MODEL_PATH  = str(_HERE / "Personal-Info.pt")

# ───────────────────────────────────────────────
# 싱글톤 모델 (None이면 아직 로드 안 됨)
# ───────────────────────────────────────────────
_obstacle_model = None
_privacy_model  = None


def _get_obstacle_model():
    """Obstacle.pt 모델을 한 번만 로드하여 반환."""
    global _obstacle_model
    if _obstacle_model is None:
        from ultralytics import YOLO
        logger.info("Obstacle 모델 로드 중: %s", OBSTACLE_MODEL_PATH)
        _obstacle_model = YOLO(OBSTACLE_MODEL_PATH)
        logger.info("Obstacle 모델 로드 완료")
    return _obstacle_model


def _get_privacy_model():
    """Personal-Info.pt 모델을 한 번만 로드하여 반환."""
    global _privacy_model
    if _privacy_model is None:
        from ultralytics import YOLO
        logger.info("Privacy 모델 로드 중: %s", PRIVACY_MODEL_PATH)
        _privacy_model = YOLO(PRIVACY_MODEL_PATH)
        logger.info("Privacy 모델 로드 완료")
    return _privacy_model


def _bytes_to_bgr(image_bytes: bytes) -> np.ndarray:
    """bytes → OpenCV BGR ndarray 변환."""
    arr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError("이미지를 디코딩할 수 없습니다.")
    return img


def _bgr_to_jpeg(img: np.ndarray, quality: int = 90) -> bytes:
    """OpenCV BGR ndarray → JPEG bytes 변환."""
    ok, buf = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, quality])
    if not ok:
        raise RuntimeError("JPEG 인코딩 실패")
    return buf.tobytes()


# 클래스별 bbox 색상 (BGR)
_OBSTACLE_COLORS: dict[str, tuple[int, int, int]] = {
    "stairs":  (0,   0,   220),   # 빨강
    "cone":    (0,   165, 255),   # 주황
    "bollard": (0,   200, 255),   # 노랑
    "slope":   (50,  205, 50 ),   # 초록
    "curb":    (255, 0,   0  ),   # 파랑
}
_DEFAULT_COLOR = (200, 50, 200)   # 보라 (기타)


def analyze_obstacle(
    image_bytes: bytes,
    conf: float = 0.28,
    iou: float  = 0.45,
    imgsz: int  = 960,
) -> tuple[bytes, list[dict]]:
    """
    장애물 감지 후 bbox가 그려진 이미지와 감지 목록을 반환합니다.

    Parameters
    ----------
    image_bytes : bytes
        원본 이미지 바이트
    conf : float
        신뢰도 임계값 (기본 0.28)
    iou : float
        NMS IoU 임계값 (기본 0.45)
    imgsz : int
        추론 이미지 크기 (기본 960)

    Returns
    -------
    annotated_jpeg : bytes
        bbox가 그려진 JPEG 이미지 바이트
    detections : list[dict]
        감지된 객체 목록. 각 항목은 {class, confidence, box} 형태.
    """
    model = _get_obstacle_model()
    img   = _bytes_to_bgr(image_bytes)

    results = model(img, conf=conf, iou=iou, imgsz=imgsz, verbose=False)

    detections: list[dict] = []
    annotated = img.copy()

    for result in results:
        if result.boxes is None:
            continue
        for box in result.boxes:
            cls_id     = int(box.cls[0])
            cls_name   = result.names[cls_id]
            confidence = float(box.conf[0])
            x1, y1, x2, y2 = map(int, box.xyxy[0])

            detections.append({
                "class":      cls_name,
                "confidence": round(confidence, 4),
                "box":        [x1, y1, x2, y2],
            })

            color = _OBSTACLE_COLORS.get(cls_name.lower(), _DEFAULT_COLOR)
            thickness = 3

            # bbox 직사각형
            cv2.rectangle(annotated, (x1, y1), (x2, y2), color, thickness)

            # 라벨 배경 + 텍스트
            label      = f"{cls_name} {confidence:.0%}"
            font_scale = 0.65
            font_thick = 2
            (tw, th), baseline = cv2.getTextSize(
                label, cv2.FONT_HERSHEY_SIMPLEX, font_scale, font_thick
            )
            label_y1 = max(y1 - th - baseline - 6, 0)
            label_y2 = y1
            cv2.rectangle(
                annotated,
                (x1, label_y1),
                (x1 + tw + 6, label_y2),
                color,
                cv2.FILLED,
            )
            cv2.putText(
                annotated,
                label,
                (x1 + 3, y1 - baseline - 2),
                cv2.FONT_HERSHEY_SIMPLEX,
                font_scale,
                (255, 255, 255),
                font_thick,
                cv2.LINE_AA,
            )

    # 신뢰도 내림차순 정렬
    detections.sort(key=lambda d: d["confidence"], reverse=True)

    return _bgr_to_jpeg(annotated), detections


def blur_privacy(
    image_bytes: bytes,
    conf: float        = 0.15,
    iou: float         = 0.45,
    imgsz: int         = 1280,
    shrink_ratio: float = 0.15,
    blur_ksize: int    = 51,
) -> bytes:
    """
    얼굴·번호판을 감지하여 GaussianBlur 처리한 이미지를 반환합니다.

    Parameters
    ----------
    image_bytes : bytes
        원본 이미지 바이트
    conf : float
        신뢰도 임계값 (기본 0.15 — 개인정보라서 낮게 설정)
    iou : float
        NMS IoU 임계값 (기본 0.45)
    imgsz : int
        추론 이미지 크기 (기본 1280 — 번호판처럼 작은 객체를 위해 크게)
    shrink_ratio : float
        bbox 내부 여백 비율. 0.15이면 박스를 15% 안쪽으로 수축 (기존 Blur.py 기본값)
    blur_ksize : int
        GaussianBlur 커널 크기 (홀수, 클수록 강한 블러)

    Returns
    -------
    blurred_jpeg : bytes
        블러 처리된 JPEG 이미지 바이트
    """
    model = _get_privacy_model()
    img   = _bytes_to_bgr(image_bytes)
    h_img, w_img = img.shape[:2]

    results = model(img, conf=conf, iou=iou, imgsz=imgsz, verbose=False)

    blurred = img.copy()

    for result in results:
        if result.boxes is None:
            continue
        for box in result.boxes:
            x1, y1, x2, y2 = map(int, box.xyxy[0])

            # bbox 수축 (shrink_ratio)
            w = x2 - x1
            h = y2 - y1
            dx = int(w * shrink_ratio / 2)
            dy = int(h * shrink_ratio / 2)

            sx1 = max(0,     x1 + dx)
            sy1 = max(0,     y1 + dy)
            sx2 = min(w_img, x2 - dx)
            sy2 = min(h_img, y2 - dy)

            roi = blurred[sy1:sy2, sx1:sx2]
            if roi.size == 0:
                continue

            # 커널 크기는 반드시 홀수여야 함
            ksize = blur_ksize if blur_ksize % 2 == 1 else blur_ksize + 1
            blurred[sy1:sy2, sx1:sx2] = cv2.GaussianBlur(roi, (ksize, ksize), 0)

    return _bgr_to_jpeg(blurred)


# ───────────────────────────────────────────────
# 독립 실행 테스트용
# ───────────────────────────────────────────────
if __name__ == "__main__":
    import argparse, sys

    parser = argparse.ArgumentParser(description="yolo_service 단독 테스트")
    parser.add_argument("--img",  required=True, help="입력 이미지 경로")
    parser.add_argument("--mode", choices=["analyze", "blur", "both"], default="both")
    args = parser.parse_args()

    img_path = Path(args.img)
    if not img_path.exists():
        print(f"이미지 없음: {img_path}"); sys.exit(1)

    raw = img_path.read_bytes()

    if args.mode in ("analyze", "both"):
        out_bytes, dets = analyze_obstacle(raw)
        out_path = img_path.with_stem(img_path.stem + "_detected")
        out_path.write_bytes(out_bytes)
        print(f"[analyze] 결과 → {out_path}")
        for d in dets:
            print(f"  {d['class']:12s}  conf={d['confidence']:.2%}  box={d['box']}")

    if args.mode in ("blur", "both"):
        out_bytes = blur_privacy(raw)
        out_path  = img_path.with_stem(img_path.stem + "_blurred")
        out_path.write_bytes(out_bytes)
        print(f"[blur]    결과 → {out_path}")
