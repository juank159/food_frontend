import 'package:flutter_test/flutter_test.dart';
import 'package:food_platform_app/features/auth/domain/entities/user.dart';

/// Tests del entity `User` para la lógica de permisos finos.
/// Regla clave: **admin pasa siempre**, sin importar la matriz.
/// Otros roles solo pasan si el permiso está en true.
void main() {
  User build({
    String roleCode = 'cashier',
    Map<String, bool> permissions = const {},
  }) {
    return User(
      id: 'u1',
      email: 'a@b.c',
      firstName: 'A',
      lastName: 'B',
      roleId: 'r1',
      roleName: 'Cashier',
      roleCode: roleCode,
      permissions: permissions,
      tenantId: 't1',
      isActive: true,
      createdAt: DateTime(2026),
    );
  }

  group('User.hasPermission', () {
    test('admin pasa SIEMPRE aunque la matriz esté vacía', () {
      expect(
        build(roleCode: 'admin').hasPermission('payments.refund'),
        isTrue,
      );
    });

    test('admin pasa aunque el permiso explícitamente esté en false', () {
      expect(
        build(
          roleCode: 'admin',
          permissions: const {'payments.refund': false},
        ).hasPermission('payments.refund'),
        isTrue,
      );
    });

    test('cashier con permiso explícito true → pasa', () {
      expect(
        build(permissions: const {'payments.refund': true})
            .hasPermission('payments.refund'),
        isTrue,
      );
    });

    test('cashier con permiso false → bloqueado', () {
      expect(
        build(permissions: const {'payments.refund': false})
            .hasPermission('payments.refund'),
        isFalse,
      );
    });

    test('cashier sin entry para ese permiso → bloqueado (default deny)', () {
      expect(build().hasPermission('payments.refund'), isFalse);
    });

    test('roleCode null → default deny salvo admin', () {
      final u = User(
        id: 'u1',
        email: 'a@b.c',
        firstName: 'A',
        lastName: 'B',
        roleId: 'r1',
        roleName: 'Anonymous',
        roleCode: null,
        tenantId: 't1',
        isActive: true,
        createdAt: DateTime(2026),
      );
      expect(u.hasPermission('orders.create'), isFalse);
    });
  });

  group('User.hasAnyPermission', () {
    test('admin pasa con cualquier lista (incluso vacía)', () {
      expect(build(roleCode: 'admin').hasAnyPermission([]), isTrue);
      expect(
        build(roleCode: 'admin').hasAnyPermission(['x.y']),
        isTrue,
      );
    });

    test('cashier con AL MENOS UNO del listado en true → pasa', () {
      expect(
        build(
          permissions: const {
            'orders.create': true,
            'payments.refund': false,
          },
        ).hasAnyPermission(['payments.refund', 'orders.create']),
        isTrue,
      );
    });

    test('cashier con TODOS en false o ausentes → bloqueado', () {
      expect(
        build(permissions: const {'orders.read': true})
            .hasAnyPermission(['payments.refund', 'orders.delete']),
        isFalse,
      );
    });
  });

  group('User.isAdminOrManager', () {
    test('admin → true', () {
      expect(build(roleCode: 'admin').isAdminOrManager, isTrue);
    });
    test('manager → true', () {
      expect(build(roleCode: 'manager').isAdminOrManager, isTrue);
    });
    test('cashier → false', () {
      expect(build(roleCode: 'cashier').isAdminOrManager, isFalse);
    });
  });
}
