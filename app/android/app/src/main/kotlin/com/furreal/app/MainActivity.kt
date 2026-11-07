package com.furreal.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createChannels()
    }

    /**
     * Channel notifikasi. Id-nya sama dengan `channel_id` yang dikirim Edge
     * Function: daily drop (send-daily-drop, prioritas tinggi, PRD §6.2) dan
     * "teman udah catch" (notify-catch, M10), reaksi & komentar dan pengingat
     * streak (send-activity, M14). User bisa mematikan masing-masing.
     */
    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                DAILY_DROP_CHANNEL,
                getString(R.string.daily_drop_channel_name),
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = getString(R.string.daily_drop_channel_description)
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                FRIEND_CATCH_CHANNEL,
                getString(R.string.friend_catch_channel_name),
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = getString(R.string.friend_catch_channel_description)
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                ACTIVITY_CHANNEL,
                getString(R.string.activity_channel_name),
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = getString(R.string.activity_channel_description)
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                STREAK_CHANNEL,
                getString(R.string.streak_channel_name),
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = getString(R.string.streak_channel_description)
            },
        )
    }

    private companion object {
        const val DAILY_DROP_CHANNEL = "daily_drop"
        const val FRIEND_CATCH_CHANNEL = "friend_catch"
        const val ACTIVITY_CHANNEL = "activity"
        const val STREAK_CHANNEL = "streak_reminder"
    }
}
