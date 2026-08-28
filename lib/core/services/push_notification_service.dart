import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';

import '../config/constants/api_constants.dart';
import '../routes/app_routes.dart';
import '../utils/api_response_utils.dart';
import '../../features/payments/presentation/controllers/breb_payment_controller.dart';

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
  static final FlutterTts _tts = FlutterTts();
  static bool _ttsConfigured = false;

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

    // Pago Bre-B conciliado: actualizar el diálogo de cobro si está abierto
    // (evita esperar el próximo tick del polling de 3s) y anunciarlo con voz.
    if (message.data['type'] == 'breb_payment_confirmed') {
      final orderId = message.data['order_id'] as String?;
      final amount = message.data['amount'] as String? ?? '';
      final payerName = message.data['payer_name'] as String? ?? '';
      final bank = message.data['bank'] as String? ?? '';

      final activeCtrl = BrebPaymentController.active;
      if (activeCtrl != null && activeCtrl.activeOrderId == orderId) {
        activeCtrl.markConfirmed(payer: payerName);
      }

      if (amount.isNotEmpty) {
        _speak(
          bank.isNotEmpty
              ? 'Recibiste en $bank, $amount pesos'
              : 'Pago recibido, $amount pesos',
        );
      }

      _localNotifs.show(
        'breb_payment_confirmed'.hashCode,
        bank.isNotEmpty ? '💰 Pago recibido — $bank' : '💰 Pago Bre-B recibido',
        payerName.isNotEmpty ? '\$$amount · $payerName' : '\$$amount',
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

  /// Anuncia el texto en voz alta (reemplaza al TTS nativo del listener de
  /// notificaciones que se sacó por bloquear la publicación en las tiendas
  /// de apps). Si el motor TTS no está disponible en el dispositivo, cae a
  /// un sonido simple — nunca debe fallar en silencio total.
  static Future<void> _speak(String text) async {
    try {
      if (!_ttsConfigured) {
        await _tts.setLanguage('es-CO');
        await _tts.setSpeechRate(0.48);
        await _tts.setVolume(1.0);
        _ttsConfigured = true;
      }
      await _tts.speak(text);
    } catch (e) {
      debugPrint('[TTS] error hablando "$text": $e — usando sonido de respaldo');
      try {
        await AudioPlayer().play(AssetSource('sounds/qr_alert.mp3'));
      } catch (_) {}
    }
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
