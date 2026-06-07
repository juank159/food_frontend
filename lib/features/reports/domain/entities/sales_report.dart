import 'package:equatable/equatable.dart';

/// Sales Report Entity
///
/// Representa el resultado del endpoint `GET /orders/statistics`. Reúne
/// los KPIs principales del módulo de ventas (ingresos, ticket promedio,
/// distribución por estado y por tipo de orden) en una sola estructura
/// inmutable apta para alimentar la pantalla de Reporte de Ventas.
class SalesReport extends Equatable {
  /// Cantidad total de órdenes incluidas en el rango.
  final int totalOrders;

  /// Suma del `total_amount` de las órdenes del rango (en la moneda local).
  final double totalRevenue;

  /// Ticket promedio (`totalRevenue / totalOrders`).
  final double averageOrderValue;

  /// Distribución de órdenes por estado (`pending`, `completed`,
  /// `cancelled`, etc.). Llave: `OrderStatus.value` (string del backend).
  final Map<String, int> byStatus;

  /// Distribución de órdenes por tipo (`dine_in`, `takeaway`, `delivery`).
  /// Llave: `OrderType.value`.
  final Map<String, int> byType;

  /// Inicio del rango consultado (informativo — el backend no lo retorna
  /// en el body, pero lo guardamos para mostrar el header de la página).
  final DateTime? dateFrom;

  /// Fin del rango consultado.
  final DateTime? dateTo;

  const SalesReport({
    required this.totalOrders,
    required this.totalRevenue,
    required this.averageOrderValue,
    required this.byStatus,
    required this.byType,
    this.dateFrom,
    this.dateTo,
  });

  /// Reporte vacío — útil como valor inicial del controller antes del
  /// primer `load()`.
  factory SalesReport.empty() => const SalesReport(
        totalOrders: 0,
        totalRevenue: 0,
        averageOrderValue: 0,
        byStatus: {},
        byType: {},
      );

  /// Cantidad de órdenes completadas en el rango.
  int get completedCount => byStatus['completed'] ?? 0;

  /// Cantidad de órdenes canceladas en el rango.
  int get cancelledCount => byStatus['cancelled'] ?? 0;

  /// Cantidad de órdenes activas (cualquier estado distinto a completed
  /// y cancelled).
  int get activeCount {
    var sum = 0;
    byStatus.forEach((status, count) {
      if (status != 'completed' && status != 'cancelled') sum += count;
    });
    return sum;
  }

  @override
  List<Object?> get props => [
        totalOrders,
        totalRevenue,
        averageOrderValue,
        byStatus,
        byType,
        dateFrom,
        dateTo,
      ];
}
