package com.fittimer.fittimer

import android.app.*
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class RestTimerService : Service() {
    companion object {
        const val CHANNEL_ID = "rest_timer_channel"
        const val NOTIFICATION_ID = 1
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.getStringExtra("action")
        if (action == "stop") {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        val exerciseName = intent?.getStringExtra("exerciseName") ?: "训练"
        val seconds = intent?.getIntExtra("seconds", 0) ?: 0

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("休息倒计时")
            .setContentText("$exerciseName · ${seconds}秒")
            .setSmallIcon(android.R.drawable.ic_media_pause)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        startForeground(NOTIFICATION_ID, notification)
        return START_NOT_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "休息计时器",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "显示休息倒计时通知"
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
