from ultralytics import YOLO
import cv2

def blur_detected_bboxes(image_path, output_path):
    model = YOLO("best.pt")  # 모델 경로

    # 이미지 읽기
    image = cv2.imread(image_path)
    if image is None:
        raise ValueError("이미지를 불러올 수 없습니다.")

    # YOLO 추론
    results = model(image_path, conf=0.25)

    for result in results:
        if result.boxes is None:
            continue

        for box in result.boxes:
            # bbox 좌표 (정수로 변환)
            x1, y1, x2, y2 = map(int, box.xyxy[0])

            # bbox 영역 crop
            roi = image[y1:y2, x1:x2]

            if roi.size == 0:
                continue

            # 블러 처리 (커널 크기는 상황에 맞게 조절)
            blurred_roi = cv2.GaussianBlur(roi, (31, 31), 0)

            # 다시 원본 이미지에 덮어쓰기
            image[y1:y2, x1:x2] = blurred_roi

    # 결과 저장
    cv2.imwrite(output_path, image)

if __name__ == "__main__":
    blur_detected_bboxes(
        image_path="test.jpg",
        output_path="result_blur.jpg"
    )
