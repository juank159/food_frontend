import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

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

  @override
  void onInit() {
    super.onInit();
    _start();
  }

  void _start() {
    // En web dart:io no está disponible — asumimos siempre online.
    // Dio se encarga de propagar errores de red cuando falla una petición.
    if (kIsWeb) {
      isOnline.value = true;
      return;
    }

    final checker = InternetConnectionChecker();

    // Verificar estado inicial de forma no bloqueante
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
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}

/// Forward declaration para evitar dependencia circular.
/// El SyncService real se registra en DI.
abstract class SyncService {
  Future<void> processQueue();
}
