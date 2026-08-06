package com.foodplatform.food_platform_app

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {

    companion object {
        private const val PAYMENT_EVENTS_CHANNEL = "com.foodplatform/payment_notifications"
        private const val PAYMENT_METHODS_CHANNEL = "com.foodplatform/payment_methods"
    }

    // TTS de prueba — instancia separada de la del servicio
    private var testTts: TextToSpeech? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        setupPaymentNotificationChannels(flutterEngine)
    }

    private fun setupPaymentNotificationChannels(flutterEngine: FlutterEngine) {
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, PAYMENT_EVENTS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    PaymentNotificationListenerService.eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    PaymentNotificationListenerService.eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PAYMENT_METHODS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isNotificationListenerEnabled" -> result.success(isNotificationListenerEnabled())
                    "openNotificationListenerSettings" -> {
                        openNotificationListenerSettings()
                        result.success(null)
                    }
                    "requestIgnoreBatteryOptimization" -> {
                        requestIgnoreBatteryOptimization()
                        result.success(null)
                    }
                    "isBatteryOptimizationIgnored" -> result.success(isBatteryOptimizationIgnored())
                    "updateConfig" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        val banks = call.argument<List<String>>("enabled_banks") ?: emptyList()
                        val template = call.argument<String>("template") ?: "Llegó {monto} por {banco}"
                        PaymentNotificationListenerService.globalEnabled = enabled
                        PaymentNotificationListenerService.enabledBanks = banks.toSet()
                        PaymentNotificationListenerService.messageTemplate = template
                        result.success(null)
                    }
                    "testTts" -> {
                        val text = call.argument<String>("text") ?: "Llegó cincuenta mil pesos por Nequi"
                        speakTestMessage(text)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun speakTestMessage(text: String) {
        testTts?.stop()
        testTts?.shutdown()
        testTts = TextToSpeech(applicationContext) { status ->
            if (status == TextToSpeech.SUCCESS) {
                val locale = Locale("es", "CO")
                val res = testTts?.setLanguage(locale)
                if (res == TextToSpeech.LANG_MISSING_DATA || res == TextToSpeech.LANG_NOT_SUPPORTED) {
                    testTts?.setLanguage(Locale("es", "ES"))
                }
                testTts?.setSpeechRate(0.95f)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    testTts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "test_tts")
                } else {
                    @Suppress("DEPRECATION")
                    testTts?.speak(text, TextToSpeech.QUEUE_FLUSH, null)
                }
                // Limpiar después de hablar
                Handler(Looper.getMainLooper()).postDelayed({
                    testTts?.stop()
                    testTts?.shutdown()
                    testTts = null
                }, 8_000L)
            }
        }
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val cn = ComponentName(this, PaymentNotificationListenerService::class.java)
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
        return flat.contains(cn.flattenToString())
    }

    private fun openNotificationListenerSettings() {
        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        })
    }

    private fun isBatteryOptimizationIgnored(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = getSystemService(POWER_SERVICE) as? PowerManager ?: return false
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimization() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:$packageName")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        try {
            startActivity(intent)
        } catch (_: Exception) {
            startActivity(Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            })
        }
    }

    override fun onDestroy() {
        testTts?.stop()
        testTts?.shutdown()
        testTts = null
        super.onDestroy()
    }
}
