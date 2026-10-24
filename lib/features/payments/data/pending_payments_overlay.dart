import '../../../core/services/offline_queue_service.dart';

/// Un pago cobrado SIN internet que todavía espera en la cola
/// (`QueueOperationType.createPayment`) — normalizado desde los 3
/// formatos que encola `PaymentRepositoryImpl`:
///   - `processTabPayment`: cobro de una cuenta (`tab_session_id` + `amount`).
///   - `createPayment`: cobro de UN ticket (`order_id` + `amount`).
///   - `processOrderPayment` (o sin `type`, legacy): saldo completo de
///     un ticket (`order_id`, sin `amount`).
class PendingPayment {
  final String? tabSessionId;
  final String? orderId;

  /// `null` = "el saldo completo del ticket" (`processOrderPayment`).
  final double? amount;
  final String? paymentMethod;
  final String? notes;
  final DateTime createdAt;

  const PendingPayment({
    this.tabSessionId,
    this.orderId,
    this.amount,
    this.paymentMethod,
    this.notes,
    required this.createdAt,
  });
}

List<PendingPayment> pendingPaymentsFromQueue(Iterable<QueueEntry> entries) {
  final result = <PendingPayment>[];
  for (final e in entries) {
    if (e.type != QueueOperationType.createPayment) continue;
    final p = e.payload;
    final isTab = p['type'] == 'processTabPayment';
    result.add(PendingPayment(
      tabSessionId: isTab ? p['tab_session_id'] as String? : null,
      orderId: isTab ? null : p['order_id'] as String?,
      amount: (p['amount'] as num?)?.toDouble(),
      paymentMethod: p['payment_method'] as String?,
      notes: p['notes'] as String?,
      createdAt: e.createdAt,
    ));
  }
  result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return result;
}

class TabPaymentsOverlay {
  /// Tickets de la cuenta con los pagos pendientes ya agregados a su
  /// `payments` (y `payment_status` recalculado). Misma lista si no
  /// había nada que aplicar.
  final List<dynamic> orders;

  /// Cuánto sumarle a `paid_amount` (y restarle a `balance`) de la cuenta.
  final double paidDelta;

  const TabPaymentsOverlay({required this.orders, required this.paidDelta});
}

double _num(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

double _round2(double v) => (v * 100).round() / 100;

/// Aplica a una cuenta los pagos cobrados offline que todavía no se
/// sincronizaron, para que el cajero vea lo mismo que va a ver cuando
/// el servidor los reciba — "como si hubiera internet".
///
/// El reparto de un cobro de cuenta entre sus tickets es el MISMO que
/// hace el backend (`TabSessionsService.buildPaymentDistribution`):
/// FIFO por `created_at`, sin canceladas, con tope en el saldo de cada
/// ticket. Así, al sincronizar, ninguna card cambia de estado.
///
/// Los topes también evitan contar doble en el instante en que el pago
/// ya llegó al servidor pero todavía no salió de la cola: el saldo del
/// servidor ya es 0, así que no queda nada que aplicar.
///
/// Solo se agregan pagos a tickets que traen su lista `payments` (el
/// detalle completo); la lista liviana de "Cuentas abiertas" no la
/// trae y ahí basta con el total de la cuenta.
TabPaymentsOverlay overlayPendingPayments({
  required String tabSessionId,
  required List<dynamic> orders,
  required double balance,
  required List<PendingPayment> pending,
}) {
  final orderIds = <String>{
    for (final o in orders)
      if (o is Map && o['id'] is String) o['id'] as String,
  };
  final relevant = pending
      .where((p) =>
          p.tabSessionId == tabSessionId ||
          (p.orderId != null && orderIds.contains(p.orderId)))
      .toList();
  if (relevant.isEmpty || balance <= 0.001) {
    return TabPaymentsOverlay(orders: orders, paidDelta: 0);
  }

  final copies = <Map<String, dynamic>>[];
  final remaining = <String, double>{};
  for (final o in orders) {
    if (o is! Map) continue;
    final copy = Map<String, dynamic>.from(o);
    final hasPayments = copy['payments'] is List;
    if (hasPayments) copy['payments'] = List<dynamic>.from(copy['payments'] as List);
    copies.add(copy);
    if (copy['status'] == 'cancelled') continue;
    final paid = hasPayments
        ? (copy['payments'] as List)
            .whereType<Map>()
            .where((p) => p['status'] == 'completed')
            .fold<double>(0, (s, p) => s + _num(p['amount']))
        : 0.0;
    final id = copy['id'];
    if (id is String) {
      remaining[id] = _round2(_num(copy['total_amount']) - paid);
    }
  }
  final fifo = [...copies]
    ..sort((a, b) => (a['created_at']?.toString() ?? '')
        .compareTo(b['created_at']?.toString() ?? ''));

  var requested = 0.0;
  var seq = 0;
  void addSlice(Map<String, dynamic> order, double amount, PendingPayment p) {
    final id = order['id'] as String;
    remaining[id] = _round2((remaining[id] ?? 0) - amount);
    if (order['payments'] is! List) return;
    (order['payments'] as List).add(<String, dynamic>{
      'id': 'local_pending_${seq++}',
      'order_id': id,
      'amount': amount,
      'status': 'completed',
      'payment_method': p.paymentMethod,
      'notes': p.notes,
      'created_at': p.createdAt.toIso8601String(),
    });
    final paid = (order['payments'] as List)
        .whereType<Map>()
        .where((x) => x['status'] == 'completed')
        .fold<double>(0, (s, x) => s + _num(x['amount']));
    if (paid >= _num(order['total_amount']) - 0.01) {
      order['payment_status'] = 'completed';
    }
    order['payment_method'] = p.paymentMethod;
  }

  for (final p in relevant) {
    if (p.orderId != null) {
      final order = copies.firstWhere(
        (o) => o['id'] == p.orderId,
        orElse: () => <String, dynamic>{},
      );
      final left = remaining[p.orderId] ?? 0;
      final amount = p.amount ?? left;
      requested += amount;
      final slice = amount < left ? amount : left;
      if (order.isNotEmpty && slice > 0.001) addSlice(order, _round2(slice), p);
      continue;
    }
    var left = p.amount ?? 0;
    requested += left;
    for (final order in fifo) {
      if (left <= 0.001) break;
      final orderLeft = remaining[order['id']] ?? 0;
      if (orderLeft <= 0.001) continue;
      final slice = left < orderLeft ? left : orderLeft;
      addSlice(order, _round2(slice), p);
      left = _round2(left - slice);
    }
  }

  final delta = _round2(requested < balance ? requested : balance);
  return TabPaymentsOverlay(orders: copies, paidDelta: delta < 0 ? 0 : delta);
}
