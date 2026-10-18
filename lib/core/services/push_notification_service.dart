import 'dart:async';
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
import 'package:vibration/vibration.dart';

import '../config/constants/api_constants.dart';
import '../routes/app_routes.dart';
import '../utils/api_response_utils.dart';
import '../../features/payments/presentation/controllers/breb_payment_controller.dart';

/// `playerId` fijo (no uno random por instancia) — así una llamada a
/// `AudioPlayer(playerId: _kRingingPlayerId).stop()` hecha desde el
/// isolate PRINCIPAL (cuando el usuario abre el pedido) apunta al mismo
/// reproductor nativo que arrancó `firebaseBackgroundMessageHandler` en
/// su propio isolate — son objetos Dart distintos, pero `audioplayers`
/// los resuelve por este id contra el mismo registro nativo del proceso.
const _kRingingPlayerId = 'qr_alert_ring';

/// Mismo patrón que usa `PendingReviewWatcher` para la alerta en
/// foreground — repetir el mismo patrón es intencional, es la MISMA
/// alerta, solo que esta corre con la app cerrada/bloqueada.
const _kRingingVibrationPattern = [0, 800, 200, 800, 200, 800, 200, 800];

/// El audio de `qr_alert.mp3` es corto — sonar UNA sola vez no se nota
/// lo suficiente. Se repite esta cantidad de veces (NO infinito, a
/// diferencia de la vibración) si el pedido no se revisa antes.
const _kRingingSoundRepeats = 3;

/// Canal v7: IMPORTANCE_HIGH con sonido custom (`res/raw/qr_alert.mp3`) y
/// vibración. Creado de verdad por `MainApplication.setupQrChannel()` (Kotlin
/// nativo, corre en `Application.onCreate()` antes de que exista el engine
/// de Flutter) — este objeto solo mantiene el `id` sincronizado para que las
/// notificaciones mostradas en foreground (`_localNotifs.show`) usen el
/// mismo canal. Bug real reportado: el canal v6 sonaba con el tono default
/// de Android y no vibraba estando bloqueado — Android fija sonido/vibración
/// la PRIMERA vez que un canal se crea en el dispositivo y nunca los
/// actualiza después aunque el código cambie, así que cualquier ajuste de
/// sonido/vibración necesita subir el ID del canal (ver el comentario largo
/// en `MainApplication.kt` para la causa real de por qué el intento anterior
/// de sonido custom quedaba mudo).
final _kQrChannel = AndroidNotificationChannel(
  'qr_orders_v7',
  'Pedidos QR',
  description: 'Alertas de nuevos pedidos enviados por clientes desde el menú QR.',
  importance: Importance.max,
  enableVibration: true,
  vibrationPattern: Int64List.fromList([0, 800, 200, 800, 200, 800]),
  sound: const RawResourceAndroidNotificationSound('qr_alert'),
);

