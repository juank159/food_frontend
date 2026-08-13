import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import '../config/constants/api_constants.dart';
import '../routes/app_routes.dart';
import '../utils/api_response_utils.dart';

/// Canal v6: IMPORTANCE_HIGH con sonido del sistema (sin URI custom).
/// Creado por MainApplication.setupQrChannel() — solo si no existe, para que
/// Android no degrade la importancia al borrar/recrear con el mismo ID.
final _kQrChannel = AndroidNotificationChannel(
  'qr_orders_v6',
  'Pedidos QR',
  description: 'Alertas de nuevos pedidos enviados por clientes desde el menú QR.',
  importance: Importance.max,
  enableVibration: true,
  vibrationPattern: Int64List.fromList([0, 800, 200, 800, 200, 800]),
);

final FlutterLocalNotificationsPlugin _localNotifs =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  // Cuando otro dispositivo del mismo tenant aprobó/rechazó el pedido,
  // cancelamos la notificación local para que no siga visible en la bandeja.
  if (message.data['action'] == 'dismiss_notification') {
    final orderId = message.data['order_id'] as String?;
    if (orderId != null) {
      WidgetsFlutterBinding.ensureInitialized();
      final notifs = FlutterLocalNotificationsPlugin();
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      await notifs.initialize(
        const InitializationSettings(android: androidSettings),
      );
      await notifs.cancel(orderId.hashCode);
    }
  }
}

class PushNotificationService {
  PushNotificationService._();

  static bool _initialized = false;

  static Future<void> init() async {
    if (kIsWeb) return; // FCM + flutter_local_notifications no soportados en web
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
      _initialized = true;
    } catch (e) {
      debugPrint('[FCM] Firebase no inicializado: $e');
      return;
    }

    await _localNotifs
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_kQrChannel);

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

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      sound: true,
      badge: true,
    );

    // Foreground: mostrar heads-up via flutter_local_notifications
    FirebaseMessaging.onMessage.listen(_showForegroundNotif);

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpen);
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handleMessageOpen(initial);
  }

  static Future<void> registerToken(Dio dio) async {
    if (kIsWeb) return;
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

      await dio.post(
        ApiConstants.fcmRegisterToken,
        data: {'token': token, 'platform': platform},
      );

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          await dio.post(ApiConstants.fcmRegisterToken, data: {
            'token': newToken,
            'platform': platform,
          });
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('[FCM] registerToken error: ${ApiResponseUtils.errorMessage(e)}');
    }
  }

  static Future<void> unregisterToken(Dio dio) async {
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await dio.delete(ApiConstants.fcmUnregisterToken, data: {'token': token});
    } catch (_) {}
  }

  static void _showForegroundNotif(RemoteMessage message) {
    // Señal de dismiss: otro dispositivo del mismo tenant ya atendió el pedido.
    if (message.data['action'] == 'dismiss_notification') {
      final orderId = message.data['order_id'] as String?;
      if (orderId != null) _localNotifs.cancel(orderId.hashCode);
      return;
    }

    // Alerta de pago bancario: mostrar heads-up con el texto del pago.
    if (message.data['type'] == 'payment_alert') {
      final speechText = message.data['speech_text'] as String? ?? '';
      final bank = message.data['bank'] as String? ?? 'banco';
      final amount = message.data['amount'] as String? ?? '';
      if (speechText.isNotEmpty) {
        _localNotifs.show(
          'payment_alert'.hashCode,
          '💰 Pago recibido',
          speechText,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _kQrChannel.id,
              _kQrChannel.name,
              channelDescription: _kQrChannel.description,
              importance: Importance.max,
              priority: Priority.max,
              enableVibration: true,
              icon: '@drawable/ic_notification',
              color: const Color(0xFF4CAF50),
            ),
            iOS: const DarwinNotificationDetails(),
          ),
        );
      }
      return;
    }

    final notif = message.notification;
    if (notif == null) return;

    // Usar order_id como ID de notificación para poder cancelarla luego.
    final orderId = message.data['order_id'] as String?;
    final notifId = orderId?.hashCode ?? notif.hashCode;

    _localNotifs.show(
      notifId,
      notif.title,
      notif.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _kQrChannel.id,
          _kQrChannel.name,
          channelDescription: _kQrChannel.description,
          importance: Importance.max,
          priority: Priority.max,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 800, 200, 800, 200, 800]),
          icon: '@drawable/ic_notification',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          color: const Color(0xFFFF6B35),
        ),
        iOS: const DarwinNotificationDetails(),
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.toNamed(AppRoutes.pendingReviewOrders);
      });
    }
  }
}
