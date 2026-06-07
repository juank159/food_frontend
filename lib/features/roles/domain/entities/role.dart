import 'package:equatable/equatable.dart';

/// Rol del sistema con sus permisos asociados.
///
/// `permissions` es un mapa agrupado por recurso: cada clave es un
/// recurso (orders, payments, ...) y el valor la lista de acciones
/// permitidas (`['create', 'read', 'refund']`).
///
/// `isSystem=true` significa que el rol viene del seed (admin, manager,
/// cashier, etc.) y NO se puede eliminar. Se puede editar el nombre
/// y los permisos, pero el código queda fijo.
class Role extends Equatable {
  final String id;
  final String name;
  final String code;
  final String? description;
  final Map<String, List<String>> permissions;
  final bool isActive;
  final bool isSystem;
  final int sortOrder;

  const Role({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    required this.permissions,
    required this.isActive,
    required this.isSystem,
    required this.sortOrder,
  });

  /// True si el rol tiene esta acción para un recurso dado.
  bool can(String resource, String action) {
    final actions = permissions[resource];
    if (actions == null) return false;
    return actions.contains(action);
  }

  /// Total de acciones habilitadas — para mostrar en la lista
  /// "5 permisos otorgados".
  int get totalPermissions {
    return permissions.values.fold(0, (sum, a) => sum + a.length);
  }

  Role copyWith({
    String? id,
    String? name,
    String? code,
    String? description,
    Map<String, List<String>>? permissions,
    bool? isActive,
    bool? isSystem,
    int? sortOrder,
  }) {
    return Role(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      permissions: permissions ?? this.permissions,
      isActive: isActive ?? this.isActive,
      isSystem: isSystem ?? this.isSystem,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        code,
        description,
        permissions,
        isActive,
        isSystem,
        sortOrder,
      ];
}

/// Catálogo CANÓNICO de permisos disponibles. La UI del editor lo usa
/// para renderizar el checklist agrupado por categoría.
///
/// Cada entrada describe un recurso con sus acciones posibles y un
/// label legible. Si el backend agrega un permiso nuevo, hay que
/// reflejarlo acá (por ahora no se descubre dinámico — sería deuda
/// futura cuando los permisos sean realmente extensibles).
class PermissionCatalog {
  static const List<PermissionResource> resources = [
    PermissionResource(
      key: 'orders',
      label: 'Órdenes',
      icon: 'receipt_long',
      actions: [
        PermissionAction('create', 'Crear'),
        PermissionAction('read', 'Ver'),
        PermissionAction('update', 'Editar'),
        PermissionAction('cancel', 'Cancelar'),
      ],
    ),
    PermissionResource(
      key: 'menu',
      label: 'Menú / Productos',
      icon: 'restaurant_menu',
      actions: [
        PermissionAction('create', 'Crear'),
        PermissionAction('read', 'Ver'),
        PermissionAction('update', 'Editar'),
        PermissionAction('delete', 'Eliminar'),
      ],
    ),
    PermissionResource(
      key: 'payments',
      label: 'Pagos',
      icon: 'payments',
      actions: [
        PermissionAction('create', 'Cobrar'),
        PermissionAction('read', 'Ver'),
        PermissionAction('refund', 'Reembolsar'),
      ],
    ),
    PermissionResource(
      key: 'reports',
      label: 'Reportes',
      icon: 'insights',
      actions: [
        PermissionAction('read', 'Ver'),
        PermissionAction('export', 'Exportar'),
      ],
    ),
    PermissionResource(
      key: 'tables',
      label: 'Mesas',
      icon: 'table_restaurant',
      actions: [
        PermissionAction('read', 'Ver'),
        PermissionAction('update', 'Cambiar estado'),
      ],
    ),
    PermissionResource(
      key: 'customers',
      label: 'Clientes',
      icon: 'people',
      actions: [
        PermissionAction('create', 'Crear'),
        PermissionAction('read', 'Ver'),
        PermissionAction('update', 'Editar'),
      ],
    ),
    PermissionResource(
      key: 'users',
      label: 'Equipo',
      icon: 'badge',
      actions: [
        PermissionAction('create', 'Crear'),
        PermissionAction('read', 'Ver'),
        PermissionAction('update', 'Editar'),
        PermissionAction('delete', 'Eliminar'),
      ],
    ),
    PermissionResource(
      key: 'delivery',
      label: 'Domicilios',
      icon: 'delivery_dining',
      actions: [
        PermissionAction('read', 'Ver'),
        PermissionAction('update', 'Cambiar estado'),
      ],
    ),
    PermissionResource(
      key: 'settings',
      label: 'Configuración',
      icon: 'settings',
      actions: [
        PermissionAction('read', 'Ver'),
        PermissionAction('update', 'Editar'),
      ],
    ),
  ];
}

class PermissionResource {
  final String key;
  final String label;
  final String icon;
  final List<PermissionAction> actions;

  const PermissionResource({
    required this.key,
    required this.label,
    required this.icon,
    required this.actions,
  });
}

class PermissionAction {
  final String key;
  final String label;

  const PermissionAction(this.key, this.label);
}
