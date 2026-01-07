from ultralytics import YOLO

# 결과 이미지 경로 : \runs\detect\predict

def main():
    model = YOLO(r"pt 모델 주소")
    
    results = model.predict(
        source=r"이미지 주소",
        save=True,      # 결과 이미지 저장
        conf=0.25       # confidence threshold
    )

if __name__ == "__main__":
    main()
