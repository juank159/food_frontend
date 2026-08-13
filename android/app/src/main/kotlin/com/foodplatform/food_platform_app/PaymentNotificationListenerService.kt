package com.foodplatform.food_platform_app

import android.app.Notification
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioManager
import android.os.Build
import android.os.PowerManager
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.speech.tts.TextToSpeech
import android.util.Log
import io.flutter.plugin.common.EventChannel
import org.json.JSONObject
import java.util.Locale
import java.util.regex.Pattern

/**
 * Escucha notificaciones de apps bancarias colombianas y:
 *  1. Habla el monto recibido via TTS nativo (funciona con pantalla bloqueada)
 *  2. Envía el evento a Flutter via EventChannel para que haga el webhook al backend
 *
 * El servicio solo escucha si:
 *  - El usuario otorgó acceso a notificaciones (Ajustes → Acceso a notificaciones)
 *  - La app bancaria está habilitada en la config del usuario
 */
class PaymentNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "PaymentNotifListener"

        /** Sink activo del EventChannel; se setea desde MainActivity al conectar Flutter. */
        var eventSink: EventChannel.EventSink? = null

        /** Set de packages bancarios habilitados; actualizado desde Flutter. */
        var enabledBanks: Set<String> = emptySet()

        /** Template de mensaje. {monto} y {banco} son los placeholders. */
        var messageTemplate: String = "Llegó {monto} por {banco}"

        /** Si false, el servicio no habla ni envía eventos aunque esté activo. */
        var globalEnabled: Boolean = true

        // Bancos soportados: packageName → nombre amigable
        val BANK_NAMES: Map<String, String> = mapOf(
            "com.nequi.mobileapp"                 to "Nequi",
            "com.bancolombia.bancolombia"          to "Bancolombia",
            "co.com.davivienda.daviplataapp"       to "Daviplata",
            "com.movii.app"                        to "Movii",
            "com.bbva.bbvanetcash"                 to "BBVA",
            "co.com.bancobogota.pab"               to "Banco Bogotá",
        )

        // Patrones para extraer el monto — ordenados de más específico a más genérico.
        // Cubren los formatos reales de Nequi, Bancolombia, Daviplata y similares.
        private val AMOUNT_PATTERNS = listOf(
            // Nequi: "Te enviaron $50.000" / "Recibiste $1.200.000"
            Pattern.compile("""\$\s*([\d]{1,3}(?:[.,]\d{3})*)"""),
            // Nequi alternativo: "50.000 pesos" o "50,000 pesos"
            Pattern.compile("""([\d]{1,3}(?:[.,]\d{3})+)\s*(?:pesos?|cop)""", Pattern.CASE_INSENSITIVE),
            // Bancolombia: "Transferencia por $50.000,00"
            Pattern.compile("""(?:por|de|valor|monto)[:\s]+\$?\s*([\d]{1,3}(?:[.,]\d{3})*)""", Pattern.CASE_INSENSITIVE),
            // Daviplata: "recibiste 50000"
            Pattern.compile("""recib(?:iste|ió|e)\s+\$?\s*([\d.,]+)""", Pattern.CASE_INSENSITIVE),
            // Genérico: cualquier número con puntos de miles (mínimo 4 dígitos)
            Pattern.compile("""([\d]{1,3}(?:\.\d{3})+)"""),
            // Genérico sin separadores (mínimo 4 dígitos)
            Pattern.compile("""(?<!\d)([\d]{4,10})(?!\d)"""),
        )
    }

    private var tts: TextToSpeech? = null
    private var ttsReady = false

    override fun onCreate() {
        super.onCreate()
        initTTS()
        Log.d(TAG, "PaymentNotificationListenerService creado")
    }

    override fun onDestroy() {
        super.onDestroy()
        tts?.stop()
        tts?.shutdown()
        tts = null
        Log.d(TAG, "PaymentNotificationListenerService destruido")
    }

    private fun initTTS() {
        tts = TextToSpeech(applicationContext) { status ->
            if (status == TextToSpeech.SUCCESS) {
                val locale = Locale("es", "CO")
                val result = tts?.setLanguage(locale)
                if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                    tts?.setLanguage(Locale("es", "ES"))
                }
                tts?.setSpeechRate(0.95f)
                tts?.setPitch(1.0f)
                ttsReady = true
                Log.d(TAG, "TTS inicializado OK")
            } else {
                Log.w(TAG, "TTS init falló con status=$status")
            }
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return

        val pkg = sbn.packageName ?: return

        // Log todas las notificaciones de apps bancarias para debug
        if (BANK_NAMES.containsKey(pkg)) {
            Log.d(TAG, "📱 Notif bancaria recibida de $pkg | globalEnabled=$globalEnabled | enabledBanks=$enabledBanks")
        }

        if (!globalEnabled) return

        val bankName = BANK_NAMES[pkg] ?: return

        // Verificar que esta app bancaria esté habilitada
        if (!enabledBanks.contains(pkg)) {
            Log.d(TAG, "⚠️ $pkg no está en enabledBanks — ignorando")
            return
        }

        val extras = sbn.notification?.extras ?: return
        val title = extras.getString(Notification.EXTRA_TITLE) ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString() ?: ""
        val infoText = extras.getCharSequence(Notification.EXTRA_INFO_TEXT)?.toString() ?: ""

        val fullText = listOf(title, text, bigText, subText, infoText)
            .filter { it.isNotBlank() }
            .joinToString(" | ")
        Log.d(TAG, "📨 Texto completo de $bankName: [$fullText]")

        // Extraer monto
        val amount = extractAmount(fullText)

        // SIEMPRE enviar el evento a Flutter para el panel de debug,
        // aunque no se haya podido extraer el monto.
        val debugPayload = mapOf(
            "bank" to bankName,
            "bank_package" to pkg,
            "amount" to (amount ?: ""),
            "speech_text" to "",
            "raw_text" to fullText.trim(),
            "debug_only" to (amount == null),  // true = solo para debug, no hablar
        )
        eventSink?.success(debugPayload)

        if (amount == null) {
            Log.w(TAG, "❌ No se pudo extraer monto de: [$fullText]")
            return
        }
        Log.d(TAG, "✅ Monto detectado: $amount de $bankName")

        // Construir mensaje TTS
        val speechText = messageTemplate
            .replace("{monto}", amount)
            .replace("{banco}", bankName)
            .replace("{banco_nombre}", bankName)

        // Actualizar el payload del evento con los datos completos
        val payload = mapOf(
            "bank" to bankName,
            "bank_package" to pkg,
            "amount" to amount,
            "speech_text" to speechText,
            "raw_text" to fullText.trim(),
            "debug_only" to false,
        )
        eventSink?.success(payload)

        // Hablar con TTS + WakeLock para pantalla bloqueada
        speakWithWakeLock(speechText)
    }

    private fun extractAmount(text: String): String? {
        for (pattern in AMOUNT_PATTERNS) {
            val matcher = pattern.matcher(text)
            if (matcher.find()) {
                val raw = matcher.group(1) ?: continue
                // Normalizar: "50.000" → "50000"
                val normalized = raw.replace(".", "").replace(",", "")
                if (normalized.isNotEmpty() && normalized.all { it.isDigit() }) {
                    // Formatear para mostrar: 50000 → $50.000
                    val number = normalized.toLongOrNull() ?: continue
                    return "$${"%,d".format(number).replace(",", ".")}"
                }
            }
        }
        return null
    }

    private fun formatAmountForSpeech(formatted: String): String {
        // "$50.000" → "cincuenta mil pesos" sería ideal pero TTS español lo lee bien
        // Simplemente remover el $ y los puntos para que TTS lea "50000" o "50.000"
        return formatted
    }

    private fun speakWithWakeLock(text: String) {
        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
        val wl = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "MenuPlat::PaymentTTS",
        )
        wl.acquire(8_000L)  // máximo 8 segundos

        try {
            // Asegurarse de que el volumen de media está alto
            val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            am?.let {
                val maxVol = it.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                if (it.getStreamVolume(AudioManager.STREAM_MUSIC) < maxVol / 3) {
                    it.setStreamVolume(AudioManager.STREAM_MUSIC, maxVol * 2 / 3, 0)
                }
            }

            if (ttsReady && tts != null) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    tts!!.speak(text, TextToSpeech.QUEUE_FLUSH, null, "payment_${System.currentTimeMillis()}")
                } else {
                    @Suppress("DEPRECATION")
                    tts!!.speak(text, TextToSpeech.QUEUE_FLUSH, null)
                }
            } else {
                Log.w(TAG, "TTS no listo — reiniciando")
                initTTS()
            }
        } finally {
            // Liberar WakeLock después de que TTS termine (~5s)
            android.os.Handler(mainLooper).postDelayed({ wl.releaseIfHeld() }, 6_000L)
        }
    }

    private fun PowerManager.WakeLock.releaseIfHeld() {
        if (isHeld) release()
    }
}
