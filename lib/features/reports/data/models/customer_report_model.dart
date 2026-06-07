import '../../../customers/data/models/customer_model.dart';
import '../../../customers/data/models/customer_statistics_model.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../domain/entities/customer_report.dart';

/// Customer Report Model
///
/// Combina el modelo de estadísticas globales (`GET /customers/statistics`)
/// con la lista de clientes (`GET /customers`). El reporte combinado se
/// arma 100% client-side: sólo necesitamos los dos endpoints existentes.
class CustomerReportModel {
  final CustomerStatisticsModel statistics;
  final List<CustomerModel> customers;

  CustomerReportModel({
    required this.statistics,
    required this.customers,
  });

  CustomerReport toEntity() {
    final list = customers.map<Customer>((m) => m.toEntity()).toList();
    return CustomerReport(
      statistics: statistics.toEntity(),
      customers: list,
    );
  }
}
