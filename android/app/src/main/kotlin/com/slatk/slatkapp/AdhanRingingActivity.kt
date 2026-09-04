package com.slatk.slatkapp

import android.app.Activity
import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.animation.AlphaAnimation
import android.view.animation.Animation
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

class AdhanRingingActivity : Activity() {

    companion object {
        private const val TAG = "AdhanRingingActivity"
        const val ACTION_DISMISS_RINGING = "com.slatk.slatkapp.DISMISS_RINGING"
        @Volatile
        var currentInstance: AdhanRingingActivity? = null

        // Static wake lock held at class level so it survives configuration changes
        private var staticScreenWakeLock: PowerManager.WakeLock? = null

        /**
         * Must be called as EARLY as possible — ideally before super.onCreate().
         * Acquires a FULL_WAKE_LOCK | ACQUIRE_CAUSES_WAKEUP to physically turn on
         * the screen. This is the most aggressive (and reliable) approach for
         * Samsung One UI and other OEM ROMs.
         */
        @Suppress("DEPRECATION")
        fun acquireEarlyWakeLock(context: Context) {
            try {
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                if (staticScreenWakeLock?.isHeld == true) return // already held

                staticScreenWakeLock = pm.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                    PowerManager.ACQUIRE_CAUSES_WAKEUP or
                    PowerManager.ON_AFTER_RELEASE,
                    "slatkapp:AdhanEarlyScreenWakeLock"
                ).apply {
                    setReferenceCounted(false)
                    acquire(10 * 60 * 1000L) // 10 minutes maximum timeout
                }
                Log.d(TAG, "Early screen wake lock acquired (SCREEN_BRIGHT | ACQUIRE_CAUSES_WAKEUP)")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to acquire early wake lock: ${e.message}", e)
            }
        }

        fun releaseEarlyWakeLock() {
            try {
                if (staticScreenWakeLock?.isHeld == true) {
                    staticScreenWakeLock?.release()
                    staticScreenWakeLock = null
                    Log.d(TAG, "Early screen wake lock released")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error releasing early wake lock: ${e.message}")
            }
        }
    }

    private var stopReceiver: BroadcastReceiver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // ─── STEP 1: Wake the screen BEFORE anything else ───────────────────────
        // This must happen before super.onCreate() to be effective on Samsung One UI.
        acquireEarlyWakeLock(applicationContext)
        applyWindowFlagsEarly()

        super.onCreate(savedInstanceState)

        // ─── STEP 2: Apply modern lock screen APIs ───────────────────────────────
        configureLockScreenDisplay()

        currentInstance = this

        val prayerName = intent?.getStringExtra("prayer_name") ?: "الصلاة"
        val prayerTime = intent?.getStringExtra("prayer_time") ?: ""
        val adhanSound = intent?.getStringExtra("adhan_sound") ?: "adhan_makkah"
        val isTest = intent?.getBooleanExtra("is_test", false) ?: false

        Log.d(TAG, "AdhanRingingActivity started for $prayerName ($prayerTime), sound=$adhanSound, isTest=$isTest")

        // ─── STEP 3: Build UI ────────────────────────────────────────────────────
        setContentView(buildRingingLayout(prayerName, prayerTime))

