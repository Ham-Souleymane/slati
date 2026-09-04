package com.slatk.slatkapp

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.util.Calendar

object AdhanScheduler {
    private const val TAG = "AdhanScheduler"
    const val PREFS_NAME = "slati_adhan_prefs"

    private val prayerCodes = mapOf(
        "الفجر" to 101,
        "الظهر" to 102,
        "العصر" to 103,
        "المغرب" to 104,
        "العشاء" to 105,
        "test_alarm" to 999
    )

    fun getPrayerCode(prayerName: String): Int {
        return when {
            prayerName.contains("فجر") -> 101
            prayerName.contains("ظهر") -> 102
            prayerName.contains("عصر") -> 103
            prayerName.contains("مغرب") -> 104
            prayerName.contains("عشاء") -> 105
            prayerName.contains("تجربة") || prayerName == "test_alarm" -> 999
            else -> prayerCodes[prayerName] ?: 100
        }
    }

    fun normalizeDigits(input: String): String {
        val arabic = charArrayOf('٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩')
        val persian = charArrayOf('۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹')
        val latin = charArrayOf('0', '1', '2', '3', '4', '5', '6', '7', '8', '9')
        var res = input.replace("\u200e", "")
            .replace("\u200f", "")
            .replace("\u061c", "")
            .replace("\u00a0", " ")
            .trim()
        for (i in arabic.indices) {
            res = res.replace(arabic[i], latin[i])
        }
        for (i in persian.indices) {
            res = res.replace(persian[i], latin[i])
        }
        return res
    }

    /**
     * Parses timeStr into triggerAtMillis with full support for:
     * - Any whitespace or separator variations
     * - Arabic / Persian numerals
     * - AM / PM markers in Arabic (ص / م) or English
     * - Automatic 12-hour to 24-hour correction for Dhuhr, Asr, Maghrib, Isha
     * - Rescheduling for tomorrow if the time has already passed today (> 60s ago)
     */
    fun parsePrayerTimeToMillis(prayerName: String, timeStr: String): Long? {
        if (prayerName == "الشروق") return null

        val norm = normalizeDigits(timeStr)
        val isPM = norm.contains("م") || norm.contains("PM", ignoreCase = true)
        val isAM = norm.contains("ص") || norm.contains("AM", ignoreCase = true)

        val regex = Regex("""(\d{1,2})\s*:\s*(\d{1,2})""")
        val match = regex.find(norm)
        if (match == null) {
            Log.e(TAG, "Could not extract hour:minute from '$timeStr' for $prayerName")
            return null
        }

        var hour = match.groupValues[1].toIntOrNull() ?: return null
        val minute = match.groupValues[2].toIntOrNull() ?: return null

        if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
            Log.e(TAG, "Invalid hour ($hour) or minute ($minute) for $prayerName from '$timeStr'")
            return null
        }

        // Handle 12-hour conversions
        if (isPM && hour < 12) {
            hour += 12
        } else if (isAM && hour == 12) {
            hour = 0
        } else if (!isPM && !isAM) {
            // Auto-detect 12-hour values for afternoon/night prayers if given without AM/PM
            when {
                prayerName.contains("ظهر") && hour in 1..10 -> hour += 12
                prayerName.contains("عصر") && hour < 12 -> hour += 12
                prayerName.contains("مغرب") && hour < 12 -> hour += 12
                prayerName.contains("عشاء") && hour < 12 -> hour += 12
            }
        }

        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        val now = System.currentTimeMillis()
        // If the prayer time has already passed today, schedule for tomorrow.
        if (calendar.timeInMillis <= now) {
            calendar.add(Calendar.DAY_OF_YEAR, 1)
        }

