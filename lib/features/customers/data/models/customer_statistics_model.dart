import '../../domain/entities/customer_statistics.dart';
import '../../../../core/utils/json_parsers.dart';
import 'package:json_annotation/json_annotation.dart';

/// Customer Statistics Model — mapea la respuesta de
/// `GET /customers/statistics`. Los promedios pueden venir como decimales
/// con string desde el backend (NUMERIC).
class CustomerStatisticsModel {
  final int totalCustomers;
  final int activeCustomers;
  final int inactiveCustomers;
  final int totalOrders;
  @JsonKey(fromJson: JsonParsers.parseDouble)
  final double totalRevenue;
  @JsonKey(fromJson: JsonParsers.parseDouble)
  final double averageOrdersPerCustomer;
  @JsonKey(fromJson: JsonParsers.parseDouble)
  final double averageRevenuePerCustomer;

  const CustomerStatisticsModel({
    required this.totalCustomers,
    required this.activeCustomers,
    required this.inactiveCustomers,
    required this.totalOrders,
    required this.totalRevenue,
    required this.averageOrdersPerCustomer,
    required this.averageRevenuePerCustomer,
  });

  CustomerStatistics toEntity() {
    return CustomerStatistics(
      totalCustomers: totalCustomers,
      activeCustomers: activeCustomers,
      inactiveCustomers: inactiveCustomers,
      totalOrders: totalOrders,
      totalRevenue: totalRevenue,
      averageOrdersPerCustomer: averageOrdersPerCustomer,
      averageRevenuePerCustomer: averageRevenuePerCustomer,
    );
  }

  factory CustomerStatisticsModel.fromJson(Map<String, dynamic> json) {
    double parseDecimal(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    return CustomerStatisticsModel(
      totalCustomers: parseInt(json['total_customers']),
      activeCustomers: parseInt(json['active_customers']),
      inactiveCustomers: parseInt(json['inactive_customers']),
      totalOrders: parseInt(json['total_orders']),
      totalRevenue: parseDecimal(json['total_revenue']),
      averageOrdersPerCustomer:
          parseDecimal(json['average_orders_per_customer']),
      averageRevenuePerCustomer:
          parseDecimal(json['average_revenue_per_customer']),
    );
  }
}
