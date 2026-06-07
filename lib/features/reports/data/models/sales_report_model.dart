import '../../domain/entities/sales_report.dart';
import '../../../../core/utils/json_parsers.dart';
import 'package:json_annotation/json_annotation.dart';

/// Sales Report Model
///
/// Mapea la respuesta de `GET /orders/statistics`. El backend retorna:
///
/// ```json
/// {
///   "total_orders": 42,
///   "total_revenue": 12345.67,
///   "average_order_value": 293.94,
///   "by_status": { "completed": 30, "cancelled": 2, ... },
///   "by_type": { "dine_in": 20, "takeaway": 15, "delivery": 7 }
/// }
/// ```
///
/// El parsing es defensivo: claves faltantes se interpretan como 0 y los
/// mapas se reducen a `Map<String, int>` aceptando ints, doubles o strings.
class SalesReportModel {
  final int totalOrders;
  @JsonKey(fromJson: JsonParsers.parseDouble)
  final double totalRevenue;
  @JsonKey(fromJson: JsonParsers.parseDouble)
  final double averageOrderValue;
  final Map<String, int> byStatus;
  final Map<String, int> byType;

  SalesReportModel({
    required this.totalOrders,
    required this.totalRevenue,
    required this.averageOrderValue,
    required this.byStatus,
    required this.byType,
  });

  factory SalesReportModel.fromJson(Map<String, dynamic> json) {
    return SalesReportModel(
      totalOrders: _parseInt(json['total_orders']),
      totalRevenue: _parseDouble(json['total_revenue']),
      averageOrderValue: _parseDouble(json['average_order_value']),
      byStatus: _parseIntMap(json['by_status']),
      byType: _parseIntMap(json['by_type']),
    );
  }

  /// Convierte el modelo en la entidad de dominio. Los rangos se
  /// inyectan acá porque el backend no los devuelve en el body.
  SalesReport toEntity({DateTime? dateFrom, DateTime? dateTo}) {
    return SalesReport(
      totalOrders: totalOrders,
      totalRevenue: totalRevenue,
      averageOrderValue: averageOrderValue,
      byStatus: byStatus,
      byType: byType,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static Map<String, int> _parseIntMap(dynamic value) {
    if (value is! Map) return const {};
    final result = <String, int>{};
    value.forEach((key, val) {
      result[key.toString()] = _parseInt(val);
    });
    return result;
  }
}
