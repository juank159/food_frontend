import 'package:flutter_test/flutter_test.dart';
import 'package:menu_plat/core/services/offline_queue_service.dart';
import 'package:menu_plat/features/payments/data/pending_payments_overlay.dart';

Map<String, dynamic> _order(
  String id,
  double total, {
  String createdAt = '2026-10-24T10:00:00Z',
  List<Map<String, dynamic>>? payments = const [],
  String status = 'completed',
}) =>
    {
      'id': id,
      'total_amount': total,
      'created_at': createdAt,
      'status': status,
      'payment_status': 'pending',
      if (payments != null) 'payments': payments,
    };

QueueEntry _entry(Map<String, dynamic> payload, {int minute = 0}) => QueueEntry(
      id: 'q$minute',
      type: QueueOperationType.createPayment,
      payload: payload,
      createdAt: DateTime(2026, 10, 24, 12, minute),
    );

double _paid(dynamic order) => ((order as Map)['payments'] as List)
    .whereType<Map>()
    .where((p) => p['status'] == 'completed')
    .fold<double>(0, (s, p) => s + (p['amount'] as num).toDouble());

void main() {
  group('overlayPendingPayments', () {
    test(
      'cobro de cuenta offline: reparte FIFO entre tickets, igual que el backend',
      () {
        final orders = [
          _order('b', 10000, createdAt: '2026-10-24T11:00:00Z'),
          _order('a', 28500, createdAt: '2026-10-24T10:00:00Z'),
        ];
        final pending = pendingPaymentsFromQueue([
          _entry({
            'type': 'processTabPayment',
            'tab_session_id': 'tab-1',
            'amount': 30000,
            'payment_method': 'cash',
          }),
        ]);

        final r = overlayPendingPayments(
          tabSessionId: 'tab-1',
          orders: orders,
          balance: 38500,
          pending: pending,
        );

        expect(r.paidDelta, 30000);
        final a = r.orders.firstWhere((o) => o['id'] == 'a');
        final b = r.orders.firstWhere((o) => o['id'] == 'b');
        expect(_paid(a), 28500);
        expect(a['payment_status'], 'completed');
        expect(_paid(b), 1500);
        expect(b['payment_status'], 'pending');
        // La lista original no se toca (es la caché).
        expect((orders[1]['payments'] as List), isEmpty);
      },
    );

    test('cobro de UN ticket offline (createPayment): solo ese ticket', () {
      final r = overlayPendingPayments(
        tabSessionId: 'tab-1',
        orders: [_order('a', 28500), _order('b', 10000)],
        balance: 38500,
        pending: pendingPaymentsFromQueue([
          _entry({
            'type': 'createPayment',
            'order_id': 'b',
            'amount': 10000,
            'payment_method': 'transfer',
          }),
        ]),
      );

      expect(r.paidDelta, 10000);
      expect(r.orders.firstWhere((o) => o['id'] == 'b')['payment_status'],
          'completed');
      expect(_paid(r.orders.firstWhere((o) => o['id'] == 'a')), 0);
    });

    test(
      'pago ya recibido por el servidor pero aún en la cola: no cuenta doble',
      () {
        final r = overlayPendingPayments(
          tabSessionId: 'tab-1',
          orders: [
            _order('a', 28500, payments: [
              {'amount': 28500, 'status': 'completed'},
            ]),
          ],
          balance: 0,
          pending: pendingPaymentsFromQueue([
            _entry({
              'type': 'processTabPayment',
              'tab_session_id': 'tab-1',
              'amount': 28500,
            }),
          ]),
        );

        expect(r.paidDelta, 0);
        expect(_paid(r.orders.single), 28500);
      },
    );

    test('lista liviana (sin payments por ticket): solo ajusta el total', () {
      final r = overlayPendingPayments(
        tabSessionId: 'tab-1',
        orders: [_order('a', 28500, payments: null)],
        balance: 28500,
        pending: pendingPaymentsFromQueue([
          _entry({
            'type': 'processTabPayment',
            'tab_session_id': 'tab-1',
            'amount': 28500,
          }),
        ]),
      );

      expect(r.paidDelta, 28500);
      expect((r.orders.single as Map).containsKey('payments'), isFalse);
    });

    test('pagos de OTRA cuenta no se aplican', () {
      final orders = [_order('a', 28500)];
      final r = overlayPendingPayments(
        tabSessionId: 'tab-1',
        orders: orders,
        balance: 28500,
        pending: pendingPaymentsFromQueue([
          _entry({
            'type': 'processTabPayment',
            'tab_session_id': 'tab-2',
            'amount': 5000,
          }),
          _entry({'type': 'createPayment', 'order_id': 'zzz', 'amount': 5000}),
        ]),
      );

      expect(r.paidDelta, 0);
      expect(identical(r.orders, orders), isTrue);
    });

    test('tickets cancelados no reciben parte del cobro', () {
      final r = overlayPendingPayments(
        tabSessionId: 'tab-1',
        orders: [
          _order('x', 5000, status: 'cancelled'),
          _order('a', 10000, createdAt: '2026-10-24T11:00:00Z'),
        ],
        balance: 10000,
        pending: pendingPaymentsFromQueue([
          _entry({
            'type': 'processTabPayment',
            'tab_session_id': 'tab-1',
            'amount': 10000,
          }),
        ]),
      );

      expect(_paid(r.orders.firstWhere((o) => o['id'] == 'x')), 0);
      expect(_paid(r.orders.firstWhere((o) => o['id'] == 'a')), 10000);
    });
  });
}
