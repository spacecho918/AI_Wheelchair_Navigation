from ultralytics import YOLO

def detect_objects(image_path):
    model = YOLO("best.pt")  # 모델 경로
    results = model(image_path, conf=0.25)

    detected_class_ids = set()

    for result in results:
        if result.boxes is None:
            continue

        for cls_id in result.boxes.cls:
            detected_class_ids.add(int(cls_id))

    # 인식된 클래스 ID 리스트 반환 (예: [0, 1, 2])
    return sorted(detected_class_ids)

if __name__ == "__main__":
    classes = detect_objects("test.jpg")
    print(classes)