        // ─── STEP 4: Start AdhanService for audio + persistent notification ──────
        val serviceIntent = Intent(this, AdhanService::class.java).apply {
            putExtra("prayer_name", prayerName)
            putExtra("prayer_time", prayerTime)
            putExtra("adhan_sound", adhanSound)
            putExtra("is_test", isTest)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                androidx.core.content.ContextCompat.startForegroundService(this, serviceIntent)
            } else {
                startService(serviceIntent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error starting AdhanService from AdhanRingingActivity: ${e.message}", e)
        }

        // ─── STEP 5: Register broadcast receiver for stop signal ─────────────────
        registerStopReceiver()

        // ─── STEP 6: Reschedule for tomorrow (offline-safe) ─────────────────────
        if (!isTest && prayerName != "تجربة الأذان") {
            try {
                val finalTime = if (prayerTime.isNotEmpty()) prayerTime else {
                    val prefs = getSharedPreferences(AdhanScheduler.PREFS_NAME, Context.MODE_PRIVATE)
                    prefs.getString("prayer_$prayerName", "") ?: ""
                }
                if (finalTime.isNotEmpty()) {
                    AdhanScheduler.schedulePrayer(applicationContext, prayerName, finalTime, null)
                    Log.d(TAG, "Rescheduled $prayerName for tomorrow at $finalTime")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error rescheduling for tomorrow from activity: ${e.message}", e)
            }
        }
    }

    /**
     * Apply window flags BEFORE super.onCreate() for maximum Samsung compatibility.
     * Some OEM ROMs check these flags at Activity creation time.
     */
    @Suppress("DEPRECATION")
    private fun applyWindowFlagsEarly() {
        try {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
            )
            Log.d(TAG, "Early window flags applied")
        } catch (e: Exception) {
            Log.e(TAG, "Error applying early window flags: ${e.message}")
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        configureLockScreenDisplay()
    }

    override fun onResume() {
        super.onResume()
        configureLockScreenDisplay()
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        applyWindowFlagsEarly()
        configureLockScreenDisplay()
        val prayerName = intent?.getStringExtra("prayer_name") ?: "الصلاة"
        val prayerTime = intent?.getStringExtra("prayer_time") ?: ""
        Log.d(TAG, "AdhanRingingActivity onNewIntent for $prayerName ($prayerTime)")
        setContentView(buildRingingLayout(prayerName, prayerTime))
    }

    private fun configureLockScreenDisplay() {
        // Modern Android 8.1+ (API 27+) APIs — preferred over window flags
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }

        // Window flags for all API levels (especially needed on Samsung One UI)
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
        )

