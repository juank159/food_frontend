import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

import 'app_sync_service.dart';
import 'offline_queue_service.dart';

/// Registra los handlers de sincronización para cada tipo de operación.
/// Llamar una sola vez en la inicialización de la app (en di.init o en
/// el AuthController al hacer login).
class SyncHandlers {
  static void register() {
    final syncService = Get.find<AppSyncService>();
    final sl = GetIt.instance;
    final dio = sl<Dio>();

    // Handler para crear órdenes encoladas offline
    syncService.registerHandler(
      QueueOperationType.createOrder,
      (entry) async {
        try {
          await dio.post('/orders', data: entry.payload);
          return true;
        } catch (e) {
          return false;
        }
      },
    );

    // Handler para pagos encolados offline
    syncService.registerHandler(
      QueueOperationType.createPayment,
      (entry) async {
        try {
          final orderId = entry.payload['order_id'] as String?;
          if (orderId == null) return true; // discard corrupt entry
          await dio.post('/orders/$orderId/payments', data: entry.payload);
          return true;
        } catch (e) {
          return false;
        }
      },
    );
  }
}
