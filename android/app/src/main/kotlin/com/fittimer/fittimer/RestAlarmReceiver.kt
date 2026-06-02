package com.fittimer.fittimer

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
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
        const val CHANNEL_ID = "fittimer_reminder_v2"
        const val CHANNEL_NAME = "训练提醒"
        const val NOTIFICATION_ID = 2001
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

        try {
            // 震动
            vibrate(context)
            android.util.Log.d("VIBRATE", "RestAlarmReceiver 震动执行成功")
        } catch (e: Exception) {
            android.util.Log.e("VIBRATE", "RestAlarmReceiver 震动失败", e)
        }

        try {
            // 显示通知
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

        val audioAttrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        // 确保渠道存在
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "休息结束震动提醒"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500)
                setBypassDnd(true)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM), audioAttrs)
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
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setVibrate(longArrayOf(0, 500, 200, 500, 200, 500))
            .setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))
            .setFullScreenIntent(pendingLaunch, true)
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
    }
}
