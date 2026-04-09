-- 길벗 휠체어 내비게이션 - 스키마 참조용 (Context only)
-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

-- 1. comments 테이블: 장애물(obstacles) 게시글 댓글
CREATE TABLE public.comments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  obstacle_id uuid NOT NULL,
  user_id uuid NOT NULL,
  content text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT comments_pkey PRIMARY KEY (id),
  CONSTRAINT comments_obstacle_id_fkey FOREIGN KEY (obstacle_id) REFERENCES public.obstacles(id),
  CONSTRAINT comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);

-- 2. drive_logs 테이블: 주행 기록
CREATE TABLE public.drive_logs (
  drive_log_id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  start_lat double precision NOT NULL,
  start_lon double precision NOT NULL,
  end_lat double precision NOT NULL,
  end_lon double precision NOT NULL,
  duration_sec integer NOT NULL,              -- 주행 시간 (초)
  started_at timestamp with time zone NOT NULL,
  ended_at timestamp with time zone NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  start_label text NOT NULL,
  end_label text NOT NULL,
  start_place_id text,
  end_place_id text,
  distance_km numeric NOT NULL CHECK (distance_km >= 0::numeric),  -- 거리 (km)
  CONSTRAINT drive_logs_pkey PRIMARY KEY (drive_log_id),
  CONSTRAINT drive_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_profiles(user_id)
);

-- 3. edges 테이블: 사전 계산된 경사도 데이터
CREATE TABLE public.edges (
  id integer NOT NULL DEFAULT nextval('edges_id_seq'::regclass),
  edge_id character varying NOT NULL UNIQUE,   -- "시작노드_끝노드_키" 형식
  start_node_id bigint NOT NULL,
  end_node_id bigint NOT NULL,
  start_lat double precision NOT NULL,
  start_lon double precision NOT NULL,
  end_lat double precision NOT NULL,
  end_lon double precision NOT NULL,
  length double precision DEFAULT 0,          -- 거리 (m)
  grade double precision DEFAULT 0,           -- 대표 경사도 (도)
  max_grade double precision DEFAULT 0,       -- 최대 경사도 (도)
  min_grade double precision DEFAULT 0,       -- 최소 경사도 (도)
  avg_grade double precision DEFAULT 0,       -- 평균 경사도 (도)
  grade_segments integer DEFAULT 0,           -- 측정 구간 수
  elevation_start double precision DEFAULT 0, -- 시작점 고도 (m)
  elevation_end double precision DEFAULT 0,   -- 끝점 고도 (m)
  elevation_max double precision DEFAULT 0,   -- 최대 고도 (m)
  elevation_min double precision DEFAULT 0,   -- 최소 고도 (m)
  total_ascent double precision DEFAULT 0,    -- 총 오르막 (m)
  total_descent double precision DEFAULT 0,   -- 총 내리막 (m)
  surface_type character varying DEFAULT 'paved'::character varying,  -- 노면 타입
  surface_penalty double precision DEFAULT 1.0,
  highway_type character varying DEFAULT 'unknown'::character varying, -- 도로 타입
  is_wheelchair_accessible boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT edges_pkey PRIMARY KEY (id)
);

-- 4. edit_requests 테이블: 장애물(obstacles) 수정 요청
CREATE TABLE public.edit_requests (
  edit_request_id uuid NOT NULL DEFAULT gen_random_uuid(),
  obstacle_id uuid NOT NULL,
  requester_id uuid NOT NULL,
  photo_url text,
  description text,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])),  -- pending / approved / rejected
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  reviewed_at timestamp with time zone,
  reason text NOT NULL CHECK (reason = ANY (ARRAY['resolved'::text, 'obstacle_error'::text, 'location_error'::text, 'other'::text])),  -- 수정 사유
  new_lat double precision,
  new_lon double precision,
  CONSTRAINT edit_requests_pkey PRIMARY KEY (edit_request_id),
  CONSTRAINT fk_edit_user FOREIGN KEY (requester_id) REFERENCES public.user_profiles(user_id),
  CONSTRAINT fk_edit_obstacle FOREIGN KEY (obstacle_id) REFERENCES public.obstacles(id)
);

-- 5. favorites 테이블: 즐겨찾기 장소
CREATE TABLE public.favorites (
  favorite_id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  place_name text NOT NULL,
  address text,
  lat double precision NOT NULL,
  lon double precision NOT NULL,
  icon_type text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  place_id text NOT NULL,
  place_type text NOT NULL,
  CONSTRAINT favorites_pkey PRIMARY KEY (favorite_id),
  CONSTRAINT favorites_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_profiles(user_id)
);

