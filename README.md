# 🦽 길벗 - 휠체어 내비게이션 알고리즘

> OSM 기반 휠체어 전용 경로 탐색 시스템  
> 실시간 장애물 제보 + 정밀 경사도 측정 + 3가지 경로 모드

---

## 📋 목차

1. [프로젝트 개요](#프로젝트-개요)
2. [파일 구조](#파일-구조)
3. [각 파일 상세 설명](#각-파일-상세-설명)
4. [실행 순서](#실행-순서)
5. [API 엔드포인트](#api-엔드포인트)
6. [환경 설정](#환경-설정)

---

## 🎯 프로젝트 개요

### 핵심 기능
- **OSM 데이터 파싱**: OpenStreetMap에서 한국공학대↔정왕역 지역 도로 데이터 추출
- **정밀 경사도 측정**: DEM(고도 모델)을 활용해 5m 간격으로 경사도 측정
- **3가지 경로 모드**: 최단거리 / 안전우선 / 최적경로
- **장애물 반영**: 제보된 장애물 위치를 경로에서 자동 회피

### 기술 스택
- **Backend**: FastAPI (Python)
- **Database**: Supabase (PostgreSQL)
- **지도 데이터**: OpenStreetMap + OSMnx
- **고도 데이터**: Open-Elevation API

---

## 📁 파일 구조

```
wheelchair_algorithm/
│
├── 📄 README.md                  ← 지금 읽고 있는 파일
├── 📄 requirements.txt           ← Python 패키지 목록
├── 📄 .env.example               ← 환경변수 템플릿
├── 📄 supabase_schema.sql        ← Supabase 테이블 생성 SQL
│
├── 🔧 전처리 스크립트 (1회 실행)
│   ├── preprocess_edges.py       ← 경사도 사전 계산 & DB 저장
│   └── elevation_calculator.py   ← DEM API로 고도/경사도 계산
│
├── 🚀 메인 서버 모듈
│   ├── main_server.py      ← FastAPI 서버 (진입점)
│   ├── osm_parser.py             ← OSM → 그래프 변환
│   ├── route_algorithm.py        ← Dijkstra 경로 탐색
│   ├── obstacle_manager.py       ← 장애물 관리
│   └── edge_data_loader.py       ← DB에서 경사도 로드
│
└── 📊 생성되는 파일
    └── edges_data.json           ← 전처리 결과 백업
```

---

## 📝 각 파일 상세 설명

### 🔧 설정 파일

#### `requirements.txt`
```
Python 패키지 목록
pip install -r requirements.txt 로 설치
```

#### `.env.example`
```
환경변수 템플릿
.env 파일로 복사 후 실제 값 입력
- SUPABASE_URL: Supabase 프로젝트 URL
- SUPABASE_KEY: Supabase API 키
- USE_PRECOMPUTED_EDGES: true (DB에서 경사도 로드)
```

#### `supabase_schema.sql`
```
Supabase 테이블 생성 SQL
- edges: 경사도 데이터 저장
- obstacles: 장애물 데이터 저장
Supabase SQL Editor에서 실행
```

---

### 🔧 전처리 스크립트 (최초 1회 실행)

#### `preprocess_edges.py` ⭐ 중요
```python
역할: OSM 그래프의 모든 엣지(도로 구간)에 대해 경사도를 계산하고 DB에 저장

실행 방법:
    python preprocess_edges.py

동작 과정:
    1. OSM에서 한국공학대↔정왕역 지역 그래프 생성
    2. 각 엣지를 5m 간격으로 샘플링
    3. Open-Elevation API로 각 지점의 고도 조회
    4. 구간별 경사도 계산 (최대/최소/평균)
    5. Supabase 'edges' 테이블에 저장
    6. edges_data.json 백업 파일 생성

소요 시간: 엣지 수에 따라 수십 분 ~ 몇 시간

주의사항:
    - Supabase 연결 정보가 .env에 있어야 함
    - 인터넷 연결 필요 (API 호출)
    - 한 번만 실행하면 됨 (지역 변경 시 재실행)
```

#### `elevation_calculator.py`
```python
역할: DEM(Digital Elevation Model) API를 통한 고도/경사도 계산

주요 클래스:
    - OpenElevationProvider: 무료 고도 API 연동
    - SRTMElevationProvider: 로컬 SRTM 데이터 사용 (선택)
    - SlopeCalculator: 경사도 계산 로직

핵심 기능:
    - 두 좌표 사이를 N개 구간으로 나눔
    - 각 구간의 고도차로 경사도 계산
    - 최대 경사도를 대표값으로 사용 (안전 기준)
```

---

### 🚀 메인 서버 모듈

#### `main_server.py` ⭐ 진입점
```python
역할: FastAPI 웹 서버 - 모든 모듈 통합

실행 방법:
    uvicorn main_server:app --host 0.0.0.0 --port 8000 --reload

초기화 순서:
    1. OSM 그래프 생성 (osm_parser)
    2. 휠체어 통행불가 구간 필터링
    3. DB에서 경사도 데이터 로드 (edge_data_loader)
    4. 경로 계산기 초기화 (route_algorithm)
    5. 장애물 관리자 초기화 (obstacle_manager)
    6. DB에서 장애물 로드

제공 API:
    - POST /route: 경로 탐색
    - POST /obstacle: 장애물 등록
    - GET /obstacles: 장애물 목록
    - GET /graph/info: 그래프 정보
```

#### `osm_parser.py`
```python
역할: OpenStreetMap 데이터를 NetworkX 그래프로 변환

주요 클래스: OSMGraphBuilder

핵심 기능:
    - build_graph_from_bbox(): 좌표 범위로 그래프 생성
    - filter_wheelchair_accessible(): 계단, 에스컬레이터 등 제거
    - add_edge_weights(): 노면 상태 패널티 추가
    - get_nearest_node(): 좌표에서 가장 가까운 노드 찾기

사용하는 좌표:
    - 한국공학대: (37.3401, 126.7315)
    - 정왕역: (37.3468, 126.7383)
```

#### `route_algorithm.py`
```python
역할: Dijkstra 알고리즘으로 최적 경로 탐색

3가지 모드:
┌─────────────┬──────────────────────────────────────────┐
│ 모드        │ 설명                                     │
├─────────────┼──────────────────────────────────────────┤
│ short       │ 최단 거리 우선, 경사도 12°까지 허용      │
│ safe        │ 안전 우선, 경사도 5° 초과 시 높은 패널티 │
│ optimal     │ 균형 모드, 경사도 8° 기준                │
└─────────────┴──────────────────────────────────────────┘

모든 모드 공통:
    - 장애물 있는 구간 = 가중치 무한대 = 완전 회피

주요 클래스:
    - WeightCalculator: 모드별 가중치 계산
    - RouteCalculator: Dijkstra 경로 탐색
    - RouteResult: 경로 결과 데이터
```

#### `obstacle_manager.py`
```python
역할: 장애물 데이터 관리 및 그래프 가중치 반영

주요 기능:
    - Supabase 'obstacles' 테이블에서 장애물 조회
    - 장애물이 실제로 위치한 엣지(도로 구간)만 정확히 탐지
    - 해당 엣지의 가중치를 무한대(∞)로 설정
    - Dijkstra가 자연스럽게 우회 경로 탐색

장애물 탐지 로직 (정밀 방식):
    - 점(장애물)에서 선분(엣지)까지의 수직 거리 계산
    - 장애물이 실제 경로 위에 있는 경우만 해당 엣지 차단
    - 엣지 끝점 근처에 있어도 경로를 막지 않으면 통과
    
    예시:
        A ─────── X(장애물) ─────── B ─────── C
        
        → A-B 엣지만 차단 (장애물이 A-B 선분 위에 있음)
        → B-C 엣지는 정상 통과

장애물 타입:
    - stairs: 계단
    - construction: 공사 구간
    - pothole: 도로 파손
    - steep_slope: 급경사
```

#### `edge_data_loader.py`
```python
역할: 사전 계산된 경사도 데이터를 DB/JSON에서 로드

데이터 소스 우선순위:
    1. Supabase 'edges' 테이블
    2. edges_data.json 파일 (백업)

주요 기능:
    - load_from_supabase(): DB에서 경사도 로드
    - load_from_json(): JSON 파일에서 로드
    - apply_to_graph(): 그래프에 경사도 데이터 적용
```

---

###▶️ 실행 순서################################################################################################

### 최초 설정 (1회)

```
┌─────────────────────────────────────────────────────────────────┐
│ 1️⃣  의존성 설치                                                 │
│     pip install -r requirements.txt                             │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2️⃣  환경변수 설정                                               │
│     copy .env.example .env                                      │
│     .env 파일 열어서 Supabase URL, Key 입력                      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3️⃣  Supabase 테이블 생성                                        │
│     Supabase 대시보드 → SQL Editor                              │
│     supabase_schema.sql 내용 복사 → 실행                        |
│     이미 테이블을 만든 DB를 사용할 예정(테스트 필요 시 카톡 확인) |
│ ⏱️ 1분 소요                                                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 4️⃣  경사도 데이터 전처리 (시간 소요!)                            │
│     python preprocess_edges.py                                  │
│     ⏱️ 수십 분 ~ 몇 시간 소요                                   │
└─────────────────────────────────────────────────────────────────┘

```

### 서버 실행 (매번)

```
┌─────────────────────────────────────────────────────────────────┐
│ 5️⃣  서버 시작                                                    │
│     uvicorn main_server:app --host 0.0.0.0 --port 8000    │
│     --reload 옵션 추가 시 코드 변경 자동 반영                     |
|     또는 main_server.py 실행해도 가능함                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 6️⃣  API 문서 확인                                               │
│     브라우저에서 http://localhost:8000/docs 접속                 |
|     ㄴ docs접속은 initialize를 위한 것임.                        │
│     Swagger UI에서 API 테스트 가능                               │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📡 API 엔드포인트

### `POST /route` - 경로 탐색

**요청:**
```json
{
  "start_lat": 37.3401,
  "start_lon": 126.7315,
  "end_lat": 37.3468,
  "end_lon": 126.7383,
  "mode": "optimal"   // 여기서 모드 바꾸면 됨. optimal = 최적 / short = 최단 / safe = 안전
}
```

**응답:**
```json
{
  "success": true,
  "message": "경로 탐색 성공",
  "route": {
    "distance": 850.5,
    "estimated_time": 14,
    "geometry": [[37.3401, 126.7315], ...],
    "avoided_obstacles": 2,
    "mode": "optimal"
  }
}
```

### `POST /obstacle` - 장애물 등록

**요청:**
```json
{
  "latitude": 37.3420,
  "longitude": 126.7340,
  "obstacle_type": "construction",
  "description": "공사 중",
  "radius": 15.0
}
```

### `GET /obstacles` - 장애물 목록 조회

### `POST /route/compare` - 3가지 모드 비교

---

## ⚙️ 환경 설정

### `.env` 파일 예시

```bash
# Supabase 연결 정보
SUPABASE_URL=https://abcdefg.supabase.co
SUPABASE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6...

# 경사도 데이터 설정
USE_PRECOMPUTED_EDGES=true   # 사전 계산 데이터 사용 (권장)
USE_DEM_ELEVATION=false      # 실시간 API 사용 (비권장)
DEM_SAMPLE_INTERVAL=5        # 샘플링 간격 (m) - 샘플링 간격 5m로 미리 db에 저장 작업함.
```

---

## 👥 팀원별 작업 가이드

### 🖥️ 앱 팀 (Flutter)
- `POST /route` API 연동
- 경로 geometry를 지도에 표시
- 장애물 제보 시 `POST /obstacle` 호출

### 🖧 서버 팀
- `main_server.py` 관리
- Supabase 연동 및 데이터 관리
- API 추가/수정

### 🤖 AI 팀 (YOLOv8)
- 장애물 인식 후 `POST /obstacle` 호출
- `obstacle_type` 설정 (stairs, construction 등)

### 📊 알고리즘 팀
- `route_algorithm.py` 가중치 조정
- `osm_parser.py` 필터링 로직 수정
- 새로운 경로 모드 추가

---

## ❓ 자주 묻는 질문

### Q: 서버 시작이 느려요
A: 최초 시작 시 OSM 데이터를 다운로드를 해야됨. 다음 실행부터는 빨라짐.

### Q: 경사도가 0으로 나와요
A: DB연결이 잘못되었거나 오류가 난 것임. 확인 필요함.

### Q: Supabase 연결이 안 돼요
A: `.env` 파일에 올바른 SUPABASE_URL과 SUPABASE_KEY가 설정되어 있는지 확인.

### Q: 지역을 변경하고 싶어요
A: `osm_parser.py`의 `BBOX_NORTH/SOUTH/EAST/WEST` 값을 수정 후 `preprocess_edges.py`를 다시 실행.
    ㄴ경사도 전처리 때문에 박스는 바꿀거면 미리 보고.
