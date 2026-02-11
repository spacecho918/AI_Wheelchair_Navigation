from ultralytics import YOLO
import cv2
import os
import argparse

# python Blur.py --img image_path

def blur_detected_bboxes(image_path, shrink_ratio=0.15):
    model = YOLO("Personal-Info.pt")  # YOLO 모델 경로

    image = cv2.imread(image_path)
    if image is None:
        raise ValueError("이미지를 불러올 수 없습니다.")

    h_img, w_img = image.shape[:2]

    results = model(image_path, conf=0.15, iou=0.45, imgsz=1280, augment=False)

    for result in results:
        if result.boxes is None:
            continue

        for box in result.boxes:
            x1, y1, x2, y2 = map(int, box.xyxy[0])

            # ---------- bbox 축소 ----------
            w = x2 - x1
            h = y2 - y1

            dx = int(w * shrink_ratio / 2)
            dy = int(h * shrink_ratio / 2)

            x1_new = max(0, x1 + dx)
            y1_new = max(0, y1 + dy)
            x2_new = min(w_img, x2 - dx)
            y2_new = min(h_img, y2 - dy)
            # -------------------------------

            roi = image[y1_new:y2_new, x1_new:x2_new]

            if roi.size == 0:
                continue

            blurred_roi = cv2.GaussianBlur(roi, (31, 31), 0)
            image[y1_new:y2_new, x1_new:x2_new] = blurred_roi

    # ------ 입력 위치에 저장 -------
    dir_path, filename = os.path.split(image_path)
    name, ext = os.path.splitext(filename)
    output_path = os.path.join(dir_path, f"{name}_blur{ext}")
    # ------------------------------

    cv2.imwrite(output_path, image)
    print(f"저장 완료 → {output_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="YOLOv8 Privacy Blur")
    parser.add_argument("--img", required=True, help="입력 이미지 경로")

    args = parser.parse_args()

    if not os.path.exists(args.img):
        print("이미지 파일이 존재하지 않습니다.")
        exit()

    blur_detected_bboxes(
        image_path=args.img,
        shrink_ratio=0.15   # bbox 축소 비율
    )
