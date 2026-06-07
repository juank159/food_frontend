import 'package:equatable/equatable.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../customers/domain/entities/customer_statistics.dart';

/// Customer Report Entity
///
/// Combina los KPIs globales devueltos por `GET /customers/statistics`
/// con la lista enriquecida obtenida de `GET /customers`. El backend ya
/// mantiene contadores agregados por cliente (`total_orders`,
/// `total_spent`, `last_order_date`) que actualiza al cerrar cada orden,
/// así que el reporte se compone con un par de llamadas y todo el
/// procesamiento (top spender, nuevos del mes, ranking) se hace acá.
class CustomerReport extends Equatable {
  /// KPIs globales del tenant (totales, promedios).
  final CustomerStatistics statistics;

  /// Lista de clientes para el ranking.
  final List<Customer> customers;

  const CustomerReport({
    required this.statistics,
    this.customers = const [],
  });

  factory CustomerReport.empty() => CustomerReport(
        statistics: CustomerStatistics.empty(),
        customers: const [],
      );

  /// Total de clientes del tenant (viene de las estadísticas globales).
  int get totalCustomers => statistics.totalCustomers;

  /// Cantidad de clientes creados durante el mes en curso.
  int get newThisMonth =>
      customers.where((c) => c.isNewThisMonth).length;

  /// Promedio de gasto por cliente (de las estadísticas globales).
  double get averageSpend => statistics.averageRevenuePerCustomer;

  /// Cliente con mayor `total_spent`.
  Customer? get topSpender {
    if (customers.isEmpty) return null;
    final sorted = [...customers]
      ..sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
    return sorted.first;
  }

  /// Clientes ordenados por monto gastado descendente — ranking de la
  /// pantalla.
  List<Customer> get rankedBySpend {
    final list = [...customers]
      ..sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
    return list;
  }

  @override
  List<Object?> get props => [statistics, customers];
}
