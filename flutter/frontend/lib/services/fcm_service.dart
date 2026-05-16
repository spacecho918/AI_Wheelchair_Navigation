import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gilbeot/screens/community_detail_screen.dart';
import 'package:gilbeot/services/api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 앱이 완전히 종료된 상태에서 수신되는 메시지 핸들러 (top-level 필수)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] 백그라운드 메시지: ${message.messageId}');
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  // main.dart의 navigatorKey를 주입받아 사용
  GlobalKey<NavigatorState>? navigatorKey;

  static const _androidChannel = AndroidNotificationChannel(
    'gilbeot_high_importance',
    '길벗 알림',
    description: '좋아요, 댓글 등 주요 알림',
    importance: Importance.high,
  );

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      await _saveToken();
      return;
    }
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] 권한 상태: ${settings.authorizationStatus}');

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // 백그라운드에서 알림 탭
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleDeeplink(message.data);
    });

    // 앱 종료 상태에서 알림 탭
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      // 앱이 완전히 초기화된 후 이동
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleDeeplink(initial.data);
      });
    }

    await _saveToken();
    _messaging.onTokenRefresh.listen(_uploadToken);
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _handleDeeplink(data);
    } catch (e) {
      debugPrint('[FCM] 로컬 알림 탭 파싱 실패: $e');
    }
  }

  Future<void> _handleDeeplink(Map<String, dynamic> data) async {
    final deeplinkUrl = data['deeplink_url'] as String?;
    if (deeplinkUrl == null || deeplinkUrl.isEmpty) return;

    // /community/{obstacle_id} 형태 파싱
    final match = RegExp(r'^/community/(.+)$').firstMatch(deeplinkUrl);
    if (match == null) return;
    final obstacleId = match.group(1);
    if (obstacleId == null) return;

    try {
      final report = await ApiService.getReportById(obstacleId);
      final context = navigatorKey?.currentContext;
      if (report == null || context == null) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CommunityDetailScreen(report: report),
        ),
      );
    } catch (e) {
      debugPrint('[FCM] 딥링크 이동 실패: $e');
    }
  }

  Future<void> _saveToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _uploadToken(token);
    } catch (e) {
      debugPrint('[FCM] 토큰 저장 실패: $e');
    }
  }

  Future<void> _uploadToken(String token) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.from('user_fcm_tokens').upsert({
        'user_id': user.id,
        'token': token,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      debugPrint('[FCM] 토큰 저장 완료');
    } catch (e) {
      debugPrint('[FCM] 토큰 업로드 실패: $e');
    }
  }

  /// 로그아웃 시 토큰 삭제
  Future<void> deleteToken() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client
            .from('user_fcm_tokens')
            .delete()
            .eq('user_id', user.id);
      }
      await _messaging.deleteToken();
      debugPrint('[FCM] 토큰 삭제 완료');
    } catch (e) {
      debugPrint('[FCM] 토큰 삭제 실패: $e');
    }
  }
}
