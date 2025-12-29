-- 길벗 휠체어 내비게이션 - Supabase 테이블 생성 SQL
-- Supabase SQL Editor에서 실행하세요

-- 1. edges 테이블: 사전 계산된 경사도 데이터
CREATE TABLE IF NOT EXISTS edges (
    id SERIAL PRIMARY KEY,
    edge_id VARCHAR(100) UNIQUE NOT NULL,      -- "시작노드_끝노드_키" 형식
    start_node_id BIGINT NOT NULL,
    end_node_id BIGINT NOT NULL,
    start_lat DOUBLE PRECISION NOT NULL,
    start_lon DOUBLE PRECISION NOT NULL,
    end_lat DOUBLE PRECISION NOT NULL,
    end_lon DOUBLE PRECISION NOT NULL,
    length DOUBLE PRECISION DEFAULT 0,          -- 거리 (m)
    grade DOUBLE PRECISION DEFAULT 0,           -- 대표 경사도 (도)
    max_grade DOUBLE PRECISION DEFAULT 0,       -- 최대 경사도 (도)
    min_grade DOUBLE PRECISION DEFAULT 0,       -- 최소 경사도 (도)
    avg_grade DOUBLE PRECISION DEFAULT 0,       -- 평균 경사도 (도)
    grade_segments INTEGER DEFAULT 0,           -- 측정 구간 수
    elevation_start DOUBLE PRECISION DEFAULT 0, -- 시작점 고도 (m)
    elevation_end DOUBLE PRECISION DEFAULT 0,   -- 끝점 고도 (m)
    elevation_max DOUBLE PRECISION DEFAULT 0,   -- 최대 고도 (m)
    elevation_min DOUBLE PRECISION DEFAULT 0,   -- 최소 고도 (m)
    total_ascent DOUBLE PRECISION DEFAULT 0,    -- 총 오르막 (m)
    total_descent DOUBLE PRECISION DEFAULT 0,   -- 총 내리막 (m)
    surface_type VARCHAR(50) DEFAULT 'paved',   -- 노면 타입
    surface_penalty DOUBLE PRECISION DEFAULT 1.0,
    highway_type VARCHAR(50) DEFAULT 'unknown', -- 도로 타입
    is_wheelchair_accessible BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_edges_nodes ON edges(start_node_id, end_node_id);
CREATE INDEX IF NOT EXISTS idx_edges_edge_id ON edges(edge_id);
CREATE INDEX IF NOT EXISTS idx_edges_accessible ON edges(is_wheelchair_accessible);

-- 2. obstacles 테이블: 장애물 데이터
CREATE TABLE IF NOT EXISTS obstacles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    obstacle_type VARCHAR(50) NOT NULL,         -- "stairs", "construction", "pothole" 등
    description TEXT DEFAULT '',
    radius DOUBLE PRECISION DEFAULT 15.0,       -- 영향 반경 (m)
    severity VARCHAR(20) DEFAULT 'high',        -- "low", "medium", "high"
    is_active BOOLEAN DEFAULT true,
    reported_by VARCHAR(100),                   -- 제보자 ID
    image_url TEXT,                             -- YOLOv8 처리된 이미지 URL
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_obstacles_location ON obstacles(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_obstacles_active ON obstacles(is_active);
CREATE INDEX IF NOT EXISTS idx_obstacles_type ON obstacles(obstacle_type);

-- Row Level Security (RLS) 활성화
ALTER TABLE edges ENABLE ROW LEVEL SECURITY;
ALTER TABLE obstacles ENABLE ROW LEVEL SECURITY;

-- 읽기 정책: 모든 사용자가 읽기 가능
CREATE POLICY "edges_read_all" ON edges FOR SELECT USING (true);
CREATE POLICY "obstacles_read_all" ON obstacles FOR SELECT USING (true);

-- 쓰기 정책: 인증된 사용자만 쓰기 가능 (또는 서비스 키 사용)
-- 필요에 따라 수정하세요
CREATE POLICY "edges_insert_service" ON edges FOR INSERT WITH CHECK (true);
CREATE POLICY "obstacles_insert_auth" ON obstacles FOR INSERT WITH CHECK (true);

-- updated_at 자동 갱신 트리거
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_edges_updated_at BEFORE UPDATE ON edges
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_obstacles_updated_at BEFORE UPDATE ON obstacles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
