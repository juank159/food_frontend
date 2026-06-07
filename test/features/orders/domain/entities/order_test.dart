import 'package:flutter_test/flutter_test.dart';
import 'package:food_platform_app/core/config/constants/order_enums.dart';
import 'package:food_platform_app/features/orders/domain/entities/order.dart';

/// Tests de los getters críticos del entity Order que la UI consume
/// para decidir badges y botones:
///
///   - `hasPartialPayment` → badge "Parcial NN%"
///   - `belongsToTabSession` → badge "En cuenta"
///   - `isReadyToCharge` → muestra botón "Cobrar"
///   - `balance` → cuánto falta cobrar
void main() {
  Order build({
    double total = 7000,
    double paid = 0,
    PaymentStatus status = PaymentStatus.pending,
    OrderStatus workflow = OrderStatus.ready,
    String? tabSessionId,
  }) {
    return Order(
      id: 'o1',
      orderNumber: 'ORD-1',
      orderType: OrderType.dineIn,
      orderSource: OrderSource.pos,
      status: workflow,
      tabSessionId: tabSessionId,
      items: const [],
      subtotal: total,
      discountAmount: 0,
      deliveryFee: 0,
      tipAmount: 0,
      taxAmount: 0,
      totalAmount: total,
      paymentStatus: status,
      paidAmount: paid,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  group('Order.balance', () {
    test('total 7000 - paid 2000 = 5000', () {
      expect(build(total: 7000, paid: 2000).balance, 5000);
    });

    test('paid > total → balance 0 (nunca negativo)', () {
      expect(build(total: 5000, paid: 6000).balance, 0);
    });

    test('paid = 0 → balance = total', () {
      expect(build(total: 7000).balance, 7000);
    });
  });

  group('Order.hasPartialPayment', () {
    test('paid > 0 y NO completed → true', () {
      final o = build(
        paid: 2000,
        status: PaymentStatus.pending,
      );
      expect(o.hasPartialPayment, isTrue);
    });

    test('paid > 0 y completed → false (ya está pagada)', () {
      final o = build(
        paid: 7000,
        status: PaymentStatus.completed,
      );
      expect(o.hasPartialPayment, isFalse);
    });

    test('paid = 0 → false (no hay nada parcial)', () {
      final o = build(paid: 0);
      expect(o.hasPartialPayment, isFalse);
    });

    test('paid ≈ 0 (centavos por redondeo) → false (umbral 1 centavo)', () {
      final o = build(paid: 0.005);
      expect(o.hasPartialPayment, isFalse);
    });
  });

  group('Order.belongsToTabSession', () {
    test('con tabSessionId no vacío → true', () {
      expect(
        build(tabSessionId: 'tab-1').belongsToTabSession,
        isTrue,
      );
    });
    test('sin tabSessionId → false', () {
      expect(build().belongsToTabSession, isFalse);
    });
    test('tabSessionId vacío → false', () {
      expect(build(tabSessionId: '').belongsToTabSession, isFalse);
    });
  });

  group('Order.isReadyToCharge', () {
    test('pago pendiente + status ready → true', () {
      expect(build(workflow: OrderStatus.ready).isReadyToCharge, isTrue);
    });
    test('pago pendiente + status delivered → true', () {
      expect(build(workflow: OrderStatus.delivered).isReadyToCharge, isTrue);
    });
    test('pago pendiente + status completed → true', () {
      expect(build(workflow: OrderStatus.completed).isReadyToCharge, isTrue);
    });
    test('pago pendiente + status preparing → false (todavía en cocina)', () {
      expect(build(workflow: OrderStatus.preparing).isReadyToCharge, isFalse);
    });
    test('pago pendiente + status pending → false (no se ha confirmado nada)', () {
      expect(build(workflow: OrderStatus.pending).isReadyToCharge, isFalse);
    });
    test('pago completed → false (no hay nada que cobrar)', () {
      expect(
        build(
          workflow: OrderStatus.completed,
          status: PaymentStatus.completed,
        ).isReadyToCharge,
        isFalse,
      );
    });
  });
}
