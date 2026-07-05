package com.foodplatform.food_platform_app

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build

/**
 * Application class que crea el canal de notificaciones QR con sonido
 * custom ANTES de que Firebase pueda auto-crearlo sin sonido.
 *
 * Android cachea los ajustes del canal la primera vez que se crea. Si FCM
 * llega con channelId='qr_orders_v2' y el canal no existe, Android lo crea
 * con ajustes por defecto (sin sonido custom). Esta clase previene eso
 * creando el canal correctamente en el primer arranque de la app/proceso.
 */
class MainApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            createQrOrdersChannel()
        }
    }

    private fun createQrOrdersChannel() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Si el canal ya existe no hacemos nada (Android lo ignora de todas formas).
        if (manager.getNotificationChannel("qr_orders_v2") != null) return

        val soundUri = Uri.parse(
            "android.resource://$packageName/raw/qr_alert"
        )
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val channel = NotificationChannel(
            "qr_orders_v2",
            "Pedidos QR",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Alertas de nuevos pedidos enviados por clientes desde el menú QR."
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 800, 200, 800, 200, 800)
            setSound(soundUri, audioAttributes)
            enableLights(true)
            lightColor = 0xFFFF6B35.toInt()
        }

        manager.createNotificationChannel(channel)
    }
}
