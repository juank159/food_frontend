import 'package:equatable/equatable.dart';

/// Customer Statistics Entity
///
/// Resumen agregado devuelto por `GET /customers/statistics`. Lo usa
/// `CustomersPage` para alimentar las KPI chips del header.
class CustomerStatistics extends Equatable {
  final int totalCustomers;
  final int activeCustomers;
  final int inactiveCustomers;
  final int totalOrders;
  final double totalRevenue;
  final double averageOrdersPerCustomer;
  final double averageRevenuePerCustomer;

  const CustomerStatistics({
    required this.totalCustomers,
    required this.activeCustomers,
    required this.inactiveCustomers,
    required this.totalOrders,
    required this.totalRevenue,
    required this.averageOrdersPerCustomer,
    required this.averageRevenuePerCustomer,
  });

  /// Estadísticas vacías — placeholder antes de la primera carga, así los
  /// chips de KPIs no parpadean entre `null` y "0".
  factory CustomerStatistics.empty() {
    return const CustomerStatistics(
      totalCustomers: 0,
      activeCustomers: 0,
      inactiveCustomers: 0,
      totalOrders: 0,
      totalRevenue: 0,
      averageOrdersPerCustomer: 0,
      averageRevenuePerCustomer: 0,
    );
  }

  @override
  List<Object?> get props => [
        totalCustomers,
        activeCustomers,
        inactiveCustomers,
        totalOrders,
        totalRevenue,
        averageOrdersPerCustomer,
        averageRevenuePerCustomer,
      ];
}
