"""
Supabase Database Webhook → FCM 푸시 알림 라우터

Supabase에서 notifications 테이블에 INSERT가 발생하면
이 엔드포인트를 Webhook으로 호출합니다.
"""

import logging
import os
from typing import Any, Optional

from fastapi import APIRouter, Header, HTTPException, Request
from pydantic import BaseModel

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/notifications", tags=["notifications"])

# Supabase Webhook 검증용 시크릿 (선택적 보안 강화)
_WEBHOOK_SECRET = os.getenv("SUPABASE_WEBHOOK_SECRET", "")


class WebhookPayload(BaseModel):
    type: str                        # "INSERT" | "UPDATE" | "DELETE"
    table: str
    record: Optional[dict[str, Any]] = None
    old_record: Optional[dict[str, Any]] = None
    schema: str = "public"


@router.post("/webhook")
async def notification_webhook(
    payload: WebhookPayload,
    request: Request,
    authorization: Optional[str] = Header(None),
):
    """
    Supabase Database Webhook 수신 엔드포인트.
    notifications 테이블 INSERT 이벤트에 연결하세요.
    """
    # 시크릿 검증 (SUPABASE_WEBHOOK_SECRET 설정 시 활성화)
    if _WEBHOOK_SECRET:
        secret = (authorization or "").replace("Bearer ", "").strip()
        if secret != _WEBHOOK_SECRET:
            raise HTTPException(status_code=401, detail="Unauthorized")

    if payload.type != "INSERT" or payload.table != "notifications":
        return {"ok": True, "skipped": True}

    record = payload.record
    if not record:
        return {"ok": True, "skipped": True}

    user_id = record.get("user_id")
    title = record.get("title", "길벗 알림")
    body = record.get("content", "")
    noti_type = record.get("type", "info")

    if not user_id:
        return {"ok": True, "skipped": True, "reason": "user_id 없음"}

    supabase_client = getattr(request.app.state, "supabase_client", None)
    if not supabase_client:
        logger.warning("[Webhook] Supabase 클라이언트 없음 — FCM 발송 불가")
        return {"ok": False, "reason": "supabase_client 없음"}

    try:
        from fcm_sender import send_push_to_user

        success = send_push_to_user(
            supabase_client,
            user_id=user_id,
            title=title,
            body=body,
            data={
                "type": noti_type,
                "notification_id": str(record.get("notification_id", "")),
                "deeplink_url": str(record.get("deeplink_url", "")),
            },
        )
        return {"ok": True, "sent": success}
    except Exception as e:
        logger.error("[Webhook] FCM 발송 중 오류: %s", e)
        return {"ok": False, "error": str(e)}


@router.post("/send")
async def send_notification_directly(
    request: Request,
    body: dict[str, Any],
    authorization: Optional[str] = Header(None),
):
    """
    내부 테스트용: user_id + title + body로 직접 푸시 발송.
    SUPABASE_WEBHOOK_SECRET으로 보호됩니다.
    """
    if _WEBHOOK_SECRET:
        secret = (authorization or "").replace("Bearer ", "").strip()
        if secret != _WEBHOOK_SECRET:
            raise HTTPException(status_code=401, detail="Unauthorized")

    user_id = body.get("user_id")
    title = body.get("title", "길벗 알림")
    content = body.get("body", "")

    if not user_id:
        raise HTTPException(status_code=400, detail="user_id 필수")

    supabase_client = getattr(request.app.state, "supabase_client", None)
    if not supabase_client:
        raise HTTPException(status_code=503, detail="Supabase 클라이언트 없음")

    from fcm_sender import send_push_to_user

    success = send_push_to_user(supabase_client, user_id, title, content)
    return {"ok": True, "sent": success}
