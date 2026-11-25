package com.example.project_ena

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    // Canal de las notificaciones push. Debe coincidir con
    // ANDROID_CHANNEL_ID del servidor (app/services/push_service.py).
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            "connect_do_general",
            "Actividad de Connect Do",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Mensajes, me gusta, comentarios, contactos y postulaciones"
        }
        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }
}
