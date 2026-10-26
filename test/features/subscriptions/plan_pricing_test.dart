import 'package:flutter_test/flutter_test.dart';
import 'package:menu_plat/features/subscriptions/data/models/subscription_plan_model.dart';
import 'package:menu_plat/features/subscriptions/data/models/subscription_usage_model.dart';

Map<String, dynamic> _plan(String code, String m, String s, String y) => {
      'id': code,
      'code': code,
      'name': code,
      'description': '',
      'price_monthly': m,
      'price_semiannual': s,
      'price_yearly': y,
      'currency': 'COP',
      'trial_period_days': 30,
      'features': <String, dynamic>{},
      'limits': <String, dynamic>{},
    };

Map<String, dynamic> _usage(String status, {String plan = 'basic', DateTime? grace}) => {
      'plan_name': plan,
      'plan_code': plan,
      'subscription_status': status,
      'is_trial': false,
      'grace_period_ends_at': grace?.toIso8601String(),
      'billing_cycle': 'semiannual',
    };

void main() {
  group('Precios de los planes (COP)', () {
    final basic = SubscriptionPlanModel.fromJson(
            _plan('basic', '50000.00', '270000.00', '480000.00'))
        .toEntity();
    final pro = SubscriptionPlanModel.fromJson(
            _plan('professional', '100000.00', '570000.00', '1080000.00'))
        .toEntity();

    test('lee price_monthly (antes salía "Gratis")', () {
      expect(basic.price, 50000);
      expect(basic.isFree, isFalse);
      expect(basic.trialDays, 30);
      expect(basic.currency, 'COP');
    });

    test('total y equivalente mensual por ciclo', () {
      expect(basic.priceFor('semiannual'), 270000);
      expect(basic.monthlyEquivalent('semiannual'), 45000);
      expect(basic.monthlyEquivalent('yearly'), 40000);
      expect(pro.monthlyEquivalent('semiannual'), 95000);
      expect(pro.monthlyEquivalent('yearly'), 90000);
    });

    test('ahorro frente a pagar mes a mes', () {
      expect(basic.savingsFor('monthly'), 0);
      expect(basic.savingsFor('semiannual'), 30000);
      expect(pro.savingsFor('yearly'), 120000);
    });
  });

  group('Gracia y bloqueo (espeja TenantInterceptor)', () {
    test('mora con gracia vigente: avisa pero NO bloquea', () {
      final u = SubscriptionUsageModel.fromJson(_usage('past_due',
              grace: DateTime.now().add(const Duration(days: 3))))
          .toEntity();
      expect(u.inGracePeriod, isTrue);
      expect(u.operationsBlocked, isFalse);
      expect(u.billingCycle, 'semiannual');
    });

    test('mora con gracia vencida: bloquea', () {
      final u = SubscriptionUsageModel.fromJson(_usage('past_due',
              grace: DateTime.now().subtract(const Duration(hours: 1))))
          .toEntity();
      expect(u.inGracePeriod, isFalse);
      expect(u.operationsBlocked, isTrue);
    });

    test('expirado bloquea; activo no', () {
      expect(SubscriptionUsageModel.fromJson(_usage('expired')).toEntity().operationsBlocked, isTrue);
      expect(SubscriptionUsageModel.fromJson(_usage('active')).toEntity().operationsBlocked, isFalse);
    });

    test('prueba terminada en plan Free bloquea', () {
      expect(
          SubscriptionUsageModel.fromJson(_usage('active', plan: 'free'))
              .toEntity()
              .operationsBlocked,
          isTrue);
    });
  });
}
