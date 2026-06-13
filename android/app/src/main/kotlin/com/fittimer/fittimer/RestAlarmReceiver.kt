package com.fittimer.fittimer

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.VibrationEffect
import android.os.VibrationAttributes
import android.os.Vibrator
import android.os.VibratorManager
import android.os.PowerManager
import androidx.core.app.NotificationCompat

class RestAlarmReceiver : BroadcastReceiver() {
    companion object {
        const val CHANNEL_ID = "fittimer_reminder_v3"
        const val CHANNEL_NAME = "训练提醒"
        const val NOTIFICATION_ID = 2001
        const val REST_NOTIFICATION_ID = 1001  // 倒计时通知 ID
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val exerciseName = intent?.getStringExtra("exerciseName") ?: "训练"
        android.util.Log.d("VIBRATE", "RestAlarmReceiver.onReceive 被调用, exerciseName=$exerciseName")

        // 获取 WakeLock 确保 CPU 不休眠，震动能执行完毕
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "fittimer:rest_alarm_vibrate"
        )
        wakeLock.acquire(10_000L) // 最多持有 10 秒

        // 先清除倒计时通知
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(REST_NOTIFICATION_ID)
        android.util.Log.d("VIBRATE", "RestAlarmReceiver 已清除倒计时通知")

        try {
            // 震动
            vibrate(context)
            android.util.Log.d("VIBRATE", "RestAlarmReceiver 震动执行成功")
        } catch (e: Exception) {
            android.util.Log.e("VIBRATE", "RestAlarmReceiver 震动失败", e)
        }

        // 音效由前台 Dart 端播放，RestAlarmReceiver 只处理震动和通知

        try {
            // 显示通知（不含声音，声音由上方 MediaPlayer 处理）
            showNotification(context, exerciseName)
            android.util.Log.d("VIBRATE", "RestAlarmReceiver 通知显示成功")
        } catch (e: Exception) {
            android.util.Log.e("VIBRATE", "RestAlarmReceiver 通知失败", e)
        }

        // 震动持续 1.6 秒后释放 WakeLock
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            wakeLock.release()
        }, 2000L)
    }

    private fun playSound(context: Context) {
        // 检查前台是否已播放音效（1秒内）
        val prefs = context.getSharedPreferences("fittimer_prefs", Context.MODE_PRIVATE)
        val soundPlayedAt = prefs.getLong("sound_played_at", 0)
        val elapsed = System.currentTimeMillis() - soundPlayedAt
        if (elapsed < 1000) {
            android.util.Log.d("SOUND", "RestAlarmReceiver 跳过音效：前台已播放 (${elapsed}ms前)")
            return
        }

        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

        // 检查通知音量和媒体音量，任一为0则不播放
        val notifVol = audioManager.getStreamVolume(AudioManager.STREAM_NOTIFICATION)
        val mediaVol = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
        android.util.Log.d("SOUND", "RestAlarmReceiver 音量检查: 通知=$notifVol, 媒体=$mediaVol")
        if (notifVol == 0 || mediaVol == 0) {
            android.util.Log.d("SOUND", "RestAlarmReceiver 音量为0，不播放音效")
            return
        }

        // 使用通知音量流，跟随系统通知音量
        var player: MediaPlayer? = null
        try {
            val afd = context.resources.openRawResourceFd(R.raw.beep_long)
            if (afd != null) {
                player = MediaPlayer()
                player.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
                player.setAudioStreamType(AudioManager.STREAM_NOTIFICATION)
                player.isLooping = false
                player.prepare()
                player.start()
                player.setOnCompletionListener { mp ->
                    mp.release()
                    android.util.Log.d("SOUND", "RestAlarmReceiver 音效播放完毕")
                }
                android.util.Log.d("SOUND", "RestAlarmReceiver 开始播放 beep_long (STREAM_NOTIFICATION)")
            }
        } catch (e: Exception) {
            android.util.Log.e("SOUND", "RestAlarmReceiver MediaPlayer 播放失败", e)
            try { player?.release() } catch (_: Exception) {}
        }
    }

    private fun vibrate(context: Context) {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

        val pattern = longArrayOf(0, 500, 200, 500, 200, 500)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // API 31+: 使用 VibrationAttributes USAGE_ALARM 确保息屏时震动不被抑制
            val attrs = VibrationAttributes.createForUsage(VibrationAttributes.USAGE_ALARM)
            vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1), attrs)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // API 26-30: 使用已弃用的带 AudioAttributes 的重载
            val audioAttrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            @Suppress("DEPRECATION")
            vibrator.vibrate(pattern, -1, audioAttrs)
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(pattern, -1)
        }
    }

    private fun showNotification(context: Context, exerciseName: String) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // 确保渠道存在（IMPORTANCE_LOW + 无声音，音效由 MediaPlayer 单独处理）
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "休息结束震动提醒"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                setSound(null, null)
            }
            notificationManager.createNotificationChannel(channel)
        }

        // 用于启动 MainActivity 的 PendingIntent
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingLaunch = if (launchIntent != null) {
            android.app.PendingIntent.getActivity(
                context, 1, launchIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
        } else null

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("休息结束")
            .setContentText("$exerciseName 准备开始下一组")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setAutoCancel(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setVibrate(longArrayOf(0, 500, 200, 500, 200, 500))
            .setSound(null)
            .setFullScreenIntent(pendingLaunch, true)
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
    }
}
