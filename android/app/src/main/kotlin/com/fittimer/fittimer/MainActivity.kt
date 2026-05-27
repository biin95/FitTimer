package com.fittimer.fittimer

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val VIBRATE_CHANNEL = "com.fittimer/vibrate"
    private val REST_SERVICE_CHANNEL = "com.fittimer/rest_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VIBRATE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "vibrate" -> {
                        try {
                            val durationMs = call.argument<Number>("duration")?.toLong() ?: 3000L
                            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                val vibratorManager =
                                    getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                                vibratorManager.defaultVibrator
                            } else {
                                @Suppress("DEPRECATION")
                                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                            }
                            
                            // Try 1: VibrationEffect.createOneShot (API 26+)
                            try {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                    vibrator.vibrate(
                                        VibrationEffect.createOneShot(
                                            durationMs,
                                            VibrationEffect.DEFAULT_AMPLITUDE
                                        )
                                    )
                                } else {
                                    @Suppress("DEPRECATION")
                                    vibrator.vibrate(durationMs)
                                }
                            } catch (e: Exception) {
                                // Try 2: Fallback to deprecated vibrate()
                                try {
                                    @Suppress("DEPRECATION")
                                    vibrator.vibrate(durationMs)
                                } catch (e2: Exception) {
                                    // Try 3: Use haptic feedback via view
                                    runOnUiThread {
                                        window.decorView.performHapticFeedback(
                                            android.view.HapticFeedbackConstants.LONG_PRESS
                                        )
                                    }
                                }
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("VIBRATE_FAILED", e.message, null)
                        }
                    }
                    "cancel" -> {
                        val vibrator =
                            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                        vibrator.cancel()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, REST_SERVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val exerciseName = call.argument<String>("exerciseName") ?: "训练"
                        val seconds = call.argument<Int>("seconds") ?: 0
                        val intent = Intent(this, RestTimerService::class.java).apply {
                            putExtra("exerciseName", exerciseName)
                            putExtra("seconds", seconds)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                    "stop" -> {
                        val intent = Intent(this, RestTimerService::class.java).apply {
                            putExtra("action", "stop")
                        }
                        startService(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
