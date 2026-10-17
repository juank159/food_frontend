import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

/// Tipo de operación en la cola offline.
enum QueueOperationType {
  createOrder,
  createPayment,
  clockIn,
  clockOut,
  createExpense,

  /// Mutación genérica sobre una entidad YA creada con id real —
  /// cambiar estado de una orden, marcar un item, agregar/quitar/
  /// editar cantidad de un item, editar cliente/notas, cancelar,
  /// renombrar una cuenta abierta, etc. El payload trae `method` +
  /// `path` + `body` ya resueltos por el caller (ver
  /// `enqueueGenericMutation`) — el handler solo reproduce la request
  /// tal cual, sin necesitar saber de qué mutación específica se
  /// trata. Nunca se usa para CREAR algo nuevo (eso necesita un id
  /// real del servidor) — solo para mutar algo que ya lo tiene.
  /// Reemplaza a los viejos `updateOrderStatus`/`openTabSession`/
  /// `closeTabSession`/`addOrderToTab`, que quedaron declarados en una
  /// ronda anterior pero NUNCA se usaron (sin encolador, sin handler)
  /// — se borraron en vez de dejarlos muertos.
  genericMutation,
}

/// Encola una mutación genérica (ver `QueueOperationType.genericMutation`)
/// — PATCH/POST/DELETE sobre algo que ya tiene id real. El sync handler
/// (`SyncHandlers.register`) reproduce la request tal cual con
/// `dio.request(path, data: body, options: Options(method: method))`.
///
/// [clientRef] es opcional — una referencia LOCAL (ej. el id temporal
/// `local_...` de un item agregado offline) que nunca se manda al
/// servidor (vive fuera de `body`, el handler la ignora) pero permite
/// des-encolar esta entrada después con `removeByClientRef` si el
/// usuario revierte la acción antes de que sincronice (ej. agrega un
/// item offline y lo borra offline, antes de reconectar).
Future<String> enqueueGenericMutation(
  OfflineQueueService queue, {
  required String method,
  required String path,
  dynamic body,
  String? clientRef,
}) async {
  final id = const Uuid().v4();
  await queue.enqueue(QueueEntry(
    id: id,
    type: QueueOperationType.genericMutation,
    payload: {
      'method': method,
      'path': path,
      if (body != null) 'body': body,
      if (clientRef != null) 'client_ref': clientRef,
    },
    createdAt: DateTime.now(),
  ));
  return id;
}

/// Busca una entrada `genericMutation` pendiente por su `clientRef` (ver
/// `enqueueGenericMutation`) y la borra de la cola sin mandarla nunca —
/// para cuando el usuario revierte offline algo que él mismo había
/// encolado offline (ej. agrega un item y lo borra, todo sin conexión).
/// Devuelve `true` si encontró y borró algo.
Future<bool> removeQueuedMutationByClientRef(
  OfflineQueueService queue,
  String clientRef,
) async {
  final match = queue.getAll().where(
        (e) =>
            e.type == QueueOperationType.genericMutation &&
            e.payload['client_ref'] == clientRef,
      );
  if (match.isEmpty) return false;
  for (final entry in match) {
    await queue.remove(entry.id);
  }
  return true;
}

/// Una entrada en la cola de operaciones pendientes.
class QueueEntry {
  final String id;
  final QueueOperationType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  int retryCount;
  String? lastError;

  QueueEntry({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
        'lastError': lastError,
      };

  factory QueueEntry.fromJson(Map<String, dynamic> json) => QueueEntry(
        id: json['id'] as String,
        type: QueueOperationType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => QueueOperationType.createOrder,
        ),
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        createdAt: DateTime.parse(json['createdAt'] as String),
        retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
        lastError: json['lastError'] as String?,
      );
}

/// Cola durable de operaciones pendientes para el modo offline.
///
/// Persiste en Hive para sobrevivir reinicios de la app.
/// El [AppSyncService] la consume cuando hay conexión.
///
/// Uso:
///   ```dart
///   // Al crear orden offline:
///   await queue.enqueue(QueueEntry(
///     id: uuid,
///     type: QueueOperationType.createOrder,
///     payload: orderDto.toJson(),
///     createdAt: DateTime.now(),
///   ));
///
///   // Al procesar:
///   final entries = await queue.getAll();
///   // procesar...
///   await queue.remove(entry.id);
///   ```
class OfflineQueueService {
  static const _boxName = 'offline_queue';
  static const _queueKey = 'entries';

  late Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  /// Agrega una operación a la cola.
  Future<void> enqueue(QueueEntry entry) async {
    final entries = _loadEntries();
    entries.add(entry.toJson());
    await _box.put(_queueKey, jsonEncode(entries));
  }

  /// Devuelve todas las entradas pendientes, en orden de creación.
  List<QueueEntry> getAll() {
    return _loadEntries()
        .map((e) => QueueEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Cantidad de operaciones pendientes.
  int get pendingCount => _loadEntries().length;

  /// Elimina una entrada de la cola (operación procesada con éxito).
  Future<void> remove(String id) async {
    final entries = _loadEntries().where((e) {
      final entry = Map<String, dynamic>.from(e as Map);
      return entry['id'] != id;
    }).toList();
    await _box.put(_queueKey, jsonEncode(entries));
  }

  /// Actualiza el retry count y el error de una entrada.
  Future<void> markRetried(String id, {String? error}) async {
    final entries = _loadEntries().map((e) {
      final entry = Map<String, dynamic>.from(e as Map);
      if (entry['id'] == id) {
        entry['retryCount'] = ((entry['retryCount'] as num?)?.toInt() ?? 0) + 1;
        entry['lastError'] = error;
      }
      return entry;
    }).toList();
    await _box.put(_queueKey, jsonEncode(entries));
  }

  /// Vacía toda la cola (ej. al hacer logout).
  Future<void> clearAll() async {
    await _box.put(_queueKey, jsonEncode([]));
  }

  List _loadEntries() {
    final raw = _box.get(_queueKey) as String?;
    if (raw == null) return [];
    try {
      return jsonDecode(raw) as List;
    } catch (_) {
      return [];
    }
  }
}
