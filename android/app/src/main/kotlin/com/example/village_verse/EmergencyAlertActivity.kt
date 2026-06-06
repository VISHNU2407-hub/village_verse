package com.example.village_verse

import android.animation.ArgbEvaluator
import android.animation.ValueAnimator
import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import java.util.Locale

class EmergencyAlertActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private var startedAtMillis = 0L
    private var timerView: TextView? = null
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var flashAnimator: ValueAnimator? = null
    private var locationLink: String = ""

    private val timerRunnable = object : Runnable {
        override fun run() {
            val elapsedSeconds = ((System.currentTimeMillis() - startedAtMillis) / 1000).coerceAtLeast(0)
            val minutes = elapsedSeconds / 60
            val seconds = elapsedSeconds % 60
            timerView?.text = String.format(Locale.US, "%02d:%02d", minutes, seconds)
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        configureLockScreenWindow()
        readAlertExtras(intent)
        setContentView(buildAlertView())
        startEmergencyEffects()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        readAlertExtras(intent)
    }

    private fun configureLockScreenWindow() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }

        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
        )
    }

    private fun readAlertExtras(intent: Intent?) {
        val extras = intent?.extras
        locationLink = extras?.getString(EXTRA_LOCATION_LINK).orEmpty()
        startedAtMillis = extras?.getLong(EXTRA_STARTED_AT_MILLIS)
            ?.takeIf { it > 0L }
            ?: System.currentTimeMillis()
    }

    private fun buildAlertView(): LinearLayout {
        val victimName = intent.getStringExtra(EXTRA_VICTIM_NAME).orEmpty().ifBlank { "Emergency contact" }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(36, 48, 36, 48)
            setBackgroundColor(Color.rgb(160, 0, 0))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }

        val title = TextView(this).apply {
            text = "EMERGENCY ACTIVE"
            setTextColor(Color.WHITE)
            textSize = 34f
            gravity = Gravity.CENTER
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        }

        val victim = TextView(this).apply {
            text = victimName
            setTextColor(Color.WHITE)
            textSize = 28f
            gravity = Gravity.CENTER
            setPadding(0, 28, 0, 12)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        }

        timerView = TextView(this).apply {
            text = "00:00"
            setTextColor(Color.WHITE)
            textSize = 46f
            gravity = Gravity.CENTER
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            setPadding(0, 10, 0, 40)
        }

        val mapsButton = Button(this).apply {
            text = "OPEN LIVE LOCATION"
            textSize = 21f
            setTextColor(Color.rgb(120, 0, 0))
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            setOnClickListener { openMaps() }
        }

        val dismissButton = Button(this).apply {
            text = "STOP ALERT SOUND"
            textSize = 16f
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.rgb(90, 0, 0))
            setOnClickListener { stopEmergencyEffects() }
        }

        val buttonParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply {
            topMargin = 18
        }

        root.addView(title)
        root.addView(victim)
        root.addView(timerView)
        root.addView(mapsButton, buttonParams)
        root.addView(dismissButton, buttonParams)
        return root
    }

    private fun openMaps() {
        if (locationLink.isBlank()) {
            return
        }

        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(locationLink)))
    }

    private fun startEmergencyEffects() {
        handler.post(timerRunnable)
        startFlashing()
        startSiren()
        startVibration()
    }

    private fun startFlashing() {
        val root = window.decorView.rootView
        flashAnimator = ValueAnimator.ofObject(
            ArgbEvaluator(),
            Color.rgb(95, 0, 0),
            Color.rgb(255, 0, 0)
        ).apply {
            duration = 450
            repeatMode = ValueAnimator.REVERSE
            repeatCount = ValueAnimator.INFINITE
            addUpdateListener { root.setBackgroundColor(it.animatedValue as Int) }
            start()
        }
    }

    private fun startSiren() {
        val alarmUri = android.provider.Settings.System.DEFAULT_ALARM_ALERT_URI
        mediaPlayer = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            setDataSource(this@EmergencyAlertActivity, alarmUri)
            isLooping = true
            prepare()
            start()
        }
    }

    private fun startVibration() {
        vibrator = getSystemService(VIBRATOR_SERVICE) as Vibrator
        val pattern = longArrayOf(0, 700, 250, 700, 250, 1100)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(pattern, 0)
        }
    }

    private fun stopEmergencyEffects() {
        handler.removeCallbacks(timerRunnable)
        flashAnimator?.cancel()
        flashAnimator = null
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
        vibrator?.cancel()
    }

    override fun onDestroy() {
        stopEmergencyEffects()
        super.onDestroy()
    }

    companion object {
        private const val EXTRA_VICTIM_NAME = "victimName"
        private const val EXTRA_LOCATION_LINK = "locationLink"
        private const val EXTRA_STARTED_AT_MILLIS = "startedAtMillis"

        fun extrasFrom(data: Map<String, String>): Bundle {
            return Bundle().apply {
                putString(EXTRA_VICTIM_NAME, data["victimName"])
                putString(EXTRA_LOCATION_LINK, data["locationLink"])
                putLong(EXTRA_STARTED_AT_MILLIS, data["startedAtMillis"]?.toLongOrNull() ?: 0L)
            }
        }
    }
}
