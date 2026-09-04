package com.slatk.slatkapp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.FileOutputStream

class AdhanService : Service() {
    companion object {
        private const val TAG = "AdhanService"
        const val CHANNEL_ID = "adhan_alarm_ring_v5"
        const val NOTIFICATION_ID = 8888
        const val ACTION_STOP_ADHAN = "com.slatk.slatkapp.STOP_ADHAN"

        @Volatile
        var currentInstance: AdhanService? = null

        fun createNotificationChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

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
    }

    private var mediaPlayer: MediaPlayer? = null
    private var serviceWakeLock: PowerManager.WakeLock? = null
    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        currentInstance = this
        createNotificationChannel(this)
        audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
    }

    private fun safeStartForeground(notification: Notification) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in safeStartForeground (specialUse): ${e.message}", e)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    startForeground(
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK or
                            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                    )
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
            } catch (e2: Exception) {
                Log.e(TAG, "Fallback startForeground failed: ${e2.message}", e2)
                try {
                    startForeground(NOTIFICATION_ID, notification)
                } catch (e3: Exception) {
                    Log.e(TAG, "Ultimate startForeground failed: ${e3.message}", e3)
                }
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP_ADHAN) {
            stopAdhan()
            return START_NOT_STICKY
        }

        val prayerName = intent?.getStringExtra("prayer_name") ?: "الصلاة"
        val prayerTime = intent?.getStringExtra("prayer_time") ?: ""
        val adhanSound = intent?.getStringExtra("adhan_sound")

        val notification = buildAlarmNotification(this, prayerName, prayerTime, adhanSound)
        safeStartForeground(notification)

        acquireServiceWakeLock()

        // NOTE: On Android 12+, startActivity() from a Service is BLOCKED by BAL restrictions.
        // The AdhanRingingActivity is launched by the AlarmManager.AlarmClockInfo operation
        // (an Activity PendingIntent with BAL exemption). We do not attempt startActivity here.
        // If the activity is already showing (e.g. from a previous alarm or app open), it will
        // receive the onNewIntent callback when the AlarmClock fires again.

        playAdhan(prayerName, adhanSound)

        return START_NOT_STICKY
    }

    private fun acquireServiceWakeLock() {
        try {
            if (serviceWakeLock == null) {
                val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                serviceWakeLock = powerManager.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "slatkapp:AdhanServiceWakeLock"
                ).apply {
                    setReferenceCounted(false)
                }
            }
            serviceWakeLock?.acquire(4 * 60 * 1000L) // 4 minutes timeout
        } catch (e: Exception) {
            Log.e(TAG, "Error acquiring service wake lock: ${e.message}")
        }
    }

    private fun releaseServiceWakeLock() {
        try {
            if (serviceWakeLock?.isHeld == true) {
                serviceWakeLock?.release()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing service wake lock: ${e.message}")
        }
    }

    private fun requestAudioFocus() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val playbackAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
                audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                    .setAudioAttributes(playbackAttributes)
                    .setAcceptsDelayedFocusGain(false)
                    .build()
                audioFocusRequest?.let { audioManager?.requestAudioFocus(it) }
            } else {
                @Suppress("DEPRECATION")
                audioManager?.requestAudioFocus(
                    null,
                    AudioManager.STREAM_ALARM,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error requesting audio focus: ${e.message}")
        }
    }

    private fun abandonAudioFocus() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let { audioManager?.abandonAudioFocusRequest(it) }
            } else {
                @Suppress("DEPRECATION")
                audioManager?.abandonAudioFocus(null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error abandoning audio focus: ${e.message}")
        }
    }

    private fun playAdhan(prayerName: String, requestedSound: String?) {
        try {
            val prefs = getSharedPreferences(AdhanScheduler.PREFS_NAME, Context.MODE_PRIVATE)
            val isMuted = prefs.getBoolean("adhan_muted", false) || prefs.getBoolean("adhan_muted_$prayerName", false)
            val soundKey = requestedSound 
                ?: prefs.getString("adhan_sound_$prayerName", null) 
                ?: prefs.getString("selected_adhan_sound", "adhan_makkah") 
                ?: "adhan_makkah"

            if (isMuted || soundKey == "silent" || soundKey == "adhan_none") {
                Log.d(TAG, "Adhan is muted for $prayerName (soundKey=$soundKey). Notification active only.")
                Handler(Looper.getMainLooper()).postDelayed({
                    stopForeground(false)
                    stopSelf()
                }, 15000) // Keep banner visible for 15 seconds
                return
            }

            val rawResId = when (soundKey) {
                "adhan_madina" -> R.raw.adhan_madina
                "adhan_makkah" -> R.raw.adhan_makkah
                "adhan", "adhan_default" -> R.raw.adhan
                else -> {
                    val dynamicId = resources.getIdentifier(soundKey, "raw", packageName)
                    if (dynamicId != 0) dynamicId else R.raw.adhan_makkah
                }
            }

            requestAudioFocus()

            // Ensure alarm volume is audible so the user hears the Adhan
            try {
                val currentVol = audioManager?.getStreamVolume(AudioManager.STREAM_ALARM) ?: 0
                val maxVol = audioManager?.getStreamMaxVolume(AudioManager.STREAM_ALARM) ?: 1
                if (currentVol == 0) {
                    audioManager?.setStreamVolume(AudioManager.STREAM_ALARM, (maxVol * 0.85).toInt().coerceAtLeast(1), 0)
                }
            } catch (e: Exception) {
                Log.w(TAG, "Could not adjust alarm volume: ${e.message}")
            }

            mediaPlayer?.release()
            mediaPlayer = null

            val playbackAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()

            var player: MediaPlayer? = null
            try {
                player = MediaPlayer.create(applicationContext, rawResId, playbackAttributes, 0)
            } catch (e: Exception) {
                Log.e(TAG, "MediaPlayer.create failed for $rawResId: ${e.message}", e)
            }

            // Fallback: if MediaPlayer.create failed (e.g. AAPT compression), load via InputStream to cache file
            if (player == null) {
                try {
                    val cacheFile = File(cacheDir, "adhan_${soundKey}.mp3")
                    if (!cacheFile.exists() || cacheFile.length() < 1000) {
                        resources.openRawResource(rawResId).use { input ->
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
                        Log.d(TAG, "Created MediaPlayer via cache file fallback for $soundKey")
                    }
                } catch (cacheEx: Exception) {
                    Log.e(TAG, "Cache file fallback failed for $soundKey: ${cacheEx.message}", cacheEx)
                }
            }

            if (player == null) {
                try {
                    player = MediaPlayer.create(applicationContext, R.raw.adhan_makkah, playbackAttributes, 0)
                } catch (e: Exception) {
                    Log.e(TAG, "MediaPlayer.create fallback failed: ${e.message}", e)
                }
            }

            if (player == null) {
                try {
                    val fallbackFile = File(cacheDir, "adhan_fallback_makkah.mp3")
                    if (!fallbackFile.exists() || fallbackFile.length() < 1000) {
                        resources.openRawResource(R.raw.adhan_makkah).use { input ->
                            FileOutputStream(fallbackFile).use { output ->
                                input.copyTo(output)
                            }
                        }
                    }
                    if (fallbackFile.exists() && fallbackFile.length() > 1000) {
                        player = MediaPlayer().apply {
                            setAudioAttributes(playbackAttributes)
                            setDataSource(fallbackFile.absolutePath)
                            prepare()
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Final fallback to makkah cache file failed: ${e.message}", e)
                }
            }

            if (player == null) {
                Log.e(TAG, "Could not play any adhan audio resource. Stopping service.")
                stopSelf()
                return
            }

            mediaPlayer = player
            player.setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)
            player.setVolume(1.0f, 1.0f)
            player.start()
            Log.d(TAG, "Adhan MediaPlayer started playing successfully (resId: $rawResId, key: $soundKey)")

            player.setOnCompletionListener {
                Log.d(TAG, "Adhan playback completed naturally")
                stopSelf()
            }

            player.setOnErrorListener { _, what, extra ->
                Log.e(TAG, "MediaPlayer error: what=$what, extra=$extra")
                stopSelf()
                true
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error playing adhan: ${e.message}", e)
            stopSelf()
        }
    }

    private fun stopAdhan() {
        try {
            if (mediaPlayer?.isPlaying == true) {
                mediaPlayer?.stop()
            }
            mediaPlayer?.release()
            mediaPlayer = null
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping adhan: ${e.message}")
        } finally {
            abandonAudioFocus()
            releaseServiceWakeLock()
            stopForeground(true)
            stopSelf()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopAdhan()
        AdhanAlarmReceiver.releaseWakeLock()
        Log.d(TAG, "AdhanService destroyed")
    }
}
