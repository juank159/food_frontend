import 'package:equatable/equatable.dart';
import 'employee_role.dart';

/// Estado de un empleado, calcado de `UserStatus` del backend.
enum EmployeeStatus {
  active('active'),
  inactive('inactive'),
  suspended('suspended');

  final String value;
  const EmployeeStatus(this.value);

  static EmployeeStatus fromValue(String? raw) {
    switch (raw) {
      case 'active':
        return EmployeeStatus.active;
      case 'suspended':
        return EmployeeStatus.suspended;
      case 'inactive':
        return EmployeeStatus.inactive;
      default:
        return EmployeeStatus.active;
    }
  }

  String get displayName {
    switch (this) {
      case EmployeeStatus.active:
        return 'Activo';
      case EmployeeStatus.inactive:
        return 'Inactivo';
      case EmployeeStatus.suspended:
        return 'Suspendido';
    }
  }
}

/// Empleado del restaurante. En el backend se serializa como `User` —
/// acá lo modelamos como `Employee` para que el feature hable el lenguaje
/// del producto, no el del schema.
class Employee extends Equatable {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final EmployeeStatus status;
  final DateTime? lastLogin;

  // Datos laborales
  final String? employeeCode;
  final DateTime? hireDate;
  final double? salary;
  final String? notes;

  // Relación con rol
  final String roleId;
  final EmployeeRole? role;

  // Métricas (sólo lectura, vienen del backend)
  final int totalOrdersHandled;
  final double totalSalesAmount;
  final double? averageServiceRating;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Employee({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.avatarUrl,
    required this.status,
    this.lastLogin,
    this.employeeCode,
    this.hireDate,
    this.salary,
    this.notes,
    required this.roleId,
    this.role,
    this.totalOrdersHandled = 0,
    this.totalSalesAmount = 0,
    this.averageServiceRating,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == EmployeeStatus.active;
  bool get isSuspended => status == EmployeeStatus.suspended;
  bool get isInactive => status == EmployeeStatus.inactive;

  /// Iniciales para el avatar — máximo 2 letras.
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    final first = parts.first.substring(0, 1);
    final last = parts.last.substring(0, 1);
    return (first + last).toUpperCase();
  }

  /// Primer nombre — usado en algunos chips compactos.
  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : fullName;
  }

  /// Apellido — pesa de derecha a izquierda. Sirve para split en el form.
  String get lastName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length <= 1) return '';
    return parts.sublist(1).join(' ');
  }

  Employee copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    String? avatarUrl,
    EmployeeStatus? status,
    DateTime? lastLogin,
    String? employeeCode,
    DateTime? hireDate,
    double? salary,
    String? notes,
    String? roleId,
    EmployeeRole? role,
    int? totalOrdersHandled,
    double? totalSalesAmount,
    double? averageServiceRating,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Employee(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      lastLogin: lastLogin ?? this.lastLogin,
      employeeCode: employeeCode ?? this.employeeCode,
      hireDate: hireDate ?? this.hireDate,
      salary: salary ?? this.salary,
      notes: notes ?? this.notes,
      roleId: roleId ?? this.roleId,
      role: role ?? this.role,
      totalOrdersHandled: totalOrdersHandled ?? this.totalOrdersHandled,
      totalSalesAmount: totalSalesAmount ?? this.totalSalesAmount,
      averageServiceRating: averageServiceRating ?? this.averageServiceRating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        fullName,
        phone,
        avatarUrl,
        status,
        lastLogin,
        employeeCode,
        hireDate,
        salary,
        notes,
        roleId,
        role,
        totalOrdersHandled,
        totalSalesAmount,
        averageServiceRating,
        createdAt,
        updatedAt,
      ];
}
