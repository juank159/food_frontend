import 'package:dio/dio.dart';
import '../../../../core/config/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../customers/data/models/customer_model.dart';
import '../../../customers/data/models/customer_statistics_model.dart';
import '../../../employees/data/models/employee_model.dart';
import '../../../products/data/models/product_model.dart';
import '../models/customer_report_model.dart';
import '../models/employee_report_model.dart';
import '../models/inventory_report_model.dart';
import '../models/sales_report_model.dart';

/// Reports Remote Data Source
///
/// Encapsula los llamados HTTP del módulo de reportes. Cada método
/// reusa endpoints existentes del backend (no se introducen nuevos):
///
///   * Sales → `GET /orders/statistics`
///   * Inventory → `GET /products?is_available=true`
///   * Employees → `GET /users`
///   * Customers → `GET /customers/statistics` + `GET /customers`
abstract class ReportsRemoteDataSource {
  /// Llama a `GET /orders/statistics?date_from=&date_to=` y devuelve el
  /// modelo crudo. Las fechas se serializan en ISO-8601 (sólo la parte
  /// de fecha, sin hora) para coincidir con la convención del backend.
  Future<SalesReportModel> getSalesReport({
    DateTime? dateFrom,
    DateTime? dateTo,
  });

  /// Llama a `GET /products?is_available=true` y devuelve los productos
  /// crudos para que la capa de dominio filtre los trackeados.
  Future<InventoryReportModel> getInventoryReport();

  /// Llama a `GET /users` y devuelve la lista de empleados con sus
  /// métricas agregadas (`total_orders_handled`, `total_sales_amount`,
  /// `average_service_rating`).
  Future<EmployeeReportModel> getEmployeeReport();

  /// Llama a `GET /customers/statistics` y `GET /customers` en paralelo
  /// para componer el reporte combinado.
  Future<CustomerReportModel> getCustomerReport();
}

class ReportsRemoteDataSourceImpl implements ReportsRemoteDataSource {
  final Dio dio;

  ReportsRemoteDataSourceImpl({required this.dio});

  @override
  Future<SalesReportModel> getSalesReport({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (dateFrom != null) {
        queryParams['date_from'] = _formatDate(dateFrom);
      }
      if (dateTo != null) {
        queryParams['date_to'] = _formatDate(dateTo);
      }

      final response = await dio.get(
        '${ApiConstants.orders}/statistics',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        // El backend puede envolver la respuesta en `data` (estilo POS) o
        // mandarla raw — soportamos ambos para ser defensivos.
        final dynamic raw = response.data;
        final Map<String, dynamic> data;
        if (raw is Map<String, dynamic> && raw['data'] is Map) {
          data = (raw['data'] as Map).cast<String, dynamic>();
        } else if (raw is Map<String, dynamic>) {
          data = raw;
        } else {
          throw ServerException('Unexpected statistics response format');
        }
        return SalesReportModel.fromJson(data);
      } else {
        throw ServerException('Failed to load sales report');
      }
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<InventoryReportModel> getInventoryReport() async {
    try {
      // Pedimos sólo productos disponibles — los descontinuados no aportan
      // al reporte de stock vigente. Subimos el `limit` para no perder
      // productos en catálogos grandes.
      final response = await dio.get(
        ApiConstants.products,
        queryParameters: <String, dynamic>{
          'is_available': true,
          'limit': 500,
        },
      );

      if (response.statusCode != 200) {
        throw ServerException('Failed to load inventory report');
      }

      final list = _extractList(response.data);
      final products = list
          .whereType<Map<String, dynamic>>()
          .map(ProductModel.fromJson)
          .toList();
      return InventoryReportModel(products: products);
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<EmployeeReportModel> getEmployeeReport() async {
    try {
      final response = await dio.get(ApiConstants.users);
      if (response.statusCode != 200) {
        throw ServerException('Failed to load employee report');
      }
      final list = _extractList(response.data);
      final employees = list
          .whereType<Map<String, dynamic>>()
          .map(EmployeeModel.fromJson)
          .toList();
      return EmployeeReportModel(employees: employees);
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  @override
  Future<CustomerReportModel> getCustomerReport() async {
    try {
      // Las dos llamadas son independientes — las disparamos en paralelo
      // para reducir el tiempo total de carga del reporte.
      final results = await Future.wait([
        dio.get('${ApiConstants.customers}/statistics'),
        dio.get(ApiConstants.customers),
      ]);

      final statsResponse = results[0];
      final customersResponse = results[1];

      if (statsResponse.statusCode != 200 ||
          customersResponse.statusCode != 200) {
        throw ServerException('Failed to load customer report');
      }

      final statsRaw = _extractMap(statsResponse.data);
      final stats = CustomerStatisticsModel.fromJson(statsRaw);

      final list = _extractList(customersResponse.data);
      final customers = list
          .whereType<Map<String, dynamic>>()
          .map(CustomerModel.fromJson)
          .toList();

      return CustomerReportModel(statistics: stats, customers: customers);
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  // ─────────────────────────── Helpers ───────────────────────────

  /// Extrae una lista de un payload que puede venir como `List` directo
  /// o envuelto en `{data: [...]}` (formatos coexisten en el backend).
  List<dynamic> _extractList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is List) return data;
    }
    return const [];
  }

  /// Extrae un objeto de un payload que puede venir plano o envuelto en
  /// `{data: {...}}`.
  Map<String, dynamic> _extractMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is Map<String, dynamic>) return data;
      return raw;
    }
    return const {};
  }

  /// Formatea como `YYYY-MM-DD` — el backend acepta sólo fecha sin hora
  /// para los filtros del rango.
  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  void _handleDioException(DioException e) {
    if (e.response?.statusCode == 401) {
      throw UnauthorizedException('Unauthorized');
    } else if (e.response?.statusCode == 404) {
      throw NotFoundException('Statistics not found');
    } else if (e.response?.statusCode == 400) {
      final message = e.response?.data is Map
          ? (e.response?.data['message']?.toString() ?? 'Bad request')
          : 'Bad request';
      throw ValidationException(message);
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw NetworkException('Connection timeout');
    } else if (e.type == DioExceptionType.unknown) {
      throw NetworkException('Network error: ${e.message}');
    } else {
      final fallback = e.response?.data is Map
          ? (e.response?.data['message']?.toString() ??
              'Server error occurred')
          : 'Server error occurred';
      throw ServerException(fallback);
    }
  }
}
