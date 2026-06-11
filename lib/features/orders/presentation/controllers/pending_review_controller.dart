import 'dart:async';
// `unawaited` está en dart:async desde 2.15 — el SDK del proyecto
// (3.8.1) lo soporta.

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../printer_configs/data/printing_orchestrator.dart';
import '../../data/datasources/order_remote_datasource.dart';
import '../../data/models/order_model.dart';

/// Controller de la bandeja "Pendientes de aprobación".
///
/// **Hot path para meseros:** se monta cuando el usuario abre la
/// pantalla y polea cada 12s la cola de self-orders esperando
/// aprobación. Si llega una nueva (count subió), dispara
/// `HapticFeedback.heavyImpact` para alertar.
///
/// **Por qué polling y no WebSocket:** WebSocket requiere
/// infraestructura adicional (ws server, reconexión, fallbacks).
/// Polling de 12s da latencia aceptable (cliente espera ~10s desde
/// que envía hasta que el mesero ve la orden), sobrevive reconexiones
/// triviales y es 100% stateless.
///
/// **Por qué no se hace polling global** (en home, todo el tiempo):
/// quemaría batería y datos. El waiter abre la bandeja solo cuando
/// la necesita; el badge en el home se actualiza con un fetch único
/// al entrar.
class PendingReviewController extends GetxController {
  PendingReviewController({
    OrderRemoteDataSource? remoteDataSource,
    Duration pollInterval = const Duration(seconds: 12),
  })  : _remote = remoteDataSource ?? sl<OrderRemoteDataSource>(),
        _pollInterval = pollInterval;

  final OrderRemoteDataSource _remote;
  final Duration _pollInterval;
  Timer? _pollTimer;

  /// Cola actual ordenada por created_at ASC (las más viejas primero).
  final RxList<OrderModel> orders = <OrderModel>[].obs;

  /// Count separado por si el backend devuelve un total que NO matchea
  /// `orders.length` (paginación futura).
  final RxInt count = 0.obs;

  /// `loading` solo para el primer fetch; los siguientes son polls
  /// silenciosos (no queremos un spinner cada 12s).
  final RxBool loading = true.obs;
  final RxnString error = RxnString();

  /// IDs ya conocidos — usado para detectar órdenes NUEVAS y disparar
  /// alerta. Si una orden ya estaba en la cola previa y sigue ahí,
  /// no genera nueva alerta.
  final Set<String> _knownIds = <String>{};

  /// Para flag visual "rejecting/approving este id" en la UI.
  final RxSet<String> processingIds = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    fetch(initial: true);
    _startPolling();
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    super.onClose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => fetch());
  }

  /// Trae la cola. `initial=true` muestra loading + setea `_knownIds`
  /// sin alertar (evita alertar al abrir la pantalla con 5 pendientes).
  Future<void> fetch({bool initial = false}) async {
    try {
      final batch = await _remote.getPendingReviewOrders();
      final newIds = batch.items.map((o) => o.id).toSet();

      // Detectar órdenes nuevas (no estaban en _knownIds).
      // En la primera carga no alertamos — el waiter ya las verá listadas.
      if (!initial) {
        final freshlyArrived = newIds.difference(_knownIds);
        if (freshlyArrived.isNotEmpty) {
          _notifyNewOrders(freshlyArrived.length);
        }
      }

      _knownIds
        ..clear()
        ..addAll(newIds);

      orders.assignAll(batch.items);
      count.value = batch.count;
      error.value = null;
    } catch (e) {
      error.value = e.toString();
      // No interrumpimos polling — el siguiente intent puede recuperarse.
    } finally {
      if (loading.value) loading.value = false;
    }
  }

  void _notifyNewOrders(int count) {
    // Vibración + sonido nativo si está disponible. HapticFeedback en
    // iOS hace el "pop"; en Android dispara la vibración corta.
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);

    AppSnackbar.show(
      count == 1 ? 'Nuevo pedido' : 'Pedidos nuevos',
      count == 1
          ? '1 cliente envió su pedido desde el QR'
          : '$count clientes enviaron pedidos desde el QR',
      duration: const Duration(seconds: 4),
    );
  }

  /// Aprueba la orden y la saca de la cola.
  /// Optimistic: la remueve antes del response. Si falla, se recarga.
  /// Si [printKitchen] es true, **dispara auto-impresión de comanda**
  /// vía `PrintingOrchestrator`: lee la impresora default de cocina
  /// del tenant y manda directo si está configurada con `auto_print`.
  Future<void> approve(
    String orderId, {
    bool toConfirmed = false,
    bool printKitchen = false,
    String? destinationLabel, // ej. "Mesa 1 · Areas verdes"
  }) async {
    if (processingIds.contains(orderId)) return;
    processingIds.add(orderId);

    final removedIndex = orders.indexWhere((o) => o.id == orderId);
    OrderModel? removed;
    if (removedIndex >= 0) {
      removed = orders.removeAt(removedIndex);
      count.value = orders.length;
    }

    try {
      await _remote.approveSelfOrder(orderId, toConfirmed: toConfirmed);
      _knownIds.remove(orderId);

      if (printKitchen) {
        // Fire-and-forget: el orchestrator maneja errores y muestra
        // snackbars elegantes. El mesero puede seguir aprobando los
        // siguientes sin esperar la impresión.
        unawaited(
          PrintingOrchestrator.autoPrintKitchen(
            orderId: orderId,
            subtitle: destinationLabel,
          ),
        );
      }

      AppSnackbar.show(
        'Pedido aprobado',
        toConfirmed
            ? 'Confirmado y enviado a cocina'
            : 'Listo para confirmar en el flujo normal',
      );
    } catch (e) {
      // Rollback: re-insertar y avisar.
      if (removed != null) {
        orders.insert(removedIndex, removed);
        count.value = orders.length;
      }
      AppSnackbar.show(
        'Error al aprobar',
        e.toString(),
        duration: const Duration(seconds: 5),
      );
    } finally {
      processingIds.remove(orderId);
    }
  }

  /// Rechaza la orden con razón obligatoria.
  Future<void> reject(String orderId, String reason) async {
    if (processingIds.contains(orderId)) return;
    if (reason.trim().length < 3) {
      AppSnackbar.show(
        'Motivo requerido',
        'Escribí brevemente por qué rechazás el pedido.',
      );
      return;
    }
    processingIds.add(orderId);

    final removedIndex = orders.indexWhere((o) => o.id == orderId);
    OrderModel? removed;
    if (removedIndex >= 0) {
      removed = orders.removeAt(removedIndex);
      count.value = orders.length;
    }

    try {
      await _remote.rejectSelfOrder(orderId, reason.trim());
      _knownIds.remove(orderId);
      AppSnackbar.show('Pedido rechazado', 'El cliente no será notificado automáticamente.');
    } catch (e) {
      if (removed != null) {
        orders.insert(removedIndex, removed);
        count.value = orders.length;
      }
      AppSnackbar.show('Error al rechazar', e.toString());
    } finally {
      processingIds.remove(orderId);
    }
  }
}
