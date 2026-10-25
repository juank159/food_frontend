import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import 'browser/browser_online.dart';
import 'realtime_service.dart';

/// Servicio singleton que expone el estado de conectividad como stream reactivo.
///
/// Se registra en DI como `Get.put(ConnectivityService(), permanent: true)`.
///
/// Al detectar reconexión, dispara automáticamente el [SyncService]
/// para procesar la cola de operaciones pendientes.
///
/// Uso en widgets:
///   ```dart
///   Obx(() => ConnectivityService.to.isOnline.value
///     ? const SizedBox()
///     : const OfflineBanner())
///   ```
class ConnectivityService extends GetxController {
  static ConnectivityService get to => Get.find<ConnectivityService>();

  final RxBool isOnline = true.obs;
  StreamSubscription<InternetConnectionStatus>? _sub;
  StreamSubscription<bool>? _webSub;

  @override
  void onInit() {
    super.onInit();
    _start();
  }

  void _start() {
    // En web dart:io no está disponible: se usan los eventos `online` /
    // `offline` del navegador. Bug real: antes se asumía "siempre online"
    // y la cola offline (compras, ajustes de inventario hechos justo
    // cuando se cayó la red) NUNCA se sincronizaba en la PWA.
    if (kIsWeb) {
      isOnline.value = browserIsOnline();
      _webSub = browserOnlineChanges().listen((online) {
        final wasOffline = !isOnline.value;
        isOnline.value = online;
        if (wasOffline && online) _onReconnected();
      });
      return;
    }

    final checker = InternetConnectionChecker();

    // Verificar estado inicial de forma no bloqueante. (La cola pendiente
    // de una sesión anterior se manda al iniciar sesión — ver
    // `AuthController._startBackgroundServices`; acá todavía no hay token.)
    checker.hasConnection.then((connected) {
      isOnline.value = connected;
    });

    // Suscribirse a cambios continuos
    _sub = checker.onStatusChange.listen((status) {
      final wasOffline = !isOnline.value;
      isOnline.value = status == InternetConnectionStatus.connected;

      if (wasOffline && isOnline.value) {
        _onReconnected();
      }
    });
  }

  void _onReconnected() {
    // Disparar sync si el servicio está registrado
    if (Get.isRegistered<SyncService>()) {
      Get.find<SyncService>().processQueue();
    }
    // Reconectar el socket de "aviso en vivo" — si se cayó junto con
    // la red, socket.io ya reintenta solo, pero esto cubre el caso
    // donde nunca llegó a conectar (ej. arrancó sin red) y ahora sí
    // hay sesión + red.
    if (Get.isRegistered<RealtimeService>()) {
      Get.find<RealtimeService>().connect().ignore();
    }
  }

  @override
  void onClose() {
    _sub?.cancel();
    _webSub?.cancel();
    super.onClose();
  }
}

/// Forward declaration para evitar dependencia circular.
/// El SyncService real se registra en DI.
abstract class SyncService {
  Future<void> processQueue();
}
