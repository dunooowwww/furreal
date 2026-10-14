package com.dun.furreal

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createDailyDropChannel()
    }

    /**
     * Channel prioritas tinggi untuk notifikasi daily drop (PRD §6.2). Id-nya sama
     * dengan `channel_id` yang dikirim send-daily-drop dan meta-data di manifest.
     */
    private fun createDailyDropChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            DAILY_DROP_CHANNEL,
            getString(R.string.daily_drop_channel_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = getString(R.string.daily_drop_channel_description)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private companion object {
        const val DAILY_DROP_CHANNEL = "daily_drop"
    }
}