-- 6. likes 테이블: 커뮤니티(obstacles) 게시글 좋아요/싫어요
CREATE TABLE public.likes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  obstacle_id uuid NOT NULL,
  is_like boolean NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT likes_pkey PRIMARY KEY (id),
  CONSTRAINT likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT likes_obstacle_id_fkey FOREIGN KEY (obstacle_id) REFERENCES public.obstacles(id)
);

-- 7. notifications 테이블: 알림
CREATE TABLE public.notifications (
  notification_id bigint NOT NULL DEFAULT nextval('notifications_notification_id_seq'::regclass),
  user_id uuid NOT NULL,
  title text NOT NULL,
  content text NOT NULL,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  type text NOT NULL DEFAULT 'system_notice'::text,
  deeplink_url text,
  CONSTRAINT notifications_pkey PRIMARY KEY (notification_id),
  CONSTRAINT fk_notifications_user_profiles FOREIGN KEY (user_id) REFERENCES public.user_profiles(user_id)
);

-- 8. obstacles 테이블: 장애물 데이터
CREATE TABLE public.obstacles (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  obstacle_type character varying NOT NULL,  -- "stairs", "construction", "pothole" 등
  description text DEFAULT ''::text,
  radius double precision DEFAULT 15.0,       -- 영향 반경 (m)
  severity character varying DEFAULT 'high'::character varying,  -- "low", "medium", "high"
  is_active boolean DEFAULT true,
  reported_by character varying,             -- 제보자 ID
  image_url text,                             -- YOLOv8 처리된 이미지 URL
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT obstacles_pkey PRIMARY KEY (id)
);

-- 9. posts 테이블: (레거시, 현재는 obstacles 사용)
CREATE TABLE public.posts (
  post_id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  title text NOT NULL,
  post_content text NOT NULL,
  post_image_url text,
  like_count integer NOT NULL DEFAULT 0 CHECK (like_count >= 0),
  comment_count integer NOT NULL DEFAULT 0 CHECK (comment_count >= 0),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  address text,
  lat double precision NOT NULL,
  lon double precision NOT NULL,
  dislike_count integer NOT NULL DEFAULT 0 CHECK (dislike_count >= 0),
  CONSTRAINT posts_pkey PRIMARY KEY (post_id),
  CONSTRAINT posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_profiles(user_id)
);

-- 10. recent_searches 테이블: 최근 검색 기록
CREATE TABLE public.recent_searches (
  recent_search_id bigint NOT NULL DEFAULT nextval('recent_searches_recent_search_id_seq'::regclass),
  user_id uuid NOT NULL,
  place_id text NOT NULL,
  place_name text NOT NULL,
  lat double precision NOT NULL CHECK (lat >= '-90'::integer::double precision AND lat <= 90::double precision),
  lon double precision NOT NULL CHECK (lon >= '-180'::integer::double precision AND lon <= 180::double precision),
  searched_at timestamp with time zone NOT NULL DEFAULT now(),
  icon_type text,
  address text,
  CONSTRAINT recent_searches_pkey PRIMARY KEY (recent_search_id),
  CONSTRAINT recent_searches_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_profiles(user_id)
);

-- 11. user_profiles 테이블: 사용자 프로필
CREATE TABLE public.user_profiles (
  user_id uuid NOT NULL,
  wheelchair_type text NOT NULL CHECK (wheelchair_type = ANY (ARRAY['electric'::text, 'manual'::text, 'assisted_manual'::text, 'none'::text])),  -- electric / manual / assisted_manual / none
  nickname text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  name text NOT NULL,
  report_level integer NOT NULL DEFAULT 0 CHECK (report_level >= 0),  -- 제보 레벨
  profile_image_url text,
  role text NOT NULL DEFAULT 'user'::text CHECK (role = ANY (ARRAY['user'::text, 'admin'::text])),  -- 일반 / 관리자
  CONSTRAINT user_profiles_pkey PRIMARY KEY (user_id),
  CONSTRAINT user_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);

-- -----------------------------------------------------------------
-- 참고: public.obstacles RLS (실제 DB는 algorithm_server/supabase_schema.sql 기준)
-- - obstacles_read_all: SELECT USING (true)
-- - obstacles_insert_auth: INSERT WITH CHECK (true)
-- - obstacles_delete_own_or_admin: DELETE — reported_by = auth.uid()::text OR is_admin()
-- - obstacles_update_own_or_admin: UPDATE — 동일 USING / WITH CHECK
-- - public.is_admin(): user_profiles에서 현재 사용자(auth.uid()) 행의 role = 'admin' 판별 (SECURITY DEFINER)
-- -----------------------------------------------------------------
