"""
Firebase Cloud Messaging (FCM) 푸시 알림 발송 유틸리티
"""

import logging
import os
from typing import Optional

logger = logging.getLogger(__name__)

_fcm_initialized = False


def _init_firebase():
    global _fcm_initialized
    if _fcm_initialized:
        return True
    try:
        import firebase_admin
        from firebase_admin import credentials

        cred_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_KEY", "")
        if not cred_path or not os.path.exists(cred_path):
            logger.warning("[FCM] FIREBASE_SERVICE_ACCOUNT_KEY 파일이 없습니다: %s", cred_path)
            return False

        if not firebase_admin._apps:
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)

        _fcm_initialized = True
        logger.info("[FCM] Firebase Admin SDK 초기화 완료")
        return True
    except Exception as e:
        logger.error("[FCM] Firebase Admin SDK 초기화 실패: %s", e)
        return False


def send_push_notification(
    fcm_token: str,
    title: str,
    body: str,
    data: Optional[dict] = None,
) -> bool:
    """FCM 토큰으로 푸시 알림 발송. 성공 시 True 반환."""
    if not _init_firebase():
        return False
    try:
        from firebase_admin import messaging

        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
            token=fcm_token,
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="gilbeot_high_importance",
                    sound="default",
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound="default"),
                ),
            ),
        )
        messaging.send(message)
        logger.info("[FCM] 알림 발송 성공 → token: %s…", fcm_token[:20])
        return True
    except Exception as e:
        logger.error("[FCM] 알림 발송 실패: %s", e)
        return False


def send_push_to_user(
    supabase_client,
    user_id: str,
    title: str,
    body: str,
    data: Optional[dict] = None,
) -> bool:
    """user_id로 FCM 토큰을 조회한 뒤 푸시 알림 발송."""
    try:
        res = (
            supabase_client.table("user_fcm_tokens")
            .select("token")
            .eq("user_id", user_id)
            .single()
            .execute()
        )
        token = res.data.get("token") if res.data else None
        if not token:
            logger.info("[FCM] user_id=%s 의 FCM 토큰 없음 (알림 생략)", user_id)
            return False
        return send_push_notification(token, title, body, data)
    except Exception as e:
        logger.warning("[FCM] 토큰 조회 실패 (user_id=%s): %s", user_id, e)
        return False
