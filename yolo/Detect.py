from ultralytics import YOLO
import argparse
import os

# python Detect.py --img image_path
def detect_objects(image_path, conf=0.28, iou=0.45, imgsz=960, augment=False):
    model = YOLO("Obstacle.pt") # YOLO 모델 경로

    results = model(
        image_path,
        conf=conf,
        iou=iou,
        imgsz=imgsz,
        augment=augment
    )

    detected_class_ids = set()

    for result in results:
        if result.boxes is None:
            continue

        for cls_id in result.boxes.cls:
            detected_class_ids.add(int(cls_id))

    return sorted(detected_class_ids)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="YOLOv8 Object Detection")
    parser.add_argument("--img", required=True, help="입력 이미지 경로")

    args = parser.parse_args()

    if not os.path.exists(args.img):
        print("이미지 파일이 존재하지 않습니다.")
        exit()

    classes = detect_objects(args.img)

    print("\nClass ID:")
    print(classes)
