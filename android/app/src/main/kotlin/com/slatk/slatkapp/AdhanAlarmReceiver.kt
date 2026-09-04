package com.slatk.slatkapp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.io.File
import java.io.FileOutputStream

class AdhanAlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "AdhanAlarmReceiver"
        const val CHANNEL_ID = "adhan_alarm_ring_v5"
        const val NOTIFICATION_ID = 8888
        const val ACTION_STOP_ADHAN = "com.slatk.slatkapp.STOP_ADHAN"

        private var wakeLock: PowerManager.WakeLock? = null
        private var screenWakeLock: PowerManager.WakeLock? = null
        private var activePlayer: MediaPlayer? = null

        @Suppress("DEPRECATION")
        fun acquireScreenWakeLock(context: Context) {
            try {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                try {
                    if (screenWakeLock?.isHeld == true) {
                        screenWakeLock?.release()
                    }
                } catch (_: Exception) {}

                screenWakeLock = powerManager.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                    PowerManager.ACQUIRE_CAUSES_WAKEUP or
                    PowerManager.ON_AFTER_RELEASE,
                    "slatkapp:AdhanScreenWakeLock"
                ).apply {
                    setReferenceCounted(false)
                }
                screenWakeLock?.acquire(60_000L)
                Log.d(TAG, "AdhanScreenWakeLock (SCREEN_BRIGHT_WAKE_LOCK | ACQUIRE_CAUSES_WAKEUP) acquired")
            } catch (e: Exception) {
                Log.e(TAG, "Error acquiring screen wake lock: ${e.message}", e)
            }
        }

        fun releaseScreenWakeLock() {
            try {
                if (screenWakeLock?.isHeld == true) {
                    screenWakeLock?.release()
                    Log.d(TAG, "AdhanScreenWakeLock released")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error releasing screen wake lock: ${e.message}")
            }
        }

        fun acquireWakeLock(context: Context, timeoutMs: Long = 4 * 60 * 1000L) {
            try {
                if (wakeLock == null) {
                    val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                    wakeLock = powerManager.newWakeLock(
                        PowerManager.PARTIAL_WAKE_LOCK,
                        "slatkapp:AdhanAlarmWakeLock"
                    ).apply {
                        setReferenceCounted(false)
                    }
                }
                wakeLock?.acquire(timeoutMs)
                Log.d(TAG, "AdhanAlarmWakeLock acquired successfully for ${timeoutMs}ms")
            } catch (e: Exception) {
                Log.e(TAG, "Error acquiring wake lock in receiver: ${e.message}", e)
            }
        }

        fun releaseWakeLock() {
            try {
                if (wakeLock?.isHeld == true) {
                    wakeLock?.release()
                    Log.d(TAG, "AdhanAlarmWakeLock released")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error releasing wake lock: ${e.message}")
            }
            releaseScreenWakeLock()
        }

        fun createNotificationChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

                // Clean up any stale channels from earlier versions to force high importance
                try {
                    manager.deleteNotificationChannel("adhan_alarm_playback_channel")
                    manager.deleteNotificationChannel("adhan_alarm_playback_channel_v2")
                    manager.deleteNotificationChannel("adhan_alarm_playback_channel_v3")
                } catch (_: Exception) {}

                val soundUri = android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_ALARM)
                    ?: android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_NOTIFICATION)

                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()

                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "صوت الأذان وشاشة التنبيه",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "تشغيل صوت الأذان وعرض واجهة الصلاة فوق شاشة القفل"
                    setSound(soundUri, audioAttributes)
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 500, 250, 500)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    setBypassDnd(true)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        setAllowBubbles(false)
                    }
                }
                manager.createNotificationChannel(channel)
            }
        }

        fun buildAlarmNotification(context: Context, prayerName: String, prayerTime: String, adhanSound: String? = null): Notification {
            createNotificationChannel(context)

            val ringingIntent = Intent(context, AdhanRingingActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                putExtra("prayer_name", prayerName)
                putExtra("prayer_time", prayerTime)
                if (adhanSound != null) {
                    putExtra("adhan_sound", adhanSound)
                }
            }
            val ringingPendingIntent = PendingIntent.getActivity(
                context,
                7777, // Unique request code for full-screen intent
                ringingIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )

            val stopIntent = Intent(context, AdhanActionReceiver::class.java).apply {
                action = ACTION_STOP_ADHAN
            }
            val stopPendingIntent = PendingIntent.getBroadcast(
                context,
                7778, // Unique request code for stop action
                stopIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )

            val timeSub = if (prayerTime.isNotEmpty()) " ($prayerTime)" else ""
            val soundUri = android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_ALARM)
                ?: android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_NOTIFICATION)

            return NotificationCompat.Builder(context, CHANNEL_ID)
                .setContentTitle("🕌 حان الآن وقت $prayerName$timeSub")
                .setContentText("حي على الصلاة، حي على الفلاح")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentIntent(ringingPendingIntent)
                .setFullScreenIntent(ringingPendingIntent, true)
                .setSound(soundUri, AudioManager.STREAM_ALARM)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setOngoing(true)
                .setAutoCancel(false)
                .setDefaults(NotificationCompat.DEFAULT_VIBRATE or NotificationCompat.DEFAULT_LIGHTS)
                .addAction(
                    android.R.drawable.ic_media_pause,
                    "⏹️ إيقاف الأذان",
                    stopPendingIntent
                )
                .build()
        }

        fun playAdhanAudio(context: Context, prayerName: String, soundKey: String?) {
            try {
                if (soundKey == "silent") {
                    Log.d(TAG, "Adhan is set to silent for $prayerName")
                    return
                }

                val rawResId = when (soundKey) {
                    "adhan_madina" -> R.raw.adhan_madina
                    "adhan_makkah" -> R.raw.adhan_makkah
                    "adhan", "adhan_default" -> R.raw.adhan
                    else -> {
                        val dynamicId = context.resources.getIdentifier(soundKey, "raw", context.packageName)
                        if (dynamicId != 0) dynamicId else R.raw.adhan_makkah
                    }
                }

                // Ensure alarm volume is audible so the user hears the Adhan
                val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                try {
                    val currentVol = audioManager?.getStreamVolume(AudioManager.STREAM_ALARM) ?: 0
                    val maxVol = audioManager?.getStreamMaxVolume(AudioManager.STREAM_ALARM) ?: 1
                    if (currentVol == 0) {
                        audioManager?.setStreamVolume(AudioManager.STREAM_ALARM, (maxVol * 0.85).toInt().coerceAtLeast(1), 0)
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Could not adjust alarm volume: ${e.message}")
                }

                // Stop previous player without releasing wakelock
                try {
                    if (activePlayer?.isPlaying == true) {
                        activePlayer?.stop()
                    }
                    activePlayer?.release()
                    activePlayer = null
                } catch (_: Exception) {}

                // Keep wake lock alive during playback
                acquireWakeLock(context, 4 * 60 * 1000L)

                val playbackAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()

                var player: MediaPlayer? = null
                try {
                    player = MediaPlayer.create(context.applicationContext, rawResId, playbackAttributes, 0)
                } catch (e: Exception) {
                    Log.e(TAG, "MediaPlayer create failed for resId $rawResId: ${e.message}")
                }

                // Fallback via cache file if direct open failed
                if (player == null) {
                    try {
                        val cacheFile = File(context.cacheDir, "adhan_${soundKey}.mp3")
                        if (!cacheFile.exists() || cacheFile.length() < 1000) {
                            context.resources.openRawResource(rawResId).use { input ->
                                FileOutputStream(cacheFile).use { output ->
                                    input.copyTo(output)
                                }
                            }
                        }
                        if (cacheFile.exists() && cacheFile.length() > 1000) {
                            player = MediaPlayer().apply {
                                setAudioAttributes(playbackAttributes)
                                setDataSource(cacheFile.absolutePath)
                                prepare()
                            }
                        }
                    } catch (cacheEx: Exception) {
                        Log.e(TAG, "Cache file fallback failed in receiver: ${cacheEx.message}")
                    }
                }

                if (player == null) {
                    try {
                        player = MediaPlayer.create(context.applicationContext, R.raw.adhan_makkah, playbackAttributes, 0)
                    } catch (e: Exception) {
                        Log.e(TAG, "MediaPlayer fallback to makkah failed: ${e.message}")
                    }
                }

                if (player != null) {
                    activePlayer = player
                    player.setWakeMode(context.applicationContext, PowerManager.PARTIAL_WAKE_LOCK)
                    player.setVolume(1.0f, 1.0f)
                    player.start()
                    Log.d(TAG, "Adhan MediaPlayer started playing successfully (resId: $rawResId, prayer: $prayerName)")

                    player.setOnCompletionListener {
                        Log.d(TAG, "Adhan playback completed naturally")
                        stopPlayback(context)
                    }

                    player.setOnErrorListener { _, what, extra ->
                        Log.e(TAG, "MediaPlayer playback error: what=$what, extra=$extra")
                        stopPlayback(context)
                        true
                    }
                } else {
                    Log.e(TAG, "Failed to create MediaPlayer for Adhan playback")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in playAdhanAudio: ${e.message}", e)
            }
        }

        fun stopPlayback(context: Context? = null) {
            try {
                if (activePlayer?.isPlaying == true) {
                    activePlayer?.stop()
                }
                activePlayer?.release()
                activePlayer = null
                Log.d(TAG, "Adhan playback stopped and released")
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping Adhan playback: ${e.message}")
            } finally {
                if (context != null) {
                    try {
                        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        nm.cancel(NOTIFICATION_ID)
                    } catch (e: Exception) {}
                }
                releaseWakeLock()
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val prayerName = intent.getStringExtra("prayer_name") ?: "الصلاة"
        val prayerTime = intent.getStringExtra("prayer_time") ?: ""
        val adhanSound = intent.getStringExtra("adhan_sound")
        val isTest = intent.getBooleanExtra("is_test", false)

        Log.d(TAG, "=================================================")
        Log.d(TAG, "AdhanAlarmReceiver triggered for: $prayerName ($prayerTime), sound=$adhanSound, isTest=$isTest")
        Log.d(TAG, "=================================================")

        // 1. Keep CPU alive during processing
        acquireWakeLock(context, 30_000L)

        // NOTE: On Android 12+ (API 31+), startActivity() from a BroadcastReceiver is
        // BLOCKED unless the app has a visible window or is granted a BAL exemption.
        // The activity launch is now handled by AlarmManager.setAlarmClock() using an
        // Activity PendingIntent as the operation — this gives the system-granted BAL
        // exemption. We do NOT attempt startActivity() here to avoid crashes/silently
        // dropped launches on Samsung One UI and other OEM ROMs.

        // 2. Post lockscreen notification with fullScreenIntent.
        //    On Android 12+ this is the SECONDARY mechanism (the alarm clock activity
        //    launch is primary). The fullScreenIntent here acts as a fallback in case
        //    the alarm clock PendingIntent did not fire the activity (e.g. DND mode).
        try {
            val notification = buildAlarmNotification(context, prayerName, prayerTime, adhanSound)
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(NOTIFICATION_ID, notification)
            Log.d(TAG, "Adhan lockscreen notification posted successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error posting notification: ${e.message}", e)
        }

        // 3. Start foreground service to play audio and maintain wake lock
        val serviceIntent = Intent(context, AdhanService::class.java).apply {
            putExtra("prayer_name", prayerName)
            putExtra("prayer_time", prayerTime)
            putExtra("adhan_sound", adhanSound)
            putExtra("is_test", isTest)
        }

        var serviceStarted = false
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(context, serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            serviceStarted = true
            Log.d(TAG, "Successfully started AdhanService for $prayerName")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start AdhanService from receiver: ${e.message}. Executing in-receiver fallback.", e)
        }

        // 4. In-receiver audio fallback if foreground service was blocked
        if (!serviceStarted) {
            playAdhanAudio(context, prayerName, adhanSound)
        }

        // 5. Safely reschedule for tomorrow completely offline
        if (!isTest && prayerName != "تجربة الأذان") {
            try {
                val finalTime = if (prayerTime.isNotEmpty()) prayerTime else {
                    val prefs = context.getSharedPreferences(AdhanScheduler.PREFS_NAME, Context.MODE_PRIVATE)
                    prefs.getString("prayer_$prayerName", "") ?: ""
                }
                if (finalTime.isNotEmpty()) {
                    AdhanScheduler.schedulePrayer(context, prayerName, finalTime, null)
                    Log.d(TAG, "Rescheduled $prayerName for tomorrow at $finalTime")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error rescheduling for tomorrow: ${e.message}", e)
            }
        }
    }
}
