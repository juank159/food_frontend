import 'package:equatable/equatable.dart';

/// User entity (Domain Layer)
/// This represents the business logic model
class User extends Equatable {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? phoneNumber;
  final String roleId;
  final String roleName;

  /// Código corto del rol — `admin`, `manager`, `cashier`, `waiter`,
  /// `kitchen`, `delivery`, `bartender`. Usado para filtrar el menú
  /// y secciones de la UI según el permiso del usuario. Puede ser
  /// `null` si el backend no lo devolvió (compat con tokens viejos).
  final String? roleCode;

  /// Permisos finos del rol — mapa `{ 'payments.refund': true,
  /// 'orders.void': false, ... }`. Viene del backend en
  /// `role.permissions` (JSONB). Si el rol no tiene permisos finos
  /// configurados (caso default), queda vacío y la app se rige solo
  /// por `roleCode`.
  final Map<String, bool> permissions;

  final String tenantId;
  final bool isActive;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phoneNumber,
    required this.roleId,
    required this.roleName,
    this.roleCode,
    this.permissions = const {},
    required this.tenantId,
    required this.isActive,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName';

  /// `true` si el usuario tiene rol administrativo (admin/manager).
  /// Lo usamos para mostrar/ocultar acciones sensibles en la UI.
  bool get isAdminOrManager =>
      roleCode == 'admin' || roleCode == 'manager';

  /// `true` si el usuario es admin (acceso total).
  bool get isAdmin => roleCode == 'admin';

  /// Verifica si el usuario tiene cualquiera de los roles dados.
  bool hasAnyRole(List<String> codes) {
    final c = roleCode;
    if (c == null) return false;
    return codes.contains(c);
  }

  /// Verifica un permiso fino. **Admin pasa siempre** — la matriz de
  /// permisos no aplica a admin (acceso total por diseño). Para los
  /// demás roles, mira el flag en `permissions`. Si no está definido,
  /// se considera denegado por defecto (seguro).
  bool hasPermission(String key) {
    if (isAdmin) return true;
    return permissions[key] == true;
  }

  /// `true` si tiene CUALQUIERA de los permisos listados (OR).
  bool hasAnyPermission(List<String> keys) {
    if (isAdmin) return true;
    return keys.any((k) => permissions[k] == true);
  }

  @override
  List<Object?> get props => [
        id,
        email,
        firstName,
        lastName,
        phoneNumber,
        roleId,
        roleName,
        roleCode,
        permissions,
        tenantId,
        isActive,
        createdAt,
      ];
}
