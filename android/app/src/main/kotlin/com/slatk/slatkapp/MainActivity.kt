package com.slatk.slatkapp

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.slatk.slatkapp/adhan"
    private var previewPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "schedulePrayer" -> {
                    val prayerName = call.argument<String>("prayerName")
                    val timeStr = call.argument<String>("timeStr")
                    val soundKey = call.argument<String>("soundKey")
                    if (prayerName != null && timeStr != null) {
                        AdhanScheduler.schedulePrayer(applicationContext, prayerName, timeStr, soundKey)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "prayerName and timeStr required", null)
                    }
                }
                "cancelPrayer" -> {
                    val prayerName = call.argument<String>("prayerName")
                    if (prayerName != null) {
                        AdhanScheduler.cancelPrayer(applicationContext, prayerName)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "prayerName required", null)
                    }
                }
                "scheduleAll" -> {
                    val prayers = call.argument<Map<String, String>>("prayers")
                    val enabledMap = call.argument<Map<String, Boolean>>("enabled") ?: emptyMap()
                    val soundsMap = call.argument<Map<String, String>>("sounds") ?: emptyMap()
                    if (prayers != null) {
                        for ((name, time) in prayers) {
                            val isEnabled = enabledMap[name] ?: (name != "الشروق")
                            val sound = soundsMap[name]
                            if (isEnabled) {
                                AdhanScheduler.schedulePrayer(applicationContext, name, time, sound)
                            } else {
                                AdhanScheduler.cancelPrayer(applicationContext, name)
                            }
                        }
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "prayers map required", null)
                    }
                }
                "setAdhanSound" -> {
                    val soundKey = call.argument<String>("soundKey") ?: "adhan_makkah"
                    val prayerName = call.argument<String>("prayerName")
                    val prefs = getSharedPreferences(AdhanScheduler.PREFS_NAME, Context.MODE_PRIVATE)
                    val editor = prefs.edit()
                    if (prayerName != null && prayerName.isNotEmpty()) {
                        editor.putString("adhan_sound_$prayerName", soundKey)
                    } else {
                        editor.putString("selected_adhan_sound", soundKey)
                    }
                    editor.apply()
                    result.success(true)
                }
                "setAdhanMuted" -> {
                    val isMuted = call.argument<Boolean>("isMuted") ?: false
                    val prayerName = call.argument<String>("prayerName")
                    val prefs = getSharedPreferences(AdhanScheduler.PREFS_NAME, Context.MODE_PRIVATE)
                    val editor = prefs.edit()
                    if (prayerName != null && prayerName.isNotEmpty()) {
                        editor.putBoolean("adhan_muted_$prayerName", isMuted)
                    } else {
                        editor.putBoolean("adhan_muted", isMuted)
                    }
                    editor.apply()
                    result.success(true)
                }
                "previewAdhan" -> {
                    val soundKey = call.argument<String>("soundKey") ?: "adhan_makkah"
                    playPreviewAudio(soundKey, result)
                }
                "stopPreview" -> {
                    stopPreviewAudio()
                    result.success(true)
                }
                "scheduleTestAlarm" -> {
                    val soundKey = call.argument<String>("soundKey")
                    AdhanScheduler.scheduleTestAlarmInOneMinute(applicationContext, soundKey)
                    result.success(true)
                }
                "playTestAdhan" -> {
                    val soundKey = call.argument<String>("soundKey")
                    val ringIntent = Intent(applicationContext, AdhanRingingActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                        putExtra("prayer_name", "تجربة الأذان")
                        putExtra("prayer_time", "الآن")
                        putExtra("is_test", true)
                        if (soundKey != null) {
                            putExtra("adhan_sound", soundKey)
                        }
                    }
                    try {
                        startActivity(ringIntent)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error starting AdhanRingingActivity for test: ${e.message}")
                    }

                    val intent = Intent(applicationContext, AdhanService::class.java).apply {
                        putExtra("prayer_name", "تجربة الأذان")
                        putExtra("prayer_time", "الآن")
                        putExtra("is_test", true)
                        if (soundKey != null) {
                            putExtra("adhan_sound", soundKey)
                        }
                    }
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            ContextCompat.startForegroundService(applicationContext, intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error starting test AdhanService: ${e.message}", e)
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "stopAdhan" -> {
                    val intent = Intent(applicationContext, AdhanService::class.java).apply {
                        action = AdhanService.ACTION_STOP_ADHAN
                    }
                    startService(intent)
                    result.success(true)
                }
                "canDrawOverlays" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        result.success(Settings.canDrawOverlays(applicationContext))
                    } else {
                        result.success(true)
                    }
                }
                "openOverlaySettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            ).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.parse("package:$packageName")
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(fallback)
                                result.success(true)
                            } catch (e2: Exception) {
                                result.error("OVERLAY_ERROR", e2.message, null)
                            }
                        }
                    } else {
                        result.success(true)
                    }
                }
                "canScheduleExactAlarms" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        result.success(alarmManager.canScheduleExactAlarms())
                    } else {
                        result.success(true)
                    }
                }
                "openExactAlarmSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                            data = Uri.parse("package:$packageName")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                    }
                    result.success(true)
                }
                "isIgnoringBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val powerManager = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                        result.success(powerManager.isIgnoringBatteryOptimizations(packageName))
                    } else {
                        result.success(true)
                    }
                }
                "requestIgnoreBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(fallbackIntent)
                                result.success(true)
                            } catch (e2: Exception) {
                                result.error("BATTERY_SETTINGS_ERROR", e2.message, null)
                            }
                        }
                    } else {
                        result.success(true)
                    }
                }
                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:$packageName")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("APP_SETTINGS_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun playPreviewAudio(soundKey: String, result: MethodChannel.Result) {
        try {
            stopPreviewAudio()

            if (soundKey == "silent" || soundKey == "adhan_none") {
                result.success(true)
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

            val player = MediaPlayer().apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                            .build()
                    )
                } else {
                    @Suppress("DEPRECATION")
                    setAudioStreamType(AudioManager.STREAM_MUSIC)
                }
            }
            previewPlayer = player

            var loaded = false
            try {
                resources.openRawResourceFd(rawResId)?.use { afd ->
                    player.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    player.prepare()
                    player.start()
                    loaded = true
                    result.success(true)
                }
            } catch (e: Exception) {
                Log.e("MainActivity", "Error playing preview for $soundKey: ${e.message}", e)
            }

            if (!loaded) {
                try {
                    resources.openRawResourceFd(R.raw.adhan_makkah)?.use { afd ->
                        player.reset()
                        player.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                        player.prepare()
                        player.start()
                        loaded = true
                        result.success(true)
                    }
                } catch (fallbackEx: Exception) {
                    Log.e("MainActivity", "Fallback preview failed: ${fallbackEx.message}", fallbackEx)
                }
            }

            if (!loaded) {
                result.error("RAW_NOT_FOUND", "Could not find or prepare raw resource for $soundKey", null)
                return
            }

            player.setOnCompletionListener {
                stopPreviewAudio()
            }
            player.setOnErrorListener { _, _, _ ->
                stopPreviewAudio()
                true
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error in playPreviewAudio: ${e.message}", e)
            result.error("PREVIEW_ERROR", e.message, null)
        }
    }

    private fun stopPreviewAudio() {
        try {
            if (previewPlayer?.isPlaying == true) {
                previewPlayer?.stop()
            }
            previewPlayer?.release()
            previewPlayer = null
        } catch (e: Exception) {
            Log.e("MainActivity", "Error in stopPreviewAudio: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopPreviewAudio()
    }
}
