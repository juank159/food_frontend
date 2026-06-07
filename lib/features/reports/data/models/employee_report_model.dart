import '../../../employees/data/models/employee_model.dart';
import '../../../employees/domain/entities/employee.dart';
import '../../domain/entities/employee_report.dart';

/// Employee Report Model
///
/// Wrapper sobre la lista de empleados devuelta por `GET /users`. Se
/// envuelve para mantener simetría con el resto de los modelos del
/// módulo de reportes — el armado del ranking y los KPIs se delega a
/// la entidad de dominio.
class EmployeeReportModel {
  final List<EmployeeModel> employees;

  EmployeeReportModel({required this.employees});

  EmployeeReport toEntity() {
    final list = employees.map<Employee>((m) => m.toEntity()).toList();
    return EmployeeReport(employees: list);
  }
}
