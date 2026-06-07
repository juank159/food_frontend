import 'package:equatable/equatable.dart';

/// Rol asignado a un empleado.
///
/// El backend mantiene roles configurables por tenant (admin, cashier,
/// waiter, kitchen, delivery, bartender). El UI sólo necesita el id, el
/// nombre legible y el code para tintar chips.
class EmployeeRole extends Equatable {
  final String id;
  final String name;
  final String code;
  final String? description;
  final bool isActive;
  final bool isSystem;

  const EmployeeRole({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.isActive = true,
    this.isSystem = false,
  });

  @override
  List<Object?> get props => [id, name, code, description, isActive, isSystem];
}
