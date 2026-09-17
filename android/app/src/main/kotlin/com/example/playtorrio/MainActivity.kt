package com.example.playtorrio

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.playtorrio/power"
    private var wifiLock: WifiManager.WifiLock? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var cloudStreamBridge: CloudStreamNativeBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        cloudStreamBridge = CloudStreamNativeBridge(applicationContext, this).apply {
            register(flutterEngine)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquireLocks" -> {
                    try {
                        // 1. High-Performance Low-Latency Wi-Fi Lock
                        if (wifiLock == null) {
                            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                            val lockMode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                WifiManager.WIFI_MODE_FULL_LOW_LATENCY
                            } else {
                                WifiManager.WIFI_MODE_FULL_HIGH_PERF
                            }
                            wifiLock = wifiManager?.createWifiLock(lockMode, "playtorrio:stream_wifi")?.apply {
                                setReferenceCounted(false)
                            }
                        }
                        if (wifiLock?.isHeld == false) {
                            wifiLock?.acquire()
                        }

                        // 2. Partial Wake Lock (prevents CPU sleep during streaming)
                        if (wakeLock == null) {
                            val powerManager = applicationContext.getSystemService(Context.POWER_SERVICE) as? PowerManager
                            wakeLock = powerManager?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "playtorrio:stream_wake")?.apply {
                                setReferenceCounted(false)
                            }
                        }
                        if (wakeLock?.isHeld == false) {
                            wakeLock?.acquire(3 * 60 * 60 * 1000L) // 3 hours timeout safety
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("LOCK_ERROR", e.message, null)
                    }
                }
                "releaseLocks" -> {
                    try {
                        if (wifiLock?.isHeld == true) {
                            wifiLock?.release()
                        }
                        if (wakeLock?.isHeld == true) {
                            wakeLock?.release()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("LOCK_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        try {
            cloudStreamBridge?.destroy()
            if (wifiLock?.isHeld == true) wifiLock?.release()
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Exception) {}
        super.onDestroy()
    }
}