package com.foodplatform.food_platform_app

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build

/**
 * Gestiona el canal de notificaciones QR.
 *
 * Canal v7: se crea UNA SOLA VEZ (solo si no existe). Android almacena la
 * importancia del canal internamente — borrar y recrear con el mismo ID puede
 * degradarla; usar un ID nuevo y no destruirlo garantiza IMPORTANCE_HIGH estable.
 *
 * Bug real reportado: en v6 esto sonaba con el tono default de Android y NO
 * vibraba estando el celular bloqueado — a pesar de que el código de acá SÍ
 * pedía vibración, Android fija las propiedades de un canal (sonido,
 * vibración) la PRIMERA vez que se crea en ese dispositivo y nunca las
 * actualiza después, aunque el código cambie — por eso cualquier cambio de
 * sonido/vibración REQUIERE subir el ID del canal, no alcanza con editar
 * este archivo. Antes de v7 directamente no se intentaba sonido custom: un
 * intento más viejo (ver `qr_orders_v2`, julio 2026) lo sacó porque, con el
 * sonido armado como URI de texto (`android.resource://paquete/raw/nombre`),
 * el proceso del SDK de FCM no lograba resolver el recurso y el canal
 * quedaba mudo — peor que el sonido default. Acá se vuelve a intentar con
 * la forma recomendada por Android: URI armada con el ID de recurso
 * compilado (`R.raw.qr_alert`), no con el nombre como texto — evita esa
 * resolución en tiempo de ejecución que fallaba antes.
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

        // Eliminar canales obsoletos (v1–v6) para liberar espacio en ajustes del sistema.
        listOf(
            "qr_orders", "qr_orders_v2", "qr_orders_v3", "qr_orders_v4",
            "qr_orders_v5", "qr_orders_v6",
        ).forEach { manager.deleteNotificationChannel(it) }

        // Crear v7 solo si no existe. Si ya existe, Android conserva la importancia
        // que el usuario o el sistema hayan asignado — NO hay que borrarlo/recrearlo.
        if (manager.getNotificationChannel("qr_orders_v7") == null) {
            val soundUri = Uri.parse(
                "android.resource://$packageName/${R.raw.qr_alert}"
            )
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            val channel = NotificationChannel(
                "qr_orders_v7",
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
}
