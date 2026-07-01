import 'package:flutter/material.dart' show Color;
import 'package:get/get.dart';

import '../utils/app_snackbar.dart';
import 'connectivity_service.dart';
import 'offline_queue_service.dart';

/// Implementación concreta del SyncService.
///
/// Procesa la cola de operaciones pendientes cuando hay internet.
/// Se registra en DI como `AppSyncService` e implementa `SyncService`.
///
/// Flujo:
///   1. ConnectivityService detecta reconexión → llama processQueue()
///   2. processQueue() obtiene todas las entradas de OfflineQueueService
///   3. Para cada entrada llama al servicio correspondiente
///   4. Si éxito → elimina de la cola
///   5. Si falla → incrementa retryCount. Máx 5 reintentos, luego descarta.
///
/// EXTENSIÓN: cada feature registra su propio handler via [registerHandler].
class AppSyncService extends GetxController implements SyncService {
  static AppSyncService get to => Get.find<AppSyncService>();

  final OfflineQueueService _queue;
  final RxBool isSyncing = false.obs;
  final RxInt pendingCount = 0.obs;

  static const int _maxRetries = 5;

  /// Handlers registrados por tipo de operación.
  /// Cada feature llama `AppSyncService.to.registerHandler(...)` en su init.
  final Map<QueueOperationType, Future<bool> Function(QueueEntry)> _handlers =
      {};

  AppSyncService({required OfflineQueueService queue}) : _queue = queue;

  @override
  void onInit() {
    super.onInit();
    _refreshPendingCount();
  }

  /// Registra un handler para un tipo de operación.
  /// El handler debe devolver true si procesó con éxito.
  void registerHandler(
    QueueOperationType type,
    Future<bool> Function(QueueEntry entry) handler,
  ) {
    _handlers[type] = handler;
  }

  @override
  Future<void> processQueue() async {
    if (isSyncing.value) return;
    final entries = _queue.getAll();
    if (entries.isEmpty) return;

    isSyncing.value = true;
    _refreshPendingCount();

    int synced = 0;
    int failed = 0;

    for (final entry in entries) {
      final handler = _handlers[entry.type];
      if (handler == null) {
        // Sin handler registrado: mantener en cola
        continue;
      }

      try {
        final ok = await handler(entry);
        if (ok) {
          await _queue.remove(entry.id);
          synced++;
        } else {
          await _markFailed(entry, 'Handler devolvió false');
          failed++;
        }
      } catch (e) {
        await _markFailed(entry, e.toString());
        failed++;
      }
    }

    isSyncing.value = false;
    _refreshPendingCount();

    if (synced > 0) {
      AppSnackbar.show(
        'Sincronizado',
        '$synced operación${synced > 1 ? "es" : ""} enviada${synced > 1 ? "s" : ""} al servidor.',
        backgroundColor: const Color(0xFF2E7D32),
        colorText: const Color(0xFFFFFFFF),
      );
    }
    if (failed > 0) {
      AppSnackbar.show(
        'Pendientes',
        '$failed operación${failed > 1 ? "es" : ""} no se pudo${failed > 1 ? "ieron" : ""} sincronizar. Se reintentará más tarde.',
      );
    }
  }

  Future<void> _markFailed(QueueEntry entry, String error) async {
    if (entry.retryCount >= _maxRetries) {
      await _queue.remove(entry.id);
      return;
    }
    await _queue.markRetried(entry.id, error: error);
  }

  void _refreshPendingCount() {
    pendingCount.value = _queue.pendingCount;
  }

  /// Permite que las pantallas consulten cuántas ops pendientes hay.
  int get queueLength => _queue.pendingCount;
}
