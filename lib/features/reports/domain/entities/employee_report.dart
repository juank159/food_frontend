import 'package:equatable/equatable.dart';
import '../../../employees/domain/entities/employee.dart';

/// Employee Report Entity
///
/// Resumen del desempeño del equipo. El roster sale de `GET /users` y las
/// ventas/órdenes por empleado se calculan EN VIVO desde las órdenes del
/// mes (`GET /finance/employee-sales`, agrega por `created_by`) y se
/// inyectan en cada empleado en el datasource. No dependemos de contadores
/// en la tabla `users` (que no se mantienen). No hay sistema de rating, así
/// que `average_service_rating` queda null y la UI muestra ticket promedio.
class EmployeeReport extends Equatable {
  /// Empleados activos del tenant.
  final List<Employee> employees;

  const EmployeeReport({this.employees = const []});

  factory EmployeeReport.empty() => const EmployeeReport(employees: []);

  /// Cantidad total de empleados (activos + suspendidos + inactivos).
  int get totalEmployees => employees.length;

  /// Cantidad de empleados activos.
  int get activeEmployees =>
      employees.where((e) => e.isActive).length;

  /// Suma de ventas atribuidas a cualquier empleado del equipo.
  double get teamSales =>
      employees.fold<double>(0, (acc, e) => acc + e.totalSalesAmount);

  /// Suma de órdenes manejadas por el equipo.
  int get teamOrders =>
      employees.fold<int>(0, (acc, e) => acc + e.totalOrdersHandled);

  /// Rating promedio del equipo (sólo cuenta empleados con rating).
  double get teamAverageRating {
    final rated = employees
        .where((e) => e.averageServiceRating != null)
        .toList();
    if (rated.isEmpty) return 0;
    final sum = rated.fold<double>(
      0,
      (acc, e) => acc + (e.averageServiceRating ?? 0),
    );
    return sum / rated.length;
  }

  /// Empleado con mayor `total_sales_amount` — la "estrella" del equipo.
  Employee? get topSeller {
    if (employees.isEmpty) return null;
    final sorted = [...employees]
      ..sort((a, b) => b.totalSalesAmount.compareTo(a.totalSalesAmount));
    return sorted.first;
  }

  /// Empleados ordenados por ventas descendente (ranking principal).
  List<Employee> get rankedBySales {
    final list = [...employees]
      ..sort((a, b) => b.totalSalesAmount.compareTo(a.totalSalesAmount));
    return list;
  }

  @override
  List<Object?> get props => [employees];
}
