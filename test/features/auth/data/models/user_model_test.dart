import 'package:flutter_test/flutter_test.dart';
import 'package:food_platform_app/features/auth/data/models/user_model.dart';
import 'package:food_platform_app/features/auth/domain/entities/user.dart';

/// Tests del normalizador de permisos en UserModel.
///
/// El backend manda permisos en formato AGRUPADO por recurso:
///   `{ orders: ['create','read'], payments: ['refund'] }`
///
/// La UI consume formato PLANO `{ 'orders.create': true, ... }` para
/// que `hasPermission('orders.create')` sea O(1).
///
/// El normalizador convierte agrupado → plano + también acepta plano
/// directo (legado / casos especiales) sin romperse.
void main() {
  /// Helper para invocar el método estático privado vía un user mínimo.
  User toUser(Map<String, dynamic>? permissions) {
    final model = UserModel(
      id: 'u1',
      email: 'a@b.c',
      firstName: 'A',
      lastName: 'B',
      roleId: 'r1',
      role: RoleModel(
        id: 'r1',
        name: 'Test',
        code: 'cashier',
        permissions: permissions,
      ),
      tenantId: 't1',
      isActive: true,
      createdAt: DateTime(2026).toIso8601String(),
    );
    return model.toEntity();
  }

  group('UserModel permissions normalization', () {
    test('formato agrupado (backend real) → plano resource.action=true', () {
      final user = toUser({
        'orders': ['create', 'read'],
        'payments': ['refund'],
      });
      expect(user.permissions['orders.create'], isTrue);
      expect(user.permissions['orders.read'], isTrue);
      expect(user.permissions['payments.refund'], isTrue);
      expect(user.permissions.length, 3);
    });

    test('formato plano boolean directo → mantiene', () {
      final user = toUser({
        'orders.create': true,
        'payments.refund': false,
      });
      expect(user.permissions['orders.create'], isTrue);
      expect(user.permissions['payments.refund'], isFalse);
    });

    test('mix agrupado + plano funciona', () {
      final user = toUser({
        'orders': ['create'],
        'overrides.foo': true,
      });
      expect(user.permissions['orders.create'], isTrue);
      expect(user.permissions['overrides.foo'], isTrue);
    });

    test('null → mapa vacío', () {
      final user = toUser(null);
      expect(user.permissions, isEmpty);
    });

    test('vacío → mapa vacío', () {
      final user = toUser({});
      expect(user.permissions, isEmpty);
    });

    test('valores extraños se ignoran sin crashear', () {
      final user = toUser({
        'orders': ['read'],
        'weirdo': 42, // num
        'another': 'yes', // string truthy
        'broken': {'nested': true}, // mapa nested → ignorar
      });
      expect(user.permissions['orders.read'], isTrue);
      expect(user.permissions['weirdo'], isTrue); // num != 0 → true
      expect(user.permissions['another'], isTrue); // 'yes' → true
      expect(user.permissions.containsKey('broken'), isFalse);
    });

    test('hasPermission funciona end-to-end con formato real', () {
      final user = toUser({
        'payments': ['refund', 'read'],
      });
      expect(user.hasPermission('payments.refund'), isTrue);
      expect(user.hasPermission('payments.read'), isTrue);
      expect(user.hasPermission('payments.delete'), isFalse);
    });
  });
}