        // On Samsung / OEM devices without a secure lock screen, try to dismiss keyguard
        // so the alarm screen shows immediately without any interaction needed.
        // Note: requestDismissKeyguard is an Activity method (API 26+), but requires
        // the window to already have FLAG_SHOW_WHEN_LOCKED set first.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            try {
                val km = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
                if (km != null && !km.isKeyguardSecure) {
                    // Only dismiss if there's no PIN/Pattern/Fingerprint lock
                    km.requestDismissKeyguard(this, null)
                    Log.d(TAG, "requestDismissKeyguard called (no secure lock detected)")
                }
            } catch (e: Exception) {
                Log.d(TAG, "requestDismissKeyguard not applicable: ${e.message}")
            }
        }
    }

    private fun registerStopReceiver() {
        stopReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                Log.d(TAG, "Stop signal received in AdhanRingingActivity, finishing")
                finishAndDismiss()
            }
        }
        val filter = IntentFilter().apply {
            addAction(AdhanAlarmReceiver.ACTION_STOP_ADHAN)
            addAction(ACTION_DISMISS_RINGING)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(stopReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(stopReceiver, filter)
        }
    }

    private fun buildRingingLayout(prayerName: String, prayerTime: String): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            // Beautiful Islamic deep gradient background
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(
                    Color.parseColor("#064E3B"), // Deep Emerald
                    Color.parseColor("#022C22"), // Midnight Emerald
                    Color.parseColor("#0F172A")  // Deep Slate
                )
            )
            val pad = dp(28)
            setPadding(pad, dp(48), pad, dp(40))
        }

        // Top decorative spacing
        root.addView(View(this).apply {
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1.0f)
        })

        // Mosque / Crescent circular glowing container
        val iconContainer = FrameLayout(this).apply {
            val size = dp(110)
            layoutParams = LinearLayout.LayoutParams(size, size).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                bottomMargin = dp(24)
            }
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#10B981")) // Emerald glow
                alpha = 45
            }
        }

        val iconText = TextView(this).apply {
            text = "🕌"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 52f)
            gravity = Gravity.CENTER
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        iconContainer.addView(iconText)

        // Pulsing animation on icon
        val pulse = AlphaAnimation(0.55f, 1.0f).apply {
            duration = 900
            repeatMode = Animation.REVERSE
            repeatCount = Animation.INFINITE
        }
        iconContainer.startAnimation(pulse)
        root.addView(iconContainer)

        // Top Header
        val headerTv = TextView(this).apply {
            text = "🕌 حان الآن وقت الأذان"
            setTextColor(Color.parseColor("#F59E0B")) // Warm Gold
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f)
            setTypeface(Typeface.DEFAULT, Typeface.BOLD)
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(8)
            }
        }
        root.addView(headerTv)

        // Prayer Name (Large)
        val prayerTv = TextView(this).apply {
            text = prayerName
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 36f)
            setTypeface(Typeface.DEFAULT, Typeface.BOLD)
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(6)
            }
        }
        root.addView(prayerTv)

        // Prayer Time (if available)
        if (prayerTime.isNotEmpty()) {
            val timeTv = TextView(this).apply {
                text = prayerTime
                setTextColor(Color.parseColor("#34D399")) // Mint Green
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 26f)
                setTypeface(Typeface.DEFAULT, Typeface.BOLD)
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                ).apply {
                    bottomMargin = dp(12)
                }
            }
            root.addView(timeTv)
        }

        // Subtitle
        val subTv = TextView(this).apply {
            text = "حي على الصلاة • حي على الفلاح"
            setTextColor(Color.parseColor("#E2E8F0")) // Light Slate
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(16)
            }
        }
        root.addView(subTv)

        // Middle decorative spacing
        root.addView(View(this).apply {
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1.5f)
        })

        // Action Buttons Container
        val buttonsContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }

        // 1. Primary Button: Stop Adhan (Large Red/Crimson button)
        val stopButton = Button(this).apply {
            text = "⏹️  إيقاف الأذان"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            setTypeface(Typeface.DEFAULT, Typeface.BOLD)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(60)
            ).apply {
                bottomMargin = dp(14)
            }
            background = GradientDrawable(
                GradientDrawable.Orientation.LEFT_RIGHT,
                intArrayOf(
                    Color.parseColor("#EF4444"), // Red 500
                    Color.parseColor("#DC2626")  // Red 600
                )
            ).apply {
                cornerRadius = dp(30).toFloat()
            }
            setOnClickListener {
                Log.d(TAG, "Stop Adhan button tapped on ringing screen")
                stopAllAdhanPlayback()
                finishAndDismiss()
            }
        }
        buttonsContainer.addView(stopButton)

        // 2. Secondary Button: Open App
        val openAppButton = Button(this).apply {
            text = "الانتقال للتطبيق"
            setTextColor(Color.parseColor("#D1FAE5")) // Very light green
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            setTypeface(Typeface.DEFAULT, Typeface.BOLD)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(48)
            )
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#15803D")) // Deep Green
                alpha = 80
                cornerRadius = dp(24).toFloat()
                setStroke(dp(1), Color.parseColor("#34D399"))
            }
            setOnClickListener {
                Log.d(TAG, "Open App button tapped on ringing screen")
                val mainIntent = Intent(this@AdhanRingingActivity, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                startActivity(mainIntent)
                finishAndDismiss()
            }
        }
        buttonsContainer.addView(openAppButton)

        root.addView(buttonsContainer)
        return root
    }

    private fun stopAllAdhanPlayback() {
        try {
            // Stop in-receiver player
            AdhanAlarmReceiver.stopPlayback(this)
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping receiver playback: ${e.message}")
        }

        try {
            // Stop foreground service
            AdhanService.currentInstance?.stopSelf()
            val stopServiceIntent = Intent(this, AdhanService::class.java).apply {
                action = AdhanService.ACTION_STOP_ADHAN
            }
            startService(stopServiceIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping AdhanService: ${e.message}")
        }

        try {
            // Cancel notification
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(AdhanAlarmReceiver.NOTIFICATION_ID)
        } catch (_: Exception) {}
    }

    private fun finishAndDismiss() {
        releaseEarlyWakeLock()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                finishAndRemoveTask()
            } else {
                finish()
            }
        } catch (e: Exception) {
            finish()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        currentInstance = null
        try {
            if (stopReceiver != null) {
                unregisterReceiver(stopReceiver)
                stopReceiver = null
            }
        } catch (_: Exception) {}
        releaseEarlyWakeLock()
        Log.d(TAG, "AdhanRingingActivity destroyed")
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }
}
