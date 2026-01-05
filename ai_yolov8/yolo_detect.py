"""
YOLOv8 이미지 객체 탐지 스크립트

사용법:
    python yolo_detect.py --source 이미지경로.jpg --mode obstacle
    python yolo_detect.py --source 이미지경로.jpg --mode privacy
"""

import os
import argparse
from pathlib import Path

# ultralytics 패키지에서 YOLO 모델 import
from ultralytics import YOLO

# 결과 시각화용 (선택)
try:
    import cv2
    from PIL import Image
    HAS_DISPLAY = True
except ImportError:
    HAS_DISPLAY = False

# ========== 모델 설정 ==========
# 모델 파일을 이 폴더에 넣고 파일명을 아래에 입력하세요
MODELS = {
    "obstacle": "Obstacle.pt",      # 장애물 감지 모델
    "privacy": "Personal-Info.pt",        # 얼굴+번호판 감지 모델
}


def detect_image(source: str, model_path: str = "yolov8n.pt", conf: float = 0.25, save: bool = True):
    """
    YOLOv8을 사용하여 이미지에서 객체를 탐지합니다.
    
    Args:
        source: 탐지할 이미지 파일 경로
        model_path: YOLO 모델 가중치 파일 경로 (기본값: yolov8n.pt)
        conf: 신뢰도 임계값 (기본값: 0.25)
        save: 결과 이미지 저장 여부 (기본값: True)
    
    Returns:
        results: 탐지 결과 객체
    """
    # 모델 로드 (없으면 자동 다운로드)
    model = YOLO(model_path)
    
    # 객체 탐지 수행
    results = model.predict(
        source=source,
        conf=conf,
        save=save,
        show=False  # GUI 환경에서만 True로 설정
    )
    
    # 탐지 결과 출력
    for result in results:
        print(f"\n=== 탐지 결과 ===")
        print(f"이미지: {result.path}")
        print(f"탐지된 객체 수: {len(result.boxes)}")
        
        # 탐지된 각 객체 정보 출력
        for i, box in enumerate(result.boxes):
            cls_id = int(box.cls[0])
            cls_name = result.names[cls_id]
            confidence = float(box.conf[0])
            coords = box.xyxy[0].tolist()
            print(f"  [{i+1}] {cls_name}: {confidence:.2%} at {coords}")
    
    return results


def show_result(results, predict_num: int = None):
    """
    탐지 결과 이미지를 표시합니다.
    
    Args:
        results: YOLO 탐지 결과
        predict_num: predict 디렉토리 번호 (자동 탐색시 사용)
    """
    if not HAS_DISPLAY:
        print("cv2 또는 PIL이 설치되지 않아 이미지를 표시할 수 없습니다.")
        return
    
    # 결과 이미지 경로 찾기
    if predict_num is not None:
        predict_dir = f"runs/detect/predict{predict_num}" if predict_num > 1 else "runs/detect/predict"
        if os.path.exists(predict_dir):
            img_files = [f for f in os.listdir(predict_dir) if f.endswith(('.jpg', '.png'))]
            if img_files:
                img_path = os.path.join(predict_dir, img_files[0])
                img = Image.open(img_path)
                img.show()
                return
    
    # 결과 객체에서 직접 이미지 표시
    for result in results:
        annotated = result.plot()  # OpenCV BGR 이미지
        # BGR -> RGB 변환 후 표시
        img = Image.fromarray(cv2.cvtColor(annotated, cv2.COLOR_BGR2RGB))
        img.show()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="YOLOv8 이미지 객체 탐지")
    parser.add_argument("--source", type=str, default="img.jpg", help="탐지할 이미지 경로")
    parser.add_argument("--mode", type=str, choices=["obstacle", "privacy"], default="obstacle",
                        help="탐지 모드: obstacle(장애물) 또는 privacy(얼굴+번호판)")
    parser.add_argument("--model", type=str, default=None, help="YOLO 모델 경로 (직접 지정시)")
    parser.add_argument("--conf", type=float, default=0.25, help="신뢰도 임계값")
    parser.add_argument("--no-save", action="store_true", help="결과 이미지 저장 안 함")
    parser.add_argument("--show", action="store_true", help="결과 이미지 표시")
    
    args = parser.parse_args()
    
    # 모델 경로 결정 (직접 지정 > 모드 선택)
    if args.model:
        model_path = args.model
    else:
        model_path = MODELS.get(args.mode)
        if not model_path:
            print(f"오류: 알 수 없는 모드입니다: {args.mode}")
            print(f"사용 가능한 모드: {list(MODELS.keys())}")
            exit(1)
    
    # 모델 파일 존재 확인
    if not os.path.exists(model_path):
        print(f"오류: 모델 파일을 찾을 수 없습니다: {model_path}")
        print(f"모델 파일을 '{os.path.dirname(os.path.abspath(__file__))}' 폴더에 넣어주세요.")
        exit(1)
    
    # 이미지 파일 존재 확인
    if not os.path.exists(args.source):
        print(f"오류: 이미지 파일을 찾을 수 없습니다: {args.source}")
        exit(1)
    
    print(f"\n🔍 모드: {args.mode}")
    print(f"📦 모델: {model_path}")
    print(f"🖼️ 이미지: {args.source}")
    
    # 탐지 실행
    results = detect_image(
        source=args.source,
        model_path=model_path,
        conf=args.conf,
        save=not args.no_save
    )
    
    # 결과 이미지 표시 (옵션)
    if args.show:
        show_result(results)
    
    print(f"\n결과가 'runs/detect/' 폴더에 저장되었습니다.")


# ========== 실행 예시 ==========
# 장애물 감지 (Obstacle.pt)
# python yolo_detect.py --source 사진파일명 --mode obstacle --show

# 얼굴+번호판 감지 (Personal-Info.pt)
# python yolo_detect.py --source 사진파일명 --mode privacy --show