final FlutterLocalNotificationsPlugin _localNotifs =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  // Cuando otro dispositivo del mismo tenant aprobó/rechazó el pedido,
  // cancelamos la notificación local para que no siga visible en la bandeja
  // Y apagamos la alerta en loop (sonido+vibración) si estaba sonando.
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
    await PushNotificationService.stopRingingAlert();
    return;
  }

  // Bug real reportado: una notificación normal de Android suena UNA
  // sola vez — no alcanza para que el mesero se dé cuenta con el
  // celular en el bolsillo o bloqueado. Dentro de la app esto ya
  // funciona bien vía `PendingReviewWatcher` (loop de sonido+vibración
  // hasta "Ahora no"/"Ver pedidos") — pero ese código solo corre con
  // la app viva en memoria. Esto replica el mismo loop desde el
  // handler en background, que SÍ se dispara con la app cerrada.
  //
  // Por qué llega en un mensaje aparte (`qr_order_ring`, solo datos) y
  // no junto con la notificación visible: Android solo invoca este
  // handler en background/con la app cerrada para mensajes SIN bloque
  // `notification` — si llega junto con uno (como la notificación
  // visible principal), Android la entrega directo a la bandeja del
  // sistema y este handler nunca se dispara. Ya pasó una vez en este
  // proyecto (julio 2026): mandar TODO como solo-datos para controlar
  // el sonido hizo que las notificaciones dejaran de llegar de forma
  // confiable, y se tuvo que revertir. Por eso la notificación visible
  // (confiable, siempre llega) y este loop (best-effort, se arma
  // encima) van en mensajes separados — si este segundo mensaje
  // llegara tarde o se perdiera, el mesero de todos modos ve y
  // escucha la notificación principal una vez.
  if (message.data['type'] == 'qr_order_ring') {
    await PushNotificationService.startRingingAlert();
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
      stopRingingAlert().ignore();
      Get.toNamed(AppRoutes.pendingReviewOrders);
    }
  }

  /// Bug real reportado: con la app TOTALMENTE cerrada, tocar la
  /// notificación la abría pero mandaba a Home en vez de ir directo a
  /// la bandeja de pedidos QR. Causa: en ese caso (`getInitialMessage`,
  /// ver `init()`) este método corre DENTRO de `main()`, ANTES de
  /// `runApp()` — el Navigator de GetX todavía no existe, así que el
  /// `Get.toNamed` de abajo no tiene dónde navegar y se pierde; después,
  /// el `SplashController` decide la ruta normal (Home) sin saber que
  /// hay un pedido pendiente por mostrar.
  ///
  /// Fix: además del intento directo (que SÍ funciona cuando la app ya
  /// estaba corriendo en background — `onMessageOpenedApp`, no
  /// `getInitialMessage`), se deja una bandera que `SplashController`
  /// consume después de decidir Home, para completar la navegación en
  /// el momento correcto del ciclo de vida.
  static void _handleMessageOpen(RemoteMessage message) {
    if (message.data['type'] == 'qr_order') {
      stopRingingAlert().ignore();
      _pendingQrOrderLaunch = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.toNamed(AppRoutes.pendingReviewOrders);
      });
    }
  }

  static bool _pendingQrOrderLaunch = false;

  /// Lee y limpia la bandera de "la app se abrió tocando una
  /// notificación de pedido QR". `SplashController` la consume una sola
  /// vez, justo después de decidir que el destino es Home.
  static bool consumePendingQrOrderLaunch() {
    final value = _pendingQrOrderLaunch;
    _pendingQrOrderLaunch = false;
    return value;
  }

  // ───────────────────── Alerta en loop (ver más arriba) ─────────────────────

  static AudioPlayer? _ringPlayer;
  static StreamSubscription<void>? _ringSoundSub;

  /// Arranca la alerta desde `firebaseBackgroundMessageHandler`. Nunca
  /// debe tumbar el handler — cualquier falla queda en silencio.
  ///
  /// Vibración: en loop infinito de verdad (`repeat: 0` en el patrón) —
  /// una vez que el sistema operativo arranca ese patrón queda a su
  /// cargo, sigue sonando aunque el isolate de Dart en background
  /// termine, hasta `Vibration.cancel()` o que [stopRingingAlert] lo
  /// pare.
  ///
  /// Sonido: el audio (`qr_alert.mp3`) es corto — sonar una sola vez no
  /// se nota. Se repite [_kRingingSoundRepeats] veces (NO infinito,
  /// a diferencia de la vibración) si no se revisa antes.
  static Future<void> startRingingAlert() async {
    try {
      final hasVibrator = (await Vibration.hasVibrator()) == true;
      if (hasVibrator) {
        await Vibration.vibrate(
          pattern: _kRingingVibrationPattern,
          repeat: 0,
          intensities: const [0, 255, 0, 255, 0, 255, 0, 255],
        );
      }
    } catch (_) {}

    try {
      await _ringSoundSub?.cancel();
      final player = AudioPlayer(playerId: _kRingingPlayerId);
      _ringPlayer = player;
      await player.setReleaseMode(ReleaseMode.stop);

      var remainingPlays = _kRingingSoundRepeats - 1; // esta primera cuenta.
      _ringSoundSub = player.onPlayerComplete.listen((_) {
        if (remainingPlays <= 0) return;
        remainingPlays--;
        player.play(AssetSource('sounds/qr_alert.mp3')).ignore();
      });

      await player.play(AssetSource('sounds/qr_alert.mp3'));
    } catch (_) {
      // Sin archivo de sonido o sin soporte de audio en background — al
      // menos la vibración (que sí es confiablemente a nivel de sistema)
      // ya quedó andando arriba.
    }
  }

  /// Apaga la alerta — se llama al abrir el pedido/la bandeja de pedidos
  /// QR, al tocar la notificación, o cuando llega la señal de que otro
  /// dispositivo ya atendió el pedido. Idempotente: no hace nada si no
  /// había ninguna alerta corriendo.
  static Future<void> stopRingingAlert() async {
    try {
      await Vibration.cancel();
    } catch (_) {}
    try {
      await _ringSoundSub?.cancel();
      _ringSoundSub = null;
    } catch (_) {}
    try {
      final player = _ringPlayer ?? AudioPlayer(playerId: _kRingingPlayerId);
      await player.stop();
      await player.release();
    } catch (_) {}
    _ringPlayer = null;
  }
}
