import 'package:flutter_test/flutter_test.dart';
import 'package:menu_plat/core/services/sync_handlers.dart';

/// Bug real: un pago de cuenta/tab encolado offline se perdía en
/// silencio al sincronizar — el handler viejo asumía `order_id`
/// siempre presente y lo descartaba como "entrada corrupta" (lo
/// marcaba como sincronizado sin mandarlo nunca al backend). Ver
/// `resolvePaymentSyncRequest` en sync_handlers.dart.
void main() {
  group('resolvePaymentSyncRequest', () {
    test('processOrderPayment: resuelve a /payments/order/:id/pay', () {
      final result = resolvePaymentSyncRequest({
        'type': 'processOrderPayment',
        'order_id': 'order-1',
        'payment_method': 'cash',
        'received_amount': 20000,
      });

      expect(result, isNotNull);
      expect(result!.path, '/payments/order/order-1/pay');
      expect(result.body, {
        'payment_method': 'cash',
        'received_amount': 20000,
      });
      // El id y el discriminador 'type' no deben viajar en el body —
      // el id ya está en el path, y el backend no espera 'type'.
      expect(result.body.containsKey('order_id'), isFalse);
      expect(result.body.containsKey('type'), isFalse);
    });

    test(
      'BUG REAL: processTabPayment: resuelve a /payments/tab/:id (no se pierde)',
      () {
        final result = resolvePaymentSyncRequest({
          'type': 'processTabPayment',
          'tab_session_id': 'tab-1',
          'amount': 15000,
          'payment_method': 'card',
        });

        expect(result, isNotNull);
        expect(result!.path, '/payments/tab/tab-1');
        expect(result.body, {'amount': 15000, 'payment_method': 'card'});
        expect(result.body.containsKey('tab_session_id'), isFalse);
      },
    );

    test('sin type (legacy) y con order_id: trata como processOrderPayment', () {
      final result = resolvePaymentSyncRequest({
        'order_id': 'order-2',
        'payment_method': 'cash',
      });

      expect(result, isNotNull);
      expect(result!.path, '/payments/order/order-2/pay');
    });

    test(
      'processTabPayment sin tab_session_id (entrada corrupta) → null, nunca inventa un id',
      () {
        final result = resolvePaymentSyncRequest({
          'type': 'processTabPayment',
          'amount': 15000,
        });

        expect(result, isNull);
      },
    );

    test('createPayment (cobro de UN ticket offline): POST /payments con order_id en el body', () {
      final result = resolvePaymentSyncRequest({
        'type': 'createPayment',
        'order_id': 'order-3',
        'payment_method': 'transfer',
        'amount': 28500,
      });

      expect(result, isNotNull);
      expect(result!.path, '/payments');
      expect(result.body, {
        'order_id': 'order-3',
        'payment_method': 'transfer',
        'amount': 28500,
      });
    });

    test('createPayment sin order_id (entrada corrupta) → null', () {
      expect(
        resolvePaymentSyncRequest({'type': 'createPayment', 'amount': 1000}),
        isNull,
      );
    });

    test('sin type y sin order_id (entrada corrupta) → null', () {
      final result = resolvePaymentSyncRequest({'payment_method': 'cash'});

      expect(result, isNull);
    });
  });
}
