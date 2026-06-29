import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/customer_report.dart';
import '../entities/employee_report.dart';
import '../entities/inventory_report.dart';
import '../entities/product_sales_report.dart';
import '../entities/sales_report.dart';

/// Reports Repository
///
/// Contrato del repositorio de reportes. Expone los cuatro reportes del
/// hub de Reportes — ventas, inventario, empleados y clientes — cada uno
/// con su propia firma. La implementación reusa endpoints existentes
/// del backend para no requerir nuevos servicios.
abstract class ReportsRepository {
  /// Obtiene el reporte de ventas del rango indicado.
  ///
  /// `dateFrom` y `dateTo` son opcionales: si no se proveen, el backend
  /// devuelve estadísticas globales sin filtrar por fecha.
  Future<Either<Failure, SalesReport>> getSalesReport({
    DateTime? dateFrom,
    DateTime? dateTo,
  });

  /// Reporte de inventario — listado de productos con seguimiento y
  /// KPIs derivados de su stock actual. No tiene filtros de fecha
  /// porque es un snapshot del estado vigente.
  Future<Either<Failure, InventoryReport>> getInventoryReport();

  /// Reporte de empleados — ranking por ventas y KPIs del equipo.
  Future<Either<Failure, EmployeeReport>> getEmployeeReport();

  /// Reporte de clientes — KPIs globales + top spenders.
  Future<Either<Failure, CustomerReport>> getCustomerReport();

  /// Ranking de productos más vendidos en el período indicado.
  Future<Either<Failure, ProductSalesReport>> getProductSalesReport({
    required DateTime dateFrom,
    required DateTime dateTo,
  });
}
