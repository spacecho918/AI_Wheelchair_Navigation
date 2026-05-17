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

-- user_profiles.role 및 is_admin() — obstacles UPDATE/DELETE RLS에서 사용
-- (user_profiles 테이블이 이미 존재해야 함)
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'user';
ALTER TABLE user_profiles DROP CONSTRAINT IF EXISTS user_profiles_role_check;
ALTER TABLE user_profiles ADD CONSTRAINT user_profiles_role_check CHECK (role IN ('user', 'admin'));

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_profiles up
    WHERE up.user_id = auth.uid()
      AND up.role = 'admin'
  );
$$;

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin() TO service_role;

-- 읽기 정책: 모든 사용자가 읽기 가능
CREATE POLICY "edges_read_all" ON edges FOR SELECT USING (true);
CREATE POLICY "obstacles_read_all" ON obstacles FOR SELECT USING (true);

-- 쓰기 정책: 인증된 사용자만 쓰기 가능 (또는 서비스 키 사용)
-- 필요에 따라 수정하세요
CREATE POLICY "edges_insert_service" ON edges FOR INSERT WITH CHECK (true);
CREATE POLICY "obstacles_insert_auth" ON obstacles FOR INSERT WITH CHECK (true);

-- 제보 삭제: 본인 또는 role=admin
DROP POLICY IF EXISTS "obstacles_delete_own" ON obstacles;
DROP POLICY IF EXISTS "obstacles_delete_own_or_admin" ON obstacles;
CREATE POLICY "obstacles_delete_own_or_admin" ON obstacles FOR DELETE
  USING (reported_by = auth.uid()::text OR public.is_admin());

-- 제보 수정: 본인 또는 admin (정책 없으면 UPDATE 불가)
DROP POLICY IF EXISTS "obstacles_update_own_or_admin" ON obstacles;
CREATE POLICY "obstacles_update_own_or_admin" ON obstacles FOR UPDATE
  USING (reported_by = auth.uid()::text OR public.is_admin())
  WITH CHECK (reported_by = auth.uid()::text OR public.is_admin());

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

-- 3. likes 테이블: 커뮤니티(obstacles) 게시글 좋아요/싫어요
CREATE TABLE IF NOT EXISTS likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    obstacle_id UUID NOT NULL REFERENCES obstacles(id) ON DELETE CASCADE,
    is_like BOOLEAN NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, obstacle_id)
);

CREATE INDEX IF NOT EXISTS idx_likes_obstacle_id ON likes(obstacle_id);
CREATE INDEX IF NOT EXISTS idx_likes_user_id ON likes(user_id);

ALTER TABLE likes ENABLE ROW LEVEL SECURITY;

-- 읽기: 모든 사용자(목록/상세에서 집계용)
CREATE POLICY "likes_read_all" ON likes FOR SELECT USING (true);
-- 쓰기: 본인만 (insert/update/delete)
CREATE POLICY "likes_insert_own" ON likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "likes_update_own" ON likes FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "likes_delete_own" ON likes FOR DELETE USING (auth.uid() = user_id);

CREATE TRIGGER update_likes_updated_at BEFORE UPDATE ON likes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ================================================================
-- 4. notifications 테이블 RLS + Realtime
-- ================================================================

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_notifications_user_id    ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read    ON notifications(user_id, is_read);

-- RLS: 본인 알림만 조회/수정 허용
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notifications_read_own"      ON notifications;
DROP POLICY IF EXISTS "notifications_update_own"    ON notifications;
DROP POLICY IF EXISTS "notifications_insert_service" ON notifications;

CREATE POLICY "notifications_read_own" ON notifications
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "notifications_update_own" ON notifications
    FOR UPDATE USING (auth.uid() = user_id);

-- 트리거 함수(SECURITY DEFINER)가 다른 유저 알림 삽입할 수 있도록 허용
CREATE POLICY "notifications_insert_service" ON notifications
    FOR INSERT WITH CHECK (true);

-- Realtime 구독 활성화 (Flutter RealtimeChannel 사용)
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

