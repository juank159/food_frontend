import 'package:flutter/foundation.dart' show debugPrint;
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/constants/api_constants.dart';
import '../di/injection_container.dart';
import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/orders/presentation/controllers/orders_controller.dart';
import '../../features/products/presentation/controllers/products_controller.dart';
import '../../features/tab_sessions/presentation/controllers/open_tabs_controller.dart';
import '../../features/tab_sessions/presentation/controllers/tab_session_detail_controller.dart';
import '../../features/inventory/services/inventory_stock_service.dart';

/// Aviso en vivo entre dispositivos del mismo negocio — ver el
/// comentario largo en `realtime.gateway.ts` (backend) para el
/// diseño completo y por qué esto NO es sync incremental real.
///
/// Bug real reportado: "necesito que me entere automático si otro
/// dispositivo hizo cambios, sin tener que refrescar a mano". Antes
/// de esto, un dispositivo solo veía cambios hechos en OTRO
/// dispositivo cuando el operario refrescaba manualmente o
/// re-entraba a la pantalla.
///
/// Cómo funciona: el backend emite un evento `change` (con
/// `{entity, action, at}`) por cada escritura relevante en
/// Orders/Products/TabSessions — ver `RealtimeGateway.notifyChange`.
/// Este servicio escucha ese evento y llama al MISMO método de
/// refresco que ya usa cada pantalla (pull-to-refresh / entrar a la
/// pantalla) — no inventa un camino de datos nuevo, solo decide
/// CUÁNDO disparar el que ya existe.
///
/// **Nunca bloquea ni puede tumbar la app**: conectar/desconectar
/// corre siempre en background, cualquier error se loguea y se
/// ignora — esto es una mejora de UX, no una dependencia crítica.
class RealtimeService extends GetxController {
  static RealtimeService get to => Get.find<RealtimeService>();

  io.Socket? _socket;

  /// `true` si hay un socket activo y autenticado — informativo nomás
  /// (ningún flujo de negocio depende de esto).
  final RxBool isConnected = false.obs;

  /// Conecta (o reconecta) el socket con el access token actual. Si no
  /// hay sesión (nadie logueado todavía) no hace nada — se vuelve a
  /// intentar en el próximo `connect()` explícito (login exitoso,
  /// reconexión de red — ver `ConnectivityService`).
  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    String? token;
    try {
      token = await sl<AuthLocalDataSource>().getAccessToken();
    } catch (_) {
      return;
    }
    if (token == null || token.isEmpty) return;

    final socketBaseUrl = ApiConstants.baseUrl.replaceFirst('/api/v1', '');
    debugPrint('[RealtimeService] conectando a $socketBaseUrl/realtime...');

    // Reconstruir de cero en vez de reusar: el token pudo haber
    // cambiado (refresh) desde la última conexión, y socket.io no
    // relee `auth` solo porque se lo pida — hay que recrear el socket
    // con el valor nuevo.
    _socket?.dispose();

    _socket = io.io(
      '$socketBaseUrl/realtime',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .build(),
    );

    _socket!.onConnect((_) {
      isConnected.value = true;
      debugPrint('[RealtimeService] conectado');
    });
    _socket!.onDisconnect((_) {
      isConnected.value = false;
      debugPrint('[RealtimeService] desconectado');
    });
    _socket!.onConnectError((error) {
      isConnected.value = false;
      debugPrint('[RealtimeService] error de conexión: $error');
    });
    _socket!.on('change', _handleChange);
  }

  /// Decide a qué controller avisarle según `entity` — mismo método
  /// de refresco que cada pantalla ya usa al entrar/pull-to-refresh.
  /// Si el controller no está registrado (pantalla no abierta en este
  /// momento), no hay nada que refrescar — la próxima vez que se abra
  /// esa pantalla va a pedir datos frescos de cualquier forma (local-
  /// first: `load()`/`loadOrders()`/`loadProducts()`).
  void _handleChange(dynamic data) {
    try {
      final map = data as Map;
      final entity = map['entity'] as String?;
      debugPrint('[RealtimeService] change recibido: $data');
      switch (entity) {
        case 'orders':
          if (Get.isRegistered<OrdersController>()) {
            Get.find<OrdersController>().loadOrders();
          }
          break;
        case 'tab_sessions':
          if (Get.isRegistered<OpenTabsController>()) {
            Get.find<OpenTabsController>().load();
          }
          // Bug real reportado: el backend ahora SÍ avisa este evento
          // al vender/agregar un item/aplicar un descuento/pagar (ver
          // `TabSessionsService.recomputeRollups` — antes nunca
          // notificaba porque no tenía `tenantSchema` a mano). Si la
          // pantalla de detalle de UNA cuenta (con todos sus tickets)
          // está abierta, también se refresca sola — antes solo se
          // actualizaba el LISTADO de "Cuentas abiertas", nunca el
          // detalle de una cuenta específica ya abierta.
          if (Get.isRegistered<TabSessionDetailController>()) {
            Get.find<TabSessionDetailController>().load();
          }
          break;
        case 'inventory':
          // Otra caja vendió (descuenta insumos) o alguien registró una
          // compra/merma/receta: refrescar el stock local-first que usan
          // la pantalla de venta y la de inventario.
          InventoryStockService.maybe?.refresh();
          break;
        case 'products':
          if (Get.isRegistered<ProductsController>()) {
            Get.find<ProductsController>().loadProducts();
          }
          break;
      }
    } catch (error) {
      debugPrint('[RealtimeService] error procesando evento change: $error');
    }
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    isConnected.value = false;
  }

  @override
  void onClose() {
    disconnect();
    super.onClose();
  }
}
