import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/tab_session.dart';

abstract class TabSessionRepository {
  /// Abre una cuenta nueva. `tableElementId` solo para dine-in;
  /// para delivery puro queda null y se crea la cuenta de un solo
  /// ticket on-the-fly.
  Future<Either<Failure, TabSession>> open({
    String? tableElementId,
    String? tableId,
    String? customerId,
    int? partySize,
    String? notes,
  });

  /// Lista de cuentas abiertas (sin tickets cargados por performance).
  Future<Either<Failure, List<TabSession>>> findOpen();

  /// Caché SIN tocar la red ni importar su edad — para pintar la
  /// pantalla al instante ("local-first"). `null` si nunca se cacheó
  /// nada.
  Future<List<TabSession>?> getCachedOpenTabsPeek();

  /// Caché de UNA cuenta sin tocar la red: la copia completa (con
  /// tickets y pagos) si alguna vez se guardó, si no la de la lista.
  Future<TabSession?> peekCachedSessionDetail(String id);

  /// Detalle completo con tickets y pagos.
  Future<Either<Failure, TabSession>> findOne(String id);

  /// Actualiza metadata editable (nombre cliente, notas, comensales).
  Future<Either<Failure, TabSession>> update(
    String id, {
    String? customerName,
    String? notes,
    int? partySize,
  });

  /// Cierra la cuenta. `force=true` permite cerrar con balance > 0
  /// (admin override).
  Future<Either<Failure, TabSession>> close({
    required String id,
    bool force = false,
    String? notes,
  });

  /// Anula la cuenta (solo si no tiene pagos completados).
  Future<Either<Failure, void>> voidSession(String id);
}
