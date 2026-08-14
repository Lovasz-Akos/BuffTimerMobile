package com.ff14.bufftimer.buff_timer_mobile

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.ff14.bufftimer/native"
    private var ringtone: Ringtone? = null
    private var wakeLock: PowerManager.WakeLock? = null

    // Nothing Glyph SDK Reflection Objects
    private var glyphManagerObj: Any? = null
    private var glyphManagerClass: Class<*>? = null
    private var isGlyphSupported = false
    private var isSessionOpen = false

    private val mainHandler = Handler(Looper.getMainLooper())
    private var glyphPulseRunnable: Runnable? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize Nothing Glyph reflection (supporting com.nothing.ketchum and com.nothing.sdk.glyph)
        initNothingGlyphReflection()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "wakeUpScreen" -> {
                    wakeUpScreen()
                    result.success(true)
                }
                "startAlarmSound" -> {
                    startAlarmSound()
                    result.success(true)
                }
                "stopAlarmSound" -> {
                    stopAlarmSound()
                    result.success(true)
                }
                "triggerGlyphAlarm" -> {
                    val success = triggerGlyphAlarm()
                    result.success(success)
                }
                "stopGlyphAlarm" -> {
                    stopGlyphAlarm()
                    result.success(true)
                }
                "isNothingDevice" -> {
                    val brand = Build.MANUFACTURER.lowercase()
                    val model = Build.MODEL.lowercase()
                    val isNothingBrand = brand.contains("nothing") || model.contains("nothing") || model.contains("ain0")
                    result.success(isNothingBrand || isGlyphSupported)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    requestIgnoreBatteryOptimizations()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun initNothingGlyphReflection() {
        val possiblePackages = arrayOf(
            "com.nothing.ketchum.GlyphManager",
            "com.nothing.sdk.glyph.GlyphManager"
        )

        for (pkg in possiblePackages) {
            try {
                val clazz = Class.forName(pkg)
                val getInstanceMethod = clazz.getMethod("getInstance", Context::class.java)
                val instance = getInstanceMethod.invoke(null, applicationContext)

                if (instance != null) {
                    glyphManagerClass = clazz
                    glyphManagerObj = instance
                    isGlyphSupported = true

                    // Try calling init & register if available
                    try {
                        val registerMethod = clazz.methods.firstOrNull { it.name == "register" }
                        registerMethod?.invoke(instance, "2a") // or "phone"
                    } catch (_: Throwable) {}

                    break
                }
            } catch (_: Throwable) {}
        }
    }

    private fun wakeUpScreen() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
            }
            window.addFlags(
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )

            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock?.release()
            @Suppress("DEPRECATION")
            wakeLock = powerManager.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "FF14BuffTimer:AlarmWakeLock"
            )
            wakeLock?.acquire(30000)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun startAlarmSound() {
        try {
            stopAlarmSound()
            var alert: Uri? = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            if (alert == null) {
                alert = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            }
            if (alert == null) {
                alert = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            }
            ringtone = RingtoneManager.getRingtone(applicationContext, alert)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                ringtone?.isLooping = true
            }
            ringtone?.audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            ringtone?.play()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun stopAlarmSound() {
        try {
            ringtone?.stop()
            ringtone = null
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun openGlyphSession() {
        if (glyphManagerObj == null || glyphManagerClass == null) return
        try {
            val openMethod = glyphManagerClass!!.methods.firstOrNull { it.name == "openSession" }
            openMethod?.invoke(glyphManagerObj)
            isSessionOpen = true
        } catch (_: Throwable) {}
    }

    private fun closeGlyphSession() {
        if (glyphManagerObj == null || glyphManagerClass == null) return
        try {
            val closeMethod = glyphManagerClass!!.methods.firstOrNull { it.name == "closeSession" }
            closeMethod?.invoke(glyphManagerObj)
            isSessionOpen = false
        } catch (_: Throwable) {}
    }

    private fun triggerGlyphAlarm(): Boolean {
        if (glyphManagerObj == null && !isNothingDeviceFallback()) {
            return false
        }

        stopGlyphAlarm()

        // Start repeating pulse animation for Glyph
        var isOn = false
        glyphPulseRunnable = object : Runnable {
            override fun run() {
                try {
                    if (glyphManagerObj != null && glyphManagerClass != null) {
                        if (!isSessionOpen) openGlyphSession()

                        val toggleMethod = glyphManagerClass!!.methods.firstOrNull { 
                            it.name == "toggle" || it.name == "animate" || it.name == "turnOn"
                        }
                        
                        if (toggleMethod != null) {
                            // Try calling toggle/animate/turnOn
                            if (toggleMethod.parameterTypes.isEmpty()) {
                                toggleMethod.invoke(glyphManagerObj)
                            } else {
                                // Build frame dynamically
                                val frame = buildDynamicGlyphFrame()
                                if (frame != null) {
                                    toggleMethod.invoke(glyphManagerObj, frame)
                                }
                            }
                        }
                    }
                } catch (e: Throwable) {
                    e.printStackTrace()
                }

                isOn = !isOn
                mainHandler.postDelayed(this, 500)
            }
        }

        mainHandler.post(glyphPulseRunnable!!)
        return true
    }

    private fun buildDynamicGlyphFrame(): Any? {
        val possibleFrameBuilders = arrayOf(
            "com.nothing.ketchum.GlyphFrame\$Builder",
            "com.nothing.sdk.glyph.GlyphFrame\$Builder"
        )

        for (builderPkg in possibleFrameBuilders) {
            try {
                val builderClazz = Class.forName(builderPkg)
                val builderInst = builderClazz.getDeclaredConstructor().newInstance()

                // Try setting all glyph channels
                val methods = builderClazz.methods
                for (m in methods) {
                    if (m.name.startsWith("buildChannel") || m.name == "setGlyph") {
                        try {
                            if (m.parameterTypes.size == 2 && m.parameterTypes[1] == Boolean::class.javaPrimitiveType) {
                                m.invoke(builderInst, 0, true)
                            } else if (m.parameterTypes.isEmpty()) {
                                m.invoke(builderInst)
                            }
                        } catch (_: Throwable) {}
                    }
                }

                val buildMethod = builderClazz.getMethod("build")
                return buildMethod.invoke(builderInst)
            } catch (_: Throwable) {}
        }
        return null
    }

    private fun isNothingDeviceFallback(): Boolean {
        val brand = Build.MANUFACTURER.lowercase()
        val model = Build.MODEL.lowercase()
        return brand.contains("nothing") || model.contains("nothing") || model.contains("ain0")
    }

    private fun stopGlyphAlarm() {
        glyphPulseRunnable?.let { mainHandler.removeCallbacks(it) }
        glyphPulseRunnable = null

        if (glyphManagerObj != null && glyphManagerClass != null) {
            try {
                val turnOffMethod = glyphManagerClass!!.methods.firstOrNull { 
                    it.name == "turnOff" || it.name == "turnOffAll" || it.name == "closeSession"
                }
                turnOffMethod?.invoke(glyphManagerObj)
            } catch (_: Throwable) {}
            closeGlyphSession()
        }
    }

    private fun requestIgnoreBatteryOptimizations() {
        try {
            val intent = Intent()
            val packageName = packageName
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !pm.isIgnoringBatteryOptimizations(packageName)) {
                intent.action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopAlarmSound()
        stopGlyphAlarm()
    }
}
