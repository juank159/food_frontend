import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../data/datasources/order_remote_datasource.dart';

/// **Servicio singleton** que vigila la cola de self-orders pendientes
/// de aprobación EN BACKGROUND, independiente de la pantalla activa.
///
/// **Por qué es necesario:**
///
/// El `PendingReviewController` solo polea cuando la bandeja está
/// abierta. Pero el flujo real es: cliente envía pedido → mesero está
/// en otra pantalla (cobrando, tomando otra mesa) → **no se entera**.
/// Sin este watcher, los pedidos se acumulan sin atención hasta que
/// alguien abre la bandeja manualmente.
///
/// Este watcher se inicia en el login (si el rol del user puede
/// aprobar) y polea cada 15s. Cuando detecta uno nuevo:
///   1. Actualiza el `count` global (lo lee el badge del dashboard).
///   2. Dispara haptic + sonido del sistema.
///   3. Muestra un snackbar persistente con "Ver" que abre la bandeja.
///
/// **Por qué 15s y no menos:** balance batería / latencia. Para el
/// cliente que envía un pedido, esperar 0-15s a que el mesero lo
/// vea es perfectamente aceptable. Bajar a 5s gastaría batería sin
/// beneficio percibido.
///
/// **Por qué no WebSocket:** un setup ws server + reconexión robusta
/// es 10x más complejo que polling y para este volumen (decenas de
/// pedidos/día por restaurante) el overhead es inaceptable. Si en
/// el futuro un cliente grande lo necesita, este watcher se vuelve
/// un fallback.
class PendingReviewWatcher extends GetxService {
  PendingReviewWatcher({
    OrderRemoteDataSource? remoteDataSource,
    Duration pollInterval = const Duration(seconds: 15),
  })  : _remote = remoteDataSource ?? sl<OrderRemoteDataSource>(),
        _pollInterval = pollInterval;

  final OrderRemoteDataSource _remote;
  final Duration _pollInterval;
  Timer? _timer;

  /// Count de pendientes — leído por el badge del dashboard via Obx.
  final RxInt count = 0.obs;

  /// Si el watcher está activo. Se setea al `start()` y se limpia
  /// en `stop()`. Útil para no mostrar el badge si el watcher no
  /// está corriendo (ej. usuario con rol kitchen).
  final RxBool active = false.obs;

  /// IDs ya conocidos — usado para detectar pedidos nuevos vs ya
  /// vistos.
  final Set<String> _knownIds = <String>{};

  /// Si el watcher ya hizo el primer fetch — evita alertar al
  /// arrancar con 3 pendientes pre-existentes.
  bool _primed = false;

  /// Roles habilitados para recibir notificaciones de pendientes.
  /// Kitchen NO está acá — la cocina ve órdenes cuando ya fueron
  /// aprobadas por el mesero, no antes.
  static const _eligibleRoles = {
    'admin',
    'manager',
    'cashier',
    'waiter',
  };

  /// `roleCode` viene del usuario logueado. Si no está en la lista
  /// `_eligibleRoles`, no arrancamos el watcher.
  void startForRole(String? roleCode) {
    if (roleCode == null || !_eligibleRoles.contains(roleCode)) {
      stop();
      return;
    }
    if (active.value) return; // ya estaba corriendo

    active.value = true;
    _primed = false;
    _knownIds.clear();

    // Primer fetch inmediato + arranque del timer.
    _tick();
    _timer = Timer.periodic(_pollInterval, (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    active.value = false;
    count.value = 0;
    _knownIds.clear();
    _primed = false;
  }

  Future<void> refreshNow() => _tick();

  Future<void> _tick() async {
    try {
      final batch = await _remote.getPendingReviewOrders();
      final newIds = batch.items.map((o) => o.id).toSet();

      // Primer fetch: solo prima el set sin alertar. La pantalla
      // dedicada (`PendingReviewPage`) se ocupa de mostrar lo que
      // hay; nosotros solo alertamos por novedades.
      if (!_primed) {
        _knownIds.addAll(newIds);
        count.value = batch.count;
        _primed = true;
        return;
      }

      final fresh = newIds.difference(_knownIds);
      if (fresh.isNotEmpty) {
        _notifyArrivals(fresh.length);
      }

      _knownIds
        ..clear()
        ..addAll(newIds);
      count.value = batch.count;
    } catch (_) {
      // Errores de red transitorios — no rompemos el polling, el
      // próximo tick puede recuperarse.
    }
  }

  void _notifyArrivals(int n) {
    // Feedback físico (vibración / pop según OS).
    HapticFeedback.heavyImpact();
    // Sonido nativo del sistema — funciona sin packages adicionales,
    // respeta volumen del usuario, no requiere asset.
    SystemSound.play(SystemSoundType.alert);

    AppSnackbar.show(
      n == 1 ? 'Nuevo pedido por QR' : '$n pedidos nuevos por QR',
      n == 1
          ? 'Un cliente envió su pedido. Tocá para aprobarlo.'
          : '$n clientes esperan aprobación.',
      duration: const Duration(seconds: 5),
    );
  }

  @override
  void onClose() {
    stop();
    super.onClose();
  }
}
