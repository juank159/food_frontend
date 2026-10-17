import 'package:uuid/uuid.dart';

import '../../../../core/services/local_cache_service.dart';
import '../../../../core/services/offline_queue_service.dart';
import '../models/shift_model.dart';

/// Soporte offline para fichaje (clock-in/clock-out).
///
/// A diferencia de crear un producto/mesa/cuenta, fichar NO genera un
/// ID que algo más vaya a referenciar antes de sincronizar — es un
/// evento de una sola vez, igual de "seguro" de encolar que crear una
/// orden. Por eso acá SÍ se encola la operación offline (a diferencia
/// de products/categories/tab_sessions.open, ver las decisiones de
/// alcance en esos commits).
abstract class ShiftLocalDataSource {
  /// Encola el clock-in/clock-out para cuando vuelva la conexión.
  Future<void> enqueueClockIn(Map<String, dynamic> dto);
  Future<void> enqueueClockOut(Map<String, dynamic> dto);

  /// Shift "optimista" mientras la operación real está en la cola —
  /// con id temporal, para que `getMyCurrent()` pueda seguir
  /// mostrando "estás en turno" sin esperar la sincronización.
  Future<void> savePendingShift(ShiftModel? shift);
  Future<ShiftModel?> getPendingShift();
  Future<void> clearPendingShift();
}

class ShiftLocalDataSourceImpl implements ShiftLocalDataSource {
  static const _pendingKey = 'shift_pending_optimistic';

  final LocalCacheService cache;
  final OfflineQueueService queue;

  ShiftLocalDataSourceImpl({required this.cache, required this.queue});

  @override
  Future<void> enqueueClockIn(Map<String, dynamic> dto) async {
    await queue.enqueue(QueueEntry(
      id: const Uuid().v4(),
      type: QueueOperationType.clockIn,
      payload: dto,
      createdAt: DateTime.now(),
    ));
  }

  @override
  Future<void> enqueueClockOut(Map<String, dynamic> dto) async {
    await queue.enqueue(QueueEntry(
      id: const Uuid().v4(),
      type: QueueOperationType.clockOut,
      payload: dto,
      createdAt: DateTime.now(),
    ));
  }

  @override
  Future<void> savePendingShift(ShiftModel? shift) async {
    if (shift == null) {
      await clearPendingShift();
      return;
    }
    await cache.saveObject(_pendingKey, shift.toJson());
  }

  @override
  Future<ShiftModel?> getPendingShift() async {
    final raw = cache.getObject(_pendingKey);
    if (raw == null) return null;
    return ShiftModel.fromJson(raw);
  }

  @override
  Future<void> clearPendingShift() async {
    await cache.invalidate(_pendingKey);
  }
}