-- ================================================================
-- 5. 좋아요 발생 시 → 제보 작성자에게 'like' 알림 자동 생성
--    자기 자신의 글에 좋아요는 알림 제외
-- ================================================================
CREATE OR REPLACE FUNCTION notify_on_like()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_obstacle_owner UUID;
    v_liker_nickname TEXT;
    v_obstacle_type  TEXT;
BEGIN
    -- 제보 작성자 조회
    SELECT reported_by::UUID, obstacle_type
    INTO v_obstacle_owner, v_obstacle_type
    FROM obstacles
    WHERE id = NEW.obstacle_id;

    -- 작성자가 없거나 자신의 글에 좋아요 → SKIP
    IF v_obstacle_owner IS NULL THEN RETURN NEW; END IF;
    IF v_obstacle_owner = NEW.user_id THEN RETURN NEW; END IF;

    -- 좋아요 누른 사람 닉네임 조회
    SELECT COALESCE(nickname, '누군가')
    INTO v_liker_nickname
    FROM user_profiles
    WHERE user_id = NEW.user_id;

    -- is_like = TRUE 일 때만 알림 삽입
    IF NEW.is_like = TRUE THEN
        INSERT INTO notifications (user_id, title, content, type, deeplink_url)
        VALUES (
            v_obstacle_owner,
            '내 제보에 좋아요가 달렸어요 👍',
            v_liker_nickname || '님이 ''' || COALESCE(v_obstacle_type, '제보') || ''' 글을 좋아합니다.',
            'like',
            '/community/' || NEW.obstacle_id::TEXT
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_like ON likes;
CREATE TRIGGER trg_notify_on_like
    AFTER INSERT OR UPDATE ON likes
    FOR EACH ROW
    EXECUTE FUNCTION notify_on_like();

-- ================================================================
-- 6. 댓글 작성 시 → 제보 작성자에게 'comment' 알림 자동 생성
--    자기 자신의 글에 댓글은 알림 제외
-- ================================================================
CREATE OR REPLACE FUNCTION notify_on_comment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_obstacle_owner UUID;
    v_commenter_nick TEXT;
    v_obstacle_type  TEXT;
    v_preview        TEXT;
BEGIN
    -- 제보 작성자 조회
    SELECT reported_by::UUID, obstacle_type
    INTO v_obstacle_owner, v_obstacle_type
    FROM obstacles
    WHERE id = NEW.obstacle_id;

    IF v_obstacle_owner IS NULL THEN RETURN NEW; END IF;
    IF v_obstacle_owner = NEW.user_id THEN RETURN NEW; END IF;

    -- 댓글 작성자 닉네임 조회
    SELECT COALESCE(nickname, '누군가')
    INTO v_commenter_nick
    FROM user_profiles
    WHERE user_id = NEW.user_id;

    -- 댓글 미리보기 (30자 제한)
    v_preview := LEFT(COALESCE(NEW.content, ''), 30);
    IF LENGTH(COALESCE(NEW.content, '')) > 30 THEN
        v_preview := v_preview || '...';
    END IF;

    INSERT INTO notifications (user_id, title, content, type, deeplink_url)
    VALUES (
        v_obstacle_owner,
        '내 제보에 댓글이 달렸어요 💬',
        v_commenter_nick || '님: "' || v_preview || '"',
        'comment',
        '/community/' || NEW.obstacle_id::TEXT
    );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_comment ON comments;
CREATE TRIGGER trg_notify_on_comment
    AFTER INSERT ON comments
    FOR EACH ROW
    EXECUTE FUNCTION notify_on_comment();
-- ================================================================
-- 7. 수정 요청 시 → 제보 작성자에게 'edit_request' 알림 자동 생성
--    자기 자신의 글에 대한 수정 요청은 알림 제외
-- ================================================================
CREATE OR REPLACE FUNCTION notify_on_edit_request()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_obstacle_owner UUID;
    v_requester_nick TEXT;
    v_obstacle_type  TEXT;
BEGIN
    -- 제보 작성자 조회
    SELECT reported_by::UUID, obstacle_type
    INTO v_obstacle_owner, v_obstacle_type
    FROM obstacles
    WHERE id = NEW.obstacle_id;

    IF v_obstacle_owner IS NULL THEN RETURN NEW; END IF;
    IF v_obstacle_owner = NEW.requester_id THEN RETURN NEW; END IF;

    -- 요청자 닉네임 조회
    SELECT COALESCE(nickname, '누군가')
    INTO v_requester_nick
    FROM user_profiles
    WHERE user_id = NEW.requester_id;

    INSERT INTO notifications (user_id, title, content, type, deeplink_url)
    VALUES (
        v_obstacle_owner,
        '내 제보에 수정 요청이 등록되었어요 📝',
        v_requester_nick || '님이 ''' || COALESCE(v_obstacle_type, '제보') || ''' 글에 수정을 요청했습니다.',
        'edit_request',
        '/community/' || NEW.obstacle_id::TEXT
    );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_edit_request ON edit_requests;
CREATE TRIGGER trg_notify_on_edit_request
    AFTER INSERT ON edit_requests
    FOR EACH ROW
    EXECUTE FUNCTION notify_on_edit_request();

-- ================================================================
-- [8] user_profiles 테이블 컬럼 추가 (점수)
--     role 컬럼은 파일 상단 obstacles RLS 직전에 ADD 됨.
-- ================================================================
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS score INTEGER DEFAULT 0;

-- ================================================================
-- [8] score_logs 테이블 생성 (점수 획득 이력 저장)
-- ================================================================
CREATE TABLE IF NOT EXISTS score_logs (
    log_id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    obstacle_id UUID REFERENCES obstacles(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL, -- 'report_created', 'report_liked'
    score_change INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_score_logs_user_id ON score_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_score_logs_action ON score_logs(obstacle_id, action_type);

-- ================================================================
-- [9] 함수: 점수에 따른 레벨 갱신
-- ================================================================
CREATE OR REPLACE FUNCTION update_user_level_and_score(p_user_id UUID, p_score_change INTEGER)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_new_score INTEGER;
    v_new_level INTEGER;
BEGIN
    -- 현재 점수에 추가
    UPDATE user_profiles
    SET score = COALESCE(score, 0) + p_score_change
    WHERE user_id = p_user_id
    RETURNING score INTO v_new_score;

    -- 점수에 따른 레벨 계산
    -- Lv.0: 0~9, Lv.1: 10~49, Lv.2: 50~149, Lv.3: 150~299, Lv.4: 300~499, Lv.5: 500~
    IF v_new_score >= 500 THEN
        v_new_level := 5;
    ELSIF v_new_score >= 300 THEN
        v_new_level := 4;
    ELSIF v_new_score >= 150 THEN
        v_new_level := 3;
    ELSIF v_new_score >= 50 THEN
        v_new_level := 2;
    ELSIF v_new_score >= 10 THEN
        v_new_level := 1;
    ELSE
        v_new_level := 0;
    END IF;

    -- 레벨 갱신
    UPDATE user_profiles
    SET report_level = v_new_level
    WHERE user_id = p_user_id;
END;
$$;

-- ================================================================
-- [10] 트리거: 제보 등록 시 점수 부여 (+10점)
-- ================================================================
CREATE OR REPLACE FUNCTION award_score_on_report()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NEW.reported_by IS NOT NULL THEN
        -- 1. 로그 기록
        INSERT INTO score_logs(user_id, obstacle_id, action_type, score_change)
        VALUES (NEW.reported_by::UUID, NEW.id, 'report_created', 10);
        
        -- 2. 점수 및 레벨 갱신
        PERFORM update_user_level_and_score(NEW.reported_by::UUID, 10);
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_score_on_report ON obstacles;
CREATE TRIGGER trg_score_on_report
    AFTER INSERT ON obstacles
    FOR EACH ROW
    EXECUTE FUNCTION award_score_on_report();

-- ================================================================
-- [11] 트리거: 좋아요 10개 달성 시 점수 부여 (+20점, 1회 한정)
-- ================================================================
CREATE OR REPLACE FUNCTION award_score_on_likes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_obstacle_owner UUID;
    v_like_count INTEGER;
    v_already_awarded BOOLEAN;
BEGIN
    -- 삭제/취소가 아닌 '좋아요 추가' 상태인지 확인
    IF NEW.is_like = false THEN
        RETURN NEW;
    END IF;

    -- 제보 작성자 조회
    SELECT reported_by::UUID
    INTO v_obstacle_owner
    FROM obstacles
    WHERE id = NEW.obstacle_id;

    IF v_obstacle_owner IS NULL THEN RETURN NEW; END IF;

    -- 제보의 총 좋아요 개수 계산
    SELECT COUNT(*) INTO v_like_count
    FROM likes
    WHERE obstacle_id = NEW.obstacle_id AND is_like = true;

    -- 10개 단위 달성 여부가 아니라, "최초 10개 달성 시 1회 보너스"인지 확인
    IF v_like_count >= 10 THEN
        -- 이미 해당 제보로 좋아요 점수를 받았는지 확인
        SELECT EXISTS (
            SELECT 1 FROM score_logs
            WHERE obstacle_id = NEW.obstacle_id
              AND action_type = 'report_liked_bonus'
        ) INTO v_already_awarded;

        -- 보상을 받은 적이 없으면 점수 지급
        IF v_already_awarded = false THEN
            INSERT INTO score_logs(user_id, obstacle_id, action_type, score_change)
            VALUES (v_obstacle_owner, NEW.obstacle_id, 'report_liked_bonus', 20);

            PERFORM update_user_level_and_score(v_obstacle_owner, 20);
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_score_on_likes ON likes;
CREATE TRIGGER trg_score_on_likes
    AFTER INSERT OR UPDATE ON likes
    FOR EACH ROW
    EXECUTE FUNCTION award_score_on_likes();

-- ================================================================
-- [12] 트리거: 싫어요 5개 누적 시 장애물 자동 비활성화
-- ================================================================
CREATE OR REPLACE FUNCTION deactivate_obstacle_on_dislikes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_dislike_count INTEGER;
BEGIN
    -- '싫어요 추가' 상태인지 확인 (is_like = false)
    IF NEW.is_like = true THEN
        RETURN NEW;
    END IF;

    -- 제보의 총 싫어요 개수 계산
    SELECT COUNT(*) INTO v_dislike_count
    FROM likes
    WHERE obstacle_id = NEW.obstacle_id AND is_like = false;

    -- 싫어요가 5개 이상이면 해당 장애물을 비활성화
    IF v_dislike_count >= 5 THEN
        UPDATE obstacles
        SET is_active = false
        WHERE id = NEW.obstacle_id AND is_active = true;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_deactivate_on_dislikes ON likes;
CREATE TRIGGER trg_deactivate_on_dislikes
    AFTER INSERT OR UPDATE ON likes
    FOR EACH ROW
    EXECUTE FUNCTION deactivate_obstacle_on_dislikes();

-- ================================================================
-- [13] 주행 중 장애물 존재 여부 검증 (obstacle_verifications)
-- ================================================================
CREATE TABLE IF NOT EXISTS obstacle_verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    obstacle_id UUID NOT NULL REFERENCES obstacles(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL, -- 'exists'(존재함), 'missing'(사라짐)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, obstacle_id)
);

ALTER TABLE obstacle_verifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "verifications_read_all" ON obstacle_verifications FOR SELECT USING (true);
CREATE POLICY "verifications_insert_own" ON obstacle_verifications FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "verifications_update_own" ON obstacle_verifications FOR UPDATE USING (auth.uid() = user_id);

-- '사라짐(missing)' 3회 누적 시 비활성화 트리거
CREATE OR REPLACE FUNCTION deactivate_obstacle_on_missing()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_missing_count INTEGER;
BEGIN
    -- 상태가 'missing'일 때만 검사
    IF NEW.status != 'missing' THEN
        RETURN NEW;
    END IF;

    -- 해당 장애물의 'missing' 개수 계산
    SELECT COUNT(*) INTO v_missing_count
    FROM obstacle_verifications
    WHERE obstacle_id = NEW.obstacle_id AND status = 'missing';

    -- 3회 이상이면 비활성화
    IF v_missing_count >= 3 THEN
        UPDATE obstacles
        SET is_active = false
        WHERE id = NEW.obstacle_id AND is_active = true;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_deactivate_on_missing ON obstacle_verifications;
CREATE TRIGGER trg_deactivate_on_missing
    AFTER INSERT OR UPDATE ON obstacle_verifications
    FOR EACH ROW
    EXECUTE FUNCTION deactivate_obstacle_on_missing();
