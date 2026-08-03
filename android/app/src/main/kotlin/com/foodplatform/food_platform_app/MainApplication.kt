package com.foodplatform.food_platform_app

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

/**
 * Gestiona el canal de notificaciones QR.
 *
 * Canal v6: se crea UNA SOLA VEZ (solo si no existe). Android almacena la
 * importancia del canal internamente — borrar y recrear con el mismo ID puede
 * degradarla; usar un ID nuevo y no destruirlo garantiza IMPORTANCE_HIGH estable.
 */
class MainApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            setupQrChannel()
        }
    }

    private fun setupQrChannel() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Eliminar canales obsoletos (v1–v5) para liberar espacio en ajustes del sistema.
        listOf("qr_orders", "qr_orders_v2", "qr_orders_v3", "qr_orders_v4", "qr_orders_v5")
            .forEach { manager.deleteNotificationChannel(it) }

        // Crear v6 solo si no existe. Si ya existe, Android conserva la importancia
        // que el usuario o el sistema hayan asignado — NO hay que borrarlo/recrearlo.
        if (manager.getNotificationChannel("qr_orders_v6") == null) {
            val channel = NotificationChannel(
                "qr_orders_v6",
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
}
