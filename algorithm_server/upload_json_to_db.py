"""
로컬 edges_data.json 파일을 읽어 Supabase DB에 덮어씌우는 스크립트
"""
import os
import json
import logging
from dotenv import load_dotenv
from supabase import create_client

# 로깅 설정
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def upload_json_to_db():
    # 1. 환경변수 로드
    load_dotenv()
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_KEY")

    if not supabase_url or not supabase_key:
        logger.error("Supabase 설정이 없습니다. .env 파일을 확인하세요.")
        return

    # 2. JSON 파일 로드
    json_path = "edges_data.json"
    if not os.path.exists(json_path):
        logger.error(f"{json_path} 파일이 없습니다.")
        return

    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        logger.info(f"{len(data)}개의 엣지 데이터를 로드했습니다.")
    except Exception as e:
        logger.error(f"JSON 파일 읽기 실패: {e}")
        return

    # 3. Supabase 연결
    try:
        client = create_client(supabase_url, supabase_key)
        logger.info("Supabase 연결 성공")
    except Exception as e:
        logger.error(f"Supabase 연결 실패: {e}")
        return

    # 4. 데이터 업로드 (기존 데이터 삭제 후 입력)
    try:
        # 기존 데이터 삭제
        logger.info("기존 데이터 삭제 중...")
        client.table("edges").delete().neq("edge_id", "placeholder").execute()  # 모든 데이터 삭제
        
        # 배치 업로드
        batch_size = 100
        total = len(data)
        saved = 0
        
        logger.info("데이터 업로드 시작...")
        for i in range(0, total, batch_size):
            batch = data[i:i + batch_size]
            client.table("edges").insert(batch).execute()
            saved += len(batch)
            print(f"진행: {saved}/{total} ({saved*100//total}%)", end='\r')
            
        print() # 줄바꿈
        logger.info("모든 데이터 업로드가 완료되었습니다.")
        
    except Exception as e:
        logger.error(f"업로드 중 오류 발생: {e}")

if __name__ == "__main__":
    upload_json_to_db()