        return calendar.timeInMillis
    }

    /**
     * Creates a PendingIntent for AdhanRingingActivity with all required extras.
     * This is the single source of truth for creating the activity intent used
     * both as the AlarmClockInfo show intent AND as the alarm operation.
     */
    private fun buildActivityPendingIntent(context: Context, requestCode: Int, prayerName: String, timeStr: String, soundName: String, isTest: Boolean = false): PendingIntent {
        val showIntent = Intent(context, AdhanRingingActivity::class.java).apply {
            // FLAG_ACTIVITY_NEW_TASK is required when starting from non-Activity context.
            // FLAG_ACTIVITY_CLEAR_TOP ensures only one instance of the alarm screen.
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("prayer_name", prayerName)
            putExtra("prayer_time", timeStr)
            putExtra("adhan_sound", soundName)
            putExtra("request_code", requestCode)
            if (isTest) putExtra("is_test", true)
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            showIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )
    }

    /**
     * Creates a PendingIntent for AdhanAlarmReceiver (BroadcastReceiver).
     * The receiver handles audio playback and posting the notification.
     * Note: On Android 12+ the receiver CANNOT launch activities from background.
     * Activity launching is handled by AlarmManager.AlarmClockInfo's show intent.
     */
    private fun buildReceiverPendingIntent(context: Context, requestCode: Int, prayerName: String, timeStr: String, soundName: String, isTest: Boolean = false): PendingIntent {
        val intent = Intent(context, AdhanAlarmReceiver::class.java).apply {
            action = "com.slatk.slatkapp.PLAY_ADHAN"
            putExtra("prayer_name", prayerName)
            putExtra("prayer_time", timeStr)
            putExtra("adhan_sound", soundName)
            putExtra("request_code", requestCode)
            if (isTest) putExtra("is_test", true)
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun schedulePrayer(context: Context, prayerName: String, timeStr: String, customSound: String? = null) {
        if (prayerName == "الشروق") return // Sunrise is not a prayer

        val triggerAtMillis = parsePrayerTimeToMillis(prayerName, timeStr)
        if (triggerAtMillis == null) {
            Log.e(TAG, "Failed to parse trigger time for $prayerName with raw string: '$timeStr'")
            return
        }

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val editor = prefs.edit()
        editor.putString("prayer_$prayerName", timeStr)
        editor.putBoolean("enabled_$prayerName", true)
        if (customSound != null) {
            editor.putString("adhan_sound_$prayerName", customSound)
        }
        editor.apply()

        val isMuted = prefs.getBoolean("adhan_muted", false) || prefs.getBoolean("adhan_muted_$prayerName", false)
        val soundName = if (isMuted) {
            "silent"
        } else {
            customSound
                ?: prefs.getString("adhan_sound_$prayerName", null)
                ?: prefs.getString("selected_adhan_sound", "adhan_makkah")
                ?: "adhan_makkah"
        }

        val requestCode = getPrayerCode(prayerName)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val targetDate = java.util.Date(triggerAtMillis)

        // -----------------------------------------------------------------------
        // STRATEGY: Use setAlarmClock() with TWO separate PendingIntents:
        //
        //   1. activityPendingIntent (PendingIntent.getActivity) is passed as
        //      BOTH the AlarmClockInfo "showIntent" AND the alarm operation.
        //      This ensures Android grants the app the Background Activity Launch
        //      (BAL) exemption, so AdhanRingingActivity can show over the lock
        //      screen even when the app is killed.
        //
        //   2. receiverPendingIntent (PendingIntent.getBroadcast) is scheduled
        //      via a *separate* setAndAllowWhileIdle alarm at the same time.
        //      This fires AdhanAlarmReceiver to play audio via the foreground
        //      service and post the fullScreenIntent notification as a fallback.
        //
        // This dual-alarm approach ensures:
        //   - Screen wake-up via the privileged AlarmClock Activity launch (1)
        //   - Audio playback + notification via the BroadcastReceiver (2)
        // -----------------------------------------------------------------------
        val activityPendingIntent = buildActivityPendingIntent(context, requestCode, prayerName, timeStr, soundName)
        val receiverPendingIntent = buildReceiverPendingIntent(context, requestCode + 1000, prayerName, timeStr, soundName)

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // Primary: AlarmClock with Activity as operation → guaranteed BAL exemption
                val alarmClockInfo = AlarmManager.AlarmClockInfo(triggerAtMillis, activityPendingIntent)
                alarmManager.setAlarmClock(alarmClockInfo, activityPendingIntent)
                Log.d(TAG, "Scheduled AlarmClock (Activity operation) for $prayerName at $targetDate (sound=$soundName)")

                // Secondary: Broadcast for audio/notification at the same time
                try {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, receiverPendingIntent)
                    Log.d(TAG, "Scheduled secondary receiver alarm for $prayerName at $targetDate")
                } catch (e: Exception) {
                    Log.w(TAG, "Secondary receiver alarm failed for $prayerName: ${e.message}")
                }
            } else {
                // Pre-Marshmallow: just use exact alarm with broadcast receiver
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, receiverPendingIntent)
                Log.d(TAG, "Scheduled Exact Alarm (broadcast) for $prayerName at $targetDate (sound=$soundName)")
            }
        } catch (se: SecurityException) {
            Log.w(TAG, "Exact alarm permission denied for $prayerName, falling back: ${se.message}")
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, activityPendingIntent)
                } else {
                    alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, receiverPendingIntent)
                }
            } catch (fallbackEx: Exception) {
                Log.e(TAG, "Fallback alarm scheduling failed for $prayerName: ${fallbackEx.message}", fallbackEx)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule alarm for $prayerName: ${e.message}", e)
        }
    }


    fun cancelPrayer(context: Context, prayerName: String) {
        val requestCode = getPrayerCode(prayerName)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)

        // Cancel both the activity alarm and the receiver alarm
        try {
            val activityIntent = Intent(context, AdhanRingingActivity::class.java)
            val activityPi = PendingIntent.getActivity(context, requestCode, activityIntent, flags)
            alarmManager.cancel(activityPi)
        } catch (_: Exception) {}

        try {
            val receiverIntent = Intent(context, AdhanAlarmReceiver::class.java)
            val receiverPi = PendingIntent.getBroadcast(context, requestCode + 1000, receiverIntent, flags)
            alarmManager.cancel(receiverPi)
        } catch (_: Exception) {}

        // Also cancel old-style alarm that used requestCode for broadcast (legacy cleanup)
        try {
            val legacyIntent = Intent(context, AdhanAlarmReceiver::class.java)
            val legacyPi = PendingIntent.getBroadcast(context, requestCode, legacyIntent, flags)
            alarmManager.cancel(legacyPi)
        } catch (_: Exception) {}

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean("enabled_$prayerName", false).apply()
        Log.d(TAG, "Cancelled alarm for $prayerName")
    }

    fun scheduleTestAlarmInOneMinute(context: Context, testSound: String? = null) {
        val triggerAtMillis = System.currentTimeMillis() + 60_000 // in 60 seconds
        val requestCode = 999

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isMuted = prefs.getBoolean("adhan_muted", false)
        val soundName = if (isMuted) "silent" else (testSound ?: prefs.getString("selected_adhan_sound", "adhan_makkah") ?: "adhan_makkah")

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val activityPendingIntent = buildActivityPendingIntent(context, requestCode, "تجربة الأذان", "الآن", soundName, isTest = true)
        val receiverPendingIntent = buildReceiverPendingIntent(context, requestCode + 1000, "تجربة الأذان", "الآن", soundName, isTest = true)

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // Primary: AlarmClock with Activity as operation → screen wake-up guaranteed
                val alarmClockInfo = AlarmManager.AlarmClockInfo(triggerAtMillis, activityPendingIntent)
                alarmManager.setAlarmClock(alarmClockInfo, activityPendingIntent)
                Log.d(TAG, "Scheduled 1-min test AlarmClock (Activity operation, sound=$soundName)")

                // Secondary: Broadcast for audio/notification
                try {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, receiverPendingIntent)
                    Log.d(TAG, "Scheduled 1-min secondary test receiver alarm")
                } catch (e: Exception) {
                    Log.w(TAG, "Secondary test receiver alarm failed: ${e.message}")
                }
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, receiverPendingIntent)
                Log.d(TAG, "Scheduled 1-min test Exact Alarm (pre-M, broadcast, sound=$soundName)")
            }
        } catch (se: SecurityException) {
            Log.w(TAG, "Exact alarm permission denied for test, falling back: ${se.message}")
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, activityPendingIntent)
                } else {
                    alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, receiverPendingIntent)
                }
            } catch (fallbackEx: Exception) {
                Log.e(TAG, "Fallback test alarm scheduling failed: ${fallbackEx.message}", fallbackEx)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule test alarm: ${e.message}", e)
        }
    }

    fun rescheduleAll(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        for (prayerName in listOf("الفجر", "الظهر", "العصر", "المغرب", "العشاء")) {
            val enabled = prefs.getBoolean("enabled_$prayerName", true)
            val timeStr = prefs.getString("prayer_$prayerName", null)
            val sound = prefs.getString("adhan_sound_$prayerName", null)
            if (enabled && timeStr != null) {
                schedulePrayer(context, prayerName, timeStr, sound)
            }
        }
    }
}
