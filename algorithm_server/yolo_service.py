"""
yolo_service.py - 길벗 서버 전용 YOLO 서비스 모듈
(algorithm_server/ 디렉터리 내에 위치, .pt 파일도 같은 위치)

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
from PIL import Image, ImageDraw, ImageFont  # 한글 폰트용

logger = logging.getLogger(__name__)

# ───────────────────────────────────────────────
# 모델 파일 경로 (상위 디렉터리의 yolo/ 디렉터리)
# ───────────────────────────────────────────────
_HERE = Path(__file__).parent
_YOLO_DIR = _HERE.parent / "yolo"
OBSTACLE_MODEL_PATH = str(_YOLO_DIR / "Obstacle.pt")
PRIVACY_MODEL_PATH  = str(_YOLO_DIR / "Personal-Info.pt")

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

def warmup_models():
    """서버 구동 시 모델을 메모리에 미리 로드하여 첫 요청 지연시간(Cold Start) 방지"""
    _get_obstacle_model()
    _get_privacy_model()
    logger.info("YOLO 모델 워밍업 완료")


def _bytes_to_bgr(image_bytes: bytes, max_size: int = 1024) -> np.ndarray:
    """bytes → OpenCV BGR ndarray 변환 + 필요시 리사이즈."""
    arr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError("이미지를 디코딩할 수 없습니다.")
        
    # 이미지가 너무 크면 연산/전송 속도 최적화를 위해 max_size로 제한
    h, w = img.shape[:2]
    if max(h, w) > max_size:
        scale = max_size / max(h, w)
        new_w, new_h = int(w * scale), int(h * scale)
        img = cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_AREA)
        
    return img


def _bgr_to_jpeg(img: np.ndarray, quality: int = 90) -> bytes:
    """OpenCV BGR ndarray → JPEG bytes 변환."""
    ok, buf = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, quality])
    if not ok:
        raise RuntimeError("JPEG 인코딩 실패")
    return buf.tobytes()


# 클래스명 → 한글 이름 매핑
_CLASS_TO_KO: dict[str, str] = {
    "stair":   "계단",
    "stairs":  "계단",
    "cone":    "라바콘",
    "bollard": "볼라드",
    "slope":   "경사로",
    "curb":    "턱",
}

# 클래스별 bbox 색상 (BGR)
_OBSTACLE_COLORS: dict[str, tuple[int, int, int]] = {
    "stair":   (0,   0,   220),   # 빨강
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
    imgsz: int  = 640,
) -> tuple[bytes, list[dict]]:
    """
    장애물 감지 후 bbox가 그려진 이미지와 감지 목록을 반환합니다.
    (Segmentation 모델이 아니므로 반투명 박스로 영역을 표시합니다.)
    """
    model = _get_obstacle_model()
    # 통신 및 처리 최적화를 위해 입력을 1024px로 제한
    img   = _bytes_to_bgr(image_bytes, max_size=1024)

    results = model(img, conf=conf, iou=iou, imgsz=imgsz, verbose=False)

    detections: list[dict] = []
    
    # 1. OpenCV(BGR) -> Pillow(RGBA) 변환
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    pil_img = Image.fromarray(img_rgb).convert("RGBA")
    
    # 2. 투명 오버레이 생성 (박스 채우기용)
    overlay = Image.new("RGBA", pil_img.size, (0, 0, 0, 0))
    draw    = ImageDraw.Draw(overlay)

    # 한글 폰트 로드
    try:
        font = ImageFont.truetype("malgun.ttf", 25) # 크기 40 -> 20 (사용자 요청)
    except:
        font = ImageFont.load_default()

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

            # 색상 (BGR -> RGB)
            bgr_color = _OBSTACLE_COLORS.get(cls_name.lower(), _DEFAULT_COLOR)
            rgb_color = (bgr_color[2], bgr_color[1], bgr_color[0])
            
            # 1) 반투명 채우기 (Alpha 60/255 = 약 23%)
            fill_color = (*rgb_color, 60)
            draw.rectangle([x1, y1, x2, y2], fill=fill_color, outline=rgb_color, width=3)

            # 2) 텍스트 라벨 (이름만 표시, 퍼센트 제거)
            ko_name = _CLASS_TO_KO.get(cls_name.lower(), cls_name)
            label   = ko_name

            bbox = font.getbbox(label)
            w_text = bbox[2] - bbox[0]
            h_text = bbox[3] - bbox[1]

            label_y1 = max(y1 - h_text - 10, 0)
            label_y2 = label_y1 + h_text + 10
            
            # 텍스트 배경 (불투명)
            draw.rectangle(
                [x1, label_y1, x1 + w_text + 10, label_y2],
                fill=(*rgb_color, 255),
                outline=(*rgb_color, 255)
            )
            
            # 텍스트 (흰색)
            draw.text(
                (x1 + 5, label_y1 + 5), 
                label, 
                font=font, 
                fill=(255, 255, 255, 255)
            )

    # 3. 합성 (원본 + 오버레이)
    out = Image.alpha_composite(pil_img, overlay)

    # 4. Pillow(RGBA) -> OpenCV(BGR) 복원
    annotated = cv2.cvtColor(np.array(out.convert("RGB")), cv2.COLOR_RGB2BGR)

    # 신뢰도 내림차순 정렬
    detections.sort(key=lambda d: d["confidence"], reverse=True)

    return _bgr_to_jpeg(annotated), detections


def blur_privacy(
    image_bytes: bytes,
    conf: float        = 0.15,
    iou: float         = 0.45,
    imgsz: int         = 640,
    shrink_ratio: float = 0.15,
    blur_ksize: int    = 51,
) -> bytes:
    """
    얼굴·번호판을 감지하여 GaussianBlur 처리한 이미지를 반환합니다.
    """
    model = _get_privacy_model()
    img   = _bytes_to_bgr(image_bytes, max_size=1024)
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

            ksize = blur_ksize if blur_ksize % 2 == 1 else blur_ksize + 1
            blurred[sy1:sy2, sx1:sx2] = cv2.GaussianBlur(roi, (ksize, ksize), 0)

    return _bgr_to_jpeg(blurred)


# ───────────────────────────────────────────────
# 독립 실행 테스트용 (CLI)
# python yolo_service.py --img photo.jpg --mode both
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
