package com.example.gilbeot

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "GilbeotOAuth"
        private const val CHANNEL = "com.example.gilbeot/oauth"
        private const val EVENT_CHANNEL = "com.example.gilbeot/oauth_events"
        private const val AUTH_HOST = "auth"
        private const val AUTH_SCHEME = "com.example.gilbeot"

        @Volatile
        var pendingAuthUri: String? = null
            private set

        @Volatile
        var authUriEventSink: EventChannel.EventSink? = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent?.data?.let { uri ->
            if (uri.scheme == AUTH_SCHEME && uri.host == AUTH_HOST && uri.getQueryParameter("code") != null) {
                val uriStr = uri.toString()
                pendingAuthUri = uriStr
                Log.d(TAG, "onCreate: pendingAuthUri set (code=${uri.getQueryParameter("code")?.take(8)}...)")
                authUriEventSink?.success(uriStr)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getPendingAuthUri") {
                val uri = pendingAuthUri
                pendingAuthUri = null
                result.success(uri)
            } else {
                result.notImplemented()
            }
        }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    authUriEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    authUriEventSink = null
                }
            }
        )
    }

    override fun onNewIntent(intent: Intent) {
        intent.data?.let { uri ->
            if (uri.scheme == AUTH_SCHEME && uri.host == AUTH_HOST && uri.getQueryParameter("code") != null) {
                val uriStr = uri.toString()
                pendingAuthUri = uriStr
                Log.d(TAG, "onNewIntent: pendingAuthUri set (code=${uri.getQueryParameter("code")?.take(8)}...)")
                Handler(Looper.getMainLooper()).postDelayed({
                    val sink = authUriEventSink
                    if (sink != null) {
                        sink.success(uriStr)
                        Log.d(TAG, "onNewIntent: EventChannel로 URI 전송 완료")
                    }
                }, 350)
            }
        }
        super.onNewIntent(intent)
        setIntent(intent)
    }
}
