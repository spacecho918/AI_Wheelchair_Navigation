from ultralytics import YOLO
import cv2
import os

def blur_detected_bboxes(image_path):
    model = YOLO(r"model/Personal-Info.pt")  # 모델 경로

    # 이미지 읽기
    image = cv2.imread(image_path)
    if image is None:
        raise ValueError(f"이미지를 불러올 수 없습니다: {image_path}")

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

            # 블러 처리 
            blurred_roi = cv2.GaussianBlur(roi, (71, 71), 0)

            # 다시 원본 이미지에 덮어쓰기
            image[y1:y2, x1:x2] = blurred_roi

    # 🔹 원본 이미지 경로 + 파일명_blur.확장자로 저장
    dir_path = os.path.dirname(image_path)
    filename = os.path.basename(image_path)
    name, ext = os.path.splitext(filename)

    output_path = os.path.join(dir_path, f"{name}_blur{ext}")
    cv2.imwrite(output_path, image)

    print(f"블러 처리 완료: {output_path}")

if __name__ == "__main__":
    blur_detected_bboxes("test.jpg")
