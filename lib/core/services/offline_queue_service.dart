import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Tipo de operación en la cola offline.
enum QueueOperationType {
  createOrder,
  updateOrderStatus,
  createPayment,
  openTabSession,
  closeTabSession,
  addOrderToTab,
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
