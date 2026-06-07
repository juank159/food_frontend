import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/user.dart';

part 'user_model.g.dart';

/// User Model (Data Layer)
/// Handles JSON serialization/deserialization
@JsonSerializable()
class UserModel {
  final String id;
  final String email;
  @JsonKey(name: 'first_name')
  final String firstName;
  @JsonKey(name: 'last_name')
  final String lastName;
  @JsonKey(name: 'phone_number')
  final String? phoneNumber;
  @JsonKey(name: 'role_id')
  final String roleId;
  @JsonKey(name: 'role')
  final RoleModel role;
  @JsonKey(name: 'tenant_id')
  final String tenantId;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'created_at')
  final String createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phoneNumber,
    required this.roleId,
    required this.role,
    required this.tenantId,
    required this.isActive,
    required this.createdAt,
  });

  /// From JSON
  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  /// To JSON
  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  /// Convert Model to Entity
  User toEntity() {
    return User(
      id: id,
      email: email,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      roleId: roleId,
      roleName: role.name,
      roleCode: role.code,
      permissions: _normalizePermissions(role.permissions),
      tenantId: tenantId,
      isActive: isActive,
      createdAt: DateTime.parse(createdAt),
    );
  }

  /// Normaliza permisos del backend a un mapa plano `{ 'resource.action':
  /// true, ... }` para que el guard del frontend pueda chequearlos con
  /// `user.hasPermission('payments.refund')`.
  ///
  /// Soporta dos formatos de entrada:
  ///   1. Agrupado por recurso (formato real del backend):
  ///      `{ orders: ['create','read'], payments: ['refund'] }`
  ///      → `{ 'orders.create': true, 'orders.read': true, 'payments.refund': true }`
  ///   2. Plano boolean (legado / futuro):
  ///      `{ 'orders.create': true, 'payments.refund': false }`
  ///      → tal cual.
  ///
  /// Combinaciones mixtas también funcionan. Null → mapa vacío.
  static Map<String, bool> _normalizePermissions(
    Map<String, dynamic>? raw,
  ) {
    if (raw == null) return const {};
    final out = <String, bool>{};
    raw.forEach((k, v) {
      if (v is List) {
        // Formato agrupado: explotar por acción.
        for (final action in v) {
          if (action is String && action.isNotEmpty) {
            out['$k.$action'] = true;
          }
        }
      } else if (v is bool) {
        out[k] = v;
      } else if (v is num) {
        out[k] = v != 0;
      } else if (v is String) {
        final lower = v.toLowerCase();
        out[k] = lower == 'true' || lower == '1' || lower == 'yes';
      }
    });
    return out;
  }

  /// Convert Entity to Model
  factory UserModel.fromEntity(User user) {
    return UserModel(
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      phoneNumber: user.phoneNumber,
      roleId: user.roleId,
      role: RoleModel(
        id: user.roleId,
        name: user.roleName,
        code: user.roleCode,
      ),
      tenantId: user.tenantId,
      isActive: user.isActive,
      createdAt: user.createdAt.toIso8601String(),
    );
  }
}

@JsonSerializable()
class RoleModel {
  final String id;
  final String name;
  final String? code;

  /// Matriz de permisos finos del rol. JSONB en backend:
  /// `{ 'payments.refund': true, 'orders.void': false, ... }`. Si el
  /// rol no tiene permisos configurados (rol default del seed), llega
  /// null y el frontend solo se rige por `code`.
  final Map<String, dynamic>? permissions;

  RoleModel({
    required this.id,
    required this.name,
    this.code,
    this.permissions,
  });

  factory RoleModel.fromJson(Map<String, dynamic> json) =>
      _$RoleModelFromJson(json);

  Map<String, dynamic> toJson() => _$RoleModelToJson(this);
}
