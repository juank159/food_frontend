import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import '../config/constants/api_constants.dart';
import '../routes/app_routes.dart';
import '../utils/api_response_utils.dart';

/// Canal de Android que recibe las alertas QR.
/// v2: renombrado para forzar recreación con sonido correcto (el canal original
/// fue creado sin sonido y Android cachea los ajustes del canal).
/// No-const porque vibrationPattern requiere Int64List.
final _kQrChannel = AndroidNotificationChannel(
  'qr_orders_v2',
  'Pedidos QR',
  description: 'Alertas de nuevos pedidos enviados por clientes desde el menú QR.',
  importance: Importance.max,
  playSound: true,
  sound: const RawResourceAndroidNotificationSound('qr_alert'),
  enableVibration: true,
  vibrationPattern: Int64List.fromList([0, 800, 200, 800, 200, 800]),
);

final FlutterLocalNotificationsPlugin _localNotifs =
    FlutterLocalNotificationsPlugin();

/// Handler en segundo plano — solo inicializa Firebase.
/// Android muestra la notificación automáticamente desde el payload FCM.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
}

/// Servicio singleton de push notifications (FCM).
///
/// Flujo:
///   1. `init()` en main.dart → inicializa Firebase + canal Android + handlers.
///   2. `registerToken(dio)` tras login → obtiene FCM token y lo envía al backend.
///   3. `unregisterToken(dio)` al logout → elimina el token del backend.
///
/// Si Firebase no está configurado (falta google-services.json), todo cae
/// silenciosamente y el sistema de alertas in-app sigue funcionando.
class PushNotificationService {
  PushNotificationService._();

  static bool _initialized = false;

  /// Inicializa Firebase, crea el canal de notificaciones de Android y
  /// configura los handlers. Llamar una sola vez en `main()`.
  static Future<void> init() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
      _initialized = true;
    } catch (e) {
      // Firebase no configurado todavía (falta google-services.json / plist).
      // El sistema de alertas in-app (polling) sigue funcionando normalmente.
      debugPrint('[FCM] Firebase no inicializado: $e');
      return;
    }

    // ── Canal Android (alta prioridad, sonido custom) ──────────────────────
    await _localNotifs
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_kQrChannel);

    // ── Inicializar flutter_local_notifications ────────────────────────────
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifs.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotifTap,
    );

    // ── Permisos ───────────────────────────────────────────────────────────
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      sound: true,
      badge: true,
    );

    // ── Foreground: mostrar como heads-up via flutter_local_notifications ──
    FirebaseMessaging.onMessage.listen(_showForegroundNotif);

    // ── Tap en notificación cuando app estaba en background (no terminada) ─
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpen);

    // ── Handler de background / terminated ────────────────────────────────
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

    // ── Tap en notificación que abrió la app desde terminada ───────────────
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handleMessageOpen(initial);
  }

  /// Obtiene el FCM token y lo registra en el backend.
  /// Llama en `AuthController` justo después de login exitoso.
  static Future<void> registerToken(Dio dio) async {
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await dio.post(
        ApiConstants.fcmRegisterToken,
        data: {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
      );

      // Escuchar renovaciones de token (FCM puede rotar el token).
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          await dio.post(ApiConstants.fcmRegisterToken, data: {
            'token': newToken,
            'platform': Platform.isIOS ? 'ios' : 'android',
          });
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('[FCM] registerToken error: ${ApiResponseUtils.errorMessage(e)}');
    }
  }

  /// Elimina el token FCM del backend al hacer logout.
  static Future<void> unregisterToken(Dio dio) async {
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await dio.delete(ApiConstants.fcmUnregisterToken, data: {'token': token});
    } catch (_) {}
  }

  // ── Helpers privados ───────────────────────────────────────────────────────

  static void _showForegroundNotif(RemoteMessage message) {
    final notif = message.notification;
    if (notif == null) return;

    _localNotifs.show(
      notif.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _kQrChannel.id,
          _kQrChannel.name,
          channelDescription: _kQrChannel.description,
          importance: Importance.max,
          priority: Priority.max,
          sound: const RawResourceAndroidNotificationSound('qr_alert'),
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 800, 200, 800, 200, 800]),
          // Ícono pequeño en la barra de estado (debe ser monochrome/blanco).
          icon: '@drawable/ic_notification',
          // Ícono grande (color completo) en la bandeja de notificaciones.
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          color: const Color(0xFFFF6B35),
        ),
        iOS: const DarwinNotificationDetails(sound: 'qr_alert.aiff'),
      ),
      payload: message.data['type'] as String?,
    );
  }

  static void _onNotifTap(NotificationResponse details) {
    if (details.payload == 'qr_order') {
      Get.toNamed(AppRoutes.pendingReviewOrders);
    }
  }

  static void _handleMessageOpen(RemoteMessage message) {
    if (message.data['type'] == 'qr_order') {
      // Diferir hasta que el árbol de widgets esté listo.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.toNamed(AppRoutes.pendingReviewOrders);
      });
    }
  }
}
