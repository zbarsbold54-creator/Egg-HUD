package com.jarvis.brain_app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.jarvis.brain_app/multicast")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquire" -> {
                        try {
                            if (multicastLock == null) {
                                val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                                multicastLock = wifi.createMulticastLock("jarvis_mdns").apply {
                                    setReferenceCounted(false)
                                }
                            }
                            multicastLock?.acquire()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("MULTICAST", e.message, null)
                        }
                    }
                    "release" -> {
                        try {
                            multicastLock?.let { if (it.isHeld) it.release() }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("MULTICAST", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.jarvis.brain_app/battery")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestExemption" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= 23) {
                                val intent = android.content.Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                                intent.data = android.net.Uri.parse("package:$packageName")
                                startActivity(intent)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("BATTERY", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.jarvis.brain_app/volume")
            .setMethodCallHandler { call, result ->
                val audio = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
                when (call.method) {
                    "get" -> result.success(audio.getStreamVolume(android.media.AudioManager.STREAM_MUSIC).toFloat() / audio.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC))
                    "set" -> {
                        val v = call.argument<Float>("value") ?: 0.5f
                        val max = audio.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC)
                        audio.setStreamVolume(android.media.AudioManager.STREAM_MUSIC, (v * max).toInt(), 0)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.jarvis.brain_app/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "request" -> {
                        if (Build.VERSION.SDK_INT >= 33) {
                            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                                result.success(true)
                            } else {
                                ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
                                result.success(false)
                            }
                        } else {
                            result.success(true)
                        }
                    }
                    "check" -> {
                        if (Build.VERSION.SDK_INT >= 33) {
                            result.success(ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED)
                        } else {
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        try {
            multicastLock?.let { if (it.isHeld) it.release() }
        } catch (_: Exception) {
        }
        super.onDestroy()
    }
}
