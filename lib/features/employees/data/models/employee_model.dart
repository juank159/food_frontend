import '../../domain/entities/employee.dart';
import '../../domain/entities/employee_role.dart';
import '../../../../core/utils/json_parsers.dart';
import 'package:json_annotation/json_annotation.dart';

/// Helper que parsea el rol embebido en la respuesta de un user.
EmployeeRole? _parseRole(dynamic raw) {
  if (raw == null) return null;
  if (raw is! Map<String, dynamic>) return null;
  return EmployeeRole(
    id: raw['id'] as String? ?? '',
    name: raw['name'] as String? ?? 'Sin rol',
    code: raw['code'] as String? ?? '',
    description: raw['description'] as String?,
    isActive: raw['is_active'] as bool? ?? true,
    isSystem: raw['is_system'] as bool? ?? false,
  );
}

DateTime _parseDate(dynamic raw, {DateTime? fallback}) {
  if (raw == null) return fallback ?? DateTime.now();
  if (raw is DateTime) return raw;
  return DateTime.tryParse(raw.toString()) ?? fallback ?? DateTime.now();
}

DateTime? _parseOptionalDate(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  return DateTime.tryParse(raw.toString());
}

double? _parseOptionalDouble(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw.toString());
}

/// Modelo de transporte para `User` del backend, decoupleado de la
/// entidad de dominio (`Employee`).
class EmployeeModel {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final String status;
  final DateTime? lastLogin;
  final String? employeeCode;
  final DateTime? hireDate;
  @JsonKey(fromJson: JsonParsers.parseNullableDouble)
  final double? salary;
  final String? notes;
  final String roleId;
  final EmployeeRole? role;
  final int totalOrdersHandled;
  @JsonKey(fromJson: JsonParsers.parseDouble)
  final double totalSalesAmount;
  @JsonKey(fromJson: JsonParsers.parseNullableDouble)
  final double? averageServiceRating;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EmployeeModel({
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

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      status: json['status'] as String? ?? 'active',
      lastLogin: _parseOptionalDate(json['last_login']),
      employeeCode: json['employee_code'] as String?,
      hireDate: _parseOptionalDate(json['hire_date']),
      salary: _parseOptionalDouble(json['salary']),
      notes: json['notes'] as String?,
      roleId: json['role_id'] as String? ?? '',
      role: _parseRole(json['role']),
      totalOrdersHandled: (json['total_orders_handled'] as num?)?.toInt() ?? 0,
      totalSalesAmount:
          _parseOptionalDouble(json['total_sales_amount']) ?? 0.0,
      averageServiceRating:
          _parseOptionalDouble(json['average_service_rating']),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'avatar_url': avatarUrl,
      'status': status,
      'last_login': lastLogin?.toIso8601String(),
      'employee_code': employeeCode,
      'hire_date': hireDate?.toIso8601String(),
      'salary': salary,
      'notes': notes,
      'role_id': roleId,
      'role': role == null
          ? null
          : {
              'id': role!.id,
              'name': role!.name,
              'code': role!.code,
              'description': role!.description,
              'is_active': role!.isActive,
              'is_system': role!.isSystem,
            },
      'total_orders_handled': totalOrdersHandled,
      'total_sales_amount': totalSalesAmount,
      'average_service_rating': averageServiceRating,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Employee toEntity() {
    return Employee(
      id: id,
      email: email,
      fullName: fullName,
      phone: phone,
      avatarUrl: avatarUrl,
      status: EmployeeStatus.fromValue(status),
      lastLogin: lastLogin,
      employeeCode: employeeCode,
      hireDate: hireDate,
      salary: salary,
      notes: notes,
      roleId: roleId,
      role: role,
      totalOrdersHandled: totalOrdersHandled,
      totalSalesAmount: totalSalesAmount,
      averageServiceRating: averageServiceRating,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
