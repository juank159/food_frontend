package com.foodplatform.food_platform_app

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

/**
 * Crea el canal de notificaciones QR en cada arranque de proceso.
 * Al borrar y recrear siempre garantizamos que el canal tiene
 * IMPORTANCE_HIGH con vibración, sin depender del estado previo.
 */
class MainApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            recreateQrChannel()
        }
    }

    private fun recreateQrChannel() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Limpiar canales anteriores del dispositivo
        listOf("qr_orders", "qr_orders_v2", "qr_orders_v3", "qr_orders_v4", "qr_orders_v5")
            .forEach { manager.deleteNotificationChannel(it) }

        // Canal v5: IMPORTANCE_HIGH con sonido por defecto del sistema y vibración fuerte.
        // Sin URI de sonido custom — el sonido custom causaba que Android no pudiera
        // resolver el recurso desde el proceso del SDK de FCM, silenciando el canal.
        val channel = NotificationChannel(
            "qr_orders_v5",
            "Pedidos QR",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Alertas de nuevos pedidos enviados por clientes desde el menú QR."
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 800, 200, 800, 200, 800)
            enableLights(true)
            lightColor = 0xFFFF6B35.toInt()
        }

        manager.createNotificationChannel(channel)
    }
}
