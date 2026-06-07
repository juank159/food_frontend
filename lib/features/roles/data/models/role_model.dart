import '../../domain/entities/role.dart';

class RoleModel {
  final String id;
  final String name;
  final String code;
  final String? description;
  final Map<String, dynamic> permissionsRaw;
  final bool isActive;
  final bool isSystem;
  final int sortOrder;

  const RoleModel({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    required this.permissionsRaw,
    required this.isActive,
    required this.isSystem,
    required this.sortOrder,
  });

  factory RoleModel.fromJson(Map<String, dynamic> json) {
    return RoleModel(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      description: json['description'] as String?,
      permissionsRaw:
          (json['permissions'] as Map<String, dynamic>?) ?? const {},
      isActive: (json['is_active'] as bool?) ?? true,
      isSystem: (json['is_system'] as bool?) ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Role toEntity() {
    final perms = <String, List<String>>{};
    permissionsRaw.forEach((k, v) {
      if (v is List) {
        perms[k] = v.whereType<String>().toList();
      }
    });
    return Role(
      id: id,
      name: name,
      code: code,
      description: description,
      permissions: perms,
      isActive: isActive,
      isSystem: isSystem,
      sortOrder: sortOrder,
    );
  }
}
