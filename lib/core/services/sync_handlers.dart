import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

import 'app_sync_service.dart';
import 'offline_queue_service.dart';

/// A dónde (y con qué body) mandar un pago encolado al sincronizar.
class PaymentSyncRequest {
  final String path;
  final Map<String, dynamic> body;
  const PaymentSyncRequest({required this.path, required this.body});
}

/// Resuelve el endpoint + body para un payload de pago encolado offline.
/// Función pura (sin DI) para poder testear el routing sin necesitar
/// `Dio`/`GetIt`/`Get` reales — ver el bug real documentado en
/// `SyncHandlers.register()`.
///
/// `null` = entrada corrupta (sin el id que ese tipo necesita) — el
/// caller debe tratarla como "descartar", nunca reintentar para
/// siempre.
PaymentSyncRequest? resolvePaymentSyncRequest(Map<String, dynamic> raw) {
  final payload = Map<String, dynamic>.from(raw);
  final type = payload.remove('type') as String?;

  if (type == 'processTabPayment') {
    final tabSessionId = payload.remove('tab_session_id') as String?;
    if (tabSessionId == null) return null;
    return PaymentSyncRequest(
      path: '/payments/tab/$tabSessionId',
      body: payload,
    );
  }

  final orderId = payload.remove('order_id') as String?;
  if (orderId == null) return null;
  return PaymentSyncRequest(
    path: '/payments/order/$orderId/pay',
    body: payload,
  );
}

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

    // Handler para pagos encolados offline.
    //
    // BUG REAL que esto corrige: antes este handler asumía que SIEMPRE
    // había `order_id` y pegaba a `/orders/:id/payments` (endpoint que
    // ni existe). Un pago de CUENTA/TAB encolado offline no tiene
    // `order_id` (tiene `tab_session_id`) — se marcaba como
    // "sincronizado" y se borraba de la cola SIN mandarlo nunca al
    // backend. Dinero cobrado offline se perdía en silencio. Ver
    // `resolvePaymentSyncRequest` para el routing correcto + sus tests.
    syncService.registerHandler(
      QueueOperationType.createPayment,
      (entry) async {
        try {
          final resolved = resolvePaymentSyncRequest(entry.payload);
          if (resolved == null) return true; // entrada corrupta: descartar
          await dio.post(resolved.path, data: resolved.body);
          return true;
        } catch (e) {
          return false;
        }
      },
    );

    // Handlers para fichaje (clock-in/clock-out) encolado offline —
    // ver ShiftRepositoryImpl para el porqué es seguro encolar esto
    // (no genera un ID que algo más vaya a referenciar antes de
    // sincronizar, a diferencia de crear un producto/una cuenta).
    syncService.registerHandler(
      QueueOperationType.clockIn,
      (entry) async {
        try {
          await dio.post('/shifts/clock-in', data: entry.payload);
          return true;
        } catch (e) {
          return false;
        }
      },
    );
    syncService.registerHandler(
      QueueOperationType.clockOut,
      (entry) async {
        try {
          await dio.post('/shifts/clock-out', data: entry.payload);
          return true;
        } catch (e) {
          return false;
        }
      },
    );
  }
}
